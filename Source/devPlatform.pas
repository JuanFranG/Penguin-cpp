{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
}

unit devPlatform;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

// Operating system services the IDE needs, kept free of GUI units so they can
// be compiled and tested on their own (see Source/Tests/PlatformTest).
// Under Free Pascal everything goes through the RTL/FCL and works on Linux
// and Windows alike; the Delphi branch keeps the original Windows calls.

interface

uses
  Classes, SysUtils;

type
  TLineOutputFunc = procedure(const Line: String) of object;
  TCheckAbortFunc = procedure(var AbortThread: boolean) of object;

{$IFDEF FPC}
// Runs Cmd (a command line; quoted arguments may contain spaces) in WorkDir
// with stdout and stderr merged, and returns everything it printed. When
// ShowReturnValue is set, ' <exit code>' is appended. LineOutputFunc receives
// output as it arrives, in chunks that end at a line break. CheckAbortFunc is
// polled while the program runs and can stop it.
function RunAndGetOutput(const Cmd, WorkDir: String; LineOutputFunc: TLineOutputFunc;
  CheckAbortFunc: TCheckAbortFunc; ShowReturnValue: Boolean = True): String;

// Directory for the IDE's settings, with trailing delimiter, e.g.
// ~/.config/penguin-cpp/ ($XDG_CONFIG_HOME is honored). Not created here.
function GetConfigDir: String;

// Default directory for new projects (the user's home on Linux)
function GetDocumentsDir: String;
{$ENDIF}

// Opens a file, directory or URL with the desktop's default application
function OpenDocument(const Path: String): Boolean;

// Starts a program without waiting for it. Anything that is not an executable
// is opened with OpenDocument instead.
function ExecuteFile(const FileName, Params, WorkDir: String): Boolean;

implementation

uses
{$IFDEF FPC}
  Process{$IFDEF UNIX}, BaseUnix{$ENDIF}{$IFDEF MSWINDOWS}, Windows, ShellAPI{$ENDIF};
{$ELSE}
  Windows, ShellAPI;
{$ENDIF}

const
  AppDirName = 'penguin-cpp';

{$IFDEF FPC}

function FindExecutable(const Name: String): String;
begin
  Result := Name;
  if ExtractFilePath(Name) = '' then begin
    Result := ExeSearch(Name, GetEnvironmentVariable('PATH'));
    if Result = '' then
      Result := Name; // let TProcess report the error
  end;
end;

function RunAndGetOutput(const Cmd, WorkDir: String; LineOutputFunc: TLineOutputFunc;
  CheckAbortFunc: TCheckAbortFunc; ShowReturnValue: Boolean): String;
var
  P: TProcess;
  Args: TStringList;
  Output, CurrentLine, Chunk: String;
  Abort: Boolean;
  I: Integer;

  procedure ReadAvailable;
  var
    Count: Integer;
  begin
    Count := P.Output.NumBytesAvailable;
    while Count > 0 do begin
      SetLength(Chunk, Count);
      Count := P.Output.Read(Chunk[1], Count);
      SetLength(Chunk, Count);
      Output := Output + Chunk;
      if Assigned(LineOutputFunc) then begin
        CurrentLine := CurrentLine + Chunk;
        if (CurrentLine <> '') and (CurrentLine[Length(CurrentLine)] = #10) then begin
          Delete(CurrentLine, Length(CurrentLine), 1);
          LineOutputFunc(CurrentLine);
          CurrentLine := '';
        end;
      end;
      Count := P.Output.NumBytesAvailable;
    end;
  end;

begin
  Output := '';
  CurrentLine := '';
  Args := TStringList.Create;
  P := TProcess.Create(nil);
  try
    CommandToList(Cmd, Args);
    if Args.Count = 0 then
      Exit('CreateProcess error: empty command');
    P.Executable := FindExecutable(Args[0]);
    for I := 1 to Args.Count - 1 do
      P.Parameters.Add(Args[I]);
    if WorkDir <> '' then
      P.CurrentDirectory := WorkDir;
    P.Options := [poUsePipes, poStderrToOutPut];
    P.ShowWindow := swoHIDE;
    try
      P.Execute;
    except
      on E: Exception do
        Exit('CreateProcess error: ' + E.Message);
    end;
    P.CloseInput; // the tools we run don't read stdin; give them EOF

    Abort := False;
    while True do begin
      if Assigned(CheckAbortFunc) then
        CheckAbortFunc(Abort);
      if Abort then begin
        P.Terminate(1);
        Break;
      end;
      if P.Output.NumBytesAvailable > 0 then
        ReadAvailable
      else if not P.Running then begin
        ReadAvailable; // whatever was written right before exiting
        Break;
      end else
        Sleep(10);
    end;
    P.WaitOnExit;

    if ShowReturnValue then
      Result := Output + ' ' + IntToStr(P.ExitCode)
    else
      Result := Output;
  finally
    P.Free;
    Args.Free;
  end;
end;

function GetConfigDir: String;
begin
{$IFDEF UNIX}
  Result := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if Result = '' then
    Result := IncludeTrailingPathDelimiter(GetUserDir) + '.config';
  Result := IncludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(Result) + AppDirName);
{$ELSE}
  Result := IncludeTrailingPathDelimiter(
    ExtractFilePath(ExcludeTrailingPathDelimiter(GetAppConfigDir(False))) + AppDirName);
{$ENDIF}
end;

function GetDocumentsDir: String;
begin
  Result := IncludeTrailingPathDelimiter(GetUserDir);
end;

{$IFDEF UNIX}
function StartDetached(const Exe: String; const Params: array of String; const WorkDir: String): Boolean;
var
  P: TProcess;
  I: Integer;
begin
  P := TProcess.Create(nil);
  try
    P.Executable := FindExecutable(Exe);
    for I := 0 to High(Params) do
      P.Parameters.Add(Params[I]);
    if WorkDir <> '' then
      P.CurrentDirectory := WorkDir;
    P.InheritHandles := False;
    try
      P.Execute; // don't wait; freeing TProcess does not stop the child
      Result := True;
    except
      Result := False;
    end;
  finally
    P.Free;
  end;
end;

function OpenDocument(const Path: String): Boolean;
begin
{$IFDEF DARWIN}
  Result := StartDetached('open', [Path], '');
{$ELSE}
  Result := StartDetached('xdg-open', [Path], '');
{$ENDIF}
end;

function ExecuteFile(const FileName, Params, WorkDir: String): Boolean;
var
  Exe: String;
  Args: TStringList;
  ArgArray: array of String;
  I: Integer;
begin
  Exe := FindExecutable(FileName);
  if DirectoryExists(Exe) or (FpAccess(Exe, X_OK) <> 0) then
    Exit(OpenDocument(FileName));
  Args := TStringList.Create;
  try
    CommandToList(Params, Args);
    SetLength(ArgArray, Args.Count);
    for I := 0 to Args.Count - 1 do
      ArgArray[I] := Args[I];
    Result := StartDetached(Exe, ArgArray, WorkDir);
  finally
    Args.Free;
  end;
end;
{$ENDIF UNIX}

{$ENDIF FPC}

{$IFDEF MSWINDOWS}
function OpenDocument(const Path: String): Boolean;
begin
  Result := ShellExecute(0, 'open', PChar(Path), nil, nil, SW_SHOWNORMAL) > 32;
end;

function ExecuteFile(const FileName, Params, WorkDir: String): Boolean;
begin
  Result := ShellExecute(0, nil, PChar(FileName), PChar(Params), PChar(WorkDir), SW_SHOWNORMAL) > 32;
end;
{$ENDIF}

end.
