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
  Classes, SysUtils, Forms, Process, devCFG, Utils;

const
  INFINITE = Cardinal($FFFFFFFF); // no time-out

type
  {$M+}
  TExecThread = class(TThread)
  private
    fFile: String;
    fPath: String;
    fParams: String;
    fTimeOut: Cardinal;
    fProcess: TProcess; // only valid while the program runs
    fVisible: boolean;
    procedure ExecAndWait;
  public
    procedure Execute; override;
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
    constructor Create;
  public
    destructor Destroy; override;
    procedure Reset;
    procedure ExecuteAndWatch(sFileName, sParams, sPath: String; bVisible: boolean; iTimeOut: Cardinal; OnTermEvent:
      TNotifyEvent);
  published
    property Running: boolean read fIsRunning;
  end;

function devExecutor: TdevExecutor;

implementation

uses
  main;

{ TExecThread }

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
    fProcess := P;

    // Wait for it to finish, like WaitForSingleObject with a time-out
    if fTimeOut = INFINITE then
      P.WaitOnExit
    else begin
      Started := GetTickCount64;
      while P.Running and (GetTickCount64 - Started < fTimeOut) do
        Sleep(50);
    end;
  finally
    fProcess := nil;
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

destructor TdevExecutor.Destroy;
begin
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

procedure TdevExecutor.Reset;
begin
  if Assigned(fExec) and Assigned(fExec.Process) then
    fExec.Process.Terminate(0);
  fIsRunning := False;
end;

procedure TdevExecutor.TerminateEvent(Sender: TObject);
begin
  fIsRunning := False;
  if Assigned(fOnTermEvent) then
    fOnTermEvent(Self);
end;

end.

