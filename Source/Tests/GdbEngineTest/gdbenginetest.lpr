{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    Tests GdbEngine with a real gdb and gcc: a small C program in a file
    with a space in its name, debugged from a breakpoint to its end
    (evaluate, stack, next, finish, assign, the exit code, console
    commands), with an argument that a shell would run, and a pause of a
    program in an endless loop. Without gdb or gcc (macOS on Apple Silicon)
    it says so and passes. Run it through build.sh --run.
}

program gdbenginetest;

{$MODE DELPHI}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, Process, DebugEngine, GdbEngine;

const
  Source: array[0..11] of String = (
    '#include <stdio.h>',
    'int suma(int a, int b) {',
    '    int r = a + b;',                                  // 3
    '    return r;',                                       // 4
    '}',
    'int main(int argc, char **argv) {',
    '    volatile int x = 40;',                            // 7
    '    int y = suma(x, 2);',                             // 8
    '    while (argc > 3) x++;',                           // 9
    '    printf("%d [%s]\n", y, argc > 1 ? argv[1] : "");', // 10
    '    return argc > 2 ? 3 : 0;',                        // 11
    '}');
  Tricky = 'hola $(touch pwned) "x" \ y';

type
  TRecorder = class
    Answered, Ok, Stopped, Running, Exited, Terminated: Boolean;
    Text: String;
    BreakId, ExitCode: Integer;
    Info: TDebugStopInfo;
    Frames: TDebugFrames;
    Output: String;
    History: String; // every event, to show when a check fails
    procedure Reset;
    procedure OnDone(AOk: Boolean; const Error: String);
    procedure OnValue(AOk: Boolean; const Value: String);
    procedure OnBreak(AOk: Boolean; Id: Integer; const Error: String);
    procedure OnFrames(AOk: Boolean; const AFrames: TDebugFrames);
    procedure OnStopped(Sender: TObject; const AInfo: TDebugStopInfo);
    procedure OnRunning(Sender: TObject);
    procedure OnExited(Sender: TObject; Code: Integer);
    procedure OnOutput(Sender: TObject; const S: String; Kind: TDebugOutputKind);
    procedure OnTerminated(Sender: TObject);
  end;

var
  Failures: Integer = 0;
  R: TRecorder;

procedure Check(Condition: Boolean; const Name: String; const Detail: String = '');
begin
  if Condition then
    WriteLn('  [OK]   ', Name)
  else begin
    WriteLn('  [FAIL] ', Name, ' ', Detail);
    Inc(Failures);
  end;
end;

procedure TRecorder.Reset;
begin
  Answered := False;
  Ok := False;
  Stopped := False;
  Running := False;
  Text := '';
end;

procedure TRecorder.OnDone(AOk: Boolean; const Error: String);
begin
  Answered := True;
  Ok := AOk;
  Text := Error;
end;

procedure TRecorder.OnValue(AOk: Boolean; const Value: String);
begin
  Answered := True;
  Ok := AOk;
  Text := Value;
end;

procedure TRecorder.OnBreak(AOk: Boolean; Id: Integer; const Error: String);
begin
  Answered := True;
  Ok := AOk;
  BreakId := Id;
  Text := Error;
end;

procedure TRecorder.OnFrames(AOk: Boolean; const AFrames: TDebugFrames);
begin
  Answered := True;
  Ok := AOk;
  Frames := AFrames;
end;

procedure TRecorder.OnStopped(Sender: TObject; const AInfo: TDebugStopInfo);
begin
  Stopped := True;
  Info := AInfo;
  History := History + Format('[stopped reason=%d %s:%d %s]', [Ord(AInfo.Reason), AInfo.Frame.Func,
    AInfo.Frame.Line, AInfo.SignalName]) + LineEnding;
end;

procedure TRecorder.OnRunning(Sender: TObject);
begin
  Running := True;
  History := History + '[running]' + LineEnding;
end;

procedure TRecorder.OnExited(Sender: TObject; Code: Integer);
begin
  Exited := True;
  ExitCode := Code;
  History := History + '[exited ' + IntToStr(Code) + ']' + LineEnding;
end;

procedure TRecorder.OnOutput(Sender: TObject; const S: String; Kind: TDebugOutputKind);
const
  Tags: array[TDebugOutputKind] of String = ('console', 'program', 'log');
