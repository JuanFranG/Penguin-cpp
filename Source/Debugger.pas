{
    This file is part of Dev-C++
    Copyright (c) 2004 Bloodshed Software

    Dev-C++ is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Dev-C++ is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Dev-C++; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

{ The IDE's side of debugging (Penguin cpp): breakpoints, watches, the
  active line, the debug panel. It drives a TDebugEngine (GdbEngine on
  Linux) and gives the program a terminal of its own (DebugTerminal).
  Dev-C++ talked to gdb's --annotate=2 output through a reader thread that
  also changed the watch tree outside the main thread; the engine's events
  all arrive on the main thread. }

unit Debugger;

{$MODE DELPHI}

interface

uses
  SysUtils, Classes, Forms, Controls, ComCtrls, Dialogs, Editor, DebugEngine, GdbEngine, DebugTerminal,
  MultiLangSupport;

type
  PWatchVar = ^TWatchVar;
  TWatchVar = record
    Name: String;
    Node: TTreeNode;
    Available: boolean; // it has a value in the current context
  end;

  PBreakPoint = ^TBreakPoint;
  TBreakPoint = record
    line: integer;
    editor: TEditor;
    id: integer; // the debugger's number while a session runs, -1 otherwise
  end;

  TDebugger = class(TObject)
  private
    fEngine: TGdbEngine;
    fTerminal: TDebugTerminal;
    fExecuting: boolean;
    fPaused: boolean;
    fCommandChanged: boolean;
    fDebugView: TTreeView;
    fLeftPageIndexBackup: integer;
    fBreakPointList: TList;
    fWatchVarList: TList;
    fActiveFile: String;
    fPartialOutput: String;   // output without its line break yet
    fWatchQueue: TStringList; // watches still to evaluate after a stop
    fWatchPending: String;    // the one being evaluated
    fSignalText: String;
    procedure EngineStopped(Sender: TObject; const Info: TDebugStopInfo);
    procedure EngineRunning(Sender: TObject);
    procedure EngineExited(Sender: TObject; ExitCode: Integer);
    procedure EngineOutput(Sender: TObject; const Text: String; Kind: TDebugOutputKind);
    procedure EngineTerminated(Sender: TObject);
    procedure ProgramLoaded(Ok: Boolean; const Error: String);
    procedure Attached(Ok: Boolean; const Error: String);
    procedure BreakpointInserted(Ok: Boolean; Id: Integer; const FileName: String; Line: Integer;
      const Error: String);
    procedure WatchEvaluated(Ok: Boolean; const Value: String);
    procedure EvaluateNextWatch;
    procedure ShowWatchValue(Watch: PWatchVar; const Value: String);
    procedure ShowSignal(Data: PtrInt);
    procedure AddOutput(const Text: String);
    function FindWatch(const Name: String): PWatchVar;
    function StartEngine: Boolean;
    procedure OpenTerminal(const Exe: String; out TtyName: String);
  public
    constructor Create;
    destructor Destroy; override;

    // A session: the program (for a library, its host program), its
    // command line as the user typed it, and its folder
    function Start(const Exe, Args, WorkDir: String): Boolean;
    function Attach(const Exe: String; Pid: Integer): Boolean;
    procedure Stop;

    // While paused
    procedure Next;
    procedure Step;
    procedure Continue;
    procedure Finish;
    procedure NextInstruction;
    procedure StepInstruction;
    // While running
    procedure Pause;

    procedure Evaluate(const Expression: String; Handler: TDebugValueHandler);
    procedure Assign(const Expression, Value: String);
    procedure UserCommand(const Command: String);
    // Forgets the pending answers of an object that goes away
    procedure CancelHandlers(Owner: TObject);

    // breakpoints
    procedure AddBreakPoint(i: integer); overload;
    procedure RemoveBreakPoint(i: integer); overload;
    procedure AddBreakPoint(Linein: integer; e: TEditor); overload;
    procedure RemoveBreakPoint(Linein: integer; e: TEditor); overload;
    procedure DeleteBreakPointsOf(editor: TEditor);

    // watch var
    procedure AddWatchVar(const namein: String);
    procedure RemoveWatchVar(nodein: TTreeNode);
    procedure RefreshWatchVars;
    procedure DeleteWatchVars(deleteparent: boolean);

    // Access
    property Executing: boolean read fExecuting;
    property Paused: boolean read fPaused;
    property LeftPageIndexBackup: integer read fLeftPageIndexBackup write fLeftPageIndexBackup;
    property WatchVarList: TList read fWatchVarList;
    property BreakPointList: TList read fBreakPointList;
    property CommandChanged: boolean read fCommandChanged write fCommandChanged;
    property DebugView: TTreeView read fDebugView write fDebugView;
    property BreakPointFile: String read fActiveFile;
    // For the CPU window; nil when no session runs
    property Engine: TGdbEngine read fEngine;
  end;

implementation

uses
  System.UITypes, Process, Math, main, devCFG, Utils, CPUFrm, GdbMI, Version;

const
  MaxWatchChildren = 200; // long arrays: the first ones are enough
  MaxOutputLines = 5000;  // the debug panel keeps the latest lines
  MaxLineLength = 65536;  // output without line breaks is cut into lines

constructor TDebugger.Create;
begin
  inherited;
  fBreakPointList := TList.Create;
  fWatchVarList := TList.Create;
  fWatchQueue := TStringList.Create;
  fTerminal := TDebugTerminal.Create;
end;

destructor TDebugger.Destroy;
var
  I: integer;
begin
  Application.RemoveAsyncCalls(Self);
  Stop;
  FreeAndNil(fEngine);
  fTerminal.Free;
  fWatchQueue.Free;

  for I := 0 to fWatchVarList.Count - 1 do
    Dispose(PWatchVar(fWatchVarList.Items[I]));
  fWatchVarList.Free;

  for I := 0 to fBreakPointList.Count - 1 do
    Dispose(PBreakPoint(fBreakPointList.Items[I]));
  fBreakPointList.Free;

  inherited;
end;

function TDebugger.StartEngine: Boolean;
var
  CompilerSet: TdevCompilerSet;
  GdbFile, Error: String;
begin
  Result := False;
  CompilerSet := devCompilerSets.CompilationSet;
  if not Assigned(CompilerSet) or (CompilerSet.gdbName = '') then begin
    MessageDlg(Lang[ID_ERR_GDBNOUTFOUND], mtError, [mbOK], 0);
    Exit;
  end;
  // The compiler set's gdb, or the one in PATH
  GdbFile := CompilerSet.gdbName;
  if (CompilerSet.BinDir.Count > 0) and FileExists(CompilerSet.BinDir[0] + pd + CompilerSet.gdbName) then
    GdbFile := CompilerSet.BinDir[0] + pd + CompilerSet.gdbName;

  FreeAndNil(fEngine);
  fEngine := TGdbEngine.Create(GdbFile);
  fEngine.OnStopped := EngineStopped;
  fEngine.OnRunning := EngineRunning;
  fEngine.OnExited := EngineExited;
  fEngine.OnOutput := EngineOutput;
  fEngine.OnTerminated := EngineTerminated;
  if not fEngine.Start(Error) then begin
    MessageDlg(Format(Lang[ID_ERR_ERRORLAUNCHINGGDB], [GdbFile, Error]), mtError, [mbOK], 0);
    FreeAndNil(fEngine);
    Exit;
  end;
  Result := True;
end;

// The program's own terminal; without one, its output comes to the panel
procedure TDebugger.OpenTerminal(const Exe: String; out TtyName: String);
var
  Error: String;
begin
  TtyName := '';
  if fTerminal.Open(Format(Lang[ID_DEBUG_TERMINALHEADER], [ExtractFileName(Exe)]), devData.TerminalProgram,
    Error) then
    TtyName := fTerminal.WaitForTty(8000);
  if TtyName = '' then begin
    fTerminal.Close;
    if Error = '' then
      Error := 'timeout';
    AddOutput(Format(Lang[ID_DEBUG_NOTERMINAL], [Error]) + LineEnding);
  end;
end;

function TDebugger.Start(const Exe, Args, WorkDir: String): Boolean;
var
  ArgList: TStringList;
  ArgArray: array of String;
  TtyName: String;
  I: integer;
begin
  Stop;
  Result := StartEngine;
  if not Result then
    Exit;
  fExecuting := True;
  fPaused := False;
  fPartialOutput := '';

  OpenTerminal(Exe, TtyName);
  fEngine.LoadProgram(Exe, ProgramLoaded);

  // The command line as typed, split like a shell would split it
  ArgList := TStringList.Create;
  try
    CommandToList(Args, ArgList);
    SetLength(ArgArray, ArgList.Count);
    for I := 0 to ArgList.Count - 1 do
      ArgArray[I] := ArgList[I];
  finally
    ArgList.Free;
  end;
  fEngine.SetArguments(ArgArray);
  if WorkDir <> '' then
    fEngine.SetWorkingDir(WorkDir);
  fEngine.SetTerminal(TtyName);

  for I := 0 to fBreakPointList.Count - 1 do
    AddBreakPoint(I);

  // Pauses at the start of main, as Dev-C++'s 'start' did
  fEngine.Run(True);

  MainForm.UpdateAppTitle;
  Application.HintHidePause := 5000;
end;

function TDebugger.Attach(const Exe: String; Pid: Integer): Boolean;
var
  I: integer;
begin
  Stop;
  Result := StartEngine;
  if not Result then
    Exit;
  fExecuting := True;
  fPaused := False;
  fPartialOutput := '';
  fEngine.LoadProgram(Exe, ProgramLoaded);
  for I := 0 to fBreakPointList.Count - 1 do
    AddBreakPoint(I);
  fEngine.Attach(Pid, Attached);
  MainForm.UpdateAppTitle;
  Application.HintHidePause := 5000;
end;

procedure TDebugger.Stop;
var
  I: integer;
begin
  if not fExecuting then
    Exit;
  fExecuting := False;
  fPaused := False;

  if fWatchVarList.Count = 0 then // nothing worth showing, restore view
    MainForm.LeftPageControl.ActivePageIndex := LeftPageIndexBackup;

  if Assigned(CPUForm) then
    CPUForm.Close;

  // gdb ends the program it started, then itself; no event comes after it
  if Assigned(fEngine) then
    fEngine.Quit;
  fTerminal.Close;
  fWatchQueue.Clear;
  fWatchPending := '';
  for I := 0 to fBreakPointList.Count - 1 do
    PBreakPoint(fBreakPointList[I])^.id := -1;
  if fPartialOutput <> '' then
    AddOutput(LineEnding);

  MainForm.RemoveActiveBreakpoints;
  MainForm.UpdateAppTitle;
  Application.HintHidePause := 2500;
end;

procedure TDebugger.ProgramLoaded(Ok: Boolean; const Error: String);
begin
  if not Ok then begin
    MessageDlg(Error, mtError, [mbOK], 0);
    Stop;
  end;
end;

procedure TDebugger.Attached(Ok: Boolean; const Error: String);
begin
  if not Ok then begin
    // Usually Linux' ptrace_scope: only a debugger's own children can be attached to
    MessageDlg(Error, mtError, [mbOK], 0);
    Stop;
  end;
end;

{ Events of the engine, on the main thread }

procedure TDebugger.EngineRunning(Sender: TObject);
begin
  fPaused := False;
  MainForm.RemoveActiveBreakpoints;
end;

procedure TDebugger.EngineStopped(Sender: TObject; const Info: TDebugStopInfo);
var
  FileName: String;
begin
  fPaused := True;
  FileName := Info.Frame.FullName;
  if FileName = '' then
    FileName := Info.Frame.FileName;
  if (FileName <> '') and (Info.Frame.Line > 0) then begin
    fActiveFile := FileName;
    MainForm.GotoBreakpoint(FileName, Info.Frame.Line);
  end else begin
    MainForm.RemoveActiveBreakpoints; // in a library without its source
    AddOutput(Info.Frame.Func + ' (' + Info.Frame.Addr + ')' + LineEnding);
  end;

  RefreshWatchVars;
  if Assigned(CPUForm) then
    CPUForm.UpdateView;

  if Info.Reason = dsSignal then begin
    // After the events of this stop, not inside them
    fSignalText := Format(Lang[ID_DEBUG_SIGNAL], [Info.SignalName, Info.SignalMeaning]);
    Application.QueueAsyncCall(ShowSignal, 0);
  end;
end;

procedure TDebugger.ShowSignal(Data: PtrInt);
begin
  if not fExecuting then
    Exit;
  Beep;
  MessageDlg(fSignalText, mtError, [mbOK], 0);
  if devData.ShowCPUSignal and not Assigned(CPUForm) then
    MainForm.ViewCPUItemClick(nil);
end;

procedure TDebugger.EngineExited(Sender: TObject; ExitCode: Integer);
begin
  // The terminal stays until the user reads it and presses Enter
  fTerminal.ProgramEnded(Format(Lang[ID_DEBUG_PROGRAMENDED], [ExitCode]));
  AddOutput(Format(Lang[ID_DEBUG_PROGRAMENDED], [ExitCode]) + LineEnding);
  Stop;
end;

procedure TDebugger.EngineTerminated(Sender: TObject);
begin
  Stop; // gdb ended by itself (or crashed)
end;

procedure TDebugger.EngineOutput(Sender: TObject; const Text: String; Kind: TDebugOutputKind);
begin
  AddOutput(Text);
end;

// The debug panel takes whole lines
procedure TDebugger.AddOutput(const Text: String);
var
  P: integer;
  Lines: TStrings;
begin
  Lines := MainForm.DebugOutput.Lines;
  fPartialOutput := fPartialOutput + Text;
  repeat
    P := Pos(#10, fPartialOutput);
    if (P > 0) and (P <= MaxLineLength + 1) then begin
      Lines.Add(TrimRight(Copy(fPartialOutput, 1, P - 1)));
      Delete(fPartialOutput, 1, P);
    end else if Length(fPartialOutput) > MaxLineLength then begin
      // a program printing without line breaks
      Lines.Add(Copy(fPartialOutput, 1, MaxLineLength));
      Delete(fPartialOutput, 1, MaxLineLength);
    end else
      Break;
  until False;
  // A program printing in a loop (with no terminal of its own) would fill memory
  if Lines.Count > MaxOutputLines then begin
    Lines.BeginUpdate;
    try
      while Lines.Count > MaxOutputLines * 9 div 10 do
        Lines.Delete(0);
    finally
      Lines.EndUpdate;
    end;
  end;
end;

{ Commands }

procedure TDebugger.Next;
begin
  if fExecuting and fPaused then
    fEngine.Next;
end;

procedure TDebugger.Step;
begin
  if fExecuting and fPaused then
    fEngine.Step;
end;

procedure TDebugger.Continue;
begin
  if fExecuting and fPaused then
    fEngine.Continue;
end;

procedure TDebugger.Finish;
begin
  if fExecuting and fPaused then
    fEngine.Finish;
end;

procedure TDebugger.NextInstruction;
begin
  if fExecuting and fPaused then
    fEngine.NextInstruction;
end;

procedure TDebugger.StepInstruction;
begin
  if fExecuting and fPaused then
    fEngine.StepInstruction;
end;

procedure TDebugger.Pause;
begin
  if fExecuting and not fPaused then
    fEngine.Interrupt;
end;

procedure TDebugger.Evaluate(const Expression: String; Handler: TDebugValueHandler);
begin
  if fExecuting then
    fEngine.Evaluate(Expression, Handler);
end;

procedure TDebugger.Assign(const Expression, Value: String);
begin
  if fExecuting then begin
    fEngine.Assign(Expression, Value);
    RefreshWatchVars;
  end;
end;

procedure TDebugger.UserCommand(const Command: String);
begin
  if fExecuting then begin
    AddOutput('(gdb) ' + Command + LineEnding);
    fEngine.UserCommand(Command);
  end;
end;

procedure TDebugger.CancelHandlers(Owner: TObject);
begin
  if Assigned(fEngine) then
    fEngine.CancelHandlers(Owner);
end;

{ Breakpoints }

procedure TDebugger.AddBreakPoint(i: integer);
begin
  with PBreakPoint(fBreakPointList.Items[i])^ do
    fEngine.InsertBreakpoint(editor.FileName, line, BreakpointInserted);
end;

procedure TDebugger.BreakpointInserted(Ok: Boolean; Id: Integer; const FileName: String; Line: Integer;
  const Error: String);
var
  I: integer;
  BP: PBreakPoint;
begin
  if not Ok then begin
    AddOutput(Error + LineEnding);
    Exit;
  end;
  for I := 0 to fBreakPointList.Count - 1 do begin
    BP := PBreakPoint(fBreakPointList[I]);
    if (BP^.id = -1) and (BP^.line = Line) and SameFileName(BP^.editor.FileName, FileName) then begin
      BP^.id := Id;
      Exit;
    end;
  end;
  // Removed before gdb answered
  if fExecuting then
    fEngine.DeleteBreakpoint(Id);
end;

procedure TDebugger.RemoveBreakPoint(i: integer);
begin
  if PBreakPoint(fBreakPointList.Items[i])^.id > 0 then
    fEngine.DeleteBreakpoint(PBreakPoint(fBreakPointList.Items[i])^.id);
end;

procedure TDebugger.AddBreakPoint(linein: integer; e: TEditor);
var
  APBreakPoint: PBreakPoint;
begin
  New(APBreakPoint);
  APBreakPoint^.line := Linein;
  APBreakPoint^.editor := e;
  APBreakPoint^.id := -1;
  fBreakPointList.Add(APBreakPoint);

  // Debugger already running? Add it to gdb
  if fExecuting then
    AddBreakPoint(fBreakPointList.Count - 1);
end;

procedure TDebugger.RemoveBreakPoint(Linein: integer; e: TEditor);
var
  i: integer;
begin
  for i := 0 to fBreakPointList.Count - 1 do
    if (PBreakPoint(fBreakPointList.Items[i])^.line = Linein) and (PBreakPoint(fBreakPointList.Items[i])^.editor = e)
      then begin
      if fExecuting then
        RemoveBreakPoint(i);
      Dispose(PBreakPoint(fBreakPointList.Items[i]));
      fBreakPointList.Delete(i);
      Break;
    end;
end;

procedure TDebugger.DeleteBreakPointsOf(editor: TEditor);
var
  I: integer;
begin
  // Breakpoints in closed files need to be deleted
  for i := fBreakPointList.Count - 1 downto 0 do
    if PBreakPoint(fBreakPointList.Items[i])^.editor = editor then begin
      if fExecuting then
        RemoveBreakPoint(i);
      Dispose(PBreakPoint(fBreakPointList.Items[i]));
      fBreakPointList.Delete(i);
    end;
end;

{ Watches: each one is evaluated after every stop, one after another (each
  answer names no watch, so the one asked is remembered), and shown as a
  tree of its members }

function TDebugger.FindWatch(const Name: String): PWatchVar;
var
  I: integer;
begin
  for I := 0 to fWatchVarList.Count - 1 do
    if SameStr(PWatchVar(fWatchVarList[I])^.Name, Name) then
      Exit(PWatchVar(fWatchVarList[I]));
  Result := nil;
end;

procedure TDebugger.AddWatchVar(const namein: String);
var
  Watch: PWatchVar;
begin
  if (Trim(namein) = '') or Assigned(FindWatch(namein)) then
    Exit;
  New(Watch);
  Watch^.Name := namein;
  Watch^.Available := False;
  Watch^.Node := DebugView.Items.AddObject(nil, namein + ' = ' + Lang[ID_DEBUG_RUNTOEVALUATE], Watch);
  Watch^.Node.ImageIndex := 21;
  Watch^.Node.SelectedIndex := 21;
  fWatchVarList.Add(Watch);

  if fExecuting and fPaused then begin
    fWatchQueue.Add(namein);
    if fWatchPending = '' then
      EvaluateNextWatch;
  end;
end;

procedure TDebugger.RemoveWatchVar(nodein: TTreeNode);
var
  I: integer;
  Watch: PWatchVar;
begin
  for I := 0 to fWatchVarList.Count - 1 do begin
    Watch := PWatchVar(fWatchVarList.Items[I]);
    if Watch^.Node = nodein then begin
      nodein.Delete;
      Dispose(Watch);
      fWatchVarList.Delete(I);
      Break;
    end;
  end;
end;

procedure TDebugger.RefreshWatchVars;
var
  I: integer;
begin
  if not (fExecuting and fPaused) then
    Exit;
  fWatchQueue.Clear;
  for I := 0 to fWatchVarList.Count - 1 do
    fWatchQueue.Add(PWatchVar(fWatchVarList[I])^.Name);
  if fWatchPending = '' then
    EvaluateNextWatch;
end;

procedure TDebugger.EvaluateNextWatch;
begin
  fWatchPending := '';
  if not fExecuting or (fWatchQueue.Count = 0) then
    Exit;
  fWatchPending := fWatchQueue[0];
  fWatchQueue.Delete(0);
  fEngine.Evaluate(fWatchPending, WatchEvaluated);
end;

procedure TDebugger.WatchEvaluated(Ok: Boolean; const Value: String);
var
  Watch: PWatchVar;
begin
  Watch := FindWatch(fWatchPending);
  if Assigned(Watch) then begin
    Watch^.Available := Ok;
    if Ok then
      ShowWatchValue(Watch, Value)
    else begin
      Watch^.Node.DeleteChildren;
      Watch^.Node.Text := Watch^.Name + ' = ' + Lang[ID_DEBUG_NOTINCONTEXT];
    end;
  end;
  EvaluateNextWatch;
end;

procedure TDebugger.ShowWatchValue(Watch: PWatchVar; const Value: String);

  // Text of a node: name = value; a struct or array shows {...} and gets
  // a child per member
  procedure AddMembers(Node: TTreeNode; const NodeValue: String);
  var
    Members: TStringList;
    I: integer;
    Name, MemberValue: String;
    Child: TTreeNode;
  begin
    Members := TStringList.Create;
    try
      if not SplitGdbValue(NodeValue, Members) then
        Exit;
      for I := 0 to Min(Members.Count, MaxWatchChildren) - 1 do begin
        SplitGdbMember(Members[I], Name, MemberValue);
        if Name = '' then
          Name := '[' + IntToStr(I) + ']';
        if SplitGdbValue(MemberValue, nil) then
          Child := DebugView.Items.AddChild(Node, Name + ' = {...}')
        else
          Child := DebugView.Items.AddChild(Node, Name + ' = ' + MemberValue);
        AddMembers(Child, MemberValue);
      end;
    finally
      Members.Free;
    end;
  end;

var
  WasExpanded: boolean;
  Probe: TStringList;
  IsCompound: boolean;
begin
  WasExpanded := Watch^.Node.Expanded or not Watch^.Node.HasChildren;
  Probe := TStringList.Create;
  try
    IsCompound := SplitGdbValue(Value, Probe);
  finally
    Probe.Free;
  end;
  DebugView.Items.BeginUpdate;
  try
    Watch^.Node.DeleteChildren;
    if IsCompound then
      Watch^.Node.Text := Watch^.Name + ' = {...}'
    else
      Watch^.Node.Text := Watch^.Name + ' = ' + Value;
    AddMembers(Watch^.Node, Value);
    if WasExpanded then
      Watch^.Node.Expand(False);
  finally
    DebugView.Items.EndUpdate;
  end;
end;

procedure TDebugger.DeleteWatchVars(deleteparent: boolean);
var
  I: integer;
  Watch: PWatchVar;
begin
  DebugView.Items.BeginUpdate;
  try
    for I := fWatchVarList.Count - 1 downto 0 do begin
      Watch := PWatchVar(fWatchVarList.Items[I]);
      if deleteparent then begin
        Watch^.Node.Delete;
        Dispose(Watch);
        fWatchVarList.Delete(I);
      end else begin
        Watch^.Node.DeleteChildren;
        Watch^.Node.Text := Watch^.Name + ' = ' + Lang[ID_DEBUG_RUNTOEVALUATE];
        Watch^.Available := False;
      end;
    end;
  finally
    DebugView.Items.EndUpdate;
  end;
end;

end.
