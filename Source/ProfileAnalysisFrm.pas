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

unit ProfileAnalysisFrm;

interface

uses
  LCLIntf, LCLType, LMessages, SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls, ExtCtrls, Spin, CBUtils;

type
  TProfileAnalysisForm = class(TForm)
    MainPanel: TPanel;
    ProfilePageControl: TPageControl;
    tabFlat: TTabSheet;
    Splitter2: TSplitter;
    memFlat: TMemo;
    lvFlat: TListView;
    tabGraph: TTabSheet;
    Splitter1: TSplitter;
    memGraph: TMemo;
    lvGraph: TListView;
    tabOpts: TTabSheet;
    FuncHiding: TGroupBox;
    chkHideNotCalled: TCheckBox;
    chkSuppressStatic: TCheckBox;
    PrevText: TLabel;
    spnMinCount: TSpinEdit;
    PostText: TLabel;
    btnApply: TButton;
    CustomCommands: TGroupBox;
    chkCustom: TCheckBox;
    editCustom: TEdit;
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure lvGraphCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState; var DefaultDraw:
      Boolean);
    procedure lvFlatCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState; var DefaultDraw:
      Boolean);
    procedure lvFlatMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure lvFlatClick(Sender: TObject);
    procedure ProfilePageControlChange(Sender: TObject);
    procedure btnApplyClick(Sender: TObject);
    procedure chkCustomClick(Sender: TObject);
    procedure commandUpdate(Sender: TObject);
    procedure lvFlatAdvancedCustomDraw(Sender: TCustomListView;
      const ARect: TRect; Stage: TCustomDrawStage;
      var DefaultDraw: Boolean);
    procedure lvGraphAdvancedCustomDraw(Sender: TCustomListView;
      const ARect: TRect; Stage: TCustomDrawStage;
      var DefaultDraw: Boolean);
  private
    flatloaded: boolean;
    graphloaded: boolean;
    procedure LoadText;
    procedure DoFlat;
    procedure DoGraph;
{$IFDEF DARWIN}
    function LLVMCommand: String;
    procedure DoFlatLLVM;
{$ENDIF}
  end;

var
  ProfileAnalysisForm: TProfileAnalysisForm = nil;

implementation

uses
  devCFG, Version, Utils, main, StrUtils, MultiLangSupport, CppParser, Editor, devPlatform;

{$R *.lfm}

procedure TProfileAnalysisForm.FormShow(Sender: TObject);
{$IFDEF DARWIN}
var
  I: Integer;
{$ENDIF}
begin
  LoadText;

{$IFDEF DARWIN}
  // Calls counted, no times nor call graph (see DoFlatLLVM)
  tabGraph.TabVisible := False;
  lvFlat.Columns[1].Caption := '% calls';
  for I in [2, 3, 5, 6] do
    lvFlat.Columns[I].Visible := False;
{$ENDIF}

  // Spawn DoFlat
  DoFlat;
end;

procedure TProfileAnalysisForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  ProfileAnalysisForm := nil;
end;

procedure TProfileAnalysisForm.DoFlat;
{$IFDEF DARWIN}
begin
  DoFlatLLVM;
end;
{$ELSE}
var
  Params: String;
  Dir: String;
  I, J: integer;
  Line, Phrase: String;
  spacepos: integer;
  buffer: TStringList;
  addeditem: TListItem;
