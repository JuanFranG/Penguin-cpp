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

unit devMonitorThread;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

// Watches a list of files by polling their last write time and size. Polling
// works the same on every platform and a few hundred open files cost little.

interface

uses
  SysUtils, Classes, SyncObjs, devMonitorTypes;

const
  MonitorPollInterval = 500; // ms

type
  // Receives changes on the main thread. The owner detaches it when it goes
  // away, so notifications still queued at that point are dropped safely.
  IdevMonitorTarget = interface
    ['{6F1E1D2A-6C3B-4E55-9C2F-2B7E0B9A41D3}']
    procedure Deliver(ChangeType: TdevMonitorChangeType; const FileName: String);
    procedure Detach;
  end;

  TdevMonitorTarget = class(TInterfacedObject, IdevMonitorTarget)
  private
    fNotify: TdevMonitorNotify;
  public
    constructor Create(NotifyFunc: TdevMonitorNotify);
    procedure Deliver(ChangeType: TdevMonitorChangeType; const FileName: String);
    procedure Detach;
  end;

  TdevMonitorThread = class(TThread)
  private
    fTarget: IdevMonitorTarget;
    fFiles: TList; // of PdevMonitorFile
    fShouldQuit: TEvent;
    procedure Notify(ChangeType: TdevMonitorChangeType; const FileName: String);
    procedure CheckFiles;
  public
    constructor Create(Target: IdevMonitorTarget; FileNames: TStrings);
    destructor Destroy; override;
    procedure Execute; override;
  end;

// Last write time and size of FileName; False if it doesn't exist
function GetMonitorFileState(const FileName: String; var TimeStamp: TDateTime; var Size: Int64): Boolean;

implementation

type
  // One queued notification; frees itself after delivery
  TdevMonitorEvent = class
  private
    fTarget: IdevMonitorTarget;
    fChangeType: TdevMonitorChangeType;
    fFileName: String;
  public
    procedure Run;
  end;

procedure TdevMonitorEvent.Run;
begin
  try
    fTarget.Deliver(fChangeType, fFileName);
  finally
    Free;
  end;
end;

{ TdevMonitorTarget }

constructor TdevMonitorTarget.Create(NotifyFunc: TdevMonitorNotify);
begin
  inherited Create;
  fNotify := NotifyFunc;
end;

procedure TdevMonitorTarget.Deliver(ChangeType: TdevMonitorChangeType; const FileName: String);
begin
  if Assigned(fNotify) then
    fNotify(ChangeType, FileName);
end;

procedure TdevMonitorTarget.Detach;
begin
  fNotify := nil;
end;

function GetMonitorFileState(const FileName: String; var TimeStamp: TDateTime; var Size: Int64): Boolean;
var
  SearchRec: TSearchRec;
begin
  Result := FindFirst(FileName, faAnyFile, SearchRec) = 0;
  if Result then begin
    TimeStamp := SearchRec.TimeStamp; // Time is deprecated in FPC 3.2.4
    Size := SearchRec.Size;
    FindClose(SearchRec);
  end;
end;

{ TdevMonitorThread }

constructor TdevMonitorThread.Create(Target: IdevMonitorTarget; FileNames: TStrings);
var
  I: integer;
  Item: PdevMonitorFile;
begin
  fTarget := Target;
  fFiles := TList.Create;
  fShouldQuit := TEvent.Create(nil, false, false, '');

  // Remember the current state of every file that exists
  for I := 0 to FileNames.Count - 1 do begin
    Item := new(PdevMonitorFile);
    Item^.FileName := FileNames[I];
    if GetMonitorFileState(Item^.FileName, Item^.TimeStamp, Item^.Size) then
      fFiles.Add(Item)
    else
      Dispose(Item);
  end;

  inherited Create(False); // start immediately, fields are ready
end;

destructor TdevMonitorThread.Destroy;
var
  I: integer;
begin
  // Ask the thread to stop and wait for it
  Terminate;
  fShouldQuit.SetEvent;
  WaitFor;

  for I := 0 to fFiles.Count - 1 do
    Dispose(PdevMonitorFile(fFiles[I]));
  fFiles.Free;
  fShouldQuit.Free;
  inherited;
end;

procedure TdevMonitorThread.CheckFiles;
var
  I: integer;
  Item: PdevMonitorFile;
  TimeStamp: TDateTime;
  Size: Int64;
begin
  for I := fFiles.Count - 1 downto 0 do begin
    if Terminated then
      Exit;
    Item := PdevMonitorFile(fFiles[I]);
    if GetMonitorFileState(Item^.FileName, TimeStamp, Size) then begin
      if (TimeStamp <> Item^.TimeStamp) or (Size <> Item^.Size) then begin
        Item^.TimeStamp := TimeStamp;
        Item^.Size := Size;
        Notify(mctChanged, Item^.FileName);
      end;
    end else begin
      // Deleted: report it once and stop watching it
      Notify(mctDeleted, Item^.FileName);
      fFiles.Delete(I);
      Dispose(Item);
    end;
  end;
end;

procedure TdevMonitorThread.Execute;
begin
  while not Terminated do begin
    if fShouldQuit.WaitFor(MonitorPollInterval) <> wrTimeout then
      Break;
    CheckFiles;
  end;
end;

procedure TdevMonitorThread.Notify(ChangeType: TdevMonitorChangeType; const FileName: String);
var
  Event: TdevMonitorEvent;
begin
  if not Assigned(fTarget) or Terminated then
    Exit;
  // Asynchronous on purpose: the handler may stop this very thread (the IDE
  // calls BeginUpdate while it shows its dialog), which Synchronize would
  // turn into a deadlock.
  Event := TdevMonitorEvent.Create;
  Event.fTarget := fTarget;
  Event.fChangeType := ChangeType;
  Event.fFileName := FileName;
  TThread.Queue(nil, Event.Run);
end;

end.
