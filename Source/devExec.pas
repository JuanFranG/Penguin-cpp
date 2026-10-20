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
  Classes, SysUtils, SyncObjs, Forms, Process, devCFG, Utils;

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
    fProcess: TProcess; // only valid while the program runs
    fProcessLock: TCriticalSection; // Reset (main thread) vs. the thread freeing it
    fVisible: boolean;
    procedure ExecAndWait;
  public
    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;
    procedure Execute; override;
    procedure TerminateProcess;
    property Args: TStringList read fArgs write fArgs; // owned
  published
    property FileName: String read fFile write fFile;
    property Path: String read fPath write fPath;
    property Params: String read fParams write fParams;
    property TimeOut: Cardinal read fTimeOut write fTimeOut;
    property Visible: boolean read fVisible write fVisible;
    property Process: TProcess read fProcess;
  end;

  TdevExecutor = class(TPersistent)
  private
    fExec: TExecThread;
    fIsRunning: boolean;
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

procedure TExecThread.TerminateProcess;
begin
  fProcessLock.Enter;
  try
    if Assigned(fProcess) then
      fProcess.Terminate(0);
  finally
    fProcessLock.Leave;
  end;
end;

procedure TExecThread.Execute;
begin
  inherited;
  ExecAndWait;
end;

procedure TExecThread.ExecAndWait;
var
  P: TProcess;
  Args: TStringList;
  Started: QWord;
begin
  P := TProcess.Create(nil);
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
      Exit; // could not start; OnTerminate still reports the end
    end;
    fProcessLock.Enter;
    fProcess := P;
    fProcessLock.Leave;

    // Wait for it to finish, like WaitForSingleObject with a time-out
    if fTimeOut = INFINITE then
      P.WaitOnExit
    else begin
      Started := GetTickCount64;
      while P.Running and (GetTickCount64 - Started < fTimeOut) do
        Sleep(50);
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
var
  Started: QWord;
begin
  if Assigned(fExec) then begin
    fOnTermEvent := nil; // the IDE is going away too
    fExec.TerminateProcess;
    Started := GetTickCount64;
    while Assigned(fExec) and (GetTickCount64 - Started < 5000) do
      CheckSynchronize(20);
  end;
  fDevExecutorSingleton := nil;
  inherited;
end;

procedure TdevExecutor.ExecuteAndWatch(sFileName, sParams, sPath: String;
  bVisible: boolean; iTimeOut: Cardinal; OnTermEvent: TNotifyEvent);
begin
  fIsRunning := True;
  fOnTermEvent := OnTermEvent;
  fExec := TExecThread.Create(True);
  with fExec do begin
    FileName := sFileName;
    Params := sParams;
    Path := sPath;
    TimeOut := iTimeOut;
    Visible := bVisible;
    OnTerminate := TerminateEvent;
    FreeOnTerminate := True;
    Start;
  end;
end;

procedure TdevExecutor.ExecuteAndWatch(const sFileName: String; sArgs: TStrings; const sPath: String;
  OnTermEvent: TNotifyEvent);
begin
  fIsRunning := True;
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
    FreeOnTerminate := True;
    Start;
  end;
end;

procedure TdevExecutor.Reset;
begin
  if Assigned(fExec) then
    fExec.TerminateProcess;
  fIsRunning := False;
end;

procedure TdevExecutor.TerminateEvent(Sender: TObject);
begin
  fIsRunning := False;
  fExec := nil; // freed after this (FreeOnTerminate)
  if Assigned(fOnTermEvent) then
    fOnTermEvent(Self);
end;

end.