begin

  // Set up GPROF execution...
  if not chkCustom.Checked then begin

    Params := ' ' + GPROF_CMD_GENFLAT;

    // Checkbox options
    if not chkHideNotCalled.checked then
      Params := Params + ' -z';
    if chkSuppressStatic.checked then
      Params := Params + ' -a';
    Params := Params + ' -m ' + spnMinCount.Text;

    if Assigned(MainForm.Project) then begin
      Dir := ExtractFilePath(MainForm.Project.Executable);
      Params := Params + ' "' + ExtractFileName(MainForm.Project.Executable) + '"';
    end else begin
      Dir := ExtractFilePath(MainForm.EditorList.GetEditor.FileName);
      Params := Params + ' "' + ExtractFileName(ChangeFileExt(MainForm.EditorList.GetEditor.FileName, EXE_EXT)) + '"';
    end;
  end else begin
    Params := editCustom.Text + ' ' + GPROF_CMD_GENFLAT;
    if Assigned(MainForm.Project) then
      Dir := ExtractFilePath(MainForm.Project.Executable)
    else
      Dir := ExtractFilePath(MainForm.EditorList.GetEditor.FileName);
  end;

  // Run a flat output
  buffer := TStringList.Create;
  buffer.Text := RunAndGetOutput(devCompilerSets.CompilationSet.gprofName + Params, Dir, nil, nil, False);

  i := 0;

  // Find and skip headers
  while (i < buffer.Count) and not ContainsStr(buffer[i], 'Ts/call') do
    Inc(i);

  Inc(i);

  // Process regular output
  lvFlat.Items.BeginUpdate;
  while (i < buffer.Count) and not SameStr(buffer[i], '') do begin

    addeditem := lvFlat.Items.Add;
    addeditem.Caption := Copy(buffer[i], 55, Length(buffer[i]) - 54); // function name

    // Store info of function in Data pointer
    if Pos('(', addeditem.Caption) > 0 then
      Phrase := Copy(addeditem.Caption, 1, Pos('(', addeditem.Caption) - 1)
    else
      Phrase := addeditem.Caption;
    addeditem.Data := MainForm.CppParser.FindStatementOf(Phrase, nil);

    // Dive remaining part based on spaces
    Line := TrimLeft(buffer[i]);
    for J := 1 to 6 do begin

      // Copy until next space
      Line := TrimLeft(Line);
      spacepos := Pos(' ', Line);
      addeditem.SubItems.Add(Copy(Line, 1, spacepos));
      Delete(Line, 1, spacepos);
    end;

    Inc(i);
  end;
  lvFlat.Items.EndUpdate;

  Inc(i);

  // Print output help
  memFlat.Lines.BeginUpdate;
  while (i < buffer.Count) do begin
    memFlat.Lines.Add(buffer[i]);
    Inc(i);
  end;
  memFlat.Lines.EndUpdate;

  buffer.Free;

  flatloaded := true;
end;
{$ENDIF}

{$IFDEF DARWIN}
// The command that lists the counts: llvm-profdata reads the program's raw
// profile as it is, with no .profdata merged first
function TProfileAnalysisForm.LLVMCommand: String;
begin
  Result := devPlatform.FindDeveloperTool(devCompilerSets.CompilationSet.gprofName);
  if Result = '' then
    Result := devCompilerSets.CompilationSet.gprofName;
  Result := '"' + Result + '" show --all-functions --counts ' + GPROF_CHECKFILE;
end;

// macOS has no gprof. A program built with -fprofile-instr-generate counts
// the calls to each of its functions, and writes them to default.profraw in
// its working folder when it ends: no times, and no call graph. llvm-profdata
// lists them as
//   Counters:
//     _Z3fibi:
//       Hash: 0x000000000001835b
//       Counters: 2
//       Function count: 21891
//       Block counts: [10946]
//     ...
//   Instrumentation level: Front-end
//   Total count: 33138
// with mangled names, a static function's after its file's
// ("prog.cpp:_ZL5ayudai"); c++filt turns them into C++ ones.
procedure TProfileAnalysisForm.DoFlatLLVM;
type
  TCalls = record
    Name: String;
    Count: Int64;
    IsStatic: Boolean;
  end;
var
  Dir, Cmd, Line, Phrase: String;
  Buffer, Trailer, Demangled: TStringList;
  Calls: array of TCalls;
  Item: TCalls;
  Total: Int64;
  I, J, N: Integer;
  AddedItem: TListItem;

  // The options' hidden functions (not the custom command's: it has none)
  function Shown(const C: TCalls): Boolean;
  begin
    Result := chkCustom.Checked or ((C.Count >= spnMinCount.Value) and
      not (chkHideNotCalled.Checked and (C.Count = 0)) and not (chkSuppressStatic.Checked and C.IsStatic));
  end;

