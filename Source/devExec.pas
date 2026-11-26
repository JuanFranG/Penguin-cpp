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

unit devExec;

interface

uses
  Classes, SysUtils, SyncObjs, Forms, Process, devCFG, Utils, devPlatform;

const
  INFINITE = Cardinal($FFFFFFFF); // no time-out

type
  {$M+}
  TExecThread = class(TThread)
  private
    fFile: String;
    fPath: String;
    fParams: String;
    fArgs: TStringList; // when set, used instead of fParams
    fTimeOut: Cardinal;
    fProcess: TManagedProcess; // only valid while the program runs
    fProcessLock: TCriticalSection; // Reset (main thread) vs. the thread freeing it
    fVisible: boolean;
    fErrorText: String;
    procedure ExecAndWait;
  public
    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;
    procedure Execute; override;
    procedure TerminateProcess;
    procedure Release;
    property Args: TStringList read fArgs write fArgs; // owned
    property ErrorText: String read fErrorText;
  published
    property FileName: String read fFile write fFile;
    property Path: String read fPath write fPath;
    property Params: String read fParams write fParams;
    property TimeOut: Cardinal read fTimeOut write fTimeOut;
    property Visible: boolean read fVisible write fVisible;
    property Process: TManagedProcess read fProcess;
  end;

  TdevExecutor = class(TPersistent)
  private
    fExec: TExecThread;
    fIsRunning: boolean;
    fLastError: String;
    fOnTermEvent: TNotifyEvent;
    procedure TerminateEvent(Sender: TObject);
  public
    constructor Create; // use devExecutor, which creates the only one
    destructor Destroy; override;
    procedure Reset;
    procedure ExecuteAndWatch(sFileName, sParams, sPath: String; bVisible: boolean; iTimeOut: Cardinal; OnTermEvent:
      TNotifyEvent); overload;
    // The arguments one per string, not as a command line to split
    procedure ExecuteAndWatch(const sFileName: String; sArgs: TStrings; const sPath: String;
      OnTermEvent: TNotifyEvent); overload;
  published
    property Running: boolean read fIsRunning;
    property LastError: String read fLastError;
  end;

function devExecutor: TdevExecutor;

implementation

uses
  main;

{ TExecThread }

constructor TExecThread.Create(CreateSuspended: Boolean);
begin
  fProcessLock := TCriticalSection.Create;
  inherited Create(CreateSuspended);
end;

destructor TExecThread.Destroy;
begin
  fArgs.Free;
  fProcessLock.Free;
  inherited;
end;

procedure TExecThread.Release;
begin
  WaitFor;
  Free;
end;

procedure TExecThread.TerminateProcess;
begin
  // The worker owns process polling and waitpid; Reset waits for it to stop.
  Terminate;
end;

procedure TExecThread.Execute;
begin
  inherited;
  ExecAndWait;
end;

procedure TExecThread.ExecAndWait;
var
  P: TManagedProcess;
  Args: TStringList;
  Started: QWord;
begin
  P := TManagedProcess.Create(nil);
  Args := TStringList.Create;
  try
    P.Executable := fFile;
    if Assigned(fArgs) then
      Args.Assign(fArgs)
    else
      CommandToList(fParams, Args);
    P.Parameters.Assign(Args);
    if fPath <> '' then
      P.CurrentDirectory := fPath;
    if fVisible then
      P.ShowWindow := swoShow
    else
      P.ShowWindow := swoHIDE;
    try
      P.Execute;
    except
      on E: Exception do begin
        fErrorText := E.Message;
        Exit;
      end;
    end;
    fProcessLock.Enter;
    fProcess := P;
    fProcessLock.Leave;

    Started := GetTickCount64;
    while P.Running do begin
      if Terminated or ((fTimeOut <> INFINITE) and (GetTickCount64-Started >= fTimeOut)) then begin
        fProcessLock.Enter;
        try P.StopTree finally fProcessLock.Leave end;
        Break;
      end;
      Sleep(10);
    end;
  finally
    fProcessLock.Enter;
    fProcess := nil;
    fProcessLock.Leave;
    Args.Free;
    P.Free;
  end;
end;

var
  fDevExecutorSingleton: TdevExecutor;

function devExecutor: TdevExecutor;
begin
  if not Assigned(fDevExecutorSingleton) and not Application.Terminated then
    fDevExecutorSingleton := TdevExecutor.Create;
  Result := fDevExecutorSingleton;
end;

{ TdevExecutor }

constructor TdevExecutor.Create;
begin
  inherited;
end;

// The watching thread reports the end of the program to this object: end the
// program and let that report arrive before the object goes
destructor TdevExecutor.Destroy;
begin
  Reset;
  fDevExecutorSingleton := nil;
  inherited;
end;

procedure TdevExecutor.ExecuteAndWatch(sFileName, sParams, sPath: String;
  bVisible: boolean; iTimeOut: Cardinal; OnTermEvent: TNotifyEvent);
begin
  Reset;
  fIsRunning := True;
  fLastError := '';
  fOnTermEvent := OnTermEvent;
  fExec := TExecThread.Create(True);
  with fExec do begin
    FileName := sFileName;
    Params := sParams;
    Path := sPath;
    TimeOut := iTimeOut;
    Visible := bVisible;
    OnTerminate := TerminateEvent;
    FreeOnTerminate := False;
    Start;
  end;
end;

procedure TdevExecutor.ExecuteAndWatch(const sFileName: String; sArgs: TStrings; const sPath: String;
  OnTermEvent: TNotifyEvent);
begin
  Reset;
  fIsRunning := True;
  fLastError := '';
  fOnTermEvent := OnTermEvent;
  fExec := TExecThread.Create(True);
  with fExec do begin
    FileName := sFileName;
    Args := TStringList.Create;
    Args.Assign(sArgs);
    Path := sPath;
    TimeOut := INFINITE;
    Visible := True;
    OnTerminate := TerminateEvent;
    FreeOnTerminate := False;
    Start;
  end;
end;

procedure TdevExecutor.Reset;
var Previous: TExecThread;
begin
  Previous := fExec;
  fOnTermEvent := nil;
  if Assigned(Previous) then begin
    // Detach the callback before waiting; the thread is owned until WaitFor ends.
    Previous.OnTerminate := nil;
    Previous.FreeOnTerminate := False;
    Previous.TerminateProcess;
    Previous.WaitFor;
    Previous.Free;
    if fExec = Previous then fExec := nil;
  end;
  fIsRunning := False;
end;

procedure TdevExecutor.TerminateEvent(Sender: TObject);
var Handler: TNotifyEvent;
begin
  if Sender <> fExec then Exit;
  fLastError := TExecThread(Sender).ErrorText;
  Handler := fOnTermEvent;
  fOnTermEvent := nil;
  fIsRunning := False;
  fExec := nil;
  try
    if Assigned(Handler) then Handler(Self);
  finally
    // OnTerminate is still synchronizing this worker; release after it returns.
    TThread.ForceQueue(nil, TExecThread(Sender).Release);
  end;
end;

end.

