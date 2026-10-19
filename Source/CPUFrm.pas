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

unit CPUFrm;

interface

uses
  LCLIntf, LCLType, LMessages, SysUtils, Variants, Classes, Math, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, SynEdit, SynEditTypes, ClipBrd, StrUtils, ComCtrls, ExtCtrls, Menus, DebugEngine;

type
  TCPUForm = class(TForm)
    edFunc: TComboBox;
    lblFunc: TLabel;
    CodeList: TSynEdit;
    RegisterListbox: TListView;
    DisasPanel: TPanel;
    StackTrace: TListView;
    RadioATT: TRadioButton;
    RadioIntel: TRadioButton;
    lblBacktrace: TLabel;
    CPUPopup: TPopupMenu;
    CPUCopy: TMenuItem;
    CPUCopyAll: TMenuItem;
    CPUPaste: TMenuItem;
    CPUCut: TMenuItem;
    N2: TMenuItem;
    CPUSelectAll: TMenuItem;
    RegPanel: TPanel;
    TracePanel: TPanel;
    VertSplit: TSplitter;
    HorzSplit: TSplitter;
    LeftPanel: TPanel;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure edFuncKeyPress(Sender: TObject; var Key: Char);
    procedure FormCreate(Sender: TObject);
    procedure gbSyntaxClick(Sender: TObject);
    procedure CPUCopyClick(Sender: TObject);
    procedure CPUCopyAllClick(Sender: TObject);
    procedure CPUPasteClick(Sender: TObject);
    procedure CPUCutClick(Sender: TObject);
    procedure StackTraceClick(Sender: TObject);
    procedure CPUSelectAllClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    procedure LoadText;
    procedure AssemblerReady(Ok: Boolean; Lines: TStrings);
    procedure RegistersReady(Ok: Boolean; Names, Values: TStrings);
    procedure FramesReady(Ok: Boolean; const Frames: TDebugFrames);
  public
    // Asks the debugger for the code, registers and stack where it stopped
    procedure UpdateView;
  end;

var
  CPUForm: TCPUForm = nil;

implementation

uses
  main, Version, MultiLangSupport, Debugger, DataFrm, Utils, devCFG, Editor, Types, SynEditCompat;

{$R *.lfm}

procedure TCPUForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  // Answers still on their way must not reach a freed window
  MainForm.Debugger.CancelHandlers(Self);

  // Save column widths of registerbox
  devData.CPURegisterCol1 := RegisterListbox.Column[0].Width;
  devData.CPURegisterCol2 := RegisterListbox.Column[1].Width;
  devData.CPURegisterCol3 := RegisterListbox.Column[2].Width;

  Action := caFree;
  CPUForm := nil;
end;

procedure TCPUForm.edFuncKeyPress(Sender: TObject; var Key: Char);
var
  propercmd: String;
begin
  if MainForm.Debugger.Executing then begin
    if Key = Chr(VK_RETURN) then begin
      Key := #0;

      // Although GDB omits void inside () in its own output, it only accepts C style empty parameter lists for input...
      propercmd := edFunc.Text;
      if EndsStr('()', propercmd) then
        propercmd := ReplaceLastStr(propercmd, '()', '(void)');
      if Assigned(MainForm.Debugger.Engine) then
        MainForm.Debugger.Engine.Disassemble(propercmd, AssemblerReady);
      if (Length(edFunc.Text) > 0) and (edFunc.Items.IndexOf(edFunc.Text) = -1) then
        edFunc.AddItem(edFunc.Text, nil);
    end;
  end;
end;

procedure TCPUForm.LoadText;
begin
  // Set interface font
  Font.Name := devData.InterfaceFont;
  Font.Size := devData.InterfaceFontSize;

  Caption := Lang[ID_CPU_CAPTION];
  lblFunc.Caption := Lang[ID_CPU_FUNC];
  lblBacktrace.Caption := Lang[ID_DEB_BACKTRACE];

  CPUCut.Caption := Lang[ID_ITEM_CUT];
  CPUCopy.Caption := Lang[ID_ITEM_COPY];
  CPUCopyAll.Caption := Lang[ID_ITEM_COPYALL];
  CPUPaste.Caption := Lang[ID_ITEM_PASTE];
  CPUSelectAll.Caption := Lang[ID_ITEM_SELECTALL];
end;

procedure TCPUForm.FramesReady(Ok: Boolean; const Frames: TDebugFrames);
var
  I: integer;
  item: TListItem;
begin
  StackTrace.Items.BeginUpdate;
  try
    StackTrace.Clear;
    for I := 0 to High(Frames) do begin
      item := StackTrace.Items.Add;
      item.Caption := Frames[I].Func;
      if Frames[I].FullName <> '' then
        item.SubItems.Add(Frames[I].FullName)
      else
        item.SubItems.Add(Frames[I].FileName);
      if Frames[I].Line > 0 then
        item.SubItems.Add(IntToStr(Frames[I].Line))
      else
        item.SubItems.Add('');
    end;
  finally
    StackTrace.Items.EndUpdate;
  end;
end;

procedure TCPUForm.AssemblerReady(Ok: Boolean; Lines: TStrings);
var
  I, activeline: integer;