begin
  if Assigned(MainForm.Project) then
    Dir := ExtractFilePath(MainForm.Project.Executable)
  else
    Dir := ExtractFilePath(MainForm.EditorList.GetEditor.FileName);
  if chkCustom.Checked then
    Cmd := editCustom.Text
  else
    Cmd := LLVMCommand;

  Buffer := TStringList.Create;
  Trailer := TStringList.Create;
  Demangled := TStringList.Create;
  try
    Buffer.Text := RunAndGetOutput(Cmd, Dir, nil, nil, False);

    // The functions, and the lines after them (or an error)
    SetLength(Calls, Buffer.Count);
    N := 0;
    Total := 0;
    Item.Name := '';
    Item.Count := 0;
    Item.IsStatic := False;
    for I := 0 to Buffer.Count - 1 do begin
      Line := Buffer[I];
      if StartsStr('  ', Line) and not StartsStr('   ', Line) and EndsStr(':', Line) then begin
        Item.Name := Trim(Copy(Line, 1, Length(Line) - 1));
        Item.IsStatic := Pos(':', Item.Name) > 0;
        if Item.IsStatic then
          Item.Name := Copy(Item.Name, RPos(':', Item.Name) + 1, MaxInt);
      end else if StartsStr('Function count:', TrimLeft(Line)) then begin
        Item.Count := StrToInt64Def(Trim(Copy(TrimLeft(Line), Length('Function count:') + 1, MaxInt)), 0);
        Inc(Total, Item.Count);
        if Shown(Item) then begin
          Calls[N] := Item;
          Inc(N);
        end;
      end else if not StartsStr(' ', Line) and (Line <> 'Counters:') then
        Trailer.Add(Line);
    end;

    // The most called first
    for I := 1 to N - 1 do begin
      Item := Calls[I];
      J := I;
      while (J > 0) and (Calls[J - 1].Count < Item.Count) do begin
        Calls[J] := Calls[J - 1];
        Dec(J);
      end;
      Calls[J] := Item;
    end;

    // C++ names, all in one run
    if N > 0 then begin
      Cmd := 'c++filt';
      for I := 0 to N - 1 do
        Cmd := Cmd + ' "' + Calls[I].Name + '"';
      Demangled.Text := RunAndGetOutput(Cmd, Dir, nil, nil, False);
      if Demangled.Count = N then
        for I := 0 to N - 1 do
          Calls[I].Name := Demangled[I];
    end;

    lvFlat.Items.BeginUpdate;
    lvFlat.Items.Clear;
    for I := 0 to N - 1 do begin
      AddedItem := lvFlat.Items.Add;
      AddedItem.Caption := Calls[I].Name;

      // Store info of function in Data pointer
      if Pos('(', AddedItem.Caption) > 0 then
        Phrase := Copy(AddedItem.Caption, 1, Pos('(', AddedItem.Caption) - 1)
      else
        Phrase := AddedItem.Caption;
      AddedItem.Data := MainForm.CppParser.FindStatementOf(Phrase, nil);

      // gprof's columns: % of the calls, then the calls (the times hidden)
      if Total > 0 then
        AddedItem.SubItems.Add(Format('%.2f', [Calls[I].Count * 100 / Total]))
      else
        AddedItem.SubItems.Add('0');
      AddedItem.SubItems.Add('');
      AddedItem.SubItems.Add('');
      AddedItem.SubItems.Add(IntToStr(Calls[I].Count));
      AddedItem.SubItems.Add('');
      AddedItem.SubItems.Add('');
    end;
    lvFlat.Items.EndUpdate;

    memFlat.Lines.BeginUpdate;
    memFlat.Lines.Clear;
    memFlat.Lines.Add(Format(Lang[ID_PROF_LLVMNOTE], [Dir + GPROF_CHECKFILE]));
    memFlat.Lines.Add('');
    memFlat.Lines.AddStrings(Trailer);
    memFlat.Lines.EndUpdate;
  finally
    Buffer.Free;
    Trailer.Free;
    Demangled.Free;
  end;

  flatloaded := true;
end;
{$ENDIF}

procedure TProfileAnalysisForm.DoGraph;
var
  Params: String;
  Dir: String;
  I, J, startcol: integer;
  Line, Phrase: String;
  spacepos: integer;
  buffer: TStringList;
  addeditem: TListItem;
