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
  Classes, SysUtils{$IFDEF FPC}, Process{$ENDIF};

type
  TLineOutputFunc = procedure(const Line: String) of object;
  TCheckAbortFunc = procedure(var AbortThread: boolean) of object;

{$IFDEF FPC}
var
  // PATH for the programs the IDE starts (compilers, gdb, the user's program).
  // Empty: they inherit the IDE's PATH. Changing the IDE's own environment
  // doesn't reliably reach TProcess, so it is applied per process instead.
  ChildPath: String = '';

// Gives P the IDE's environment with PATH replaced by ChildPath (if set).
// EnglishMessages: gcc, make and the linker speak English (LC_MESSAGES=C;
// LC_ALL and LANGUAGE would override it, so they are left out), because the
// IDE reads their messages. The character set (LC_CTYPE, LANG) is kept.
procedure PrepareProcessEnvironment(P: TProcess; EnglishMessages: Boolean = False);

// The full path of program Name, searched in the PATH the IDE gives the
// programs it starts (ChildPath); Name itself if it is not found there
function FindExecutable(const Name: String): String;

// A developer tool: in the PATH or, on macOS, where Xcode or its command line
// tools keep it (xcrun --find: lldb-dap is not in /usr/bin). '' if missing.
function FindDeveloperTool(const Name: String): String;

// Runs Cmd (a command line; quoted arguments may contain spaces) in WorkDir
// with stdout and stderr merged, and returns everything it printed. When
// ShowReturnValue is set, ' <exit code>' is appended. LineOutputFunc receives
// output as it arrives, in chunks that end at a line break. CheckAbortFunc is
// polled while the program runs and can stop it. EnglishMessages: see
// PrepareProcessEnvironment.
function RunAndGetOutput(const Cmd, WorkDir: String; LineOutputFunc: TLineOutputFunc;
  CheckAbortFunc: TCheckAbortFunc; ShowReturnValue: Boolean = True; EnglishMessages: Boolean = False): String;

// Directory for the IDE's settings, with trailing delimiter, e.g.
// ~/.config/penguin-cpp/ ($XDG_CONFIG_HOME is honored). Not created here.
function GetConfigDir: String;

// Directory of the IDE's own files (Lang/, Templates/, Help/...), with trailing
// delimiter. A build run where it was compiled has them next to it (ExeDir);
// the installed one, /usr/lib/penguin-cpp/penguin-cpp, in /usr/share/penguin-cpp/
function GetDataDir(const ExeDir: String): String;

// Directory for what the user adds to the IDE (their project templates), with
// trailing delimiter, e.g. ~/.local/share/penguin-cpp/ ($XDG_DATA_HOME is
// honored). Not created here.
function GetUserDataDir: String;

// The user's desktop folder, with trailing delimiter: XDG_DESKTOP_DIR from
// ~/.config/user-dirs.dirs (~/Escritorio on a Spanish desktop), else
// ~/Desktop when it exists, else the home folder
function GetDesktopDir: String;

// Creates Dir (and its parents) and makes Dir itself readable by the user
// alone (mode 0700): the settings list the projects the user trusts and the
// folders they work in. An existing Dir is made private too.
function ForcePrivateDirectory(const Dir: String): Boolean;

// Default directory for new projects (the user's home on Linux)
function GetDocumentsDir: String;

// Directory for the IDE's temporary files, with trailing delimiter, e.g.
// ~/.cache/penguin-cpp/tmp/ ($XDG_CACHE_HOME is honored). Unlike /tmp it
// belongs to the user alone (mode 0700), so nobody else can place a link
// where the IDE is about to write. Created if needed; '' if it can't be.
function GetPrivateTempDir: String;

// Running processes: Names receives each program name with its process ID
// stored in Objects[] (to attach the debugger). Reads /proc on Linux.
procedure ListProcesses(Names: TStrings);

