{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    What the IDE asks of a debugger, and what it hears back, without naming
    gdb: GdbEngine implements it over GDB/MI on Linux, and an lldb-dap engine
    can implement it on macOS (phase 9).

    Everything happens on the main thread: commands are sent from it, and
    events and answers arrive on it (an engine reads its debugger in a thread
    of its own, and hands what it read over with TThread.Queue). Answers come
    later, through the handler given with the command; a handler of an
    object that goes away must be cancelled first (CancelHandlers).
}

unit DebugEngine;

{$MODE DELPHI}

interface

uses
  Classes, SysUtils;

type
  // A place in the program: a stack frame, or where it stopped
  TDebugFrame = record
    Level: Integer;
    Func: String;
    FileName: String; // as compiled (may be relative)
    FullName: String; // absolute, when the debugger knows it
    Line: Integer;    // 0: no source (a library without debug information)
    Addr: String;
  end;
  TDebugFrames = array of TDebugFrame;

  TDebugStopReason = (
    dsBreakpoint,   // a breakpoint
    dsStep,         // next, step, finish... ended
    dsSignal,       // the program received a signal (segmentation fault...)
    dsInterrupted,  // Interrupt (the user paused it)
    dsOther);

  TDebugStopInfo = record
    Reason: TDebugStopReason;
    Frame: TDebugFrame;
    BreakpointId: Integer;
    SignalName: String;    // SIGSEGV
    SignalMeaning: String; // Segmentation fault
  end;

  TDebugOutputKind = (
    doConsole, // what the debugger prints for the user
    doProgram, // the program's output, when it has no terminal of its own
    doLog);    // the debugger's messages and errors

  TDebugStoppedEvent = procedure(Sender: TObject; const Info: TDebugStopInfo) of object;
  TDebugExitedEvent = procedure(Sender: TObject; ExitCode: Integer) of object;
  TDebugOutputEvent = procedure(Sender: TObject; const Text: String; Kind: TDebugOutputKind) of object;

  // Answers. Ok is False when the debugger refused; Error says why
  TDebugDoneHandler = procedure(Ok: Boolean; const Error: String) of object;
  TDebugValueHandler = procedure(Ok: Boolean; const Value: String) of object;
  TDebugBreakpointHandler = procedure(Ok: Boolean; Id: Integer; const Error: String) of object;
  TDebugFramesHandler = procedure(Ok: Boolean; const Frames: TDebugFrames) of object;

  TDebugEngine = class
  private
    fOnStopped: TDebugStoppedEvent;
    fOnRunning: TNotifyEvent;
    fOnExited: TDebugExitedEvent;
    fOnOutput: TDebugOutputEvent;
    fOnTerminated: TNotifyEvent;
  protected
    procedure DoStopped(const Info: TDebugStopInfo);
    procedure DoRunning;
    procedure DoExited(ExitCode: Integer);
    procedure DoOutput(const Text: String; Kind: TDebugOutputKind);
    procedure DoTerminated;
  public
    // Starts the debugger itself (not the program yet). False with a reason
    function Start(out Error: String): Boolean; virtual; abstract;
    // Ends the program and the debugger; no event comes after it
    procedure Quit; virtual; abstract;
    function Running: Boolean; virtual; abstract;

    // The program, its arguments (each one arrives as it is: no shell reads
    // it as commands), its folder, and the terminal it reads and writes
    // ('' none)
    procedure LoadProgram(const FileName: String; Handler: TDebugDoneHandler = nil); virtual; abstract;
    procedure SetArguments(const Args: array of String); virtual; abstract;
    procedure SetWorkingDir(const Dir: String); virtual; abstract;
    procedure SetTerminal(const TtyName: String); virtual; abstract;

    procedure InsertBreakpoint(const FileName: String; Line: Integer; Handler: TDebugBreakpointHandler = nil);
      virtual; abstract;
    procedure DeleteBreakpoint(Id: Integer); virtual; abstract;

    // Moving: each one ends with OnStopped, OnExited or OnTerminated
    procedure Run; virtual; abstract;
    procedure Continue; virtual; abstract;
    procedure Next; virtual; abstract;            // the next line, over calls
    procedure Step; virtual; abstract;            // the next line, into calls
    procedure Finish; virtual; abstract;          // out of the current function
    procedure NextInstruction; virtual; abstract;
    procedure StepInstruction; virtual; abstract;
    procedure Interrupt; virtual; abstract;       // pause the running program

    procedure Evaluate(const Expression: String; Handler: TDebugValueHandler); virtual; abstract;
    procedure Assign(const Expression, Value: String; Handler: TDebugValueHandler = nil); virtual; abstract;
    procedure GetFrames(Handler: TDebugFramesHandler); virtual; abstract;
    // A command typed by the user, in the debugger's own language; what it
    // prints arrives through OnOutput
    procedure UserCommand(const Command: String; Handler: TDebugDoneHandler = nil); virtual; abstract;

    // Forgets every pending answer for handlers of Owner
    procedure CancelHandlers(Owner: TObject); virtual; abstract;

    property OnStopped: TDebugStoppedEvent read fOnStopped write fOnStopped;
    property OnRunning: TNotifyEvent read fOnRunning write fOnRunning;
    property OnExited: TDebugExitedEvent read fOnExited write fOnExited;
    property OnOutput: TDebugOutputEvent read fOnOutput write fOnOutput;
    // The debugger itself ended (quit, or it crashed)
    property OnTerminated: TNotifyEvent read fOnTerminated write fOnTerminated;
  end;

implementation

procedure TDebugEngine.DoStopped(const Info: TDebugStopInfo);
begin
  if Assigned(fOnStopped) then
    fOnStopped(Self, Info);
end;

procedure TDebugEngine.DoRunning;
begin
  if Assigned(fOnRunning) then
    fOnRunning(Self);
end;

procedure TDebugEngine.DoExited(ExitCode: Integer);
begin
  if Assigned(fOnExited) then
    fOnExited(Self, ExitCode);
end;

procedure TDebugEngine.DoOutput(const Text: String; Kind: TDebugOutputKind);
begin
  if Assigned(fOnOutput) then
    fOnOutput(Self, Text, Kind);
end;

procedure TDebugEngine.DoTerminated;
begin
  if Assigned(fOnTerminated) then
    fOnTerminated(Self);
end;

end.