begin

  // Set up GPROF execution...
  if not chkCustom.Checked then begin

    Params := ' ' + GPROF_CMD_GENMAP;

    // Checkbox options
    if not chkHideNotCalled.checked then
      Params := Params + ' -z';
    if chkSuppressStatic.checked then
      Params := Params + ' -a';
    Params := Params + ' -m ' + spnMinCount.Text;

    if Assigned(MainForm.Project) then begin
      Dir := ExtractFilePath(MainForm.Project.Executable);
      Params := Params + ' "' + ExtractFileName(MainForm.Project.Executable) + '"';
    end else begin
      Dir := ExtractFilePath(MainForm.EditorList.GetEditor.FileName);
      Params := Params + ' "' + ExtractFileName(ChangeFileExt(MainForm.EditorList.GetEditor.FileName, EXE_EXT)) + '"';
    end;
  end else begin
    Params := editCustom.Text + ' -q';
    if Assigned(MainForm.Project) then
      Dir := ExtractFilePath(MainForm.Project.Executable)
    else
      Dir := ExtractFilePath(MainForm.EditorList.GetEditor.FileName);
  end;

  // Run a graph output
  buffer := TStringList.Create;
  buffer.Text := RunAndGetOutput(devCompilerSets.CompilationSet.gprofName + Params, Dir, nil, nil, False);

  i := 0;

  // Find and skip headers
  while (i < buffer.Count) and not ContainsStr(buffer[i], '% time') do
    Inc(i);

  Inc(i);

  // Process regular output
  lvGraph.Items.BeginUpdate;
  while (i < buffer.Count) and not SameStr(buffer[i], '') do begin

    addeditem := lvGraph.Items.Add;

    if StartsStr('---', buffer[i]) then begin
      addeditem.Caption := '';
    end else begin

      // Divide remaining part based on spaces
      if StartsStr('[', buffer[i]) then
        addeditem.Caption := Copy(buffer[i], 46, Length(buffer[i]) - 45)
      else
        addeditem.Caption := Copy(buffer[i], 50, Length(buffer[i]) - 49);

      // Store info of function in Data pointer
      if Pos('(', addeditem.Caption) > 0 then
        Phrase := Copy(addeditem.Caption, 1, Pos('(', addeditem.Caption) - 1)
      else
        Phrase := addeditem.Caption;
      addeditem.Data := MainForm.CppParser.FindStatementOf(Phrase, nil);

      // Divide remaining part based on spaces
      Line := TrimLeft(buffer[i]);

      // Add empty columns
      if not StartsStr('[', line) then begin
        addeditem.SubItems.Add('');
        addeditem.SubItems.Add('');
        startcol := 3;
      end else
        startcol := 1;

      for J := startcol to 5 do begin

        // Copy until next space
        Line := TrimLeft(Line);
        spacepos := Pos(' ', Line);
        addeditem.SubItems.Add(Copy(Line, 1, spacepos));
        Delete(Line, 1, spacepos);
      end;
    end;
    Inc(i);
  end;
  lvGraph.Items.EndUpdate;

  Inc(i);

  // Print output help
  memGraph.Lines.BeginUpdate;
  while (i < buffer.Count) do begin
    memGraph.Lines.Add(buffer[i]);
    Inc(i);
  end;
  memGraph.Lines.EndUpdate;

  buffer.Free;

  graphloaded := true;
end;

procedure TProfileAnalysisForm.lvFlatCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
  var DefaultDraw: Boolean);
begin
  if not (cdsSelected in State) then begin
    if Assigned(Item.Data) then
      Sender.Canvas.Font.Color := clBlue
    else
      Sender.Canvas.Font.Color := clWindowText;
  end;
end;

procedure TProfileAnalysisForm.lvGraphCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
  var DefaultDraw: Boolean);
begin
  if not (cdsSelected in State) then begin
    if not StartsStr('---', Item.Caption) then begin
      if Assigned(Item.Data) then
        Sender.Canvas.Font.Color := clBlue
      else
        Sender.Canvas.Font.Color := clWindowText;
    end;
  end;
end;

