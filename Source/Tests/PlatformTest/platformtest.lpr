{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    Console test for the OS layer: devPlatform (running programs, config
    directory) and the devFileMonitor component. Unix only (uses /bin/sh).
    Exit code 1 if any check fails.
}

program platformtest;

{$MODE DELPHI}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, StrUtils, Process, {$IFDEF UNIX}BaseUnix,{$ENDIF} devPlatform, devFileMonitor, devMonitorTypes;

var
  Failures: Integer = 0;

procedure Check(Condition: Boolean; const Name: String; const Detail: String = '');
begin
  if Condition then
    WriteLn('  [OK]   ', Name)
  else begin
    WriteLn('  [FAIL] ', Name, ' ', Detail);
    Inc(Failures);
  end;
end;

type
  TRecorder = class
    Lines: TStringList;
    AbortAfter: QWord;
    Events: TStringList;
    Monitor: TdevFileMonitor;
    constructor Create;
    destructor Destroy; override;
    procedure OnLine(const Line: String);
    procedure OnCheckAbort(var AbortThread: boolean);
    procedure OnFileChange(Sender: TObject; ChangeType: TdevMonitorChangeType; FileName: String);
  end;

constructor TRecorder.Create;
begin
  Lines := TStringList.Create;
  Events := TStringList.Create;
end;

destructor TRecorder.Destroy;
begin
  Events.Free;
  Lines.Free;
  inherited;
end;

procedure TRecorder.OnLine(const Line: String);
begin
  Lines.Add(Line);
end;

procedure TRecorder.OnCheckAbort(var AbortThread: boolean);
begin
  AbortThread := GetTickCount64 >= AbortAfter;
end;

procedure TRecorder.OnFileChange(Sender: TObject; ChangeType: TdevMonitorChangeType; FileName: String);
begin
  // Same pattern as TMainForm.FileMonitorNotifyChange: the handler stops and
  // restarts the monitor thread that reported the change.
  Monitor.BeginUpdate;
  try
    if ChangeType = mctChanged then
      Events.Add('changed ' + ExtractFileName(FileName))
    else
      Events.Add('deleted ' + ExtractFileName(FileName));
  finally
    Monitor.EndUpdate;
  end;
end;

function Run(const Cmd: String; WorkDir: String = ''; ShowReturnValue: Boolean = True): String;
begin
  Result := RunAndGetOutput(Cmd, WorkDir, nil, nil, ShowReturnValue);
end;

// Processes queued notifications until Count events arrived or Timeout passed
procedure WaitForEvents(R: TRecorder; Count: Integer; Timeout: QWord);
var
  Deadline: QWord;
begin
  Deadline := GetTickCount64 + Timeout;
  while (R.Events.Count < Count) and (GetTickCount64 < Deadline) do
    CheckSynchronize(50);
end;

// A pipe whose reader has gone must not end the IDE (SIGPIPE), and the
// programs the IDE starts must still get SIGPIPE as usual
procedure TestBrokenPipe;
var
  P: TProcess;
  Data, S: String;
  Failed: Boolean;
begin
  WriteLn('Broken pipes:');
  P := TProcess.Create(nil);
  try
    P.Executable := '/bin/sh';
    P.Parameters.Add('-c');
    P.Parameters.Add('exit 0');
    P.Options := [poUsePipes];
    P.Execute;
    P.WaitOnExit;
    Data := StringOfChar('x', 1 shl 20);
    Failed := False;
    try
      P.Input.WriteBuffer(Data[1], Length(Data));
    except
      Failed := True;
    end;
    Check(Failed, 'writing to a program that ended fails, and the IDE goes on');
  finally
    P.Free;
  end;
  S := Run('/bin/sh -c "yes | head -n 1"', '', False);
  Check((Trim(S) = 'y') and (Pos('Broken pipe', S) = 0), 'a program started by the IDE still gets SIGPIPE',
    QuotedStr(S));
end;

procedure TestProcesses;
var
  R: TRecorder;
  S: String;
  Started: QWord;
