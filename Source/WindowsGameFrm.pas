{ SPDX-License-Identifier: GPL-2.0-or-later }
unit WindowsGameFrm;
{$mode objfpc}{$H+}
interface
uses WindowsGameCore;
function ConfigureWindowsGame(var Config: TWindowsGameConfig): Boolean;
implementation
uses Classes, SysUtils, Forms, Graphics, Controls, StdCtrls, ExtCtrls, Dialogs, MultiLangSupport, WindowsSetupFrm, devPlatform;
type
  TGameForm = class(TForm)
  private
    InitialConfig, IncludedConfig: TWindowsGameConfig;
    ModeBox: TComboBox;
    GPTKBox: TCheckBox;
    ToolchainEdit, RunnerEdit, PrefixEdit: TEdit;
    Details: TPanel;
    Status, Info: TLabel;
    AdvancedButton, IncludedButton, VerifyButton, SaveButton, CancelButton: TButton;
    function CurrentConfig: TWindowsGameConfig;
    procedure RefreshStatus(Sender: TObject);
    procedure ToggleAdvanced(Sender: TObject);
    procedure UseIncluded(Sender: TObject);
    procedure Verify(Sender: TObject);
    procedure Populate(Sender: TObject);
    procedure Browse(Sender: TObject);
    procedure Save(Sender: TObject);
  public
    constructor CreateDialog(const Config: TWindowsGameConfig);
  end;
constructor TGameForm.CreateDialog(const Config: TWindowsGameConfig);
var Notice: TLabel;
  function PathRow(const Text: String; Y, TagValue: Integer): TEdit;
  var LabelControl: TLabel; BrowseButton: TButton;
  begin
    LabelControl := TLabel.Create(Self); LabelControl.Parent := Details;
    LabelControl.AutoSize := False; LabelControl.Caption := Text;
    LabelControl.SetBounds(0,Y,620,24);
    Result := TEdit.Create(Self); Result.Parent := Details;
    Result.SetBounds(0,Y+28,510,28);
    BrowseButton := TButton.Create(Self); BrowseButton.Parent := Details;
    BrowseButton.SetBounds(520,Y+28,100,28); BrowseButton.Caption := Lang[80105];
    BrowseButton.Tag := TagValue; BrowseButton.OnClick := @Browse;
  end;
begin
  inherited CreateNew(Screen.ActiveCustomForm);
  InitialConfig := Config; DiscoverWindowsGameConfig(Config.DataDirectory,IncludedConfig);
  OnShow := @Populate;
  Caption := Lang[80100]; Position := poMainFormCenter;
  BorderStyle := bsDialog; BorderIcons := [biSystemMenu]; Font.Assign(Screen.SystemFont);
  ClientWidth := 660; ClientHeight := 260;
  ModeBox := TComboBox.Create(Self); ModeBox.Parent := Self; ModeBox.Style := csDropDownList;
  ModeBox.SetBounds(20,20,360,28);
  ModeBox.Items.Add(Lang[80201]); ModeBox.Items.Add(Lang[80202]); ModeBox.Items.Add(Lang[80203]);
  ModeBox.ItemIndex := Ord(Config.Mode); ModeBox.OnChange := @RefreshStatus;
  VerifyButton := TButton.Create(Self); VerifyButton.Parent := Self;
  VerifyButton.SetBounds(400,20,240,28); VerifyButton.Caption := Lang[80215]; VerifyButton.OnClick := @Verify;
  Status := TLabel.Create(Self); Status.Parent := Self; Status.AutoSize := False;
  Status.SetBounds(20,66,620,26); Status.Font.Style := [fsBold];
  Info := TLabel.Create(Self); Info.Parent := Self; Info.AutoSize := False; Info.WordWrap := True;
  Info.SetBounds(20,102,620,68);
  AdvancedButton := TButton.Create(Self); AdvancedButton.Parent := Self;
  AdvancedButton.SetBounds(20,180,200,28); AdvancedButton.Caption := Lang[80223]; AdvancedButton.OnClick := @ToggleAdvanced;
  IncludedButton := TButton.Create(Self); IncludedButton.Parent := Self;
  IncludedButton.SetBounds(230,180,250,28); IncludedButton.Caption := Lang[80224]; IncludedButton.OnClick := @UseIncluded;
  Details := TPanel.Create(Self); Details.Parent := Self; Details.BevelOuter := bvNone;
  Details.SetBounds(20,216,620,302); Details.Visible := False;
  ToolchainEdit := PathRow(Lang[80103],0,1);
  RunnerEdit := PathRow(Lang[80104],72,2);
  PrefixEdit := PathRow(Lang[80106],144,3);
  GPTKBox := TCheckBox.Create(Self); GPTKBox.Parent := Details;
  GPTKBox.SetBounds(0,220,620,28); GPTKBox.Caption := Lang[80230];
{$IFNDEF DARWIN}
  GPTKBox.Enabled := False;
{$ENDIF}
  Notice := TLabel.Create(Self); Notice.Parent := Details; Notice.AutoSize := False; Notice.WordWrap := True;
  Notice.SetBounds(0,256,620,44); Notice.Caption := Lang[80108];
  SaveButton := TButton.Create(Self); SaveButton.Parent := Self;
  SaveButton.SetBounds(420,218,105,28); SaveButton.Caption := Lang[80109]; SaveButton.OnClick := @Save; SaveButton.Default := True;
  CancelButton := TButton.Create(Self); CancelButton.Parent := Self;
  CancelButton.SetBounds(535,218,105,28); CancelButton.Caption := Lang[80110]; CancelButton.ModalResult := mrCancel; CancelButton.Cancel := True;
  ToolchainEdit.OnChange := @RefreshStatus; RunnerEdit.OnChange := @RefreshStatus; PrefixEdit.OnChange := @RefreshStatus;
