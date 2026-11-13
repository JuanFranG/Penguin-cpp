{ SPDX-License-Identifier: GPL-2.0-or-later }
unit WindowsGameFrm;
{$mode objfpc}{$H+}
interface
uses WindowsGameCore;
function ConfigureWindowsGame(var Config: TWindowsGameConfig): Boolean;
implementation
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs, MultiLangSupport, WindowsSetupFrm, devPlatform;
type
  TGameForm = class(TForm)
  private
    InitialConfig: TWindowsGameConfig;
    ModeBox: TComboBox;
    GPTKBox: TCheckBox;
    ToolchainEdit, RunnerEdit, PrefixEdit: TEdit;
    procedure Verify(Sender: TObject);
    procedure Populate(Sender: TObject);
    procedure Browse(Sender: TObject);
    procedure Save(Sender: TObject);
  public
    constructor CreateDialog(const Config: TWindowsGameConfig);
  end;
constructor TGameForm.CreateDialog(const Config: TWindowsGameConfig);
var Info: TLabel; Button: TButton;
  function PathRow(const Text, Value: String; Y, TagValue: Integer): TEdit;
  var LabelControl: TLabel; BrowseButton: TButton;
  begin
    LabelControl := TLabel.Create(Self); LabelControl.Parent := Self;
    LabelControl.Caption := Text; LabelControl.SetBounds(20, Y, 620, 24);
    Result := TEdit.Create(Self); Result.Parent := Self;
    Result.SetBounds(20, Y + 28, 510, 28); Result.Text := Value;
    BrowseButton := TButton.Create(Self); BrowseButton.Parent := Self;
    BrowseButton.SetBounds(540, Y + 28, 100, 28); BrowseButton.Caption := Lang[80105];
    BrowseButton.Tag := TagValue; BrowseButton.OnClick := @Browse;
  end;
begin
  inherited CreateNew(Screen.ActiveCustomForm);
  InitialConfig := Config; OnShow := @Populate;
  Caption := Lang[80100]; Position := poMainFormCenter;
  BorderStyle := bsDialog; BorderIcons := [biSystemMenu]; Font.Assign(Screen.SystemFont);
  ClientWidth := 660; ClientHeight := 485;
  ModeBox := TComboBox.Create(Self); ModeBox.Parent := Self; ModeBox.Style := csDropDownList;
  ModeBox.SetBounds(20,20,360,28);
  ModeBox.Items.Add(Lang[80201]); ModeBox.Items.Add(Lang[80202]); ModeBox.Items.Add(Lang[80203]);
  ModeBox.ItemIndex := Ord(Config.Mode);
  Button := TButton.Create(Self); Button.Parent := Self;
  Button.SetBounds(400,20,240,28); Button.Caption := Lang[80215]; Button.OnClick := @Verify;
  Info := TLabel.Create(Self); Info.Parent := Self; Info.AutoSize := False; Info.WordWrap := True;
  Info.SetBounds(20, 60, 620, 70); Info.Caption := Lang[80102];
  ToolchainEdit := PathRow(Lang[80103], Config.Toolchain, 140, 1);
  RunnerEdit := PathRow(Lang[80104], Config.Runner, 212, 2);
  PrefixEdit := PathRow(Lang[80106], Config.Prefix, 284, 3);
  GPTKBox := TCheckBox.Create(Self); GPTKBox.Parent := Self;
  GPTKBox.SetBounds(20, 360, 620, 28); GPTKBox.Caption := Lang[80107]; GPTKBox.Checked := Config.UsesGPTK;
{$IFNDEF DARWIN}
  GPTKBox.Enabled := False;
{$ENDIF}
  Info := TLabel.Create(Self); Info.Parent := Self; Info.AutoSize := False; Info.WordWrap := True;
  Info.SetBounds(20, 396, 620, 38); Info.Caption := Lang[80108];
  Button := TButton.Create(Self); Button.Parent := Self;
  Button.SetBounds(420, 445, 105, 28); Button.Caption := Lang[80109]; Button.OnClick := @Save; Button.Default := True;
  Button := TButton.Create(Self); Button.Parent := Self;
  Button.SetBounds(535, 445, 105, 28); Button.Caption := Lang[80110]; Button.ModalResult := mrCancel; Button.Cancel := True;
