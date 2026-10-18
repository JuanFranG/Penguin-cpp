{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    Single instance. Opening a file while the IDE runs (from the file manager:
    penguin-cpp main.cpp) hands it to the running IDE instead of starting a
    second one. Dev-C++ did this with a Windows message (WM_COPYDATA); here
    the first IDE listens on a Unix socket in a folder only the user can
    enter ($XDG_RUNTIME_DIR, mode 0700), so no other user can send it files
    to open.
}

unit devInstance;

{$MODE DELPHI}

interface

uses
  Classes, SysUtils;

type
  TInstanceFilesEvent = procedure(Files: TStrings) of object;

// Sends Files (made absolute) to an IDE already running with the same
// settings file. True when one got them: this one should quit.
function SendToRunningInstance(const SettingsFile: String; Files: TStrings): Boolean;

// Listens for other starts of the IDE; OnFiles runs on the main thread (from
// PollInstanceServer, called by a timer), also with no files (to come to the front)
procedure StartInstanceServer(const SettingsFile: String; OnFiles: TInstanceFilesEvent);
procedure PollInstanceServer;
procedure StopInstanceServer;

implementation

{$IFDEF UNIX}
uses
  BaseUnix, Sockets, crc;

const
  Signature = 'PENGUIN-CPP-OPEN 1';
  MaxMessage = 1024 * 1024;

var
  ServerSocket: cint = -1;
  SocketFile: String = '';
  FilesEvent: TInstanceFilesEvent = nil;

// $XDG_RUNTIME_DIR/penguin-cpp-<settings>.sock, or the private cache folder.
// One per settings file: a portable copy or -c <folder> is another IDE.
function InstanceSocketFile(const SettingsFile: String): String;
var
  Dir: String;
begin
  Dir := GetEnvironmentVariable('XDG_RUNTIME_DIR');
  if (Dir = '') or not DirectoryExists(Dir) then begin
    Dir := GetEnvironmentVariable('XDG_CACHE_HOME');
    if Dir = '' then
      Dir := IncludeTrailingPathDelimiter(GetUserDir) + '.cache';
    Dir := IncludeTrailingPathDelimiter(Dir) + 'penguin-cpp' + PathDelim + 'tmp';
    if not ForceDirectories(Dir) or (FpChmod(Dir, &700) <> 0) then
      Exit('');
  end;
  Result := IncludeTrailingPathDelimiter(Dir) + 'penguin-cpp-' +
    IntToHex(crc32(0, PByte(PChar(SettingsFile)), Length(SettingsFile)), 8) + '.sock';
end;

function MakeAddress(const Path: String; out Addr: TUnixSockAddr; out Len: TSockLen): Boolean;
begin
  Result := (Path <> '') and (Length(Path) < SizeOf(Addr.path)); // sun_path holds 108 bytes
  if not Result then
    Exit;
  FillChar(Addr, SizeOf(Addr), 0);
  Addr.family := AF_UNIX;
  Move(Path[1], Addr.path[0], Length(Path));
  Len := SizeOf(Addr); // the path ends at its #0
end;

// A connected socket to the running IDE, or -1
function ConnectTo(const Path: String): cint;
var
  Addr: TUnixSockAddr;
  Len: TSockLen;
begin
  Result := -1;
  if not MakeAddress(Path, Addr, Len) then
    Exit;
  Result := fpSocket(AF_UNIX, SOCK_STREAM, 0);
  if Result < 0 then
    Exit;
  if fpConnect(Result, @Addr, Len) <> 0 then begin
    CloseSocket(Result);
    Result := -1;
  end;
end;

function WriteAll(Sock: cint; const Data: String): Boolean;
var
  Done, N: Integer;
begin
  Done := 0;
  while Done < Length(Data) do begin
    N := fpSend(Sock, @Data[Done + 1], Length(Data) - Done, 0);
    if N <= 0 then
      Exit(False);
    Inc(Done, N);
  end;
  Result := True;
end;

function SendToRunningInstance(const SettingsFile: String; Files: TStrings): Boolean;
var
  Sock: cint;
  Data: String;
  I: Integer;