// The command that opens a terminal window running Command (the program and
// its arguments, one per string) and waits until that window closes: Exe and
// its arguments, added to Args. With Pause, the window stays open when the
// program ends and shows its time and exit code (ExitFormat, with %s for the
// seconds and %d for the code, as for printf) until Enter (PausePrompt).
// False when no terminal is installed.
function BuildTerminalCommand(Command: TStrings; Pause: Boolean; const ExitFormat, PausePrompt: String;
  out Exe: String; Args: TStrings; const Preferred: String = ''): Boolean;

// The terminals BuildTerminalCommand knows, for the user to choose from
procedure GetTerminalNames(Names: TStrings);
{$ENDIF}

// Opens a file, directory or URL with the desktop's default application
function OpenDocument(const Path: String): Boolean;

// Starts a program without waiting for it. Anything that is not an executable
// is opened with OpenDocument instead.
function ExecuteFile(const FileName, Params, WorkDir: String): Boolean; overload;

// The same with each argument given apart, so a file name is never split or
// read as more arguments, whatever characters it has
function ExecuteFile(const FileName: String; const Args: array of String; const WorkDir: String): Boolean; overload;

implementation

uses
{$IFDEF FPC}
  {$IFDEF UNIX}BaseUnix{$ENDIF}{$IFDEF MSWINDOWS}Windows, ShellAPI{$ENDIF};
{$ELSE}
  Windows, ShellAPI;
{$ENDIF}

const
  AppDirName = 'penguin-cpp';

{$IFDEF FPC}

procedure PrepareProcessEnvironment(P: TProcess; EnglishMessages: Boolean = False);
var
  I: Integer;
  S: String;
begin
  if (ChildPath = '') and not EnglishMessages then
    Exit;
  P.Environment.Clear;
  for I := 1 to GetEnvironmentVariableCount do begin
    S := GetEnvironmentString(I);
    if (ChildPath <> '') and SameText(Copy(S, 1, 5), 'PATH=') then
      Continue;
    if EnglishMessages and ((Copy(S, 1, 7) = 'LC_ALL=') or (Copy(S, 1, 12) = 'LC_MESSAGES=') or
      (Copy(S, 1, 9) = 'LANGUAGE=')) then
      Continue;
    P.Environment.Add(S);
  end;
  if ChildPath <> '' then
    P.Environment.Add('PATH=' + ChildPath);
  if EnglishMessages then
    P.Environment.Add('LC_MESSAGES=C');
end;

function SearchPath: String;
begin
  if ChildPath <> '' then
    Result := ChildPath
  else
    Result := GetEnvironmentVariable('PATH');
end;

function FindExecutable(const Name: String): String;
begin
  Result := Name;
  if ExtractFilePath(Name) = '' then begin
    Result := ExeSearch(Name, SearchPath);
    if Result = '' then
      Result := Name; // let TProcess report the error
  end;
end;

function FindDeveloperTool(const Name: String): String;
{$IFDEF DARWIN}
var
  Output: String;
{$ENDIF}
begin
  Result := ExeSearch(Name, SearchPath);
{$IFDEF DARWIN}
  if (Result = '') and (Name <> '') and RunCommand('/usr/bin/xcrun', ['--find', Name], Output, [poNoConsole]) then begin
    Output := Trim(Output);
    if FileExists(Output) then
      Result := Output;
  end;
{$ENDIF}
end;

function RunAndGetOutput(const Cmd, WorkDir: String; LineOutputFunc: TLineOutputFunc;
  CheckAbortFunc: TCheckAbortFunc; ShowReturnValue: Boolean; EnglishMessages: Boolean): String;
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
    PrepareProcessEnvironment(P, EnglishMessages);
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

// macOS keeps an app's settings and own files in ~/Library/Application Support
{$IFDEF DARWIN}
function MacSupportDir: String;
begin
  Result := IncludeTrailingPathDelimiter(GetUserDir) + 'Library' + PathDelim + 'Application Support' + PathDelim +
    AppDirName + PathDelim;
end;
{$ENDIF}