begin
  Output := Output + S;
  History := History + '[' + Tags[Kind] + '] ' + S;
end;

procedure TRecorder.OnTerminated(Sender: TObject);
begin
  Terminated := True;
end;

// Handles the engine's events until Flag is set; False after Timeout
function Wait(var Flag: Boolean; Timeout: Integer = 10000): Boolean;
var
  Deadline: QWord;
begin
  Deadline := GetTickCount64 + QWord(Timeout);
  while not Flag and (GetTickCount64 < Deadline) do
    CheckSynchronize(20);
  Result := Flag;
end;

function Found(const Exe: String): Boolean;
begin
  Result := ExeSearch(Exe, GetEnvironmentVariable('PATH')) <> '';
end;

// gdb starts the program through /bin/sh: each argument must reach it as it
// was written, and nothing in it may run (no gdb needed)
procedure TestShellArgument(const Dir: String);
const
  Args: array[0..5] of String = (Tricky, 'it''s', '`touch pwned2`', 'a; touch pwned3', '''''', '');
var
  I: Integer;
  Output: String;
begin
  WriteLn('Arguments through /bin/sh:');
  for I := 0 to High(Args) do begin
    RunCommandInDir(Dir, '/bin/sh', ['-c', 'printf "[%s]" ' + ShellArgument(Args[I])], Output);
    Check(Output = '[' + Args[I] + ']', 'arrives as written: ' + Args[I], Output);
  end;
  Check(not FileExists(Dir + 'pwned') and not FileExists(Dir + 'pwned2') and not FileExists(Dir + 'pwned3'),
    'nothing in them ran');
end;

procedure TestDebugSession(const Dir: String);
var
  E: TGdbEngine;
  Error, Src, Exe, Output: String;
  L: TStringList;
begin
  WriteLn('A debugging session:');
  Src := Dir + 'hola mundo.c';
  Exe := Dir + 'hola mundo';
  L := TStringList.Create;
  try
    L.AddStrings(Source);
    L.SaveToFile(Src);
  finally
    L.Free;
  end;
  Check(RunCommandInDir(Dir, 'gcc', ['-g', '-O0', '-o', Exe, Src], Output, [poStderrToOutPut]) and FileExists(Exe),
    'gcc -g builds the program', Output);

  E := TGdbEngine.Create('', False);
  try
    E.OnStopped := R.OnStopped;
    E.OnRunning := R.OnRunning;
    E.OnExited := R.OnExited;
    E.OnOutput := R.OnOutput;
    E.OnTerminated := R.OnTerminated;
    Check(E.Start(Error), 'gdb starts', Error);

    R.Reset;
    E.LoadProgram(Exe, R.OnDone);
    Check(Wait(R.Answered) and R.Ok, 'program loaded', R.Text);

    E.SetArguments([Tricky, 'b']);
    E.SetWorkingDir(Dir);
    R.Reset;
    E.InsertBreakpoint(Src, 3, R.OnBreak);
    Check(Wait(R.Answered) and R.Ok and (R.BreakId > 0), 'breakpoint in a file with a space', R.Text);

    R.Reset;
    E.Run;
    Check(Wait(R.Stopped) and (R.Info.Reason = dsBreakpoint) and (R.Info.Frame.Line = 3) and
      (R.Info.Frame.Func = 'suma') and (R.Info.BreakpointId = R.BreakId), 'stops at the breakpoint in suma:3',
      R.Info.Frame.Func + ':' + IntToStr(R.Info.Frame.Line));
    Check(ExtractFileName(R.Info.Frame.FullName) = 'hola mundo.c', 'the full file name', R.Info.Frame.FullName);

    R.Reset;
    E.Evaluate('a', R.OnValue);
    Check(Wait(R.Answered) and R.Ok and (R.Text = '40'), 'evaluate a = 40', R.Text);

    R.Reset;
    E.GetFrames(R.OnFrames);
    Check(Wait(R.Answered) and R.Ok and (Length(R.Frames) >= 2) and (R.Frames[1].Func = 'main') and
      (R.Frames[1].Line = 8), 'the stack: suma, then main:8');

    R.Reset;
    E.Next;
    Check(Wait(R.Stopped) and (R.Info.Reason = dsStep) and (R.Info.Frame.Line = 4), 'next goes to line 4',
      IntToStr(R.Info.Frame.Line));

    R.Reset;
    E.Evaluate('r', R.OnValue);
    Check(Wait(R.Answered) and (R.Text = '42'), 'evaluate r = 42', R.Text);

    R.Reset;
    E.Finish;
    Check(Wait(R.Stopped) and (R.Info.Frame.Func = 'main'), 'finish returns to main', R.Info.Frame.Func);

    R.Reset;
    E.Assign('x', '5', R.OnValue);
    Check(Wait(R.Answered) and R.Ok and (R.Text = '5'), 'assign x = 5', R.Text);

    R.Reset;
    E.Evaluate('no_existe', R.OnValue);
    Check(Wait(R.Answered) and not R.Ok and (Pos('no_existe', R.Text) > 0), 'an unknown name is an error',
      R.Text);

    R.Reset;
    R.Output := '';
    E.UserCommand('info breakpoints', R.OnDone);
    Check(Wait(R.Answered) and R.Ok and (Pos('hola mundo.c:3', R.Output) > 0), 'a console command prints',
      Copy(R.Output, 1, 200));

    R.Output := '';
    R.Exited := False;
    E.Continue;
    Check(Wait(R.Exited) and (R.ExitCode = 3), 'the program ends with exit code 3', IntToStr(R.ExitCode));
    if not R.Exited then
      WriteLn('  what happened:', LineEnding, R.History);
    Check(Pos('[' + Tricky + ']', R.Output) > 0, 'the argument arrives as it was written', Copy(R.Output, 1, 200));
    Check(not FileExists(Dir + 'pwned'), 'no shell ran it');

    R.Terminated := False;
    E.Quit;
    Check(not E.Running and not R.Terminated, 'quit: gdb ends, with no event after it');
  finally
    E.Free;
  end;