begin
  if Lines.Count = 0 then
    Exit;
  activeline := -1;
  if Ok then
    edFunc.Text := Lines[0];

  CodeList.BeginUpdate;
  try
    CodeList.Clear;
    for I := 1 to Lines.Count - 1 do begin
      CodeList.Lines.Add(Lines[I]);
      if StartsStr('=>', Lines[I]) then
        activeline := I;
    end;
    if not Ok then
      CodeList.Lines.Add(Lines[0]); // gdb's message
  finally
    CodeList.EndUpdate;
  end;

  if activeline <> -1 then
    CodeList.CaretXY := BufferCoord(1, activeline);
end;

procedure TCPUForm.RegistersReady(Ok: Boolean; Names, Values: TStrings);
var
  item: TListItem;
  I: integer;
  Number: Int64;
begin
  RegisterListbox.Items.BeginUpdate;
  try
    RegisterListBox.Clear;
    for I := 0 to Names.Count - 1 do begin
      item := RegisterListbox.Items.Add;
      item.Caption := UpperCase(Names[I]);
      item.SubItems.Add(Values[I]);
      // the decimal value, for the registers that hold a number
      if StartsStr('0x', Values[I]) and TryStrToInt64('$' + Copy(Values[I], 3, MaxInt), Number) then
        item.SubItems.Add(IntToStr(Number))
      else
        item.SubItems.Add('');
    end;
  finally
    RegisterListBox.Items.EndUpdate;
  end;
end;

procedure TCPUForm.UpdateView;
begin
  if not (MainForm.Debugger.Executing and MainForm.Debugger.Paused and Assigned(MainForm.Debugger.Engine)) then
    Exit;
  MainForm.Debugger.Engine.Disassemble('', AssemblerReady);
  MainForm.Debugger.Engine.GetRegisters(RegistersReady);
  MainForm.Debugger.Engine.GetFrames(FramesReady);
end;

procedure TCPUForm.FormCreate(Sender: TObject);
begin
  LoadText;

  // Make it look a bit like a regular editor
  devEditor.AssignEditor(CodeList,'main.cpp');

  RadioATT.Checked := devData.UseATTSyntax;
  RadioIntel.Checked := not devData.UseATTSyntax;

  if MainForm.Debugger.Executing and Assigned(MainForm.Debugger.Engine) then begin
    MainForm.Debugger.Engine.SetIntelSyntax(not devData.UseATTSyntax);
    UpdateView;
  end;
end;

procedure TCPUForm.gbSyntaxClick(Sender: TObject);
var
  key: Char;
begin
  // Set disassembly flavor
  if RadioAtt.Checked then begin
    if Assigned(MainForm.Debugger.Engine) then
      MainForm.Debugger.Engine.SetIntelSyntax(False);
    RadioIntel.Checked := false;
    devData.UseATTSyntax := true;
  end else if RadioIntel.Checked then begin
    if Assigned(MainForm.Debugger.Engine) then
      MainForm.Debugger.Engine.SetIntelSyntax(True);
    RadioAtt.Checked := false;
    devData.UseATTSyntax := false;
  end;

  // load the current function
  key := Chr(VK_RETURN);
  edFuncKeyPress(nil, key);
end;

procedure TCPUForm.CPUCutClick(Sender: TObject);
begin
  if edFunc.Focused then begin
    ClipBoard.AsText := edFunc.SelText;
    edFunc.SelText := '';
  end;
end;

procedure TCPUForm.CPUCopyClick(Sender: TObject);
begin
  if edFunc.Focused then
    ClipBoard.AsText := edFunc.SelText
  else if CodeList.Focused then
    CodeList.CopyToClipboard
  else if StackTrace.Focused then
    Clipboard.AsText := GetPrettyLine(StackTrace)
  else if RegisterListbox.Focused then
    Clipboard.AsText := GetPrettyLine(RegisterListbox);
end;

procedure TCPUForm.CPUCopyAllClick(Sender: TObject);
var
  i: integer;
begin
  if edFunc.Focused then
    ClipBoard.AsText := edFunc.Text
  else if CodeList.Focused then
    CodeList.CopyToClipboard
  else if StackTrace.Focused then begin
    ClipBoard.AsText := '';
    for i := 0 to pred(StackTrace.Items.Count) do
      Clipboard.AsText := Clipboard.AsText + GetPrettyLine(StackTrace, i) + #13#10;
  end else if RegisterListbox.Focused then begin
    ClipBoard.AsText := '';
    for i := 0 to pred(RegisterListbox.Items.Count) do
      Clipboard.AsText := Clipboard.AsText + GetPrettyLine(RegisterListbox, i) + #13#10;
  end;
end;

procedure TCPUForm.CPUPasteClick(Sender: TObject);
begin
  if edFunc.Focused then
    edFunc.SelText := ClipBoard.AsText;
end;

procedure TCPUForm.CPUSelectAllClick(Sender: TObject);
begin
  if edFunc.Focused then
    edFunc.SelectAll;
end;

procedure TCPUForm.StackTraceClick(Sender: TObject);
var
  sel: TListItem;
  e: TEditor;
begin
  sel := StackTrace.Selected;
  if Assigned(sel) then begin
    e := MainForm.EditorList.GetEditorFromFileName(sel.SubItems[0]);
    if Assigned(e) then begin
      e.SetCaretPosAndActivate(StrToIntDef(sel.SubItems[1], 1), 1);
    end;
  end;
end;

procedure TCPUForm.FormShow(Sender: TObject);
begin
  // Get column widths of registerbox
  RegisterListbox.Column[0].Width := devData.CPURegisterCol1;
  RegisterListbox.Column[1].Width := devData.CPURegisterCol2;
  RegisterListbox.Column[2].Width := devData.CPURegisterCol3;
end;

end.