function GetConfigDir: String;
begin
{$IF DEFINED(DARWIN)}
  Result := MacSupportDir;
{$ELSEIF DEFINED(UNIX)}
  Result := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if Result = '' then
    Result := IncludeTrailingPathDelimiter(GetUserDir) + '.config';
  Result := IncludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(Result) + AppDirName);
{$ELSE}
  Result := IncludeTrailingPathDelimiter(
    ExtractFilePath(ExcludeTrailingPathDelimiter(GetAppConfigDir(False))) + AppDirName);
{$ENDIF}
end;

function GetDataDir(const ExeDir: String): String;
var
  Shared: String;
begin
  Result := IncludeTrailingPathDelimiter(ExeDir);
  if DirectoryExists(Result + 'Lang') then
    Exit;
{$IFDEF DARWIN}
  // Penguin cpp.app/Contents/MacOS/penguin-cpp -> Contents/Resources/
  Shared := ExpandFileName(Result + '..' + PathDelim + 'Resources');
  if DirectoryExists(Shared + PathDelim + 'Lang') then
    Exit(IncludeTrailingPathDelimiter(Shared));
{$ENDIF}
  // <prefix>/lib/penguin-cpp/ -> <prefix>/share/penguin-cpp/
  Shared := ExpandFileName(Result + '..' + PathDelim + '..' + PathDelim + 'share' + PathDelim + AppDirName);
  if DirectoryExists(Shared + PathDelim + 'Lang') then
    Result := IncludeTrailingPathDelimiter(Shared);
end;

function GetUserDataDir: String;
begin
{$IF DEFINED(DARWIN)}
  Result := MacSupportDir;
{$ELSEIF DEFINED(UNIX)}
  Result := GetEnvironmentVariable('XDG_DATA_HOME');
  if Result = '' then
    Result := IncludeTrailingPathDelimiter(GetUserDir) + '.local' + PathDelim + 'share';
  Result := IncludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(Result) + AppDirName);
{$ELSE}
  Result := GetConfigDir;
{$ENDIF}
end;

function GetDesktopDir: String;
var
  Home, Config, Line, Value: String;
  Lines: TStringList;
  I: Integer;
begin
  Home := ExcludeTrailingPathDelimiter(GetUserDir);
  Result := '';
  Config := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if Config = '' then
    Config := Home + PathDelim + '.config';
  Lines := TStringList.Create;
  try
    try
      Lines.LoadFromFile(IncludeTrailingPathDelimiter(Config) + 'user-dirs.dirs');
    except
      Lines.Clear; // no such file: the defaults below
    end;
    // XDG_DESKTOP_DIR="$HOME/Escritorio" (a line of shell)
    for I := 0 to Lines.Count - 1 do begin
      Line := Trim(Lines[I]);
      if Pos('XDG_DESKTOP_DIR=', Line) = 1 then begin
        Value := AnsiDequotedStr(Copy(Line, Length('XDG_DESKTOP_DIR=') + 1, MaxInt), '"');
        Value := StringReplace(Value, '$HOME', Home, []);
        if (Value <> '') and (Value[1] = PathDelim) and DirectoryExists(Value) then
          Result := Value;
      end;
    end;
  finally
    Lines.Free;
  end;
  if (Result = '') and DirectoryExists(Home + PathDelim + 'Desktop') then
    Result := Home + PathDelim + 'Desktop';
  if Result = '' then
    Result := Home;
  Result := IncludeTrailingPathDelimiter(Result);
end;

function ForcePrivateDirectory(const Dir: String): Boolean;
begin
  Result := ForceDirectories(Dir);
{$IFDEF UNIX}
  if Result then
    FpChmod(ExcludeTrailingPathDelimiter(Dir), &700);
{$ENDIF}
end;

function GetDocumentsDir: String;
begin
  Result := IncludeTrailingPathDelimiter(GetUserDir);
end;