end;
function TGameForm.CurrentConfig: TWindowsGameConfig;
begin
  Result := InitialConfig;
  Result.Mode := TCompatibilityMode(ModeBox.ItemIndex); Result.Enabled := Result.Mode = cmWindows;
  Result.Toolchain := Trim(ToolchainEdit.Text); Result.Runner := Trim(RunnerEdit.Text);
  Result.Prefix := Trim(PrefixEdit.Text); Result.UsesGPTK := GPTKBox.Checked;
end;
procedure TGameForm.RefreshStatus(Sender: TObject);
var Config: TWindowsGameConfig; C, Cpp: String; Command: TStringList; Valid: Boolean;
begin
  Config := CurrentConfig;
  IncludedButton.Visible := HasIncludedWindowsEnvironment(Config.DataDirectory) and
    ((Config.Toolchain <> IncludedConfig.Toolchain) or (Config.Runner <> IncludedConfig.Runner) or
     (Config.Prefix <> '') or Config.UsesGPTK);
  Command := TStringList.Create;
  try
    Valid := (ResolveWindowsCompilers(Config,C,Cpp) = wgOK) and
      (WindowsMakeProgram(Config) <> '') and
      (WindowsRuntimeCommand(Config,WindowsDefaultPrefix(GetUserDataDir),Command) = wgOK);
  finally Command.Free end;
  VerifyButton.Enabled := Valid;
  if HasIncludedWindowsEnvironment(Config.DataDirectory) and
    (Config.Toolchain = IncludedConfig.Toolchain) and (Config.Runner = IncludedConfig.Runner) and
    not Config.UsesGPTK then begin
    if WindowsEnvironmentIsReady(Config,GetUserDataDir) then Status.Caption := Lang[80213]
    else Status.Caption := Lang[80220];
    Info.Caption := Lang[80221];
  end else if Valid then begin
    Status.Caption := Lang[80227]; Info.Caption := Lang[80228];
  end else begin
    Status.Caption := Lang[80229]; Info.Caption := Lang[80222];
  end;
end;
procedure TGameForm.ToggleAdvanced(Sender: TObject);
var Config: TWindowsGameConfig;
begin
  Config := CurrentConfig;
  Details.Visible := not Details.Visible;
  if Details.Visible then ClientHeight := 568 else ClientHeight := 260;
  SaveButton.Top := ClientHeight-42; CancelButton.Top := ClientHeight-42;
  if Top+Height > Monitor.WorkareaRect.Bottom then Top := Monitor.WorkareaRect.Bottom-Height;
  if Top < Monitor.WorkareaRect.Top then Top := Monitor.WorkareaRect.Top;
  if Details.Visible then begin
    // Restore after Cocoa has created the advanced edit handles.
    ToolchainEdit.Text := Config.Toolchain; RunnerEdit.Text := Config.Runner;
    PrefixEdit.Text := Config.Prefix;
  end;
end;
procedure TGameForm.UseIncluded(Sender: TObject);
begin
  ToolchainEdit.Text := IncludedConfig.Toolchain; RunnerEdit.Text := IncludedConfig.Runner;
  PrefixEdit.Text := ''; GPTKBox.Checked := False; ModeBox.ItemIndex := Ord(cmAutomatic);
  RefreshStatus(nil);
end;
procedure TGameForm.Verify(Sender: TObject);
begin
  EnsureWindowsEnvironment(CurrentConfig,GetUserDataDir,True); RefreshStatus(nil);
end;
procedure TGameForm.Populate(Sender: TObject);
begin
  ToolchainEdit.Text := InitialConfig.Toolchain; RunnerEdit.Text := InitialConfig.Runner;
  PrefixEdit.Text := InitialConfig.Prefix; GPTKBox.Checked := InitialConfig.UsesGPTK;
  RefreshStatus(nil);
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
      Dialog.FileName := Edit.Text; Dialog.Options := [ofFileMustExist,ofEnableSizing];
      if Dialog.Execute then Edit.Text := Dialog.FileName;
    finally Dialog.Free end;
  end else begin
    Directory := Edit.Text;
    if SelectDirectory(Lang[80105],'',Directory) then Edit.Text := Directory;
  end;
end;
procedure TGameForm.Save(Sender: TObject);
var Config: TWindowsGameConfig; C, Cpp: String; Error: TWindowsGameError;
begin
  Config := CurrentConfig;
  if Config.Mode = cmWindows then begin
    Error := ResolveWindowsCompilers(Config,C,Cpp);
    if Error <> wgOK then begin MessageDlg(WindowsGameErrorText(Error),mtError,[mbOK],0); Exit end;
    if Config.Runner <> '' then begin
      if not FileExists(Config.Runner) then begin MessageDlg(WindowsGameErrorText(wgRunnerMissing),mtError,[mbOK],0); Exit end;
{$IFDEF DARWIN}
      if not HasArm64MachO(Config.Runner) then begin MessageDlg(WindowsGameErrorText(wgRunnerNotNative),mtError,[mbOK],0); Exit end;
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
    if Result then Config := Dialog.CurrentConfig;
  finally Dialog.Free end;
end;
end.
