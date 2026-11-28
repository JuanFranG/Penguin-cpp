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

unit ClangFormatterOptionsFrm;

interface

uses
  LCLIntf, LCLType, LMessages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, Buttons,
  StdCtrls, Inifiles, ExtCtrls, ComCtrls, Spin, Math, CompOptionsFrame, CompOptionsList, SynEdit,
  Editor;

type
  TClangFormatterOptionsForm = class(TForm)
    btnOk: TBitBtn;
    btnCancel: TBitBtn;
    btnHelp: TBitBtn;
    btnExecute: TBitBtn;
    lblBracketAlignmentStyle: TLabel;
    cmbBracketAlignmentStyle: TComboBox;
    synExample: TSynEdit;
    grpOptions: TGroupBox;
    lblPoweredBy: TLabel;
    spIndentWidth: TSpinEdit;
    lblCommand: TLabel;
    bvCustom: TBevel;
    lblPreview: TLabel;
    chkBracedListStyle: TCheckBox;
    memFullCommand: TMemo;
    spColumnLimit: TSpinEdit;
    chkColumnLimit: TCheckBox;
    lblBasedOnStyle: TLabel;
    coBasedOnStyle: TComboBox;
    spTabWidth: TSpinEdit;
    chkIndentWidth: TCheckBox;
    chkTabWidth: TCheckBox;
    procedure btnCancelClick(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
    procedure btnHelpClick(Sender: TObject);
    procedure btnExecuteClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure OptionChange(Sender: TObject);
    procedure CommandChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormActivate(Sender: TObject);
    procedure FitLayout(Sender: TObject);
  private
    fCreating: Boolean;
    fValid: Boolean;
    fPreviewError: TMemo;
    procedure LoadText;
    procedure LoadSettings;
    procedure LoadSampleText;
    procedure CreateScratchFile;
    procedure SaveSettings;
    function GetFullCommand: String;
  end;

implementation

uses
  main, FileCtrl, Version, devCFG, Utils, MultiLangSupport, DataFrm, devPlatform;

{$R *.lfm}

procedure TClangFormatterOptionsForm.btnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TClangFormatterOptionsForm.btnExecuteClick(Sender: TObject);
begin
  devFormatterClang.ExecFromOpt := true;
  SaveSettings;
end;

procedure TClangFormatterOptionsForm.btnOkClick(Sender: TObject);
begin
  SaveSettings;
end;

procedure TClangFormatterOptionsForm.btnHelpClick(Sender: TObject);
begin
  if fValid then
    OpenDocument('https://clang.llvm.org/docs/ClangFormatStyleOptions.html');
end;

procedure TClangFormatterOptionsForm.LoadText;
begin
  // Set interface font
  Font.Name := devData.InterfaceFont;
  Font.Size := devData.InterfaceFontSize;

  Caption := Lang[ID_FORMATTER_WINDOW];
  grpOptions.Caption := Lang[ID_FORMATTER_OPTIONS];

  lblBasedOnStyle.Caption := Lang[ID_FORMATTER_BASEDONSTYLE];
  lblBracketAlignmentStyle.Caption := Lang[ID_FORMATTER_BRACKETALIGNMENTSTYLE];
  chkIndentWidth.Caption := Lang[ID_FORMATTER_INDENTWIDTH];
  chkBracedListStyle.Caption := Lang[ID_FORMATTER_BRACEDLISTSTYLE];
  chkTabWidth.Caption := Lang[ID_FORMATTER_TABWIDTH];
  chkColumnLimit.Caption := Lang[ID_FORMATTER_COLUMNLIMIT];

  lblCommand.Caption := Lang[ID_FORMATTER_COMMAND];
  lblPreview.Caption := Lang[ID_FORMATTER_PREVIEW];
  if fValid then
    lblPoweredBy.Caption := Format(Lang[ID_FORMATTER_POWEREDBY], [devFormatterClang.GetVersion])
  else
    lblPoweredBy.Caption := Lang[ID_FORMATTER_CLANG_POWEREDBYFAIL];
end;

procedure TClangFormatterOptionsForm.FormCreate(Sender: TObject);
begin
  fCreating := True; // prevents spamming of astyle commands when initializing UI
  try
    // Missing optional tools are reported inline; their preview is not executed.
    fValid := devFormatterClang.Validate;

    btnExecute.Enabled := fValid;
    // Translate
    LoadText;

    // Load dummy text from current file or dummy file
    LoadSampleText;

    // Create scratch file
    CreateScratchFile;

    // Load settings
    LoadSettings;
  finally
    fCreating := False;
    CommandChange(Sender);
  end;
end;

procedure TClangFormatterOptionsForm.LoadSampleText;
var
  e: TEditor;
  FileName: String;
begin
  // Create a rough copy of the current file
  e := MainForm.EditorList.GetEditor;
  if Assigned(e) then begin
    FileName := e.FileName;
    synExample.Text := e.Text.Text;
  end else
    FileName := 'main.cpp';
  devEditor.AssignEditor(synExample, FileName);
  synExample.BorderStyle := bsSingle;
end;

procedure TClangFormatterOptionsForm.CreateScratchFile;
begin
  synExample.Lines.SaveToFile(FormatterTempFile('DummyInput.cpp'));
end;

procedure TClangFormatterOptionsForm.LoadSettings;
begin
  with devFormatterClang do begin
    //Set Base style
    coBasedOnStyle.ItemIndex := BasedOnStyle;

    //Set Bracket Alignment Style
    cmbBracketAlignmentStyle.ItemIndex := BracketAlignmentStyle;

    //Set Indent Width
    chkIndentWidth.Checked := ModifyIndentWidth;
    spIndentWidth.Value := IndentWidth;

    //Set Braced List Style
    chkBracedListStyle.Checked := BracedListStyle;

    //Set Modify Tab Width
    chkTabWidth.Checked := ModifyTabWidth;
    spTabWidth.Value := TabWidth;


    //Set Column Limit
    chkColumnLimit.Checked := ModifyColumnLimit;
    spColumnLimit.Value := ColumnLimit;

    // Set full command
    memFullCommand.Text := FullCommand;
  end;
end;

procedure TClangFormatterOptionsForm.SaveSettings;
begin
  with devFormatterClang do begin
    //Set Base style
    BasedOnStyle := coBasedOnStyle.ItemIndex;

    //Set Bracket Alignment Style
    BracketAlignmentStyle := cmbBracketAlignmentStyle.ItemIndex;

    //Set Indent Width
    ModifyIndentWidth := chkIndentWidth.Checked;
    IndentWidth := spIndentWidth.Value;

    //Set Braced List Style
    BracedListStyle := chkBracedListStyle.Checked;

    //Set Modify Tab Width
    ModifyTabWidth := chkTabWidth.Checked;
    TabWidth := spTabWidth.Value;


    //Set Column Limit
    ModifyColumnLimit := chkColumnLimit.Checked;
    ColumnLimit := spColumnLimit.Value;

    // Set full command
    FullCommand := memFullCommand.Text;
  end;
end;

procedure TClangFormatterOptionsForm.OptionChange(Sender: TObject);
begin
  if fCreating then
    Exit;

  // Update UI
  memFullCommand.Text := GetFullCommand;
end;

procedure TClangFormatterOptionsForm.CommandChange(Sender: TObject);
var
  ClangOutput, DummyFileName: String;
begin
  if fCreating then Exit;
  if not fValid then begin
    lblPreview.Caption := Lang[ID_FORMATTER_PREVIEW] + ' ' + Lang[ID_FORMATTER_CLANG_POWEREDBYFAIL];
    Exit;
  end;
  // Apply to dummy file
  DummyFileName := FormatterTempFile('DummyInput.cpp');
  ClangOutput := devFormatterClang.FormatFile(DummyFileName, memFullCommand.Text);

  // Errors are separate from source code and must never replace the sample file.
  if devFormatterClang.LastExitCode <> 0 then begin
    if not Assigned(fPreviewError) then begin
      fPreviewError := TMemo.Create(Self);
      fPreviewError.Parent := Self;
      fPreviewError.ReadOnly := True;
      fPreviewError.ScrollBars := ssAutoBoth;
      fPreviewError.Font.Assign(Font);
    end;
    fPreviewError.BoundsRect := synExample.BoundsRect;
    fPreviewError.Text := ClangOutput;
    fPreviewError.Visible := True;
    synExample.Visible := False;
    btnExecute.Enabled := False;
    Exit;
  end;
  if Assigned(fPreviewError) then fPreviewError.Visible := False;
  synExample.Visible := True;
  btnExecute.Enabled := True;
  if FileExists(DummyFileName) then begin
    synExample.Lines.Text := ClangOutput;
    synExample.Lines.SaveToFile(DummyFileName);
  end else
    synExample.Lines.Text := Format(Lang[ID_FORMATTER_CLANG_LOADERROR], [DummyFileName]);
end;

// copy of TdevFormatter.GetFullCommand

function TClangFormatterOptionsForm.GetFullCommand: String;
begin
  Result := '"--style={';

  // Add based style
  case coBasedOnStyle.ItemIndex of
    1: Result := Result + 'BasedOnStyle: LLVM, ';
    2: Result := Result + 'BasedOnStyle: Google, ';
    3: Result := Result + 'BasedOnStyle: Chromium, ';
    4: Result := Result + 'BasedOnStyle: Mozilla, ';
    5: Result := Result + 'BasedOnStyle: WebKit, ';
    6: Result := Result + 'BasedOnStyle: Microsoft, ';
    7: Result := Result + 'BasedOnStyle: GNU, ';
  end;

  // Add Bracket Alignment Style
  case cmbBracketAlignmentStyle.ItemIndex of
    1: Result := Result + 'AlignAfterOpenBracket: Align, ';
    2: Result := Result + 'AlignAfterOpenBracket: DontAlign, ';
    3: Result := Result + 'AlignAfterOpenBracket: AlwaysBreak, ';
  end;

  // Add IndentWidth
  if chkIndentWidth.Checked then
    Result := Result + 'IndentWidth: ' + IntToStr(spIndentWidth.Value) + ', ';

  //Add Braced List Style
  if chkBracedListStyle.Checked then
    Result := Result + 'Cpp11BracedListStyle: true, ';

  //Add Tab Width
  if chkTabWidth.Checked then
    Result := Result + 'TabWidth: ' + IntToStr(spTabWidth.Value) + ', ';

  //Add Column Limit
  if chkColumnLimit.Checked then
    Result := Result + 'ColumnLimit: ' + IntToStr(spColumnLimit.Value) + ', ';

  Result := Result + 'Language: Cpp}"';
end;

procedure TClangFormatterOptionsForm.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  Action := caFree;
end;

procedure TClangFormatterOptionsForm.FitLayout(Sender: TObject);
var ColumnWidth,RightColumn:Integer;
begin
  ColumnWidth := (grpOptions.ClientWidth - 48) div 2;
  RightColumn := ColumnWidth + 32;
  lblBasedOnStyle.SetBounds(16, 8, ColumnWidth, 20);
  lblBracketAlignmentStyle.SetBounds(RightColumn, 8, ColumnWidth, 20);
  coBasedOnStyle.SetBounds(16, 30, ColumnWidth, 26);
  cmbBracketAlignmentStyle.SetBounds(RightColumn, 30, ColumnWidth, 26);
  chkIndentWidth.AutoSize := False;
  chkTabWidth.AutoSize := False;
  chkColumnLimit.AutoSize := False;
  chkBracedListStyle.AutoSize := False;
  chkIndentWidth.SetBounds(16, 68, ColumnWidth - 76, 24);
  spIndentWidth.SetBounds(16 + ColumnWidth - 64, 64, 64, 28);
  chkBracedListStyle.SetBounds(RightColumn, 68, ColumnWidth, 24);
  chkTabWidth.SetBounds(16, 102, ColumnWidth - 76, 24);
  spTabWidth.SetBounds(16 + ColumnWidth - 64, 98, 64, 28);
  chkColumnLimit.SetBounds(RightColumn, 102, ColumnWidth - 76, 24);
  spColumnLimit.SetBounds(RightColumn + ColumnWidth - 64, 98, 64, 28);
  bvCustom.Top := 134;
  lblCommand.Top := 142;
  memFullCommand.SetBounds(16, 164, grpOptions.ClientWidth - 32, 70);
end;

procedure TClangFormatterOptionsForm.FormActivate(Sender: TObject);
begin
  ActiveControl := nil;
end;

end.

