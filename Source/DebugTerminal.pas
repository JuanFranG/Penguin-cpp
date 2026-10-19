{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    A terminal for the program being debugged. gdb's own input and output
    are the IDE's pipes, so a program started by gdb could neither read the
    keyboard nor show its output (Dev-C++ asked Windows for a new console:
    set new-console on). The IDE opens the user's terminal with a small
    holder script that:
      - writes the name of its terminal (/dev/pts/N) to a file of the IDE,
        for gdb (-inferior-tty-set): the program reads and writes there;
      - waits without reading the keyboard, so what the user types goes to
        the program (Ctrl+C is left to the IDE's Pause and Stop);
      - when the program ends, shows the IDE's message and waits for Enter;
        when the session is stopped (the file is removed), closes at once.
    The file lives in the user's private temporary folder (mode 0700).
    No LCL here: Tests/GdbEngineTest runs the holder under script(1).
}

unit DebugTerminal;

{$MODE DELPHI}

interface

uses
  Classes, SysUtils;

type
  TDebugTerminal = class
  private
    fFileName: String;
  public
    destructor Destroy; override;
    // Chooses the file the holder will write (no terminal is opened)
    function Prepare(out Error: String): Boolean;
    // Prepare, then opens the user's terminal (PreferredTerminal: the
    // IDE's setting, '' automatic) with the holder showing Header
    function Open(const Header, PreferredTerminal: String; out Error: String): Boolean;
    // The terminal's name once the holder wrote it; '' after Timeout
    // milliseconds (no terminal opened, or it is not a terminal)
    function WaitForTty(Timeout: Integer): String;
    // The program ended: the holder shows Message, waits for Enter and closes
    procedure ProgramEnded(const Message: String);
    // Closes the terminal now
    procedure Close;
    // The command that runs the holder for FileName: /bin/sh -c ...
    class procedure HolderCommand(const FileName, Header: String; Command: TStrings);
    property FileName: String read fFileName;
  end;

implementation

uses
  devPlatform;

const
  // $1: the file for the terminal's name; $2: a header line
  HolderScript =
    'f=$1; trap '''' INT; printf ''%s\n\n'' "$2"; ' +
    'tty > "$f.tmp" && mv "$f.tmp" "$f"; ' +
    'while [ -e "$f" ]; do ' +
    'if [ -e "$f.end" ]; then cat "$f.end"; rm -f "$f" "$f.end"; read dummy; exit 0; fi; ' +
    'sleep 0.2; done';

var
  Counter: Integer = 0;

destructor TDebugTerminal.Destroy;
begin
  Close;
  inherited;
end;

class procedure TDebugTerminal.HolderCommand(const FileName, Header: String; Command: TStrings);
begin
  Command.Add('/bin/sh');
  Command.Add('-c');
  Command.Add(HolderScript);
  Command.Add('penguin-cpp'); // $0
  Command.Add(FileName);
  Command.Add(Header);
end;

function TDebugTerminal.Prepare(out Error: String): Boolean;
var
  Dir: String;
begin
  Close;
  Error := '';
  Dir := GetPrivateTempDir;
  Result := Dir <> '';
  if not Result then begin
    Error := 'no private temporary folder';
    Exit;
  end;
  Inc(Counter);
  fFileName := Dir + 'debug-tty-' + IntToStr(GetProcessID) + '-' + IntToStr(Counter);
  DeleteFile(fFileName);
  DeleteFile(fFileName + '.end');
end;

function TDebugTerminal.Open(const Header, PreferredTerminal: String; out Error: String): Boolean;
var
  Command, Args: TStringList;
  Exe: String;
  ArgArray: array of String;
  I: Integer;
begin
  Result := Prepare(Error);
  if not Result then
    Exit;
  Command := TStringList.Create;
  Args := TStringList.Create;
  try
    HolderCommand(fFileName, Header, Command);
    Result := BuildTerminalCommand(Command, False, '', '', Exe, Args, PreferredTerminal);
    if not Result then begin
      Error := 'no terminal found';
      Exit;
    end;
    SetLength(ArgArray, Args.Count);
    for I := 0 to Args.Count - 1 do
      ArgArray[I] := Args[I];
    Result := ExecuteFile(Exe, ArgArray, '');
    if not Result then
      Error := 'could not start ' + Exe;
  finally
    Args.Free;
    Command.Free;
  end;
end;

function TDebugTerminal.WaitForTty(Timeout: Integer): String;
var
  Deadline: QWord;
  L: TStringList;
begin
  Result := '';
  if fFileName = '' then
    Exit;
  Deadline := GetTickCount64 + QWord(Timeout);
  repeat
    if FileExists(fFileName) then begin
      L := TStringList.Create;
      try
        try
          L.LoadFromFile(fFileName);
          if L.Count > 0 then
            Result := Trim(L[0]);
        except
          Result := '';
        end;
      finally
        L.Free;
      end;
      if Copy(Result, 1, 5) <> '/dev/' then // "not a tty"
        Result := '';
      Exit;
    end;
    Sleep(50);
  until GetTickCount64 >= Deadline;
end;

procedure TDebugTerminal.ProgramEnded(const Message: String);
var
  L: TStringList;
begin
  if fFileName = '' then
    Exit;
  L := TStringList.Create;
  try
    L.Text := Message;
    try
      // Written whole, then renamed: the holder never shows half a message
      L.SaveToFile(fFileName + '.end.tmp');
      RenameFile(fFileName + '.end.tmp', fFileName + '.end');
    except
      DeleteFile(fFileName); // could not write it: just close the terminal
    end;
  finally
    L.Free;
  end;
  fFileName := ''; // the holder removes its files when Enter is pressed
end;

procedure TDebugTerminal.Close;
begin
  if fFileName = '' then
    Exit;
  DeleteFile(fFileName); // the holder sees it gone and ends
  DeleteFile(fFileName + '.end');
  DeleteFile(fFileName + '.end.tmp');
  fFileName := '';
end;

end.