begin
  Sock := ConnectTo(InstanceSocketFile(SettingsFile));
  Result := Sock >= 0;
  if not Result then
    Exit;
  try
    // The running IDE has another current folder: absolute names
    Data := Signature + #0;
    for I := 0 to Files.Count - 1 do
      Data := Data + ExpandFileName(Files[I]) + #0;
    Result := WriteAll(Sock, Data);
  finally
    CloseSocket(Sock);
  end;
end;

procedure StartInstanceServer(const SettingsFile: String; OnFiles: TInstanceFilesEvent);
var
  Addr: TUnixSockAddr;
  Len: TSockLen;
  Probe: cint;
begin
  StopInstanceServer;
  SocketFile := InstanceSocketFile(SettingsFile);
  if not MakeAddress(SocketFile, Addr, Len) then
    Exit; // no private folder, or a path too long for a socket: no single instance

  // A socket file nobody listens on is left over from an IDE that crashed
  Probe := ConnectTo(SocketFile);
  if Probe >= 0 then begin
    CloseSocket(Probe); // another IDE with these settings is running: leave it
    SocketFile := '';
    Exit;
  end;
  FpUnlink(SocketFile);

  ServerSocket := fpSocket(AF_UNIX, SOCK_STREAM, 0);
  if ServerSocket < 0 then
    Exit;
  if (fpBind(ServerSocket, @Addr, Len) <> 0) or (fpListen(ServerSocket, 5) <> 0) then begin
    CloseSocket(ServerSocket);
    ServerSocket := -1;
    Exit;
  end;
  FpChmod(SocketFile, &600);
  FpFcntl(ServerSocket, F_SETFL, FpFcntl(ServerSocket, F_GETFL, 0) or O_NONBLOCK);
  FilesEvent := OnFiles;
end;

// Reads what one client sent, with a time limit so a stuck client cannot
// freeze the IDE
function ReadMessage(Sock: cint): String;
var
  Buffer: array[0..4095] of Char;
  Chunk: String;
  N: Integer;
  TimeOut: TTimeVal;
begin
  Result := '';
  TimeOut.tv_sec := 1;
  TimeOut.tv_usec := 0;
  fpSetSockOpt(Sock, SOL_SOCKET, SO_RCVTIMEO, @TimeOut, SizeOf(TimeOut));
  repeat
    N := fpRecv(Sock, @Buffer[0], SizeOf(Buffer), 0);
    if N > 0 then begin
      SetString(Chunk, PChar(@Buffer[0]), N); // the names are separated by #0
      Result := Result + Chunk;
    end;
  until (N <= 0) or (Length(Result) > MaxMessage);
end;

procedure PollInstanceServer;
var
  Client: cint;
  Data: String;
  Files: TStringList;
  P: Integer;
begin
  if ServerSocket < 0 then
    Exit;
  Client := fpAccept(ServerSocket, nil, nil);
  if Client < 0 then
    Exit; // nobody (non-blocking)
  try
    // A blocking client socket, read with a time limit (ReadMessage)
    FpFcntl(Client, F_SETFL, FpFcntl(Client, F_GETFL, 0) and not O_NONBLOCK);
    Data := ReadMessage(Client);
  finally
    CloseSocket(Client);
  end;
  if Copy(Data, 1, Length(Signature) + 1) <> Signature + #0 then
    Exit; // not from another Penguin cpp
  Delete(Data, 1, Length(Signature) + 1);

  Files := TStringList.Create;
  try
    while Data <> '' do begin
      P := Pos(#0, Data);
      if P = 0 then
        P := Length(Data) + 1;
      if P > 1 then
        Files.Add(Copy(Data, 1, P - 1));
      Delete(Data, 1, P);
    end;
    if Assigned(FilesEvent) then
      FilesEvent(Files);
  finally
    Files.Free;
  end;
end;

procedure StopInstanceServer;
begin
  if ServerSocket >= 0 then begin
    CloseSocket(ServerSocket);
    ServerSocket := -1;
    if SocketFile <> '' then
      FpUnlink(SocketFile);
  end;
  SocketFile := '';
  FilesEvent := nil;
end;

{$ELSE}

function SendToRunningInstance(const SettingsFile: String; Files: TStrings): Boolean;
begin
  Result := False; // not implemented here
end;

procedure StartInstanceServer(const SettingsFile: String; OnFiles: TInstanceFilesEvent);
begin
end;

procedure PollInstanceServer;
begin
end;

procedure StopInstanceServer;
begin
end;

{$ENDIF}

end.