begin
  WriteLn('RunAndGetOutput:');
  S := Run('echo hello');
  Check(S = 'hello' + LineEnding + ' 0', 'output and exit code', QuotedStr(S));
  Check(EndsStr(' 3', Run('/bin/sh -c "exit 3"')), 'non-zero exit code');
  Check(Pos('to-stderr', Run('/bin/sh -c "echo to-stderr 1>&2"')) > 0, 'stderr is merged');
  S := Run('printf "%s|" "a b" ''c d'' e', '', False);
  Check(S = 'a b|c d|e|', 'quoted arguments', QuotedStr(S));
  S := Trim(Run('pwd', GetTempDir, False));
  Check(SameFileName(ExtractFileName(ExcludeTrailingPathDelimiter(S)),
    ExtractFileName(ExcludeTrailingPathDelimiter(GetTempDir))), 'working directory', S);
  Check(StartsStr('CreateProcess error', Run('/nonexistent/program')), 'missing program reports an error');

  R := TRecorder.Create;
  try
    RunAndGetOutput('/bin/sh -c "echo one; echo two"', '', R.OnLine, nil);
    Check(Pos('one', R.Lines.Text) > 0, 'line callback receives output', QuotedStr(R.Lines.Text));

    R.AbortAfter := GetTickCount64 + 200;
    Started := GetTickCount64;
    RunAndGetOutput('sleep 5', '', nil, R.OnCheckAbort);
    Check(GetTickCount64 - Started < 2000, 'abort stops a running program',
      IntToStr(GetTickCount64 - Started) + ' ms');
  finally
    R.Free;
  end;
end;

// The compiler runs with English messages, whatever LC_ALL or LANGUAGE say
// (build.sh runs this test once with both set to Spanish)
procedure TestEnglishMessages;
var
  S: String;
begin
  WriteLn('Compiler messages in English:');
  S := Trim(RunAndGetOutput('/bin/sh -c "echo ${LC_ALL}:${LC_MESSAGES}:${LANGUAGE}"', '', nil, nil, False, True));
  Check(S = ':C:', 'LC_MESSAGES=C, without LC_ALL and LANGUAGE', QuotedStr(S));
  S := Trim(RunAndGetOutput('/bin/sh -c "echo ${LANG}"', '', nil, nil, False, True));
  Check(S = GetEnvironmentVariable('LANG'), 'LANG (the character set) is kept', QuotedStr(S));
  S := Trim(RunAndGetOutput('/bin/sh -c "echo ${LC_ALL}"', '', nil, nil, False));
  Check(S = GetEnvironmentVariable('LC_ALL'), 'other programs keep the user''s language', QuotedStr(S));
end;

procedure TestConfigDir;
var
  Expected, Xdg: String;
begin
  WriteLn('GetConfigDir:');
  Xdg := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if Xdg <> '' then
    Expected := IncludeTrailingPathDelimiter(Xdg) + 'penguin-cpp' + PathDelim
  else
    Expected := IncludeTrailingPathDelimiter(GetUserDir) + '.config' + PathDelim + 'penguin-cpp' + PathDelim;
  Check(GetConfigDir = Expected, 'follows XDG (' + GetConfigDir + ')', 'expected ' + Expected);
end;

// Built in its folder, the IDE has Lang/ next to it; installed, its files are
// in <prefix>/share/penguin-cpp/ and it is <prefix>/lib/penguin-cpp/penguin-cpp
procedure TestDataDir(const Dir: String);
var
  Built, Prefix: String;
begin
  WriteLn('GetDataDir:');
  Built := Dir + 'built' + PathDelim;
  ForceDirectories(Built + 'Lang');
  Prefix := Dir + 'usr' + PathDelim;
  ForceDirectories(Prefix + 'lib' + PathDelim + 'penguin-cpp');
  ForceDirectories(Prefix + 'share' + PathDelim + 'penguin-cpp' + PathDelim + 'Lang');
  try
    Check(GetDataDir(Built) = Built, 'files next to a build');
    Check(GetDataDir(Prefix + 'lib' + PathDelim + 'penguin-cpp' + PathDelim) =
      Prefix + 'share' + PathDelim + 'penguin-cpp' + PathDelim, 'installed files in share/penguin-cpp',
      GetDataDir(Prefix + 'lib' + PathDelim + 'penguin-cpp' + PathDelim));
    Check(GetDataDir(Dir) = Dir, 'with neither, the program''s folder');
  finally
    RemoveDir(Built + 'Lang');
    RemoveDir(Built);
    RemoveDir(Prefix + 'share' + PathDelim + 'penguin-cpp' + PathDelim + 'Lang');
    RemoveDir(Prefix + 'share' + PathDelim + 'penguin-cpp');
    RemoveDir(Prefix + 'share');
    RemoveDir(Prefix + 'lib' + PathDelim + 'penguin-cpp');
    RemoveDir(Prefix + 'lib');
    RemoveDir(Prefix);
  end;
end;

