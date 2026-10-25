{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    Tests DapEngine with a real lldb-dap and clang (macOS): a small C++
    program in a file with a space in its name, debugged from the start of
    main to its end (breakpoints, evaluate, a structure and an array written
    as gdb would, the stack, next, finish, assign, an lldb command, the exit
    code), with an argument that a shell would run, and a pause of a program
    in an endless loop. Without lldb-dap or clang it says so and passes.
    Run it through build.sh --run.
}

program dapenginetest;

{$MODE DELPHI}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, Process, DebugEngine, DapEngine, devPlatform;

const
  Source: array[0..15] of String = (
    '#include <cstdio>',
    'struct Punto { int x; int y; };',
    'int suma(int a, int b) {',
    '    int r = a + b;',                                  // 4
    '    return r;',                                       // 5
    '}',
    'int main(int argc, char **argv) {',
    '    Punto p = {1, 2};',                               // 8
    '    int arr[3] = {7, 8, 9};',                         // 9
    '    volatile int x = 40;',                            // 10
    '    int y = suma(x, 2);',                             // 11
    '    while (argc > 3) x++;',                           // 12
    '    printf("%d [%s] %d %d\n", y, argc > 1 ? argv[1] : "", p.x, arr[2]);', // 13
    '    return argc > 2 ? 3 : 0;',                        // 14
    '}',
    '');
  Tricky = 'hola $(touch pwned) "x" \ y';

type
  TRecorder = class
    Answered, Ok, Stopped, Running, Exited, Terminated: Boolean;
    Text: String;
    BreakId, ExitCode: Integer;
    Info: TDebugStopInfo;
    Frames: TDebugFrames;
    Output: String;
    History: String;
    procedure Reset;
    procedure OnDone(AOk: Boolean; const Error: String);
    procedure OnValue(AOk: Boolean; const Value: String);
    procedure OnBreak(AOk: Boolean; Id: Integer; const FileName: String; Line: Integer; const Error: String);
    procedure OnLines(AOk: Boolean; Lines: TStrings);
    procedure OnRegisters(AOk: Boolean; Names, Values: TStrings);
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

procedure TRecorder.OnBreak(AOk: Boolean; Id: Integer; const FileName: String; Line: Integer;
  const Error: String);
begin
  Answered := True;
  Ok := AOk;
  BreakId := Id;
  Text := Error + '|' + ExtractFileName(FileName) + ':' + IntToStr(Line);
end;

procedure TRecorder.OnLines(AOk: Boolean; Lines: TStrings);
begin
  Answered := True;
  Ok := AOk;
  Text := Lines.Text;
end;

procedure TRecorder.OnRegisters(AOk: Boolean; Names, Values: TStrings);
var
  I: Integer;
begin
  Answered := True;
  Ok := AOk;
  Text := '';
  for I := 0 to Names.Count - 1 do
    Text := Text + Names[I] + '=' + Values[I] + LineEnding;
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

function Wait(var Flag: Boolean; Timeout: Integer = 20000): Boolean;
var
  Deadline: QWord;
begin
  Deadline := GetTickCount64 + QWord(Timeout);
  while not Flag and (GetTickCount64 < Deadline) do
    CheckSynchronize(20);
  Result := Flag;
end;

function NewEngine: TDapEngine;
begin
  Result := TDapEngine.Create('');
  Result.OnStopped := R.OnStopped;
  Result.OnRunning := R.OnRunning;
  Result.OnExited := R.OnExited;
  Result.OnOutput := R.OnOutput;
  Result.OnTerminated := R.OnTerminated;
end;

procedure TestDebugSession(const Dir: String);
var
  E: TDapEngine;
  Error, Src, Exe, Output: String;
  L: TStringList;
