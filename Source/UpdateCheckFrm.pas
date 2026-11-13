{ SPDX-License-Identifier: GPL-2.0-or-later }
unit UpdateCheckFrm;
{$mode objfpc}{$H+}
interface
function ShowUpdateCheck: Boolean;
implementation
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics, LCLIntf,
  MultiLangSupport, Version, UpdateCheckCore;
type
  TReleaseThread = class(TThread)
  public
    Status: TUpdateResult;
    LatestVersion, PageURL: String;
    function Cancelled: Boolean;
    procedure Execute; override;
  end;
  TUpdateForm = class(TForm)
  private
    Worker: TReleaseThread;
    Timer: TTimer;
    StatusText: TLabel;
    Details: TMemo;
    RetryButton, DownloadButton, InstallButton, CloseButton: TButton;
    DownloadURL: String;
    procedure StartCheck(Sender: TObject);
    procedure Poll(Sender: TObject);
    procedure OpenDownload(Sender: TObject);
  public
    constructor CreateDialog;
    destructor Destroy; override;
  end;
function TReleaseThread.Cancelled: Boolean;
begin Result := Terminated end;
procedure TReleaseThread.Execute;
begin
  try Status := FetchLatestRelease(LatestVersion, PageURL, @Cancelled)
  except Status := urNetworkError end;
end;
constructor TUpdateForm.CreateDialog;
begin
  inherited CreateNew(Screen.ActiveCustomForm);
  Caption := Lang[80000]; Position := poMainFormCenter;
  BorderStyle := bsDialog; BorderIcons := [biSystemMenu];
  Font.Assign(Screen.SystemFont);
  ClientWidth := 600; ClientHeight := 250;
  StatusText := TLabel.Create(Self); StatusText.Parent := Self;
  StatusText.AutoSize := False; StatusText.WordWrap := True;
  StatusText.SetBounds(20, 20, 560, 56); StatusText.Font.Style := [fsBold];
  Details := TMemo.Create(Self); Details.Parent := Self;
  Details.SetBounds(20, 86, 560, 105); Details.ReadOnly := True;
  Details.BorderStyle := bsNone; Details.Color := clBtnFace;
  Details.TabStop := False; Details.ScrollBars := ssAutoVertical;
  RetryButton := TButton.Create(Self); RetryButton.Parent := Self;
  RetryButton.SetBounds(20, 210, 120, 28); RetryButton.Caption := Lang[80006];
  RetryButton.OnClick := @StartCheck;
  DownloadButton := TButton.Create(Self); DownloadButton.Parent := Self;
  DownloadButton.SetBounds(310, 210, 145, 28); DownloadButton.Caption := Lang[80007];
  DownloadButton.OnClick := @OpenDownload;
  InstallButton := TButton.Create(Self); InstallButton.Parent := Self;
  InstallButton.SetBounds(150, 210, 150, 28); InstallButton.Caption := Lang[80015];
  InstallButton.ModalResult := mrYes;
  CloseButton := TButton.Create(Self); CloseButton.Parent := Self;
  CloseButton.SetBounds(465, 210, 115, 28); CloseButton.Caption := Lang[80008];
  CloseButton.ModalResult := mrCancel; CloseButton.Cancel := True;
  Timer := TTimer.Create(Self); Timer.Enabled := False; Timer.Interval := 80;
  Timer.OnTimer := @Poll;
  StartCheck(nil);
end;
destructor TUpdateForm.Destroy;
begin
  if Assigned(Timer) then Timer.Enabled := False;
  if Assigned(Worker) then begin
    Worker.Terminate; Worker.WaitFor; Worker.Free;
  end;
  inherited Destroy;
end;
procedure TUpdateForm.StartCheck(Sender: TObject);
begin
  if Assigned(Worker) then Exit;
  StatusText.Caption := Lang[80001];
  Details.Text := Format(Lang[80010], [DEVCPP_VERSION]);
  RetryButton.Enabled := False; DownloadButton.Enabled := False; InstallButton.Enabled := False; DownloadURL := '';
  Worker := TReleaseThread.Create(True); Worker.FreeOnTerminate := False;
  Worker.Start; Timer.Enabled := True;
end;
procedure TUpdateForm.Poll(Sender: TObject);
var Comparison: Integer;
begin
  if not Assigned(Worker) or not Worker.Finished then Exit;
  Timer.Enabled := False; Worker.WaitFor;
  try
    if (Worker.Status = urSuccess) and
      CompareReleaseVersions(Worker.LatestVersion, DEVCPP_VERSION, Comparison) then begin
      if Comparison > 0 then begin
        StatusText.Caption := Format(Lang[80002], [Worker.LatestVersion, DEVCPP_VERSION]);
        DownloadURL := Worker.PageURL; DownloadButton.Enabled := True; InstallButton.Enabled := True;
{$IFDEF DARWIN}
        Details.Text := Lang[80016] + LineEnding + LineEnding + Lang[80005];
{$ELSE}
        Details.Text := Lang[80016] + LineEnding + LineEnding + Lang[80004];
{$ENDIF}
      end else if Comparison = 0 then begin
        StatusText.Caption := Format(Lang[80003], [DEVCPP_VERSION]);
        Details.Text := Format(Lang[80010], [Worker.LatestVersion]);
      end else begin
        StatusText.Caption := Format(Lang[80011], [DEVCPP_VERSION, Worker.LatestVersion]);
        Details.Text := '';
      end;
    end else begin
      StatusText.Caption := Lang[80009];
      if Worker.Status = urNoCurl then Details.Text := Lang[80012]
      else Details.Text := Lang[80013];
    end;
  finally
    FreeAndNil(Worker); RetryButton.Enabled := True;
  end;
end;
procedure TUpdateForm.OpenDownload(Sender: TObject);
begin
  if DownloadURL <> '' then OpenURL(DownloadURL);
end;
function ShowUpdateCheck: Boolean;
var F: TUpdateForm;
begin
  F := TUpdateForm.CreateDialog;
  try Result := F.ShowModal = mrYes finally F.Free end;
end;
end.
