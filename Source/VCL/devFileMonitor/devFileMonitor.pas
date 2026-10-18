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

unit devFileMonitor;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  SysUtils, Classes, devMonitorThread, devMonitorTypes;

type
  TdevFileMonitor = class(TComponent)
  private
    fMonitor: TdevMonitorThread;
    fTarget: IdevMonitorTarget;
    fFiles: TStringList;
    fNotifyChange: TdevMonitorChange;
    fUpdateCount: integer;
    procedure MonitorNotify(ChangeType: TdevMonitorChangeType; const FileName: String);
    procedure Refresh;
    procedure Activate;
    procedure Deactivate;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Monitor(const FileName: String);
    procedure UnMonitor(const FileName: String);
    procedure BeginUpdate;
    procedure EndUpdate;
  published
    property OnNotifyChange: TdevMonitorChange read fNotifyChange write fNotifyChange;
  end;

procedure Register;

implementation

{ TdevFileMonitor }

procedure Register;
begin
  RegisterComponents('Dev-C++', [TdevFileMonitor]);
end;

constructor TdevFileMonitor.Create(AOwner: TComponent);
begin
  inherited;
  fFiles := TStringList.Create;
  fMonitor := nil;
  fTarget := TdevMonitorTarget.Create(MonitorNotify);
  fUpdateCount := 0;
end;

destructor TdevFileMonitor.Destroy;
begin
  Deactivate;
  fTarget.Detach; // drop notifications that are still queued
  fFiles.Free;
  inherited;
end;

procedure TdevFileMonitor.MonitorNotify(ChangeType: TdevMonitorChangeType; const FileName: String);
begin
  if Assigned(fNotifyChange) then
    fNotifyChange(Self, ChangeType, FileName);
end;

procedure TdevFileMonitor.Activate;
begin
  if not Assigned(fMonitor) then
    fMonitor := TdevMonitorThread.Create(fTarget, fFiles); // starts immediately
end;

procedure TdevFileMonitor.Deactivate;
begin
  if Assigned(fMonitor) then begin // we can spawn a new fMonitor instance directly after calling this
    fMonitor.Free;
    fMonitor := nil;
  end;
end;

procedure TdevFileMonitor.BeginUpdate;
begin
  Inc(fUpdateCount);
  if fUpdateCount <> 0 then
    Deactivate;
end;

procedure TdevFileMonitor.EndUpdate;
begin
  Dec(fUpdateCount);
  if (fUpdateCount = 0) and (fFiles.Count > 0) then
    Activate;
end;

procedure TdevFileMonitor.Monitor(const FileName: String);
begin
  fFiles.Add(FileName);
  Refresh;
end;

procedure TdevFileMonitor.UnMonitor(const FileName: String);
var
  I: integer;
begin
  I := fFiles.IndexOf(FileName);
  if I <> -1 then begin
    fFiles.Delete(I);
    Refresh;
  end;
end;

// A new thread for the new list of files; none when no file is left (the
// last editors close when the IDE quits) or during BeginUpdate/EndUpdate
procedure TdevFileMonitor.Refresh;
begin
  Deactivate;
  if (fFiles.Count > 0) and (fUpdateCount = 0) then
    Activate;
end;

end.