end;

procedure TestInterrupt(const Dir: String);
var
  E: TGdbEngine;
  Error: String;
begin
  WriteLn('Pausing a running program:');
  E := TGdbEngine.Create('', False);
  try
    E.OnStopped := R.OnStopped;
    E.OnRunning := R.OnRunning;
    E.OnOutput := R.OnOutput;
    Check(E.Start(Error), 'gdb starts', Error);
    R.Reset;
    E.LoadProgram(Dir + 'hola mundo', R.OnDone);
    Wait(R.Answered);
    E.SetArguments(['1', '2', '3']); // argc 4: the endless loop
    R.Reset;
    E.Run;
    Check(Wait(R.Running), 'the program runs');
    Sleep(300);
    E.Interrupt;
    Check(Wait(R.Stopped) and (R.Info.Reason = dsInterrupted), 'interrupt pauses it');
    Check(R.Info.Frame.Func = 'main', 'paused in main', R.Info.Frame.Func);
  finally
    E.Free; // ends the program and gdb
  end;
end;

procedure TestGdbEnds;
var
  E: TGdbEngine;
  Error: String;
begin
  WriteLn('gdb ending by itself:');
  E := TGdbEngine.Create('', False);
  try
    E.OnTerminated := R.OnTerminated;
    Check(E.Start(Error), 'gdb starts', Error);
    R.Terminated := False;
    E.UserCommand('quit');
    Check(Wait(R.Terminated), 'OnTerminated when gdb quits');
  finally
    E.Free;
  end;
end;

procedure RemoveTree(const Dir: String);
var
  Rec: TSearchRec;
begin
  if FindFirst(Dir + '*', faAnyFile, Rec) = 0 then begin
    repeat
      if (Rec.Name <> '.') and (Rec.Name <> '..') then
        DeleteFile(Dir + Rec.Name);
    until FindNext(Rec) <> 0;
    FindClose(Rec);
  end;
  RemoveDir(Dir);
end;

var
  Dir: String;
begin
  R := TRecorder.Create;
  Dir := IncludeTrailingPathDelimiter(GetTempDir) + 'penguin-gdbtest-' + IntToStr(GetProcessID) + PathDelim;
  ForceDirectories(Dir);
  try
    TestShellArgument(Dir);
    if Found('gdb') and Found('gcc') then begin
      TestDebugSession(Dir);
      TestInterrupt(Dir);
      TestGdbEnds;
    end else
      WriteLn('(the debugging part is skipped: gdb or gcc is not installed)');
  finally
    RemoveTree(Dir);
    R.Free;
  end;
  WriteLn;
  if Failures > 0 then begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
  WriteLn('All checks passed');
end.
