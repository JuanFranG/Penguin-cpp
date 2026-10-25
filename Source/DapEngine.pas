{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    The debugger engine over lldb-dap, for macOS (gdb does not run on Apple
    Silicon; Xcode's command line tools bring lldb-dap). lldb-dap speaks the
    Debug Adapter Protocol: JSON messages, each after a "Content-Length: N"
    header, on its standard input and output. As in GdbEngine, a thread only
    reads and parses them; they go through a locked queue to the main thread,
    which answers the requests (by their sequence number) and raises the
    events. Nothing here touches the interface (Tests/DapEngineTest).

    What the protocol does differently from gdb, and how it is met here:
      - the program is launched only after its breakpoints are given
        (launch, the "initialized" event, setBreakpoints, configurationDone);
        "stop at main" is a breakpoint on the function main, removed when
        it is hit;
      - breakpoints are given per file, all of a file at once: the engine
        keeps them and gives the file's list again when one changes;
      - a stop says only the thread: the place comes from stackTrace;
      - structures and arrays come as "Punto @ 0x..." with a reference to
        their members: the engine asks for them and writes the value as gdb
        would (members as "x = 1, y = 2" between braces, array elements
        alone), which the watches read;
      - lldb's own commands (the CPU window's disassembly and registers, the
        commands typed by the user) go through evaluate with a ` before;
      - ASLR stays on (disableASLR false): with it off, macOS does not let
        lldb pause the program;
      - the program's terminal (SetTerminal) is set with lldb settings before
        it runs (target.input-path, output-path, error-path).
}

unit DapEngine;

{$MODE DELPHI}

interface

uses
  Classes, SysUtils, SyncObjs, Process, fpjson, jsonparser, DebugEngine;

type
  TDapEngine = class;

  TDapReader = class(TThread)
  private
    fEngine: TDapEngine;
    fPipe: TStream;
  protected
    procedure Execute; override;
  public
    constructor Create(Engine: TDapEngine; Pipe: TStream);
  end;

  TDapHandlerKind = (hkNone, hkDone, hkValue, hkAssign, hkBreakpoints, hkFrames, hkLines, hkRegisters, hkUser,
    hkStopFrame, hkLaunch, hkChildren);

  PDapHandler = ^TDapHandler;
  TDapHandler = record
    Seq: Int64;
    Kind: TDapHandlerKind;
    Method: TMethod;
    Text: String;   // what the answer needs: the file of a setBreakpoints,
    Data: Pointer;  // the value being built (hkChildren), the stop (hkStopFrame)
  end;

  // A breakpoint the engine keeps (lldb-dap takes them per file)
  PDapBreakpoint = ^TDapBreakpoint;
  TDapBreakpoint = record
    Id: Integer;       // the engine's own, for the IDE
    DapId: Integer;    // lldb-dap's, from its last answer (-1 none yet)
    FileName: String;
    Line: Integer;
    Handler: TDebugBreakpointHandler; // still to be answered
  end;

  // A value with members, while they are being asked for (Evaluate)
  TDapValueNode = class
    Name: String;
    Value: String;
    Ref: Integer;
    Children: TList; // TDapValueNode
    constructor Create(const AName, AValue: String; ARef: Integer);
    destructor Destroy; override;
  end;

  TDapValue = class
    Root: TDapValueNode;
    Handler: TDebugValueHandler;
    Pending: Integer;  // requests not answered yet
    Cancelled: Boolean;
    constructor Create(AHandler: TDebugValueHandler);
    destructor Destroy; override;
  end;

  TDapEngine = class(TDebugEngine)
  private
    fDapPath: String;
    fProcess: TProcess;
    fReader: TDapReader;
    fLock: TCriticalSection;
    fQueue: TList;          // TJSONObject read, waiting for the main thread (under fLock)
    fEnded: Boolean;        // the reader saw the end of lldb-dap's output (under fLock)
    fTerminatedSent: Boolean;
    fQuitting: Boolean;
    fHandlers: TList;       // PDapHandler
    fNextSeq: Int64;
    fBreakpoints: TList;    // PDapBreakpoint
    fNextBreakId: Integer;
    fValues: TList;         // TDapValue being built
    fDeferred: TList;       // PDapHandler answered locally (LoadProgram), at the next Drain
    // The program and how to run it
    fProgram: String;
    fArgs: array of String;
    fWorkDir: String;
    fTty: String;
    // The session
    fLaunched: Boolean;     // launch or attach sent
    fConfigured: Boolean;   // configurationDone sent: breakpoints go at once
    fStopAtMain: Boolean;   // a breakpoint on main is set, to remove when hit
    fAttachHandler: TDebugDoneHandler;
    fPausing: Boolean;      // Interrupt was asked: its SIGSTOP is a pause
    fUserCommands: Integer; // commands typed by the user, not answered yet
    fThreadId: Int64;       // the thread of the last stop
    fFrameId: Int64;        // its top frame, for evaluate (0: not stopped)
    fLastPC: String;
    procedure Enqueue(Msg: TJSONObject);
    procedure ReaderEnded;
    procedure Drain;
    procedure DispatchMessage(Msg: TJSONObject);
    procedure Answer(Msg: TJSONObject);
    procedure Event(Msg: TJSONObject);
    function Send(const Command: String; Args: TJSONObject; Kind: TDapHandlerKind; const Handler: TMethod;
      const Text: String = ''; Data: Pointer = nil): Int64; overload;
    procedure Send(const Command: String; Args: TJSONObject = nil); overload;
    function NoHandler: TMethod;
    procedure ClearHandlers;
    procedure StopReader;
    procedure SendFileBreakpoints(const FileName: String);
    procedure SendAllBreakpoints;
    procedure Configure;
    procedure AnswerBreakpoints(const H: TDapHandler; Ok: Boolean; Body: TJSONObject);
    procedure AnswerStop(const H: TDapHandler; Ok: Boolean; Body: TJSONObject);
    procedure AnswerChildren(const H: TDapHandler; Ok: Boolean; Body: TJSONObject);
    procedure AskChildren(V: TDapValue; Node: TDapValueNode);
    procedure FinishValue(V: TDapValue);
    procedure StepCommand(const Command: String; Instruction: Boolean);
    function ThreadArgs: TJSONObject;
  public
    // DapPath: the lldb-dap program
    constructor Create(const DapPath: String);
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

    procedure Run(StopAtMain: Boolean = False); override;
    procedure Attach(Pid: Integer; Handler: TDebugDoneHandler = nil); override;
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
    procedure Disassemble(const Location: String; Handler: TDebugLinesHandler); override;
    procedure SetIntelSyntax(Intel: Boolean); override;
    procedure GetRegisters(Handler: TDebugRegistersHandler); override;
    procedure UserCommand(const Command: String; Handler: TDebugDoneHandler = nil); override;

    procedure CancelHandlers(Owner: TObject); override;
  end;

// A value of lldb-dap that only names its members ("Punto @ 0x16f...",
// "int[3] @ 0x...", "size=3"): the engine asks for them
function IsAggregateSummary(const Value: String): Boolean;

implementation

uses
  devPlatform;

const
  MaxDepth = 3;      // members of members of members
  MaxChildren = 100; // like gdb's print elements, smaller

function IsAggregateSummary(const Value: String): Boolean;
begin
  Result := (Pos(' @ 0x', Value) > 0) or (Copy(Value, 1, 5) = 'size=') or (Value = '');
end;

function GetStr(Obj: TJSONObject; const Name: String; const Default: String = ''): String;
var
  D: TJSONData;
begin
  Result := Default;
  if not Assigned(Obj) then
    Exit;
  D := Obj.Find(Name);
  if Assigned(D) and (D.JSONType in [jtString, jtNumber, jtBoolean]) then
    Result := D.AsString;
end;

function GetInt(Obj: TJSONObject; const Name: String; Default: Int64 = 0): Int64;
var
  D: TJSONData;
begin
  Result := Default;
  if not Assigned(Obj) then
    Exit;
  D := Obj.Find(Name);
  if Assigned(D) and (D.JSONType = jtNumber) then
    Result := D.AsInt64;
end;

function GetObj(Obj: TJSONObject; const Name: String): TJSONObject;
var
  D: TJSONData;
begin
  Result := nil;
  if not Assigned(Obj) then
    Exit;
  D := Obj.Find(Name);
  if Assigned(D) and (D.JSONType = jtObject) then
    Result := TJSONObject(D);
end;

function GetArr(Obj: TJSONObject; const Name: String): TJSONArray;
var
  D: TJSONData;
begin
  Result := nil;
  if not Assigned(Obj) then
    Exit;
  D := Obj.Find(Name);
  if Assigned(D) and (D.JSONType = jtArray) then
    Result := TJSONArray(D);
end;

// A frame of stackTrace. Frames without a source of their own (system
// libraries: the "path" is "/usr/lib/dyld`start") have no file or line
function FrameOf(F: TJSONObject; Level: Integer): TDebugFrame;
var
  Src: TJSONObject;
  Path: String;
begin
  Result.Level := Level;
  Result.Func := GetStr(F, 'name');
  Result.Addr := GetStr(F, 'instructionPointerReference');
  Result.FileName := '';
  Result.FullName := '';
  Result.Line := 0;
  Src := GetObj(F, 'source');
  Path := GetStr(Src, 'path');
  if Assigned(Src) and (Path <> '') and (Pos('`', Path) = 0) and (GetInt(Src, 'sourceReference', 0) = 0) then begin
    Result.FileName := GetStr(Src, 'name');
    Result.FullName := Path;
    Result.Line := GetInt(F, 'line', 0);
  end;
  // "suma(int, int)": the name alone, as gdb gives it
  if Pos('(', Result.Func) > 1 then
    Result.Func := Copy(Result.Func, 1, Pos('(', Result.Func) - 1);
end;

{ TDapValueNode, TDapValue }

constructor TDapValueNode.Create(const AName, AValue: String; ARef: Integer);
begin
  Name := AName;
  Value := AValue;
  Ref := ARef;
  Children := TList.Create;
end;

destructor TDapValueNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to Children.Count - 1 do
    TDapValueNode(Children[I]).Free;
  Children.Free;
  inherited;
end;

constructor TDapValue.Create(AHandler: TDebugValueHandler);
begin
  Handler := AHandler;
end;

destructor TDapValue.Destroy;
begin
  Root.Free;
  inherited;
end;

// The value as gdb writes it: members as "name = value", array elements alone
function FormatNode(Node: TDapValueNode): String;
var
  I: Integer;
  Child: TDapValueNode;
  IsArray: Boolean;
begin
  if Node.Children.Count = 0 then
    Exit(Node.Value);
  IsArray := Copy(TDapValueNode(Node.Children[0]).Name, 1, 1) = '[';
  Result := '{';
  for I := 0 to Node.Children.Count - 1 do begin
    Child := TDapValueNode(Node.Children[I]);
    if I > 0 then
      Result := Result + ', ';
    if IsArray then
      Result := Result + FormatNode(Child)
    else
      Result := Result + Child.Name + ' = ' + FormatNode(Child);
  end;
  Result := Result + '}';
end;

{ TDapReader }

constructor TDapReader.Create(Engine: TDapEngine; Pipe: TStream);
begin
  fEngine := Engine;
  fPipe := Pipe;
  inherited Create(False);
end;

procedure TDapReader.Execute;
var
  Buffer: array[0..8191] of Char;
  Pending, Chunk, Header: String;
  N, P, Len: Integer;
  Data: TJSONData;
begin
  Pending := '';
  while not Terminated do begin
    N := fPipe.Read(Buffer[0], SizeOf(Buffer));
    if N <= 0 then
      Break; // lldb-dap closed its output: it has ended
    SetString(Chunk, PChar(@Buffer[0]), N);
    Pending := Pending + Chunk;
    // Each message: headers, an empty line, then Content-Length bytes
    repeat
      P := Pos(#13#10#13#10, Pending);
      if P = 0 then
        Break;
      Header := LowerCase(Copy(Pending, 1, P - 1));
      Len := -1;
      if Pos('content-length:', Header) > 0 then begin
        Header := Copy(Header, Pos('content-length:', Header) + 15, MaxInt);
        if Pos(#13, Header) > 0 then
          Header := Copy(Header, 1, Pos(#13, Header) - 1);
        Len := StrToIntDef(Trim(Header), -1);
      end;
      if Len < 0 then begin
        Delete(Pending, 1, P + 3); // not a header: skip it
        Continue;
      end;
      if Length(Pending) < P + 3 + Len then
        Break; // the rest has not arrived yet
      Chunk := Copy(Pending, P + 4, Len);
      Delete(Pending, 1, P + 3 + Len);
      try
        Data := GetJSON(Chunk);
      except
        Data := nil;
      end;
      if Assigned(Data) and (Data.JSONType = jtObject) then
        fEngine.Enqueue(TJSONObject(Data))
      else
        Data.Free;
    until False;
  end;
  fEngine.ReaderEnded;
end;

{ TDapEngine }

constructor TDapEngine.Create(const DapPath: String);
begin
  inherited Create;
  fDapPath := DapPath;
  fLock := TCriticalSection.Create;
  fQueue := TList.Create;
  fHandlers := TList.Create;
  fBreakpoints := TList.Create;
  fValues := TList.Create;
  fDeferred := TList.Create;
  fNextSeq := 1;
  fNextBreakId := 1;
end;

destructor TDapEngine.Destroy;
var
  I: Integer;
begin
  Quit;
  for I := 0 to fQueue.Count - 1 do
    TJSONObject(fQueue[I]).Free;
  fQueue.Free;
  ClearHandlers;
  fHandlers.Free;
  for I := 0 to fBreakpoints.Count - 1 do
    Dispose(PDapBreakpoint(fBreakpoints[I]));
  fBreakpoints.Free;
  fValues.Free;
  fDeferred.Free;
  fLock.Free;
  inherited;
end;

procedure TDapEngine.Enqueue(Msg: TJSONObject);
begin
  fLock.Enter;
  try
    fQueue.Add(Msg);
  finally
    fLock.Leave;
  end;
  TThread.Queue(nil, Drain);
end;

procedure TDapEngine.ReaderEnded;
begin
  fLock.Enter;
  try
    fEnded := True;
  finally
    fLock.Leave;
  end;
  TThread.Queue(nil, Drain);
end;

procedure TDapEngine.Drain;
var
  Msgs: TList;
  Ended: Boolean;
  I: Integer;
  H: PDapHandler;
begin
  // Answers given here without lldb-dap (LoadProgram)
  while (fDeferred.Count > 0) and not fQuitting do begin
    H := PDapHandler(fDeferred[0]);
    fDeferred.Delete(0);
    try
      if Assigned(H^.Method.Code) then
        TDebugDoneHandler(H^.Method)(H^.Text = '', H^.Text);
    finally
      Dispose(H);
    end;
  end;

  Msgs := TList.Create;
  try
    fLock.Enter;
    try
      Msgs.Assign(fQueue);
      fQueue.Clear;
      Ended := fEnded;
    finally
      fLock.Leave;
    end;
    for I := 0 to Msgs.Count - 1 do begin
      try
        if not fQuitting then
          DispatchMessage(TJSONObject(Msgs[I]));
      finally
        TJSONObject(Msgs[I]).Free;
        Msgs[I] := nil;
      end;
    end;
  finally
    for I := 0 to Msgs.Count - 1 do // left by an exception in a handler
      TJSONObject(Msgs[I]).Free;
    Msgs.Free;
  end;
  if Ended and not fTerminatedSent and not fQuitting then begin
    fTerminatedSent := True;
    ClearHandlers;
    DoTerminated;
  end;
end;

procedure TDapEngine.DispatchMessage(Msg: TJSONObject);
var
  Kind: String;
begin
  Kind := GetStr(Msg, 'type');
  if Kind = 'response' then
    Answer(Msg)
  else if Kind = 'event' then
    Event(Msg);
  // A request from lldb-dap (runInTerminal) is not asked for: never comes
end;

function TDapEngine.NoHandler: TMethod;
begin
  Result.Code := nil;
  Result.Data := nil;
end;

function TDapEngine.Send(const Command: String; Args: TJSONObject; Kind: TDapHandlerKind; const Handler: TMethod;
  const Text: String; Data: Pointer): Int64;
var
  H: PDapHandler;
  Msg: TJSONObject;
  Body, Frame: String;
begin
  Result := fNextSeq;
  Inc(fNextSeq);
  if Assigned(Handler.Code) or (Kind in [hkStopFrame, hkLaunch, hkChildren, hkBreakpoints, hkUser]) then begin
    New(H);
    H^.Seq := Result;
    H^.Kind := Kind;
    H^.Method := Handler;
    H^.Text := Text;
    H^.Data := Data;
    fHandlers.Add(H);
  end;
  Msg := TJSONObject.Create(['seq', Result, 'type', 'request', 'command', Command]);
  try
    if Assigned(Args) then
      Msg.Add('arguments', Args); // Msg owns it now
    Body := Msg.AsJSON;
  finally
    Msg.Free;
  end;
  if not Running then
    Exit;
  Frame := 'Content-Length: ' + IntToStr(Length(Body)) + #13#10#13#10 + Body;
  try
    fProcess.Input.WriteBuffer(Frame[1], Length(Frame));
  except
    // lldb-dap has gone: OnTerminated follows when the reader sees it
  end;
end;

procedure TDapEngine.Send(const Command: String; Args: TJSONObject);
begin
  Send(Command, Args, hkNone, NoHandler);
end;

procedure TDapEngine.ClearHandlers;
var
  I: Integer;
begin
  for I := 0 to fHandlers.Count - 1 do
    Dispose(PDapHandler(fHandlers[I]));
  fHandlers.Clear;
  for I := 0 to fDeferred.Count - 1 do
    Dispose(PDapHandler(fDeferred[I]));
  fDeferred.Clear;
  for I := 0 to fValues.Count - 1 do
    TDapValue(fValues[I]).Free;
  fValues.Clear;
end;

procedure TDapEngine.CancelHandlers(Owner: TObject);
var
  I: Integer;
begin
  for I := fHandlers.Count - 1 downto 0 do
    if PDapHandler(fHandlers[I])^.Method.Data = Pointer(Owner) then begin
      Dispose(PDapHandler(fHandlers[I]));
      fHandlers.Delete(I);
    end;
  for I := fDeferred.Count - 1 downto 0 do
    if PDapHandler(fDeferred[I])^.Method.Data = Pointer(Owner) then begin
      Dispose(PDapHandler(fDeferred[I]));
      fDeferred.Delete(I);
    end;
  // Values being built still get their members, but tell nobody
  for I := 0 to fValues.Count - 1 do
    if TMethod(TDapValue(fValues[I]).Handler).Data = Pointer(Owner) then
      TDapValue(fValues[I]).Cancelled := True;
  for I := 0 to fBreakpoints.Count - 1 do
    if TMethod(PDapBreakpoint(fBreakpoints[I])^.Handler).Data = Pointer(Owner) then
      PDapBreakpoint(fBreakpoints[I])^.Handler := nil;
end;

function TDapEngine.Start(out Error: String): Boolean;
var
  Exe: String;
  Args: TJSONObject;
begin
  Error := '';
  Result := False;
  if Running then
    Exit(True);
  if Assigned(fProcess) then
    Quit; // an lldb-dap that ended: start clean

  Exe := fDapPath;
  if Exe = '' then
    Exe := FindDeveloperTool('lldb-dap');
  if Exe = '' then begin
    Error := 'lldb-dap not found';
    Exit;
  end;
  fProcess := TProcess.Create(nil);
  fProcess.Executable := Exe;
  fProcess.Options := [poUsePipes]; // stderr apart: only DAP messages on stdout
  PrepareProcessEnvironment(fProcess, True);
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
  fEnded := False;
  fLaunched := False;
  fConfigured := False;
  fFrameId := 0;
  fThreadId := 0;
  fUserCommands := 0;
  fReader := TDapReader.Create(Self, fProcess.Output);

  Args := TJSONObject.Create(['clientID', 'penguin-cpp', 'clientName', 'Penguin cpp', 'adapterID', 'lldb-dap',
    'linesStartAt1', True, 'columnsStartAt1', True, 'pathFormat', 'path', 'supportsRunInTerminalRequest', False]);
  Send('initialize', Args);
  Result := True;
end;

function TDapEngine.Running: Boolean;
begin
  Result := Assigned(fProcess) and fProcess.Running;
end;

procedure TDapEngine.StopReader;
begin
  if not Assigned(fReader) then
    Exit;
  fReader.WaitFor;
  FreeAndNil(fReader);
  TThread.RemoveQueuedEvents(Drain); // nothing of this lldb-dap may arrive later
end;

procedure TDapEngine.Quit;
var
  Waited: QWord;
  I: Integer;
begin
  if not Assigned(fProcess) then
    Exit;
  fQuitting := True; // no events or answers from here on
  ClearHandlers;
  if fProcess.Running then begin
    Send('disconnect', TJSONObject.Create(['terminateDebuggee', True]));
    try
      fProcess.CloseInput; // lldb-dap ends when its input ends
    except
    end;
    Waited := GetTickCount64;
    while fProcess.Running and (GetTickCount64 - Waited < 3000) do
      Sleep(20);
    if fProcess.Running then
      fProcess.Terminate(1);
  end;
  StopReader;
  FreeAndNil(fProcess);
  fLock.Enter;
  try
    for I := 0 to fQueue.Count - 1 do
      TJSONObject(fQueue[I]).Free;
    fQueue.Clear;
  finally
    fLock.Leave;
  end;
end;

procedure TDapEngine.LoadProgram(const FileName: String; Handler: TDebugDoneHandler);
var
  H: PDapHandler;
begin
  // lldb-dap takes the program with launch; here it only has to exist
  fProgram := FileName;
  if not Assigned(Handler) then
    Exit;
  New(H);
  H^.Kind := hkDone;
  H^.Method := TMethod(Handler);
  if FileExists(FileName) then
    H^.Text := ''
  else
    H^.Text := FileName + ': No such file';
  fDeferred.Add(H);
  TThread.Queue(nil, Drain); // answered later, as a debugger would
end;

procedure TDapEngine.SetArguments(const Args: array of String);
var
  I: Integer;
begin
  SetLength(fArgs, Length(Args));
  for I := 0 to High(Args) do
    fArgs[I] := Args[I];
end;

procedure TDapEngine.SetWorkingDir(const Dir: String);
begin
  fWorkDir := Dir;
end;

procedure TDapEngine.SetTerminal(const TtyName: String);
begin
  fTty := TtyName;
end;

{ Breakpoints }

procedure TDapEngine.SendFileBreakpoints(const FileName: String);
var
  Lines: TJSONArray;
  I: Integer;
  B: PDapBreakpoint;
begin
  Lines := TJSONArray.Create;
  for I := 0 to fBreakpoints.Count - 1 do begin
    B := PDapBreakpoint(fBreakpoints[I]);
    if B^.FileName = FileName then
      Lines.Add(TJSONObject.Create(['line', B^.Line]));
  end;
  Send('setBreakpoints', TJSONObject.Create(['source', TJSONObject.Create(['path', FileName]), 'breakpoints', Lines]),
    hkBreakpoints, NoHandler, FileName);
end;

procedure TDapEngine.SendAllBreakpoints;
var
  Files: TStringList;
  I: Integer;
begin
  Files := TStringList.Create;
  try
    Files.Sorted := True;
    Files.Duplicates := dupIgnore;
    for I := 0 to fBreakpoints.Count - 1 do
      Files.Add(PDapBreakpoint(fBreakpoints[I])^.FileName);
    for I := 0 to Files.Count - 1 do
      SendFileBreakpoints(Files[I]);
  finally
    Files.Free;
  end;
end;

procedure TDapEngine.InsertBreakpoint(const FileName: String; Line: Integer; Handler: TDebugBreakpointHandler);
var
  B: PDapBreakpoint;
begin
  New(B);
  B^.Id := fNextBreakId;
  Inc(fNextBreakId);
  B^.DapId := -1;
  B^.FileName := FileName;
  B^.Line := Line;
  B^.Handler := Handler;
  fBreakpoints.Add(B);
  // Before the program runs they all go together, when lldb-dap asks
  if fConfigured then
    SendFileBreakpoints(FileName);
end;

procedure TDapEngine.DeleteBreakpoint(Id: Integer);
var
  I: Integer;
  FileName: String;
begin
  for I := fBreakpoints.Count - 1 downto 0 do
    if PDapBreakpoint(fBreakpoints[I])^.Id = Id then begin
      FileName := PDapBreakpoint(fBreakpoints[I])^.FileName;
      Dispose(PDapBreakpoint(fBreakpoints[I]));
      fBreakpoints.Delete(I);
      if fConfigured then
        SendFileBreakpoints(FileName);
      Exit;
    end;
end;

// lldb-dap answers a file's list in the order it was given
procedure TDapEngine.AnswerBreakpoints(const H: TDapHandler; Ok: Boolean; Body: TJSONObject);
var
  Answers: TJSONArray;
  I, N: Integer;
  B: PDapBreakpoint;
  A: TJSONObject;
  Handler: TDebugBreakpointHandler;
  Error: String;
begin
  Answers := GetArr(Body, 'breakpoints');
  N := 0;
  for I := 0 to fBreakpoints.Count - 1 do begin
    B := PDapBreakpoint(fBreakpoints[I]);
    if B^.FileName <> H.Text then
      Continue;
    A := nil;
    if Assigned(Answers) and (N < Answers.Count) and (Answers[N].JSONType = jtObject) then
      A := TJSONObject(Answers[N]);
    Inc(N);
    Error := '';
    if Assigned(A) then begin
      B^.DapId := GetInt(A, 'id', -1);
      if not (A.Get('verified', False)) then
        Error := GetStr(A, 'message');
    end else if not Ok then
      Error := 'breakpoint not set';
    if Assigned(B^.Handler) then begin
      Handler := B^.Handler;
      B^.Handler := nil;
      // Not verified yet is fine: the program's code may not be loaded
      Handler(Ok and Assigned(A), B^.Id, B^.FileName, B^.Line, Error);
    end;
  end;
end;

{ Running }

procedure TDapEngine.Run(StopAtMain: Boolean);
var
  Args: TJSONObject;
  ArgList, Pre: TJSONArray;
  I: Integer;
begin
  fStopAtMain := StopAtMain;
  ArgList := TJSONArray.Create;
  for I := 0 to High(fArgs) do
    ArgList.Add(fArgs[I]);
  Args := TJSONObject.Create(['program', fProgram, 'args', ArgList, 'stopOnEntry', False, 'disableASLR', False]);
  if fWorkDir <> '' then
    Args.Add('cwd', fWorkDir);
  if fTty <> '' then begin
    Pre := TJSONArray.Create;
    Pre.Add('settings set target.input-path ' + fTty);
    Pre.Add('settings set target.output-path ' + fTty);
    Pre.Add('settings set target.error-path ' + fTty);
    Args.Add('preRunCommands', Pre);
  end;
  fLaunched := True;
  Send('launch', Args, hkLaunch, NoHandler);
end;

procedure TDapEngine.Attach(Pid: Integer; Handler: TDebugDoneHandler);
begin
  fAttachHandler := Handler;
  fStopAtMain := False;
  fLaunched := True;
  Send('attach', TJSONObject.Create(['pid', Pid, 'program', fProgram, 'stopOnEntry', True]), hkLaunch, NoHandler,
    'attach');
end;

// lldb-dap has the program: breakpoints, the stop at main, and it may run
procedure TDapEngine.Configure;
var
  Funcs: TJSONArray;
begin
  SendAllBreakpoints;
  if fStopAtMain then begin
    Funcs := TJSONArray.Create;
    Funcs.Add(TJSONObject.Create(['name', 'main']));
    Send('setFunctionBreakpoints', TJSONObject.Create(['breakpoints', Funcs]));
  end;
  Send('configurationDone');
  fConfigured := True;
end;

function TDapEngine.ThreadArgs: TJSONObject;
begin
  Result := TJSONObject.Create(['threadId', fThreadId]);
end;

procedure TDapEngine.Continue;
begin
  Send('continue', ThreadArgs);
end;

procedure TDapEngine.StepCommand(const Command: String; Instruction: Boolean);
var
  Args: TJSONObject;
begin
  Args := ThreadArgs;
  if Instruction then
    Args.Add('granularity', 'instruction');
  Send(Command, Args);
end;

procedure TDapEngine.Next;
begin
  StepCommand('next', False);
end;

procedure TDapEngine.Step;
begin
  StepCommand('stepIn', False);
end;

procedure TDapEngine.Finish;
begin
  StepCommand('stepOut', False);
end;

procedure TDapEngine.NextInstruction;
begin
  StepCommand('next', True);
end;

procedure TDapEngine.StepInstruction;
begin
  StepCommand('stepIn', True);
end;

procedure TDapEngine.Interrupt;
begin
  fPausing := True;
  Send('pause', ThreadArgs);
end;

{ Answers and events }

procedure TDapEngine.Answer(Msg: TJSONObject);
var
  Seq: Int64;
  I: Integer;
  H: TDapHandler;
  Ok: Boolean;
  Error, Value: String;
  Body: TJSONObject;
  Frames: TDebugFrames;
  Stack: TJSONArray;
  Lines, Names, Values: TStringList;
  V: TDapValue;
begin
  Seq := GetInt(Msg, 'request_seq', -1);
  Ok := Msg.Get('success', False);
  Body := GetObj(Msg, 'body');
  Error := GetStr(Msg, 'message');
  if Assigned(GetObj(Body, 'error')) then
    Error := GetStr(GetObj(Body, 'error'), 'format', Error);
  I := 0;
  while (I < fHandlers.Count) and (PDapHandler(fHandlers[I])^.Seq <> Seq) do
    Inc(I);
  if I >= fHandlers.Count then begin
    // Nobody waits for this answer (Next, Continue...): a refusal still has
    // to reach the user
    if not Ok and (Error <> '') then
      DoOutput(Trim(Error) + LineEnding, doLog);
    Exit;
  end;
  H := PDapHandler(fHandlers[I])^;
  Dispose(PDapHandler(fHandlers[I]));
  fHandlers.Delete(I);

  case H.Kind of
    hkDone:
      TDebugDoneHandler(H.Method)(Ok, Trim(Error));
    hkLaunch: begin
        if not Ok then begin
          DoOutput(Trim(Error) + LineEnding, doLog);
          if H.Text = 'attach' then begin
            if Assigned(fAttachHandler) then
              fAttachHandler(False, Trim(Error));
          end else
            DoExited(-1); // the program could not start
        end else if (H.Text = 'attach') and Assigned(fAttachHandler) then
          fAttachHandler(True, '');
      end;
    hkValue: begin
        Value := GetStr(Body, 'result');
        if not Ok then
          TDebugValueHandler(H.Method)(False, Trim(Error))
        else if (GetInt(Body, 'variablesReference', 0) > 0) and IsAggregateSummary(Value) then begin
          // Members to ask for first
          V := TDapValue.Create(TDebugValueHandler(H.Method));
          V.Root := TDapValueNode.Create('', Value, GetInt(Body, 'variablesReference', 0));
          fValues.Add(V);
          AskChildren(V, V.Root);
        end else
          TDebugValueHandler(H.Method)(True, Value);
      end;
    hkAssign:
      if Ok then
        TDebugValueHandler(H.Method)(True, GetStr(Body, 'result'))
      else
        TDebugValueHandler(H.Method)(False, Trim(Error));
    hkBreakpoints:
      AnswerBreakpoints(H, Ok, Body);
    hkStopFrame:
      AnswerStop(H, Ok, Body);
    hkChildren:
      AnswerChildren(H, Ok, Body);
    hkFrames: begin
        SetLength(Frames, 0);
        Stack := GetArr(Body, 'stackFrames');
        if Ok and Assigned(Stack) then begin
          SetLength(Frames, Stack.Count);
          for I := 0 to Stack.Count - 1 do
            if Stack[I].JSONType = jtObject then
              Frames[I] := FrameOf(TJSONObject(Stack[I]), I);
        end;
        TDebugFramesHandler(H.Method)(Ok, Frames);
      end;
    hkUser: begin
        if fUserCommands > 0 then
          Dec(fUserCommands);
        if GetStr(Body, 'result') <> '' then
          DoOutput(GetStr(Body, 'result'), doConsole);
        if not Ok then
          DoOutput(Trim(Error) + LineEnding, doLog);
        if Assigned(H.Method.Code) then
          TDebugDoneHandler(H.Method)(Ok, Trim(Error));
      end;
    hkLines: begin
        // "p`suma:" then "->  0x100 <+12>: add w0, w1, w2" (the current one)
        Lines := TStringList.Create;
        try
          Lines.Text := GetStr(Body, 'result');
          for I := Lines.Count - 1 downto 0 do
            if Trim(Lines[I]) = '' then
              Lines.Delete(I);
          if Lines.Count > 0 then begin
            Value := Trim(Lines[0]);
            if Pos('`', Value) > 0 then
              Value := Copy(Value, Pos('`', Value) + 1, MaxInt);
            if (Value <> '') and (Value[Length(Value)] = ':') then
              Delete(Value, Length(Value), 1);
            Lines[0] := Value;
          end;
          for I := 1 to Lines.Count - 1 do
            if Copy(Lines[I], 1, 2) = '->' then
              Lines[I] := '=> ' + Trim(Copy(Lines[I], 3, MaxInt))
            else
              Lines[I] := '   ' + Trim(Lines[I]);
          TDebugLinesHandler(H.Method)(Ok and (Lines.Count > 0), Lines);
        finally
          Lines.Free;
        end;
      end;
    hkRegisters: begin
        // "      pc = 0x0000000100ebc550  p`main + 64 at p.cpp:9:7"
        Names := TStringList.Create;
        Values := TStringList.Create;
        Lines := TStringList.Create;
        try
          Lines.Text := GetStr(Body, 'result');
          for I := 0 to Lines.Count - 1 do
            if Pos(' = ', Lines[I]) > 0 then begin
              Names.Add(Trim(Copy(Lines[I], 1, Pos(' = ', Lines[I]) - 1)));
              Value := Trim(Copy(Lines[I], Pos(' = ', Lines[I]) + 3, MaxInt));
              if Pos(' ', Value) > 0 then
                Value := Copy(Value, 1, Pos(' ', Value) - 1);
              Values.Add(Value);
            end;
          TDebugRegistersHandler(H.Method)(Ok and (Names.Count > 0), Names, Values);
        finally
          Lines.Free;
          Values.Free;
          Names.Free;
        end;
      end;
  end;
end;

procedure TDapEngine.Event(Msg: TJSONObject);
var
  Name, Category, Text, Reason: String;
  Body: TJSONObject;
  Stop: ^TDebugStopInfo;
  Hits: TJSONArray;
  I, J: Integer;
begin
  Name := GetStr(Msg, 'event');
  Body := GetObj(Msg, 'body');
  if Name = 'initialized' then
    Configure
  else if Name = 'output' then begin
    Category := GetStr(Body, 'category', 'console');
    Text := GetStr(Body, 'output');
    if (Category = 'stdout') or (Category = 'stderr') then
      DoOutput(Text, doProgram)
    else if Category = 'console' then begin
      // lldb-dap tells its console what it does (the commands before the
      // run, "Ran expression as C++14", the errors of a hovered word):
      // shown only for the commands the user types
      if fUserCommands > 0 then
        DoOutput(Text, doConsole);
    end
    else if Category <> 'telemetry' then
      DoOutput(Text, doLog);
  end else if Name = 'continued' then begin
    fFrameId := 0;
    DoRunning;
  end else if Name = 'stopped' then begin
    fThreadId := GetInt(Body, 'threadId', fThreadId);
    fFrameId := 0;
    // Where: the top frame of that thread, then the event
    New(Stop);
    FillChar(Stop^, SizeOf(Stop^), 0);
    Stop^.BreakpointId := -1;
    Reason := GetStr(Body, 'reason');
    if (Reason = 'breakpoint') or (Reason = 'function breakpoint') then
      Stop^.Reason := dsBreakpoint
    else if Reason = 'step' then
      Stop^.Reason := dsStep
    else if Reason = 'pause' then
      Stop^.Reason := dsInterrupted
    else if (Reason = 'exception') or (Reason = 'signal') then begin
      Stop^.Reason := dsSignal;
      // "EXC_BAD_ACCESS (code=1, address=0x0)", "signal SIGABRT"
      Text := Trim(GetStr(Body, 'description', GetStr(Body, 'text')));
      if Copy(Text, 1, 7) = 'signal ' then
        Delete(Text, 1, 7);
      Stop^.SignalName := Text;
      if Pos(' ', Text) > 0 then
        Stop^.SignalName := Copy(Text, 1, Pos(' ', Text) - 1);
      Stop^.SignalMeaning := Text;
    end else
      Stop^.Reason := dsOther;
    // lldb-dap reports the pause it was asked for as SIGSTOP
    if fPausing and ((Stop^.Reason = dsSignal) and (Stop^.SignalName = 'SIGSTOP') or (Stop^.Reason = dsOther)) then
      Stop^.Reason := dsInterrupted;
    fPausing := False;
    Hits := GetArr(Body, 'hitBreakpointIds');
    if Assigned(Hits) then
      for I := 0 to Hits.Count - 1 do
        for J := 0 to fBreakpoints.Count - 1 do
          if PDapBreakpoint(fBreakpoints[J])^.DapId = Hits[I].AsInt64 then
            Stop^.BreakpointId := PDapBreakpoint(fBreakpoints[J])^.Id;
    Send('stackTrace', TJSONObject.Create(['threadId', fThreadId, 'startFrame', 0, 'levels', 1]), hkStopFrame,
      NoHandler, '', Stop);
  end else if Name = 'process' then
    DoRunning // launched or attached: no "continued" comes for that
  else if Name = 'exited' then
    DoExited(GetInt(Body, 'exitCode', -1));
  // "terminated" is the end of the session, not of lldb-dap: the IDE stops
  // it after the program ended; OnTerminated comes only when lldb-dap ends
end;

procedure TDapEngine.AnswerStop(const H: TDapHandler; Ok: Boolean; Body: TJSONObject);
var
  Stop: ^TDebugStopInfo;
  Stack: TJSONArray;
  Info: TDebugStopInfo;
begin
  Stop := H.Data;
  try
    Info := Stop^;
    Info.Frame.Level := -1;
    Stack := GetArr(Body, 'stackFrames');
    if Ok and Assigned(Stack) and (Stack.Count > 0) and (Stack[0].JSONType = jtObject) then begin
      Info.Frame := FrameOf(TJSONObject(Stack[0]), 0);
      fFrameId := GetInt(TJSONObject(Stack[0]), 'id', 0);
      fLastPC := Info.Frame.Addr;
    end;
    // The stop at the start of main: a breakpoint of the engine, gone now
    if fStopAtMain and (Info.Reason = dsBreakpoint) and (Info.Frame.Func = 'main') then begin
      fStopAtMain := False;
      Send('setFunctionBreakpoints', TJSONObject.Create(['breakpoints', TJSONArray.Create]));
    end;
    DoStopped(Info);
  finally
    Dispose(Stop);
  end;
end;

{ Values }

procedure TDapEngine.Evaluate(const Expression: String; Handler: TDebugValueHandler);
var
  Args: TJSONObject;
begin
  Args := TJSONObject.Create(['expression', Expression, 'context', 'watch']);
  if fFrameId <> 0 then
    Args.Add('frameId', fFrameId);
  Send('evaluate', Args, hkValue, TMethod(Handler));
end;

procedure TDapEngine.Assign(const Expression, Value: String; Handler: TDebugValueHandler);
var
  Args: TJSONObject;
begin
  Args := TJSONObject.Create(['expression', Expression + ' = ' + Value, 'context', 'watch']);
  if fFrameId <> 0 then
    Args.Add('frameId', fFrameId);
  Send('evaluate', Args, hkAssign, TMethod(Handler));
end;

procedure TDapEngine.AskChildren(V: TDapValue; Node: TDapValueNode);
begin
  Inc(V.Pending);
  Send('variables', TJSONObject.Create(['variablesReference', Node.Ref, 'count', MaxChildren]), hkChildren,
    NoHandler, '', Node);
  // The node and its value: kept in the handler's Data and in fValues
  PDapHandler(fHandlers[fHandlers.Count - 1])^.Method.Data := V;
end;

function NodeDepth(V: TDapValue; Node: TDapValueNode): Integer;

  function Find(N: TDapValueNode; Depth: Integer): Integer;
  var
    I: Integer;
  begin
    if N = Node then
      Exit(Depth);
    for I := 0 to N.Children.Count - 1 do begin
      Result := Find(TDapValueNode(N.Children[I]), Depth + 1);
      if Result >= 0 then
        Exit;
    end;
    Result := -1;
  end;

begin
  Result := Find(V.Root, 0);
end;

procedure TDapEngine.AnswerChildren(const H: TDapHandler; Ok: Boolean; Body: TJSONObject);
var
  V: TDapValue;
  Node, Child: TDapValueNode;
  Vars: TJSONArray;
  Item: TJSONObject;
  I, Depth: Integer;
begin
  V := TDapValue(H.Method.Data);
  Node := TDapValueNode(H.Data);
  if fValues.IndexOf(V) = -1 then
    Exit; // already freed (Quit)
  Dec(V.Pending);
  Vars := GetArr(Body, 'variables');
  Depth := NodeDepth(V, Node);
  if Ok and Assigned(Vars) then
    for I := 0 to Vars.Count - 1 do begin
      if Vars[I].JSONType <> jtObject then
        Continue;
      Item := TJSONObject(Vars[I]);
      Child := TDapValueNode.Create(GetStr(Item, 'name'), GetStr(Item, 'value'), GetInt(Item, 'variablesReference', 0));
      Node.Children.Add(Child);
      if (Child.Ref > 0) and IsAggregateSummary(Child.Value) and (Depth + 1 < MaxDepth) then
        AskChildren(V, Child)
      else if (Child.Ref > 0) and IsAggregateSummary(Child.Value) then
        Child.Value := '{...}';
    end;
  if V.Pending = 0 then
    FinishValue(V);
end;

procedure TDapEngine.FinishValue(V: TDapValue);
var
  Text: String;
begin
  fValues.Remove(V);
  try
    if not V.Cancelled and Assigned(V.Handler) then begin
      if V.Root.Children.Count > 0 then
        Text := FormatNode(V.Root)
      else
        Text := '{}';
      V.Handler(True, Text);
    end;
  finally
    V.Free;
  end;
end;

procedure TDapEngine.GetFrames(Handler: TDebugFramesHandler);
begin
  Send('stackTrace', TJSONObject.Create(['threadId', fThreadId, 'startFrame', 0, 'levels', 64]), hkFrames,
    TMethod(Handler));
end;

{ lldb's own commands }

procedure TDapEngine.Disassemble(const Location: String; Handler: TDebugLinesHandler);
var
  Command: String;
  Args: TJSONObject;
begin
  if Location = '' then
    Command := '`disassemble --frame'
  else if Copy(Location, 1, 2) = '0x' then
    Command := '`disassemble --start-address ' + Location + ' --count 40'
  else
    Command := '`disassemble --name ' + Location;
  Args := TJSONObject.Create(['expression', Command, 'context', 'repl']);
  if fFrameId <> 0 then
    Args.Add('frameId', fFrameId);
  Send('evaluate', Args, hkLines, TMethod(Handler));
end;

procedure TDapEngine.SetIntelSyntax(Intel: Boolean);
begin
  // Apple Silicon has a single assembly syntax
end;

procedure TDapEngine.GetRegisters(Handler: TDebugRegistersHandler);
var
  Args: TJSONObject;
begin
  Args := TJSONObject.Create(['expression', '`register read', 'context', 'repl']);
  if fFrameId <> 0 then
    Args.Add('frameId', fFrameId);
  Send('evaluate', Args, hkRegisters, TMethod(Handler));
end;

procedure TDapEngine.UserCommand(const Command: String; Handler: TDebugDoneHandler);
var
  Args: TJSONObject;
begin
  // The user types lldb's commands: the ` makes lldb-dap read one so
  Args := TJSONObject.Create(['expression', '`' + Command, 'context', 'repl']);
  if fFrameId <> 0 then
    Args.Add('frameId', fFrameId);
  Inc(fUserCommands);
  Send('evaluate', Args, hkUser, TMethod(Handler));
end;

end.