begin
  WriteLn('A debugging session:');
  Src := Dir + 'hola mundo.cpp';
  Exe := Dir + 'hola mundo';
  L := TStringList.Create;
  try
    L.AddStrings(Source);
    L.SaveToFile(Src);
  finally
    L.Free;
  end;
  Check(RunCommandInDir(Dir, 'clang++', ['-g', '-O0', '-o', Exe, Src], Output, [poStderrToOutPut]) and
    FileExists(Exe), 'clang++ -g builds the program', Output);

  E := NewEngine;
  try
    Check(E.Start(Error), 'lldb-dap starts', Error);

    R.Reset;
    E.LoadProgram(Exe, R.OnDone);
    Check(Wait(R.Answered) and R.Ok, 'program loaded', R.Text);

    E.SetArguments([Tricky, 'b']);
    E.SetWorkingDir(Dir);
    R.Reset;
    E.InsertBreakpoint(Src, 4, R.OnBreak);

    R.Reset;
    E.Run(True);
    Check(Wait(R.Stopped) and (R.Info.Frame.Func = 'main'), 'run stops at the start of main',
      R.Info.Frame.Func + ':' + IntToStr(R.Info.Frame.Line) + LineEnding + R.History);
    Check(R.BreakId > 0, 'the breakpoint was answered with an id', R.Text);

    R.Reset;
    E.Continue;
    Check(Wait(R.Stopped) and (R.Info.Reason = dsBreakpoint) and (R.Info.Frame.Line = 4) and
      (R.Info.Frame.Func = 'suma') and (R.Info.BreakpointId = R.BreakId), 'stops at the breakpoint in suma:4',
      R.Info.Frame.Func + ':' + IntToStr(R.Info.Frame.Line) + ' id ' + IntToStr(R.Info.BreakpointId));
    Check(ExtractFileName(R.Info.Frame.FullName) = 'hola mundo.cpp', 'the full file name', R.Info.Frame.FullName);

    R.Reset;
    E.Evaluate('a', R.OnValue);
    Check(Wait(R.Answered) and R.Ok and (R.Text = '40'), 'evaluate a = 40', R.Text);

    R.Reset;
    E.Disassemble('', R.OnLines);
    Check(Wait(R.Answered) and R.Ok and (Pos('suma', R.Text) = 1) and (Pos('=> ', R.Text) > 0),
      'disassembly of suma, marking where it stopped', Copy(R.Text, 1, 300));

    R.Reset;
    E.GetRegisters(R.OnRegisters);
    Check(Wait(R.Answered) and R.Ok and (Pos('pc=0x', R.Text) > 0), 'registers, with the program counter',
      Copy(R.Text, 1, 300));

    R.Reset;
    E.GetFrames(R.OnFrames);
    Check(Wait(R.Answered) and R.Ok and (Length(R.Frames) >= 2) and (R.Frames[1].Func = 'main') and
      (R.Frames[1].Line = 11), 'the stack: suma, then main:11');

    R.Reset;
    E.Next;
    Check(Wait(R.Stopped) and (R.Info.Reason = dsStep) and (R.Info.Frame.Line = 5), 'next goes to line 5',
      IntToStr(R.Info.Frame.Line));

    R.Reset;
    E.Evaluate('r', R.OnValue);
    Check(Wait(R.Answered) and (R.Text = '42'), 'evaluate r = 42', R.Text);

    R.Reset;
    E.Finish;
    Check(Wait(R.Stopped) and (R.Info.Frame.Func = 'main'), 'finish returns to main', R.Info.Frame.Func);

    R.Reset;
    E.Evaluate('p', R.OnValue);
    Check(Wait(R.Answered) and R.Ok and (R.Text = '{x = 1, y = 2}'), 'a structure as gdb writes it', R.Text);

    R.Reset;
    E.Evaluate('arr', R.OnValue);
    Check(Wait(R.Answered) and R.Ok and (R.Text = '{7, 8, 9}'), 'an array as gdb writes it', R.Text);

    R.Reset;
    E.Assign('x', '5', R.OnValue);
    Check(Wait(R.Answered) and R.Ok and (R.Text = '5'), 'assign x = 5', R.Text);

    R.Reset;
    E.Evaluate('no_existe', R.OnValue);
    Check(Wait(R.Answered) and not R.Ok and (Pos('no_existe', R.Text) > 0), 'an unknown name is an error',
      R.Text);

    R.Reset;
    R.Output := '';
    E.UserCommand('breakpoint list', R.OnDone);
    Check(Wait(R.Answered) and R.Ok and (Pos('hola mundo.cpp', R.Output) > 0), 'an lldb command prints',
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
    Check(not E.Running and not R.Terminated, 'quit: lldb-dap ends, with no event after it');
  finally
    E.Free;
  end;
end;

procedure TestInterrupt(const Dir: String);
var
  E: TDapEngine;
  Error: String;
begin
  WriteLn('Pausing a running program:');
  E := NewEngine;
  try
    Check(E.Start(Error), 'lldb-dap starts', Error);
    R.Reset;
    E.LoadProgram(Dir + 'hola mundo', R.OnDone);
    Wait(R.Answered);
    E.SetArguments(['1', '2', '3']); // argc 4: the endless loop
    R.Reset;
    E.Run;
    Check(Wait(R.Running) or Wait(R.Running, 3000), 'the program runs');
    Sleep(500);
    R.Reset;
    E.Interrupt;
    Check(Wait(R.Stopped) and (R.Info.Reason = dsInterrupted), 'interrupt pauses it', R.History);
    Check(R.Info.Frame.Func = 'main', 'paused in main', R.Info.Frame.Func);
  finally
    E.Free; // ends the program and lldb-dap
  end;
end;

var
  Dir: String;
begin
  R := TRecorder.Create;
  try
    if (FindDeveloperTool('lldb-dap') = '') or (ExeSearch('clang++', GetEnvironmentVariable('PATH')) = '') then begin
      WriteLn('lldb-dap or clang++ not found: skipped');
      Exit;
    end;
    Dir := IncludeTrailingPathDelimiter(GetTempDir) + 'penguin-daptest-' + IntToStr(GetProcessID) + PathDelim;
    ForceDirectories(Dir);
    try
      TestDebugSession(Dir);
      TestInterrupt(Dir);
    finally
      DeleteFile(Dir + 'hola mundo.cpp');
      DeleteFile(Dir + 'hola mundo');
      RemoveDir(Dir);
    end;
  finally
    R.Free;
  end;
  WriteLn;
  if Failures > 0 then begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
  WriteLn('All checks passed');
end.