// Where the error report goes
procedure TestDesktopDir;
var
  Dir: String;
begin
  WriteLn('GetDesktopDir:');
  Dir := GetDesktopDir;
  Check((Dir <> '') and (Dir[Length(Dir)] = PathDelim) and DirectoryExists(Dir), 'an existing folder (' + Dir + ')');
  Check(Pos(IncludeTrailingPathDelimiter(GetUserDir), Dir) = 1, 'inside the home folder');
end;

procedure TestPrivateTempDir;
var
  Dir: String;
{$IFDEF UNIX}
  Info: Stat;
{$ENDIF}
begin
  WriteLn('GetPrivateTempDir:');
  Dir := GetPrivateTempDir;
  Check((Dir <> '') and DirectoryExists(Dir), 'exists (' + Dir + ')');
  Check(Pos(IncludeTrailingPathDelimiter(GetTempDir), Dir) <> 1, 'is not in the shared temp dir');
{$IFDEF UNIX}
  Check((FpStat(Dir, Info) = 0) and (Info.st_mode and &777 = &700), 'only the user can use it (0700)',
    'mode ' + OctStr(Info.st_mode and &777, 3));
{$ENDIF}
end;

procedure TestProcessList;
var
  Names: TStringList;
  I: Integer;
  Found: Boolean;
begin
  WriteLn('ListProcesses:');
  Names := TStringList.Create;
  try
    ListProcesses(Names);
    Found := False;
    for I := 0 to Names.Count - 1 do
      if PtrInt(Names.Objects[I]) = GetProcessID then
        Found := True;
    {$IFDEF LINUX}
    Check(Found, 'lists this process (' + IntToStr(Names.Count) + ' processes)');
    {$ELSE}
    WriteLn('  (skipped: /proc is Linux only)');
    {$ENDIF}
  finally
    Names.Free;
  end;
end;

procedure TestExecuteFile(const Dir: String);
var
  Marker: String;
  Deadline: QWord;
begin
  WriteLn('ExecuteFile:');
  Marker := Dir + 'executed.txt';
  Check(ExecuteFile('/bin/sh', '-c "sleep 0.2; touch executed.txt"', Dir), 'starts a program');
  Deadline := GetTickCount64 + 3000;
  while not FileExists(Marker) and (GetTickCount64 < Deadline) do
    Sleep(50);
  Check(FileExists(Marker), 'program ran in its working directory, detached');
end;

procedure TestFileMonitor(const Dir: String);
var
  R: TRecorder;
  FileName: String;
  F: TStringList;
begin
  WriteLn('devFileMonitor:');
  FileName := Dir + 'watched.cpp';
  F := TStringList.Create;
  R := TRecorder.Create;
  R.Monitor := TdevFileMonitor.Create(nil);
  try
    F.Text := 'int main() {}';
    F.SaveToFile(FileName);
    R.Monitor.OnNotifyChange := R.OnFileChange;
    R.Monitor.Monitor(FileName);

    Sleep(100);
    F.Add('// edited');
    F.SaveToFile(FileName);
    WaitForEvents(R, 1, 3000);
    Check((R.Events.Count >= 1) and (R.Events[0] = 'changed watched.cpp'), 'detects a change',
      QuotedStr(R.Events.CommaText));

    DeleteFile(FileName);
    WaitForEvents(R, 2, 3000);
    Check((R.Events.Count >= 2) and (R.Events[1] = 'deleted watched.cpp'), 'detects a deletion',
      QuotedStr(R.Events.CommaText));
    Check(R.Events.Count = 2, 'one notification per change', QuotedStr(R.Events.CommaText));
  finally
    R.Monitor.Free; // must not hang even with notifications in flight
    R.Free;
    F.Free;
  end;
  Check(True, 'monitor shuts down cleanly');
end;

var
  Dir: String;
begin
  Dir := IncludeTrailingPathDelimiter(GetTempDir) + 'penguin-platformtest-' + IntToStr(GetProcessID) + PathDelim;
  ForceDirectories(Dir);
  try
    TestProcesses;
    TestBrokenPipe;
    TestEnglishMessages;
    TestConfigDir;
    TestDataDir(Dir);
    TestDesktopDir;
    TestPrivateTempDir;
    TestProcessList;
    TestExecuteFile(Dir);
    TestFileMonitor(Dir);
  finally
    DeleteFile(Dir + 'executed.txt');
    RemoveDir(Dir);
  end;
  WriteLn;
  if Failures > 0 then begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
  WriteLn('All checks passed');
end.