end;
procedure TGameForm.Verify(Sender: TObject);
var Config: TWindowsGameConfig;
begin
  Config := InitialConfig; Config.Toolchain := Trim(ToolchainEdit.Text);
  Config.Runner := Trim(RunnerEdit.Text); Config.Prefix := Trim(PrefixEdit.Text);
  EnsureWindowsEnvironment(Config,GetUserDataDir,True);
end;
procedure TGameForm.Populate(Sender: TObject);
begin
  // Populate after Cocoa has created the edit handles.
  ToolchainEdit.Text := InitialConfig.Toolchain;
  RunnerEdit.Text := InitialConfig.Runner;
  PrefixEdit.Text := InitialConfig.Prefix;
end;
procedure TGameForm.Browse(Sender: TObject);
var Directory: String; Dialog: TOpenDialog; Edit: TEdit;
begin
  case TControl(Sender).Tag of
    1: Edit := ToolchainEdit;
    2: Edit := RunnerEdit;
    else Edit := PrefixEdit;
  end;
  if TControl(Sender).Tag = 2 then begin
    Dialog := TOpenDialog.Create(Self);
    try
      Dialog.FileName := Edit.Text; Dialog.Options := [ofFileMustExist, ofEnableSizing];
      if Dialog.Execute then Edit.Text := Dialog.FileName;
    finally Dialog.Free end;
  end else begin
    Directory := Edit.Text;
    if SelectDirectory(Lang[80105], '', Directory) then Edit.Text := Directory;
  end;
end;
procedure TGameForm.Save(Sender: TObject);
var Config: TWindowsGameConfig; C, Cpp: String; Error: TWindowsGameError;
begin
  Config.Mode := TCompatibilityMode(ModeBox.ItemIndex);
  Config.Enabled := Config.Mode = cmWindows; Config.UsesGPTK := GPTKBox.Checked;
  Config.Toolchain := Trim(ToolchainEdit.Text); Config.Runner := Trim(RunnerEdit.Text);
  Config.Prefix := Trim(PrefixEdit.Text);
  if Config.Mode = cmWindows then begin
    Error := ResolveWindowsCompilers(Config, C, Cpp);
    if Error <> wgOK then begin MessageDlg(WindowsGameErrorText(Error), mtError, [mbOK], 0); Exit end;
    if Config.Runner <> '' then begin
      if not FileExists(Config.Runner) then begin MessageDlg(WindowsGameErrorText(wgRunnerMissing), mtError, [mbOK], 0); Exit end;
{$IFDEF DARWIN}
      if not HasArm64MachO(Config.Runner) then begin MessageDlg(WindowsGameErrorText(wgRunnerNotNative), mtError, [mbOK], 0); Exit end;
{$ENDIF}
    end;
  end;
  ModalResult := mrOK;
end;
function ConfigureWindowsGame(var Config: TWindowsGameConfig): Boolean;
var Dialog: TGameForm;
begin
  Dialog := TGameForm.CreateDialog(Config);
  try
    Result := Dialog.ShowModal = mrOK;
    if Result then begin
      Config.Mode := TCompatibilityMode(Dialog.ModeBox.ItemIndex);
      Config.Enabled := Config.Mode = cmWindows; Config.UsesGPTK := Dialog.GPTKBox.Checked;
      Config.Toolchain := Trim(Dialog.ToolchainEdit.Text); Config.Runner := Trim(Dialog.RunnerEdit.Text);
      Config.Prefix := Trim(Dialog.PrefixEdit.Text);
    end;
  finally Dialog.Free end;
end;
end.