function GetPrivateTempDir: String;
begin
{$IFDEF UNIX}
{$IFDEF DARWIN}
  Result := IncludeTrailingPathDelimiter(GetUserDir) + 'Library' + PathDelim + 'Caches';
{$ELSE}
  Result := GetEnvironmentVariable('XDG_CACHE_HOME');
  if Result = '' then
    Result := IncludeTrailingPathDelimiter(GetUserDir) + '.cache';
{$ENDIF}
  Result := IncludeTrailingPathDelimiter(Result) + AppDirName + PathDelim + 'tmp' + PathDelim;
  if not ForceDirectories(Result) or (FpChmod(Result, &700) <> 0) then
    Result := '';
{$ELSE}
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + AppDirName + PathDelim;
  if not ForceDirectories(Result) then
    Result := '';
{$ENDIF}
end;

procedure ListProcesses(Names: TStrings);
{$IF DEFINED(LINUX)}
var
  Rec: TSearchRec;
  PID: Integer;
  Comm: TStringList;
begin
  Comm := TStringList.Create;
  try
    if FindFirst('/proc/*', faDirectory, Rec) = 0 then
      try
        repeat
          if TryStrToInt(Rec.Name, PID) then
            try
              Comm.LoadFromFile('/proc/' + Rec.Name + '/comm');
              if Comm.Count > 0 then
                Names.AddObject(Comm[0], TObject(PtrInt(PID)));
            except
              // the process ended or is not readable; skip it
            end;
        until FindNext(Rec) <> 0;
      finally
        FindClose(Rec);
      end;
  finally
    Comm.Free;
  end;
end;
{$ELSEIF DEFINED(DARWIN)}
// No /proc on macOS: ps lists them, "  PID /path/of/program" a line
var
  Output, Line: String;
  Lines: TStringList;
  I, Space, PID: Integer;
begin
  if not RunCommand('/bin/ps', ['-axo', 'pid=,comm='], Output, [poNoConsole]) then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.Text := Output;
    for I := 0 to Lines.Count - 1 do begin
      Line := Trim(Lines[I]);
      Space := Pos(' ', Line);
      if (Space > 1) and TryStrToInt(Copy(Line, 1, Space - 1), PID) then
        Names.AddObject(ExtractFileName(Trim(Copy(Line, Space + 1, MaxInt))), TObject(PtrInt(PID)));
    end;
  finally
    Lines.Free;
  end;
end;
{$ELSE}
begin
  // Not implemented here: other systems have no /proc with process names
end;
{$ENDIF}

{$IFDEF UNIX}
type
  TTerminal = record
    Exe: String;
    Options: array[0..1] of String; // before the command; '' for none
  end;

const
  // Each with the option that makes it wait for its window: without it some
  // (gnome-terminal, mate-terminal, xfce4-terminal) hand the window to a
  // terminal server and return at once
  Terminals: array[0..5] of TTerminal = (
    (Exe: 'gnome-terminal'; Options: ('--wait', '--')),
    (Exe: 'mate-terminal'; Options: ('--disable-factory', '-x')),
    (Exe: 'xfce4-terminal'; Options: ('--disable-server', '-x')),
    (Exe: 'konsole'; Options: ('--nofork', '-e')),
    (Exe: 'x-terminal-emulator'; Options: ('-e', '')), // Debian's choice of terminal
    (Exe: 'xterm'; Options: ('-e', ''))
  );

  // Runs "$@", then reports like Dev-C++'s ConsolePauser and waits for Enter.
  // The program and its arguments arrive as separate arguments of sh, so
  // nothing in them is read as shell code. date +%s%N is GNU (nanoseconds).
  PauseScript =
    'fmt=$1; prompt=$2; shift 2; ' +
    'start=$(date +%s%N); "$@"; code=$?; finish=$(date +%s%N); ' +
    'ms=$(( (finish - start) / 1000000 )); ' +
    'printf ''\n--------------------------------\n''; ' +
    'printf "$fmt\n" "$((ms / 1000)).$(printf %03d $((ms % 1000)))" "$code"; ' +
    'printf ''%s'' "$prompt"; read dummy';

