{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    The debugger engine over gdb's machine interface (gdb --interpreter=mi).
    A thread reads gdb's output line by line and only parses it (GdbMI); the
    records go through a locked queue to the main thread, which answers the
    commands (by their token) and raises the events. Nothing here touches the
    interface, so the engine also runs in a console test (Tests/GdbEngineTest).

    gdb starts with mi-async on (the program runs while gdb still takes
    commands, so Interrupt can pause it), confirm off, width 0, height 0,
    English messages (LC_MESSAGES=C) and SHELL=/bin/sh.

    gdb starts the program through $SHELL. Without a shell
    (startup-with-shell off) it splits the arguments at every space, quotes
    or not, so an argument with a space could not be passed at all. So the
    shell stays, it is always /bin/sh (csh or fish quote otherwise), and each
    argument goes in single quotes (ShellArgument): /bin/sh reads it as text,
    and $(...), `...` or ; in it never run.
}

unit GdbEngine;

{$MODE DELPHI}

interface

uses
  Classes, SysUtils, SyncObjs, Process, DebugEngine, GdbMI;

type
  TGdbEngine = class;

  TGdbReader = class(TThread)
  private
    fEngine: TGdbEngine;
    fPipe: TStream;
  protected
    procedure Execute; override;
  public
    constructor Create(Engine: TGdbEngine; Pipe: TStream);
  end;

  TGdbHandlerKind = (hkDone, hkValue, hkBreakpoint, hkFrames);

  PGdbHandler = ^TGdbHandler;
  TGdbHandler = record
    Token: Int64;
    Kind: TGdbHandlerKind;
    Method: TMethod;
  end;

  TGdbEngine = class(TDebugEngine)
  private
    fGdbPath: String;
    fReadInitFiles: Boolean;
    fProcess: TProcess;
    fReader: TGdbReader;
    fLock: TCriticalSection;
    fQueue: TList;          // records read, waiting for the main thread (under fLock)
    fGdbEnded: Boolean;     // the reader saw the end of gdb's output (under fLock)
    fTerminatedSent: Boolean;
    fHandlers: TList;       // PGdbHandler
    fNextToken: Int64;
    fQuitting: Boolean;
    procedure Enqueue(Rec: TMIRecord);
    procedure ReaderEnded;
    procedure Drain;
    procedure DispatchRecord(Rec: TMIRecord);
    procedure Answer(Rec: TMIRecord);
    procedure Stopped(Rec: TMIRecord);
    function Send(const Command: String; Kind: TGdbHandlerKind; const Handler: TMethod): Int64; overload;
    procedure Send(const Command: String); overload;
    procedure ClearHandlers;
    procedure StopReader;
  public
    // GdbPath: the gdb program ('' finds gdb in PATH). ReadInitFiles: let
    // gdb read the user's ~/.gdbinit (the tests leave it out)
    constructor Create(const GdbPath: String; ReadInitFiles: Boolean = True);
    destructor Destroy; override;

    function Start(out Error: String): Boolean; override;
    procedure Quit; override;
    function Running: Boolean; override;

    procedure LoadProgram(const FileName: String; Handler: TDebugDoneHandler = nil); override;
    procedure SetArguments(const Args: array of String); override;
    procedure SetWorkingDir(const Dir: String); override;
    procedure SetTerminal(const TtyName: String); override;

    procedure InsertBreakpoint(const FileName: String; Line: Integer; Handler: TDebugBreakpointHandler = nil);
      override;
    procedure DeleteBreakpoint(Id: Integer); override;

    procedure Run; override;
    procedure Continue; override;
    procedure Next; override;
    procedure Step; override;
    procedure Finish; override;
    procedure NextInstruction; override;
    procedure StepInstruction; override;
    procedure Interrupt; override;

    procedure Evaluate(const Expression: String; Handler: TDebugValueHandler); override;
    procedure Assign(const Expression, Value: String; Handler: TDebugValueHandler = nil); override;
    procedure GetFrames(Handler: TDebugFramesHandler); override;
    procedure UserCommand(const Command: String; Handler: TDebugDoneHandler = nil); override;

    procedure CancelHandlers(Owner: TObject); override;

    // Any MI command, for the parts of gdb the interface does not cover
    procedure Execute(const Command: String; Handler: TDebugDoneHandler = nil);
  end;