procedure TProfileAnalysisForm.LoadText;
begin
  // Set interface font
  Font.Name := devData.InterfaceFont;
  Font.Size := devData.InterfaceFontSize;

  Caption := Lang[ID_PROF_CAPTION];
  tabFlat.Caption := Lang[ID_PROF_TABFLAT];
  tabGraph.Caption := Lang[ID_PROF_TABGRAPH];
  tabOpts.Caption := Lang[ID_PROF_TABOPTS];

  FuncHiding.Caption := Lang[ID_PROF_FUNCHIDING];
  chkHideNotCalled.Caption := Lang[ID_PROF_HIDENOTLONG];
  chkSuppressStatic.Caption := Lang[ID_PROF_SUPPRESSTATIC];
  PrevText.Caption := Lang[ID_PROF_PREVTEXT];
  PostText.Caption := Lang[ID_PROF_POSTTEXT];
  btnApply.Caption := Lang[ID_PROF_APPLY];
  CustomCommands.Caption := Lang[ID_PROF_CUSTOMCOMMANDS];
  chkCustom.Caption := Lang[ID_PROF_CUSTOMUSE];
end;

procedure TProfileAnalysisForm.lvFlatMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  It: TListItem;
begin
  with TListView(Sender) do begin
    It := GetItemAt(X, Y);
    if Assigned(It) and Assigned(It.Data) then
      Cursor := crHandPoint
    else
      Cursor := crDefault;
  end;
end;

procedure TProfileAnalysisForm.lvFlatClick(Sender: TObject);
var
  MouseItem: TListItem;
  MousePos: TPoint;
  e: TEditor;
  Statement: PStatement;
  ListView : TListView;
begin
  ListView := TListView(Sender);
  MousePos := ListView.ScreenToClient(Mouse.CursorPos);
  MouseItem := ListView.GetItemAt(MousePos.X, MousePos.Y);
  if Assigned(MouseItem) and Assigned(MouseItem.Data) then begin
    Statement := PStatement(MouseItem.Data);
    e := MainForm.EditorList.GetEditorFromFileName(Statement^._DefinitionFileName);
    if Assigned(e) then begin
      e.SetCaretPosAndActivate(Statement^._DefinitionLine, 1);
    end;
  end;
end;

procedure TProfileAnalysisForm.ProfilePageControlChange(Sender: TObject);
begin
  case ProfilePageControl.ActivePageIndex of
    0: begin
        if not flatloaded then begin
          DoFlat;
          lvFlat.SetFocus;
        end;
      end;
    1: begin
        if not graphloaded then begin
          DoGraph;
          lvGraph.SetFocus;
        end;
      end;
    2: begin
        commandUpdate(nil);
      end;
  end;
end;

procedure TProfileAnalysisForm.btnApplyClick(Sender: TObject);
begin
  flatloaded := false;
  graphloaded := false;

  // Respawn DoFlat
  ProfilePageControl.ActivePage := tabFlat;
end;

procedure TProfileAnalysisForm.chkCustomClick(Sender: TObject);
begin
  chkHideNotCalled.Enabled := not chkCustom.Checked;
  chkSuppressStatic.Enabled := not chkCustom.Checked;
  spnMinCount.Enabled := not chkCustom.Checked;

  editCustom.Enabled := chkCustom.Checked;
end;

procedure TProfileAnalysisForm.CommandUpdate(Sender: TObject);
var
  assembly: String;
begin
{$IFDEF DARWIN}
  if not chkCustom.Checked then
    editCustom.Text := LLVMCommand;
  Exit;
{$ENDIF}
  if not chkCustom.Checked then begin
    assembly := devCompilerSets.CompilationSet.gprofName;
    if Assigned(MainForm.Project) then
      assembly := assembly + ' "' + ExtractFileName(MainForm.Project.Executable) + '"'
    else
      assembly := assembly + ' "' + ExtractFileName(ChangeFileExt(MainForm.EditorList.GetEditor.FileName, EXE_EXT)) +
        '"';
    if not chkHideNotCalled.Checked then
      assembly := assembly + ' -z';
    if chkSuppressStatic.Checked then
      assembly := assembly + ' -a';
    assembly := assembly + ' -m ' + spnMinCount.Text;
    editCustom.Text := assembly;
  end;
end;

procedure TProfileAnalysisForm.lvFlatAdvancedCustomDraw(
  Sender: TCustomListView; const ARect: TRect; Stage: TCustomDrawStage;
  var DefaultDraw: Boolean);
begin
end;

procedure TProfileAnalysisForm.lvGraphAdvancedCustomDraw(
  Sender: TCustomListView; const ARect: TRect; Stage: TCustomDrawStage;
  var DefaultDraw: Boolean);
begin
end;

end.