{$IFDEF DARWIN}
  // macOS: Terminal.app runs a .command file it is given, without asking for
  // permission to be controlled (AppleScript would). This script (zsh, run
  // by the IDE) writes one into a private temporary folder: it goes to the
  // working directory, runs the program, with its arguments quoted one by
  // one, and pauses like PauseScript, timing with zsh's own clock (macOS'
  // date has no %N). The IDE waits for it, as for a Linux terminal: the
  // script leaves a "done" file when it ends, its window is closed too; and
  // stopping the IDE's wait ends the program.
  // Arguments: pause (1/0), the exit format, the prompt, the command.
  MacRunScript =
    'pause=$1; fmt=$2; prompt=$3; shift 3' + #10 +
    'dir=$(mktemp -d "${TMPDIR:-/tmp}/penguin-cpp-run.XXXXXX") || exit 1' + #10 +
    'print -r -- "$fmt" > $dir/fmt' + #10 +
    'print -rn -- "$prompt" > $dir/prompt' + #10 +
    '{' + #10 +
    '  print -r -- ''#!/bin/zsh -f''' + #10 +
    '  print -r -- "dir=${(qq)dir}"' + #10 +
    '  print -r -- ''trap "exit 129" HUP INT TERM; trap "touch \$dir/done" EXIT; print $$ > $dir/pid''' + #10 +
    '  print -r -- "cd ${(qq)PWD}"' + #10 +
    '  print -r -- ''zmodload zsh/datetime; start=$EPOCHREALTIME''' + #10 +
    '  print -r -- "${(j: :)${(qq)@}}"' + #10 +
    '  print -r -- ''code=$?''' + #10 +
    '  if [[ $pause == 1 ]]; then' + #10 +
    '    print -r -- ''elapsed=$(( EPOCHREALTIME - start )); print; print -- --------------------------------''' + #10 +
    '    print -r -- ''printf "$(<$dir/fmt)\n" "$(printf %.3f $elapsed)" $code; printf %s "$(<$dir/prompt)"; read dummy''' + #10 +
    '  fi' + #10 +
    '} > $dir/run.command' + #10 +
    'chmod 700 $dir/run.command' + #10 +
    'trap ''p=$(<$dir/pid) 2>/dev/null; if [[ -n $p ]]; then pkill -TERM -P $p; kill $p; fi; rm -rf $dir; exit 143'' TERM INT' + #10 +
    'open -a Terminal $dir/run.command || { rm -rf $dir; exit 1 }' + #10 +
    'while [[ ! -e $dir/done ]]; do sleep 0.3; done' + #10 +
    'rm -rf $dir';
{$ENDIF}

procedure GetTerminalNames(Names: TStrings);
{$IFDEF DARWIN}
begin
  Names.Add('Terminal');
end;
{$ELSE}
var
  I: Integer;
begin
  for I := Low(Terminals) to High(Terminals) do
    Names.Add(Terminals[I].Exe);
end;
{$ENDIF}

// The one the user chose, if installed; else the desktop's own terminal
// (XDG_CURRENT_DESKTOP: X-Cinnamon, MATE, XFCE, KDE...), then the others in order
function FindTerminal(out Terminal: TTerminal; const Chosen: String): Boolean;
var
  Desktop, Preferred: String;
  I: Integer;
begin
  Desktop := UpperCase(GetEnvironmentVariable('XDG_CURRENT_DESKTOP'));
  Preferred := '';
  if Chosen <> '' then
    Preferred := Chosen
  else if Pos('MATE', Desktop) > 0 then
    Preferred := 'mate-terminal'
  else if Pos('XFCE', Desktop) > 0 then
    Preferred := 'xfce4-terminal'
  else if Pos('KDE', Desktop) > 0 then
    Preferred := 'konsole';
  for I := Low(Terminals) to High(Terminals) do
    if (Terminals[I].Exe = Preferred) and (ExeSearch(Terminals[I].Exe, SearchPath) <> '') then begin
      Terminal := Terminals[I];
      Exit(True);
    end;
  for I := Low(Terminals) to High(Terminals) do
    if ExeSearch(Terminals[I].Exe, SearchPath) <> '' then begin
      Terminal := Terminals[I];
      Exit(True);
    end;
  Result := False;