// One argument for /bin/sh: in single quotes, with ' written '\''; a line
// break becomes a space (gdb takes the arguments as one line)
function ShellArgument(const Arg: String): String;

implementation

uses
  devPlatform;

function ShellArgument(const Arg: String): String;
var
  I: Integer;
begin
  Result := '''';
  for I := 1 to Length(Arg) do
    case Arg[I] of
      '''': Result := Result + '''\''''';
      #10, #13: Result := Result + ' ';
    else
      Result := Result + Arg[I];
    end;
  Result := Result + '''';
end;

// gdb writes exit codes in octal ("03", "0377")
function OctalToInt(const S: String): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(S) do
    if S[I] in ['0'..'7'] then
      Result := Result * 8 + Ord(S[I]) - Ord('0')
    else
      Exit(StrToIntDef(S, -1));
end;

function FrameOf(V: TMIValue): TDebugFrame;
begin
  Result.Level := -1;
  Result.Func := '';
  Result.FileName := '';
  Result.FullName := '';
  Result.Line := 0;
  Result.Addr := '';
  if not Assigned(V) then
    Exit;
  Result.Level := V.GetInt('level', -1);
  Result.Func := V.Get('func');
  Result.FileName := V.Get('file');
  Result.FullName := V.Get('fullname');
  Result.Line := V.GetInt('line', 0);
  Result.Addr := V.Get('addr');
end;

{ TGdbReader }

constructor TGdbReader.Create(Engine: TGdbEngine; Pipe: TStream);
begin
  fEngine := Engine;
  fPipe := Pipe;
  inherited Create(False);
end;

procedure TGdbReader.Execute;
var
  Buffer: array[0..4095] of Char;
  Pending, Line: String;
  N, P: Integer;
