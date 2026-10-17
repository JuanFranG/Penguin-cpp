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
  Classes, SysUtils, StrUtils, devPlatform, devFileMonitor, devMonitorTypes;

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
    TestConfigDir;
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