end;

function BuildTerminalCommand(Command: TStrings; Pause: Boolean; const ExitFormat, PausePrompt: String;
  out Exe: String; Args: TStrings; const Preferred: String = ''): Boolean;
var
  Terminal: TTerminal;
  I: Integer;
begin
{$IFDEF DARWIN}
  Exe := '/bin/zsh';
  Args.Add('-f');
  Args.Add('-c');
  Args.Add(MacRunScript);
  Args.Add('penguin-cpp'); // $0
  if Pause then
    Args.Add('1')
  else
    Args.Add('0');
  Args.Add(ExitFormat);
  Args.Add(PausePrompt);
  Args.AddStrings(Command);
  Exit(True);
{$ENDIF}
  Exe := '';
  Result := FindTerminal(Terminal, Preferred);
  if not Result then
    Exit;
  Exe := ExeSearch(Terminal.Exe, SearchPath);
  for I := Low(Terminal.Options) to High(Terminal.Options) do
    if Terminal.Options[I] <> '' then
      Args.Add(Terminal.Options[I]);
  if Pause then begin
    Args.Add('/bin/sh');
    Args.Add('-c');
    Args.Add(PauseScript);
    Args.Add('penguin-cpp'); // $0
    Args.Add(ExitFormat);
    Args.Add(PausePrompt);
  end;
  Args.AddStrings(Command);
end;

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
    PrepareProcessEnvironment(P);
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
  Args: TStringList;
  ArgArray: array of String;
  I: Integer;
begin
  Args := TStringList.Create;
  try
    CommandToList(Params, Args);
    SetLength(ArgArray, Args.Count);
    for I := 0 to Args.Count - 1 do
      ArgArray[I] := Args[I];
    Result := ExecuteFile(FileName, ArgArray, WorkDir);
  finally
    Args.Free;
  end;
end;

function ExecuteFile(const FileName: String; const Args: array of String; const WorkDir: String): Boolean;
var
  Exe: String;
begin
  Exe := FindExecutable(FileName);
  if DirectoryExists(Exe) or (FpAccess(Exe, X_OK) <> 0) then
    Exit(OpenDocument(FileName));
  Result := StartDetached(Exe, Args, WorkDir);
end;
{$ENDIF UNIX}

{$IFNDEF UNIX}
function BuildTerminalCommand(Command: TStrings; Pause: Boolean; const ExitFormat, PausePrompt: String;
  out Exe: String; Args: TStrings; const Preferred: String = ''): Boolean;
begin
  Exe := '';
  Result := False; // not implemented here
end;

procedure GetTerminalNames(Names: TStrings);
begin
end;
{$ENDIF}

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

function ExecuteFile(const FileName: String; const Args: array of String; const WorkDir: String): Boolean;
var
  Params: String;
  I: Integer;
begin
  Params := '';
  for I := 0 to High(Args) do
    Params := Params + ' "' + Args[I] + '"';
  Result := ExecuteFile(FileName, Trim(Params), WorkDir);
end;
{$ENDIF}

{$IFDEF UNIX}
// Writing to a pipe whose reader has gone (gdb or the formatter crashed)
// raises SIGPIPE, which by default ends the IDE on the spot. With a handler
// that does nothing the write just fails (an exception the callers catch).
// Not SIG_IGN: an ignored signal stays ignored in the programs the IDE
// starts, a handler goes back to the default there.
procedure SigPipeHandler(Signal: cint); cdecl;
begin
end;

procedure IgnoreBrokenPipes;
var
  Action: SigActionRec;
begin
  FillChar(Action, SizeOf(Action), 0);
  Action.sa_handler := SigActionHandler(@SigPipeHandler);
  FpSigAction(SIGPIPE, @Action, nil);
end;

initialization
  IgnoreBrokenPipes;
{$ENDIF}

end.