begin
  Pending := '';
  while not Terminated do begin
    N := fPipe.Read(Buffer[0], SizeOf(Buffer));
    if N <= 0 then
      Break; // gdb closed its output: it has ended
    SetString(Line, PChar(@Buffer[0]), N);
    Pending := Pending + Line;
    P := Pos(#10, Pending);
    while P > 0 do begin
      fEngine.Enqueue(ParseMILine(Copy(Pending, 1, P - 1)));
      Delete(Pending, 1, P);
      P := Pos(#10, Pending);
    end;
  end;
  if Pending <> '' then
    fEngine.Enqueue(ParseMILine(Pending));
  fEngine.ReaderEnded;
end;

{ TGdbEngine }

constructor TGdbEngine.Create(const GdbPath: String; ReadInitFiles: Boolean);
begin
  inherited Create;
  fGdbPath := GdbPath;
  fReadInitFiles := ReadInitFiles;
  fLock := TCriticalSection.Create;
  fQueue := TList.Create;
  fHandlers := TList.Create;
  fNextToken := 1;
end;

destructor TGdbEngine.Destroy;
var
  I: Integer;
begin
  Quit;
  for I := 0 to fQueue.Count - 1 do
    TMIRecord(fQueue[I]).Free;
  fQueue.Free;
  ClearHandlers;
  fHandlers.Free;
  fLock.Free;
  inherited;
end;

// Reader thread: hand a record to the main thread
procedure TGdbEngine.Enqueue(Rec: TMIRecord);
begin
  fLock.Enter;
  try
    fQueue.Add(Rec);
  finally
    fLock.Leave;
  end;
  TThread.Queue(nil, Drain);
end;

procedure TGdbEngine.ReaderEnded;
begin
  fLock.Enter;
  try
    fGdbEnded := True;
  finally
    fLock.Leave;
  end;
  TThread.Queue(nil, Drain);
end;

// Main thread: everything read so far, in order
procedure TGdbEngine.Drain;
var
  Records: TList;
  Ended: Boolean;
  I: Integer;
begin
  Records := TList.Create;
  try
    fLock.Enter;
    try
      Records.Assign(fQueue);
      fQueue.Clear;
      Ended := fGdbEnded;
    finally
      fLock.Leave;
    end;
    for I := 0 to Records.Count - 1 do begin
      try
        if not fQuitting then
          DispatchRecord(TMIRecord(Records[I]));
      finally
        TMIRecord(Records[I]).Free;
        Records[I] := nil;
      end;
    end;
  finally
    for I := 0 to Records.Count - 1 do // left by an exception in a handler
      TMIRecord(Records[I]).Free;
    Records.Free;
  end;
  if Ended and not fTerminatedSent and not fQuitting then begin
    fTerminatedSent := True;
    ClearHandlers;
    DoTerminated;
  end;
end;

procedure TGdbEngine.DispatchRecord(Rec: TMIRecord);
begin
  case Rec.Kind of
    mrResult:
      Answer(Rec);
    mrExec:
      if Rec.RecordClass = 'running' then
        DoRunning
      else if Rec.RecordClass = 'stopped' then
        Stopped(Rec);
    mrConsole:
      DoOutput(Rec.Text, doConsole);
    mrTarget:
      DoOutput(Rec.Text, doProgram);
    mrLog:
      DoOutput(Rec.Text, doLog);
    mrOther: // the program's own output, when it has no terminal of its own
      DoOutput(Rec.Text + LineEnding, doProgram);
  end;
end;

procedure TGdbEngine.Answer(Rec: TMIRecord);
var
  I: Integer;
  H: TGdbHandler;
  Ok: Boolean;
  Error: String;
  Frames: TDebugFrames;
  Stack: TMIValue;
begin
  I := 0;
  while (Rec.Token >= 0) and (I < fHandlers.Count) and (PGdbHandler(fHandlers[I])^.Token <> Rec.Token) do
    Inc(I);
  if (Rec.Token < 0) or (I >= fHandlers.Count) then begin
    // Nobody waits for this answer (Run, Next...): gdb's refusal still has
    // to reach the user
    if Rec.RecordClass = 'error' then
      DoOutput(Rec.Results.Get('msg') + LineEnding, doLog);
    Exit;
  end;
  H := PGdbHandler(fHandlers[I])^;
  Dispose(PGdbHandler(fHandlers[I]));
  fHandlers.Delete(I);

  Ok := Rec.RecordClass <> 'error';
  Error := Rec.Results.Get('msg');
  case H.Kind of
    hkDone:
      TDebugDoneHandler(H.Method)(Ok, Error);
    hkValue:
      if Ok then
        TDebugValueHandler(H.Method)(True, Rec.Results.Get('value'))
      else
        TDebugValueHandler(H.Method)(False, Error);
    hkBreakpoint:
      TDebugBreakpointHandler(H.Method)(Ok, Rec.Results.GetInt('bkpt.number', -1), Error);
    hkFrames: begin
        SetLength(Frames, 0);
        Stack := Rec.Results.Find('stack');
        if Ok and Assigned(Stack) then begin
          SetLength(Frames, Stack.Count);
          for I := 0 to Stack.Count - 1 do
            Frames[I] := FrameOf(Stack[I]);
        end;
        TDebugFramesHandler(H.Method)(Ok, Frames);
      end;
  end;
end;

procedure TGdbEngine.Stopped(Rec: TMIRecord);
var
  Reason: String;
  Info: TDebugStopInfo;
begin
  Reason := Rec.Results.Get('reason');
  if Reason = 'exited-normally' then begin
    DoExited(0);
    Exit;
  end else if Reason = 'exited' then begin
    DoExited(OctalToInt(Rec.Results.Get('exit-code')));
    Exit;
  end else if Reason = 'exited-signalled' then begin
    DoOutput('Program terminated with signal ' + Rec.Results.Get('signal-name') + ', ' +
      Rec.Results.Get('signal-meaning') + '.' + LineEnding, doLog);
    DoExited(-1);
    Exit;
  end;

  Info.Frame := FrameOf(Rec.Results.Find('frame'));
  Info.BreakpointId := Rec.Results.GetInt('bkptno', -1);
  Info.SignalName := Rec.Results.Get('signal-name');
  Info.SignalMeaning := Rec.Results.Get('signal-meaning');
  if Reason = 'breakpoint-hit' then
    Info.Reason := dsBreakpoint
  else if (Reason = 'end-stepping-range') or (Reason = 'function-finished') or (Reason = 'location-reached') then
    Info.Reason := dsStep
  else if Reason = 'signal-received' then begin
    if Info.SignalName = 'SIGINT' then
      Info.Reason := dsInterrupted
    else
      Info.Reason := dsSignal;
  end else
    Info.Reason := dsOther;
  DoStopped(Info);
end;

function TGdbEngine.Send(const Command: String; Kind: TGdbHandlerKind; const Handler: TMethod): Int64;
var
  H: PGdbHandler;
  Line: String;
begin
  Result := fNextToken;
  Inc(fNextToken);
  if Assigned(Handler.Code) then begin
    New(H);
    H^.Token := Result;
    H^.Kind := Kind;
    H^.Method := Handler;
    fHandlers.Add(H);
  end;
  if not Running then
    Exit;
  Line := IntToStr(Result) + Command + #10;
  try
    fProcess.Input.WriteBuffer(Line[1], Length(Line));
  except
    // gdb has gone: OnTerminated follows when the reader sees it
  end;
end;

procedure TGdbEngine.Send(const Command: String);
var
  None: TMethod;
begin
  None.Code := nil;
  None.Data := nil;
  Send(Command, hkDone, None);
end;

procedure TGdbEngine.ClearHandlers;
var
  I: Integer;
begin
  for I := 0 to fHandlers.Count - 1 do
    Dispose(PGdbHandler(fHandlers[I]));
  fHandlers.Clear;
end;

procedure TGdbEngine.CancelHandlers(Owner: TObject);
var
  I: Integer;
begin
  for I := fHandlers.Count - 1 downto 0 do
    if PGdbHandler(fHandlers[I])^.Method.Data = Pointer(Owner) then begin
      Dispose(PGdbHandler(fHandlers[I]));
      fHandlers.Delete(I);
    end;
end;

function TGdbEngine.Start(out Error: String): Boolean;
var
  Exe: String;
  I: Integer;
begin
  Error := '';
  Result := False;
  if Running then
    Exit(True);
  if Assigned(fProcess) then
    Quit; // a gdb that ended: start clean

  if fGdbPath = '' then
    Exe := FindExecutable('gdb')
  else
    Exe := fGdbPath;
  fProcess := TProcess.Create(nil);
  fProcess.Executable := Exe;
  fProcess.Parameters.Add('--interpreter=mi2');
  fProcess.Parameters.Add('--quiet');
  if not fReadInitFiles then
    fProcess.Parameters.Add('--nx');
  fProcess.Options := [poUsePipes, poStderrToOutPut];
  PrepareProcessEnvironment(fProcess, True); // gdb in English: its messages are read
  // gdb starts the program through $SHELL: always /bin/sh, whose quoting
  // ShellArgument follows
  for I := fProcess.Environment.Count - 1 downto 0 do
    if Copy(fProcess.Environment[I], 1, 6) = 'SHELL=' then
      fProcess.Environment.Delete(I);
  fProcess.Environment.Add('SHELL=/bin/sh');
  try
    fProcess.Execute;
  except
    on E: Exception do begin
      Error := E.Message;
      FreeAndNil(fProcess);
      Exit;
    end;
  end;

  fQuitting := False;
  fTerminatedSent := False;
  fGdbEnded := False;
  fReader := TGdbReader.Create(Self, fProcess.Output);

  Send('-gdb-set mi-async on');
  Send('-gdb-set confirm off');
  Send('-gdb-set width 0');
  Send('-gdb-set height 0');
  Result := True;
end;

function TGdbEngine.Running: Boolean;
begin
  Result := Assigned(fProcess) and fProcess.Running;
end;

// Waits for the reader thread to end (gdb's output closed) and frees it
procedure TGdbEngine.StopReader;
begin
  if not Assigned(fReader) then
    Exit;
  fReader.WaitFor;
  FreeAndNil(fReader);
  TThread.RemoveQueuedEvents(Drain); // nothing of this gdb may arrive later
end;

procedure TGdbEngine.Quit;
var
  Waited: QWord;
  I: Integer;
begin
  if not Assigned(fProcess) then
    Exit;
  fQuitting := True; // no events or answers from here on
  ClearHandlers;
  if fProcess.Running then begin
    Send('-gdb-exit');
    Waited := GetTickCount64;
    while fProcess.Running and (GetTickCount64 - Waited < 3000) do
      Sleep(20);
    if fProcess.Running then
      fProcess.Terminate(1); // gdb did not answer: its pipe closes and the reader ends
  end;
  StopReader;
  FreeAndNil(fProcess);
  fLock.Enter;
  try
    for I := 0 to fQueue.Count - 1 do
      TMIRecord(fQueue[I]).Free;
    fQueue.Clear;
  finally
    fLock.Leave;
  end;
end;

procedure TGdbEngine.LoadProgram(const FileName: String; Handler: TDebugDoneHandler);
begin
  Send('-file-exec-and-symbols ' + MIQuote(FileName), hkDone, TMethod(Handler));
end;

procedure TGdbEngine.SetArguments(const Args: array of String);
var
  Line: String;
  I: Integer;
begin
  // Through the console, so gdb gets exactly this line; /bin/sh splits it
  Line := 'set args';
  for I := 0 to High(Args) do
    Line := Line + ' ' + ShellArgument(Args[I]);
  Send('-interpreter-exec console ' + MIQuote(Line));
end;

procedure TGdbEngine.SetWorkingDir(const Dir: String);
begin
  Send('-environment-cd ' + MIQuote(Dir));
end;

procedure TGdbEngine.SetTerminal(const TtyName: String);
begin
  if TtyName = '' then
    Send('-inferior-tty-set')
  else
    Send('-inferior-tty-set ' + MIQuote(TtyName));
end;

procedure TGdbEngine.InsertBreakpoint(const FileName: String; Line: Integer; Handler: TDebugBreakpointHandler);
begin
  // -f: pending if the file is not loaded yet (a library); explicit
  // location, so a file name with spaces is never split
  Send('-break-insert -f --source ' + MIQuote(FileName) + ' --line ' + IntToStr(Line), hkBreakpoint,
    TMethod(Handler));
end;

procedure TGdbEngine.DeleteBreakpoint(Id: Integer);
begin
  Send('-break-delete ' + IntToStr(Id));
end;

procedure TGdbEngine.Run;
begin
  Send('-exec-run');
end;

procedure TGdbEngine.Continue;
begin
  Send('-exec-continue');
end;

procedure TGdbEngine.Next;
begin
  Send('-exec-next');
end;

procedure TGdbEngine.Step;
begin
  Send('-exec-step');
end;

procedure TGdbEngine.Finish;
begin
  Send('-exec-finish');
end;

procedure TGdbEngine.NextInstruction;
begin
  Send('-exec-next-instruction');
end;

procedure TGdbEngine.StepInstruction;
begin
  Send('-exec-step-instruction');
end;

procedure TGdbEngine.Interrupt;
begin
  Send('-exec-interrupt');
end;

procedure TGdbEngine.Evaluate(const Expression: String; Handler: TDebugValueHandler);
begin
  Send('-data-evaluate-expression ' + MIQuote(Expression), hkValue, TMethod(Handler));
end;

procedure TGdbEngine.Assign(const Expression, Value: String; Handler: TDebugValueHandler);
begin
  Send('-data-evaluate-expression ' + MIQuote(Expression + ' = ' + Value), hkValue, TMethod(Handler));
end;

procedure TGdbEngine.GetFrames(Handler: TDebugFramesHandler);
begin
  Send('-stack-list-frames', hkFrames, TMethod(Handler));
end;

procedure TGdbEngine.UserCommand(const Command: String; Handler: TDebugDoneHandler);
begin
  Send('-interpreter-exec console ' + MIQuote(Command), hkDone, TMethod(Handler));
end;

procedure TGdbEngine.Execute(const Command: String; Handler: TDebugDoneHandler);
begin
  Send(Command, hkDone, TMethod(Handler));
end;

end.
