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

unit Editor;

interface

uses
  System.UITypes, LCLIntf, LCLType, LMessages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  CodeCompletion, CppParser, SynEditExport, Menus, ImgList, ComCtrls, StdCtrls, ExtCtrls, SynEdit,
  SynEditKeyCmds, Version, SynExportHTML, SynEditTextBuffer, Math, StrUtils, SynEditTypes,
  SynEditHighlighter, DateUtils, CodeToolTip, CBUtils, Contnrs, ExtDlgs,
  SynEditCompat, SynEditMarks, LazSynEditText, LazUTF8, LConvEncoding, SynEditFoldedView, SynEditMiscClasses;

type
  TCloseTabSheet = class(TTabSheet)
  private
  protected
  public
    FCloseButtonRect: TRect;
    FOnClose: TNotifyEvent;
    procedure DoClose; virtual;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
  end;

  TLinesShiftEvent = procedure(FirstLine, Count: integer) of object;

  // TSynEdit with the IDE's extra commands, and the logical-coordinate API of
  // the Delphi SynEdit this code was written for: CaretX/CaretXY/BlockBegin/
  // BlockEnd are positions in the line text (Lazarus' CaretXY is physical).
  TSynEditEx = class(TSynEdit)
  public const
    ecMoveSelDown = ecUserFirst + 1;
    ecMoveSelUp = ecUserFirst + 2;
    ecDuplicateLine = ecUserFirst + 3;
    ecComment = ecUserFirst + 4;
    ecUncomment = ecUserFirst + 5;
    ecToggleComment = ecUserFirst + 6;
    ecCommentInline = ecUserFirst + 7;
  private
    FeoAddIndent: Boolean;
    FOnLinesInserted: TLinesShiftEvent;
    FOnLinesDeleted: TLinesShiftEvent;
    procedure LineCountChanged(Sender: TSynEditStrings; AIndex, ACount: Integer);
    procedure DoComment;
    procedure DoUnComment;
    procedure DoToggleComment;
    procedure DoCommentInline;
    procedure MoveLines(Down: Boolean);
    procedure DuplicateLine;
    // Dev-C++'s TBufferCoord versions of SynEdit's TPoint ones (on purpose)
    function GetCaretX: Integer; reintroduce;
    procedure SetCaretX(Value: Integer); reintroduce;
    function GetCaretXY: TBufferCoord; reintroduce;
    procedure SetCaretXY(const Value: TBufferCoord); reintroduce;
    function GetBlockBegin: TBufferCoord; reintroduce;
    procedure SetBlockBegin(const Value: TBufferCoord); reintroduce;
    function GetBlockEnd: TBufferCoord; reintroduce;
    procedure SetBlockEnd(const Value: TBufferCoord); reintroduce;
    function GetDisplayXY: TDisplayCoord;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ExecuteCommand(Command: TSynEditorCommand; const AChar: TUTF8Char; Data: pointer); override;
    procedure CommandProcessor(Command: TSynEditorCommand; AChar: TUTF8Char; Data: pointer;
      ASkipHooks: THookedCommandFlags = []); override;
    procedure SetCaretXYCentered(ForceToMiddle: Boolean; const Value: TBufferCoord);
    function BufferToDisplayPos(const P: TBufferCoord): TDisplayCoord;
    function DisplayToBufferPos(const P: TDisplayCoord): TBufferCoord;
    function PixelsToRowColumn(X, Y: Integer): TDisplayCoord; overload;
    function GetPositionOfMouse(out P: TBufferCoord): Boolean;
    function WordStart: TBufferCoord;
    function WordEnd: TBufferCoord;
    function GetMatchingBracketEx(const P: TBufferCoord): TBufferCoord;
    function LeftSpaces(const Line: string): Integer; // indent width, tabs expanded
    function IsScrolling: Boolean;
    function SelLength: Integer; // characters in the selection
    function InSelection(const P: TBufferCoord): Boolean;
    procedure SetCaretAndSel(const ACaret, ABegin, AEnd: TBufferCoord);
    function WordAtCursor: string;
    procedure InvalidateGutterLine(Line: Integer);
    procedure UncollapseAroundLine(Line: Integer);
    procedure CollapseAll;
    procedure UncollapseAll;
    property CaretX: Integer read GetCaretX write SetCaretX;
    property CaretXY: TBufferCoord read GetCaretXY write SetCaretXY;
    property BlockBegin: TBufferCoord read GetBlockBegin write SetBlockBegin;
    property BlockEnd: TBufferCoord read GetBlockEnd write SetBlockEnd;
    property DisplayXY: TDisplayCoord read GetDisplayXY;
    property eoAddIndent: Boolean read FeoAddIndent write FeoAddIndent;
    property OnLinesInserted: TLinesShiftEvent read FOnLinesInserted write FOnLinesInserted;
    property OnLinesDeleted: TLinesShiftEvent read FOnLinesDeleted write FOnLinesDeleted;
  end;

  TEditor = class;

  // Define what we want to see of the word at any position
  TWordPurpose = (
    wpCompletion, // walk backwards over words, array, functions, parents, no forward movement
    wpEvaluation, // walk backwards over words, array, functions, parents, forwards over words, array
    wpInformation // walk backwards over words, array, functions, parents, forwards over words
    );

  // Define why we are allowed to change the cursor to a handpoint
  THandPointReason = (
    hprPreprocessor, // cursor hovers above preprocessor line
    hprIdentifier, // cursor hovers above identifier
    hprSelection, // cursor hovers above selection
    hprNone // mouseover not allowed
    );

  // Define what we want to skip
  TSymbolCompleteState = (
    scsSkipped, // skipped over completed symbol
    scsInserted, // opening symbol has been inserted
    scsFinished // keystroke that triggered insertion has completed
    );

  // Define how to handle international characters, when the Save or SaveAs called
  TSymbolCorrectionEncoding = (
    sceUserDefined, // to ask the user, if found international symbol, else remains of the original encoding
    sceNever,       // never check Encoding, save as is
    sceAuto,        // automatically correct without dialog, if found, else remains of the original encoding
    sceFixedUTF8    // always set UTF8, without checking
    );

  TEditor = class(TObject)
  private
    fInProject: boolean;
    fFileName: String;
    fNew: boolean;
    fText: TSynEditEx;
    fTabSheet: TTabSheet;
    fErrorLine: integer;
    fActiveLine: integer;
    fEncoding: string; // LConvEncoding name of the file on disk
    fCurrentWord: String;
    fCurrentEvalWord: String;
    fErrorCaret: TPoint; // where SetErrorFocus put the caret
    fPreviousEditors: TList;
    fCompletionTimer: TTimer;
    fCompletionBox: TCodeCompletion;
    fCompletionInitialPosition: TBufferCoord;
    fFunctionTipTimer: TTimer;
    fFunctionTip: TCodeToolTip;
    fParenthCompleteState: TSymbolCompleteState;
    fArrayCompleteState: TSymbolCompleteState;
    fBraceCompleteState: TSymbolCompleteState;
    fEncodingCorrection: TSymbolCorrectionEncoding;
    //fSingleQuoteCompleteState: TSymbolCompleteState;
    //fDoubleQuoteCompleteState: TSymbolCompleteState;
    procedure EditorKeyPress(Sender: TObject; var Key: Char);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure EditorStatusChange(Sender: TObject; Changes: TSynStatusChanges);
    procedure EditorReplaceText(Sender: TObject; const aSearch, aReplace: String; Line, Column: integer; var Action:
      TSynReplaceAction);
    procedure EditorMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure EditorMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
      var Handled: Boolean);
    procedure EditorExit(Sender: TObject);
    procedure EditorGutterClick(Sender: TObject; X, Y, Line: integer; mark: TSynEditMark);
    procedure EditorSpecialLineColors(Sender: TObject; Line: integer; var Special: boolean; var FG, BG: TColor);
    procedure EditorSpecialLineMarkup(Sender: TObject; Line: integer; var Special: boolean;
      Markup: TSynSelectedColor);
    procedure EditorEnter(Sender: TObject);
    procedure CompletionKeyPress(Sender: TObject; var Key: Char);
    procedure CompletionInsert(const append: String);
    procedure CompletionTimer(Sender: TObject);
    function FunctionTipAllowed: boolean;
    procedure FunctionTipTimer(Sender: TObject);
    procedure HandleSymbolCompletion(var Key: Char);
    procedure HandleCodeCompletion(var Key: Char);
    function HandpointAllowed(var MousePos: TBufferCoord; ShiftState: TShiftState): THandPointReason;
    procedure SetFileName(const value: String);
    procedure OnMouseOverEvalReady(Ok: Boolean; const evalvalue: String);
    function HasBreakPoint(Line: integer): integer;
    procedure EditorPaint(Sender: TObject; ACanvas: TCanvas);
    procedure LinesInserted(FirstLine, Count: integer);
    procedure LinesDeleted(FirstLine, Count: integer);
    function GetPageControl: TPageControl;
    procedure SetPageControl(Value: TPageControl);
    procedure UpdateEncoding(const FileName: string);
  public
    constructor Create(const Filename: String; InProject, NewFile: boolean; ParentPageControl: TPageControl; AEncoding: TEncoding);
    destructor Destroy; override;
    function Save: boolean;
    function SaveAs: boolean;
    procedure Activate;
    procedure GotoLine;
    procedure SetCaretPosAndActivate(Line, Col: integer); // needs to activate in order to place cursor properly
    procedure ExportToHTML;
    procedure ExportToRTF;
    procedure ExportToTEX;
    procedure InsertString(Value: String; MoveCursor: boolean);
    procedure SetErrorFocus(Col, Line: integer);
    procedure GotoActiveBreakpoint;
    procedure SetActiveBreakpointFocus(Line: integer);
    procedure RemoveBreakpointFocus;
    procedure UpdateCaption(const NewCaption: String);
    procedure InsertDefaultText;
    procedure ToggleBreakPoint(Line: integer);
    function GetWordAtPosition(P: TBufferCoord; Purpose: TWordPurpose): String;
    procedure IndentSelection;
    procedure UnindentSelection;
    procedure InitCompletion;
    procedure ShowCompletion;
    procedure DestroyCompletion;
    property PreviousEditors: TList read fPreviousEditors;
    property FileName: String read fFileName write SetFileName;
    property InProject: boolean read fInProject write fInProject;
    property New: boolean read fNew write fNew;
    property Text: TSynEditEx read fText write fText;
    property TabSheet: TTabSheet read fTabSheet write fTabSheet;
    property FunctionTip: TCodeToolTip read fFunctionTip;
    property CompletionBox: TCodeCompletion read fCompletionBox;
    property PageControl: TPageControl read GetPageControl write SetPageControl;
    property EncodingCorrection: TSymbolCorrectionEncoding read fEncodingCorrection write fEncodingCorrection;
  end;
  const
    CTAB_PADDING = ''; // tabs used to reserve room for a hand-drawn close button

implementation

uses
  main, Project, MultiLangSupport, devCFG, Utils, DataFrm, GotoLineFrm, Macros, Debugger, GdbMI,
  IncrementalFrm, CodeCompletionForm, CharUtils, EditorPrint, PdfPrint, CodeExport, MacSupport;

{ TCloseTabSheet }
constructor TCloseTabSheet.Create(AOwner:TComponent);
begin
  inherited Create(AOwner);
  FCloseButtonRect:=Rect(125, 0, 150, 50);
end;

destructor TCloseTabSheet.Destroy;
begin
  inherited Destroy;
end;

procedure TCloseTabSheet.DoClose;
begin
  if Assigned(FOnClose) then FOnClose(Self);
  Free;
end;

procedure TEditor.LinesInserted(FirstLine, Count: integer);
var
  I, line: integer;
  bp: PBreakPoint;

  procedure LinesInsertedList(Items: TListItems);
  var
    I: integer;
  begin
    for I := 0 to Items.Count - 1 do begin
      if SameFileName(fFileName, Items[i].SubItems[1]) then begin
        line := StrToIntDef(Items[i].Caption, -1);
        if (line >= FirstLine) then
          Items[i].Caption := IntToStr(line + Count);
      end;
    end;
  end;
begin
  for I := 0 to MainForm.Debugger.BreakPointList.Count - 1 do begin
    bp := PBreakPoint(MainForm.Debugger.BreakPointList.Items[I]);
    if (bp^.editor = Pointer(Self)) and (bp^.line >= FirstLine) then
      Inc(bp^.line, Count);
  end;

  LinesInsertedList(MainForm.CompilerOutput.Items);
  LinesInsertedList(MainForm.FindOutput.Items);
end;

procedure TEditor.LinesDeleted(FirstLine, Count: integer);
var
  I, line: integer;
  bp: PBreakPoint;

  procedure LinesDeletedList(Items: TListItems);
  var
    I: integer;
  begin
    for I := Items.Count - 1 downto 0 do begin
      if SameFileName(fFileName, Items[i].SubItems[1]) then begin
        line := StrToIntDef(Items[i].Caption, -1);
        if (line >= FirstLine) then begin
          if (line >= FirstLine + Count) then
            Items[i].Caption := IntToStr(line - Count)
          else
            Items.Delete(I);
        end;
      end;
    end;
  end;

begin
  for I := MainForm.Debugger.BreakPointList.Count - 1 downto 0 do begin
    bp := PBreakPoint(MainForm.Debugger.BreakPointList.Items[I]);
    if (bp^.editor = Pointer(Self)) and (bp^.line >= FirstLine) then begin
      if (bp^.line >= FirstLine + Count) then
        Dec(bp^.line, Count)
      else
        ToggleBreakPoint(bp^.line); // remove breakpoints INSIDE deleted selection
    end;
  end;

  LinesDeletedList(MainForm.CompilerOutput.Items);
  LinesDeletedList(MainForm.FindOutput.Items);
end;

{ Encoding }

// The editor always holds UTF-8. Files are read as UTF-8 when they are valid
// UTF-8 (or have a BOM) and as Windows-1252 otherwise, the usual encoding of
// files written by Dev-C++ on Windows; they are written back the same way.

function HasNonASCII(const S: string): boolean;
var
  I: integer;
begin
  for I := 1 to Length(S) do
    if Ord(S[I]) > 127 then
      Exit(True);
  Result := False;
end;

function ReadTextFile(const FileName: string; AEncoding: TEncoding; out Encoding: string): string;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, Stream.Size);
    if Length(Result) > 0 then
      Stream.ReadBuffer(Result[1], Length(Result));
  finally
    Stream.Free;
  end;

  if (Length(Result) >= 3) and (Result[1] = #$EF) and (Result[2] = #$BB) and (Result[3] = #$BF) then begin
    Delete(Result, 1, 3);
    Encoding := EncodingUTF8BOM;
  end else if (AEncoding = TEncoding.UTF8) or
    ((AEncoding = nil) and (FindInvalidUTF8Codepoint(PChar(Result), Length(Result)) < 0)) then
    Encoding := EncodingUTF8
  else begin
    Encoding := 'cp1252';
    Result := ConvertEncoding(Result, Encoding, EncodingUTF8);
  end;
end;

procedure WriteTextFile(const FileName, Text, Encoding: string);
var
  Stream: TFileStream;
  Data: string;
begin
  if Encoding = EncodingUTF8BOM then
    Data := #$EF#$BB#$BF + Text
  else if (Encoding = EncodingUTF8) or (Encoding = '') then
    Data := Text
  else
    Data := ConvertEncoding(Text, EncodingUTF8, Encoding);
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    if Length(Data) > 0 then
      Stream.WriteBuffer(Data[1], Length(Data));
  finally
    Stream.Free;
  end;
end;

{ TEditor }

constructor TEditor.Create(const Filename: String; InProject, NewFile: boolean; ParentPageControl: TPageControl; AEncoding: TEncoding);
var
  s: String;
  I: integer;
  e: TEditor;
begin
  // Set generic options
  fErrorLine := -1;
  fActiveLine := -1;
  fInProject := InProject;
  if FileName <> '' then
    fFileName := Filename
  else
    fFileName := Lang[ID_UNTITLED] + IntToStr(dmMain.GetNewFileNumber);

  // Remember previous tabs
  fPreviousEditors := TList.Create;
  if Assigned(ParentPageControl.ActivePage) then begin
    e := TEditor(ParentPageControl.ActivePage.Tag); // copy list of previous editor
    for I := 0 to e.PreviousEditors.Count - 1 do
      fPreviousEditors.Add(e.PreviousEditors[i]);
    fPreviousEditors.Add(Pointer(e)); // make current editor history too
  end;

  // Create a new tab
  fTabSheet := TCloseTabSheet.Create(ParentPageControl);
  fTabSheet.Caption := ExtractFileName(fFilename) + CTAB_PADDING; // UntitlexX or main.cpp
  fTabSheet.PageControl := ParentPageControl;
  fTabSheet.Tag := PtrInt(Self); // Define an index for each tab
  fTabSheet.TabVisible := True;

  // Create an editor and set static options
  fText := TSynEditEx.Create(fTabSheet);

  // Load the file
  if not NewFile and FileExists(FileName) then begin
    fText.Lines.Text := ReadTextFile(FileName, AEncoding, fEncoding);
    fNew := False;

    // Save main.cpp as main.123456789.cpp
    if devData.Backups then begin
      s := '.' + IntToStr(DateTimeToUnix(Now)) + ExtractFileExt(FileName);
      WriteTextFile(ChangeFileExt(FileName, s), fText.Lines.Text, fEncoding);
    end;
  end else begin
    fEncoding := EncodingUTF8;
    fNew := True;
  end;

  // Set constant options
  fText.Parent := fTabSheet;
  fText.Visible := True;
  fText.Align := alClient;
  fText.PopupMenu := MainForm.EditorPopup;
  fText.ShowHint := True;
  fText.OnStatusChange := EditorStatusChange;
  fText.OnReplaceText := EditorReplaceText;
  fText.OnMouseUp := EditorMouseUp;
  fText.OnMouseMove := EditorMouseMove;
  fText.OnMouseWheel := EditorMouseWheel; // SynEdit asks it first, before scrolling
  fText.OnGutterClick := EditorGutterClick;
  fText.OnSpecialLineMarkup := EditorSpecialLineMarkup;
  fText.OnEnter := EditorEnter;
  fText.OnExit := EditorExit;
  fText.OnKeyPress := EditorKeyPress;
  fText.OnKeyDown := EditorKeyDown;
  fText.OnKeyUp := EditorKeyUp;
  fText.OnPaint := EditorPaint; // breakpoint and error marks in the gutter
  fText.OnLinesInserted := LinesInserted;
  fText.OnLinesDeleted := LinesDeleted;

  fText.ParentFont := False;

  // Set the variable options
  devEditor.AssignEditor(fText, fFileName);

  // Function parameter tips
  fFunctionTip := TCodeToolTip.Create(Application);
  fFunctionTip.Editor := fText;
  fFunctionTip.Parser := MainForm.CppParser;

  // Initialize code completion stuff
  InitCompletion;

  // Setup a monitor which keeps track of outside-of-editor changes
  MainForm.FileMonitor.Monitor(fFileName);

  // Set status bar for the first time
  EditorStatusChange(Self, [scInsertMode]);
end;

destructor TEditor.Destroy;
begin
  // Freeing the page makes the page control change its active page, and its
  // handlers find the editor through the page: this one is half gone by then
  if Assigned(fTabSheet) then
    fTabSheet.Tag := 0;

  // Nor may its text control call back into it: freeing the control moves the
  // focus, and the exit handler would use the code tooltip, freed before it
  if Assigned(fText) then begin
    fText.OnEnter := nil;
    fText.OnExit := nil;
    fText.OnStatusChange := nil;
    fText.OnMouseMove := nil;
    fText.OnMouseWheel := nil;
    fText.OnPaint := nil;
  end;

  // The incremental search would keep searching in the freed text
  if Assigned(IncrementalForm) and (IncrementalForm.Editor = fText) then
    IncrementalForm.Close;

  // Deactivate the file change monitor
  MainForm.FileMonitor.UnMonitor(fFileName);

  // Delete breakpoints in this editor
  MainForm.Debugger.DeleteBreakPointsOf(self);
  MainForm.Debugger.CancelHandlers(Self); // no answer may reach a freed editor

  // Destroy code completion stuff
  DestroyCompletion;

  // Free everything
  FreeAndNil(fFunctionTip);
  FreeAndNil(fText);
  FreeAndNil(fTabSheet);
  FreeAndNil(fPreviousEditors);

  // Move into TObject.Destroy...
  inherited;
end;

function TEditor.GetPageControl: TPageControl;
begin
  if Assigned(fTabSheet) then
    Result := fTabSheet.PageControl
  else
    Result := nil;
end;

procedure TEditor.SetPageControl(Value: TPageControl);
begin
  if Assigned(fTabSheet) then
    fTabSheet.PageControl := Value;
end;

procedure TEditor.OnMouseOverEvalReady(Ok: Boolean; const evalvalue: String);
begin
  if Ok then
    fText.Hint := fCurrentEvalWord + ' = ' + evalvalue
  else
    fText.Hint := '';
end;

procedure TEditor.Activate;
begin
  // Don't waste time refocusing
  if fText.Focused then
    Exit;

  // Allow the user to start typing right away
  fTabSheet.PageControl.ActivePage := fTabSheet;
  fTabSheet.PageControl.OnChange(fTabSheet.PageControl); // event is not fired when changing ActivePage
end;

procedure TEditor.EditorGutterClick(Sender: TObject; X, Y, Line: integer; mark: TSynEditMark);
begin
  ToggleBreakPoint(Line);
end;

procedure TEditor.ToggleBreakpoint(Line: integer);
var
  thisbreakpoint: integer;
begin
  thisbreakpoint := HasBreakPoint(Line);

  if thisbreakpoint <> -1 then
    MainForm.Debugger.RemoveBreakPoint(Line, self)
  else
    MainForm.Debugger.AddBreakPoint(Line, self);

  // Convert buffer to display position
  fText.InvalidateGutterLine(Line);
  fText.InvalidateLine(Line);
end;

function TEditor.HasBreakPoint(Line: integer): integer;
var
  I: integer;
begin
  result := -1;
  for I := 0 to MainForm.Debugger.BreakPointList.Count - 1 do
    if PBreakPoint(MainForm.Debugger.BreakPointList.Items[I])^.editor = Self then
      if PBreakPoint(MainForm.Debugger.BreakPointList.Items[I])^.line = Line then begin
        Result := I;
        break;
      end;
end;

// SynEdit's OnSpecialLineColors is deprecated; this feeds the colors to the
// markup exactly as SynEdit did with it
procedure TEditor.EditorSpecialLineMarkup(Sender: TObject; Line: integer; var Special: boolean;
  Markup: TSynSelectedColor);
var
  FG, BG: TColor;
begin
  if Special then begin
    FG := Markup.Foreground;
    BG := Markup.Background;
  end else begin
    FG := clNone;
    BG := clNone;
  end;
  EditorSpecialLineColors(Sender, Line, Special, FG, BG);
  Markup.Foreground := FG;
  Markup.Background := BG;
end;

procedure TEditor.EditorSpecialLineColors(Sender: TObject; Line: Integer; var Special: Boolean; var FG, BG: TColor);
var
  pt: TPoint;
begin
  if (Line = fActiveLine) then begin
    StrtoPoint(pt, devEditor.Syntax.Values[cABP]);
    BG := pt.X;
    FG := pt.Y;
    Special := TRUE;
  end else if (HasBreakpoint(Line) <> -1) then begin
    StrtoPoint(pt, devEditor.Syntax.Values[cBP]);
    BG := pt.X;
    FG := pt.Y;
    Special := TRUE;
  end else if Line = fErrorLine then begin
    StrtoPoint(pt, devEditor.Syntax.Values[cErr]);
    BG := pt.X;
    FG := pt.Y;
    Special := TRUE;
  end;
end;

procedure TEditor.EditorPaint(Sender: TObject; ACanvas: TCanvas);
var
  X, Y, Line, LastLine: integer;
begin
  // Draw marks centered in the gutter, one per visible line
  X := (fText.Gutter.Width - dmMain.GutterImages.Width) div 2;
  Y := (fText.LineHeight - dmMain.GutterImages.Height) div 2;
  LastLine := Min(fText.Lines.Count, fText.TopLine + fText.LinesInWindow);
  for Line := fText.TopLine to LastLine do begin
    if fActiveLine = Line then // prefer active line over breakpoints
      dmMain.GutterImages.Draw(ACanvas, X, Y, 1)
    else if HasBreakpoint(Line) <> -1 then
      dmMain.GutterImages.Draw(ACanvas, X, Y, 0)
    else if fErrorLine = Line then
      dmMain.GutterImages.Draw(ACanvas, X, Y, 2);
    Inc(Y, fText.LineHeight);
  end;
end;

procedure TEditor.EditorReplaceText(Sender: TObject; const aSearch, aReplace: String; Line, Column: integer; var
  Action: TSynReplaceAction);
var
  pt: TPoint;
begin
  pt := fText.ClienttoScreen(fText.RowColumnToPixels(fText.BufferToDisplayPos(BufferCoord(Column, Line))));
  Beep;
  case MessageDlgPos(format(Lang[ID_MSG_SEARCHREPLACEPROMPT], [aSearch]), mtConfirmation, [mbYes, mbNo, mbCancel,
    mbAll], 0, pt.x, pt.y + fText.LineHeight) of
    mrYes: Action := raReplace;
    mrNo: Action := raSkip;
    mrCancel: Action := raCancel;
    mrAll: Action := raReplaceAll;
  end;
end;

// Ctrl + wheel (Command on macOS) zooms every editor (the welcome screen says
// so); SynEdit would scroll instead
procedure TEditor.EditorMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
begin
  if IsZoomShift(Shift) then begin
    MainForm.ZoomEditors(WheelDelta);
    Handled := True;
  end;
end;

// Handle WM_KILLFOCUS instead of all the special cases to hide the code tooltip

procedure TEditor.EditorExit(Sender: TObject);
begin
  if Assigned(fFunctionTip) then
    fFunctionTip.ReleaseHandle;
end;

// Handling this here instead of in PageControlChange because when switching between two active editors side by side
// PageControlChange will not happen, but the editor will be entered and this will be executed

procedure TEditor.EditorEnter(Sender: TObject);
var
  I, x, y: integer;
begin
  // Set title bar to current file
  MainForm.UpdateAppTitle;

  // Set classbrowser to current file
  MainForm.ClassBrowser.CurrentFile := fFileName;

  // Set compiler selector to current file
  MainForm.UpdateCompilerList;

  // Update status bar
  MainForm.SetStatusbarLineCol;

  // Update bookmark menu
  for i := 1 to 9 do
    if fText.GetBookMark(i, x, y) then begin
      MainForm.TogglebookmarksPopItem.Items[i - 1].Checked := true;
      MainForm.TogglebookmarksItem.Items[i - 1].Checked := true;
    end else begin
      MainForm.TogglebookmarksPopItem.Items[i - 1].Checked := false;
      MainForm.TogglebookmarksItem.Items[i - 1].Checked := false;
    end;

  // Update focus of incremental search
  if Assigned(IncrementalForm) and IncrementalForm.Showing then
    IncrementalForm.Editor := fText;
end;

procedure TEditor.EditorStatusChange(Sender: TObject; Changes: TSynStatusChanges);
begin
  // scModified is only fired when the modified state changes
  if scModified in Changes then begin
    if fText.Modified then begin
      UpdateCaption('[*] ' + ExtractFileName(fFileName));
    end else begin
      UpdateCaption(ExtractFileName(fFileName));
    end;
  end;

  // In Delphi's SynEdit scSelection included anything caret related; the
  // LCL's has scCaretX and scCaretY for the caret
  if Changes * [scSelection, scCaretX, scCaretY] <> [] then begin
    MainForm.SetStatusbarLineCol;

    // Finish symbol completion
    if fParenthCompleteState = scsInserted then
      fParenthCompleteState := scsFinished;
    if fArrayCompleteState = scsInserted then
      fArrayCompleteState := scsFinished;
    if fBraceCompleteState = scsInserted then
      fBraceCompleteState := scsFinished;

    // Update the function tip
    fFunctionTip.ForceHide := false;
    if Assigned(fFunctionTipTimer) then begin
      if fFunctionTip.Activated and FunctionTipAllowed then
        fFunctionTip.Show
      else begin // Reset the timer
        fFunctionTipTimer.Enabled := false;
        fFunctionTipTimer.Enabled := true;
      end;
    end;

    // Remove error line colors once the caret leaves the error (typing moves it too)
    if (fErrorLine <> -1) and ((fText.CaretX <> fErrorCaret.X) or (fText.CaretY <> fErrorCaret.Y)) then begin
      fText.InvalidateLine(fErrorLine);
      fText.InvalidateGutterLine(fErrorLine);
      fErrorLine := -1;
    end;
  end;

  if scInsertMode in Changes then begin
    with MainForm.Statusbar do begin
      // Set readonly / insert / overwrite
      if fText.ReadOnly then
        Panels[1].Text := Lang[ID_READONLY]
      else if fText.InsertMode then
        Panels[1].Text := Lang[ID_INSERT]
      else
        Panels[1].Text := Lang[ID_OVERWRITE];
    end;
  end;
end;

function TEditor.FunctionTipAllowed: boolean;
begin
  Result :=
    not fText.IsScrolling and // don't update when scrolling
  fText.Focused and // don't update other editors
  not fText.SelAvail and // don't update when a selection is available
  devEditor.ShowFunctionTip and // only update when option is enabled
  Assigned(fText.Highlighter) and // don't update in plaintext files
  not fFunctionTip.ForceHide; // don't update when user force hides it using ESC
end;

procedure TEditor.FunctionTipTimer(Sender: TObject);
begin
  if FunctionTipAllowed then
    fFunctionTip.Show;
end;

procedure TEditor.ExportToHTML;
var
  SynExporterHTML: TSynExporterHTML;
  SaveFileName: String;
begin
  SynExporterHTML := TSynExporterHTML.Create(nil);
  try
    with TSaveDialog.Create(nil) do try
      Filter := SynExporterHTML.DefaultFilter;
      Title := Lang[ID_NV_EXPORT];
      DefaultExt := HTML_EXT;
      Options := Options + [ofOverwritePrompt];
      FileName := ChangeFileExt(ExtractFileName(fFileName), HTML_EXT);
      InitialDir := ExtractFilePath(fFileName);


      if Execute then
        SaveFileName := FileName
      else
        Exit; // automatically gotos finally
    finally
      Free;
    end;

    SynExporterHTML.Title := ExtractFileName(SaveFileName);
    SynExporterHTML.Options := SynExporterHTML.Options - [heoFragmentOnly]; // a whole page
    SynExporterHTML.ExportAsText := True;
    SynExporterHTML.UseBackground := True;
    SynExporterHTML.Font := fText.Font;
    SynExporterHTML.Highlighter := fText.Highlighter;

    SynExporterHTML.ExportAll(fText.Lines);
    SynExporterHTML.SaveToFile(SaveFileName);
  finally
    SynExporterHTML.Free;
  end;
end;

// Asks where to save an export; '' when the user cancels
function AskExportFileName(const SourceFile, AExt, AFilter: String): String;
begin
  Result := '';
  with TSaveDialog.Create(nil) do try
    Filter := AFilter;
    Title := Lang[ID_NV_EXPORT];
    DefaultExt := AExt;
    Options := Options + [ofOverwritePrompt];
    FileName := ChangeFileExt(ExtractFileName(SourceFile), AExt);
    InitialDir := ExtractFilePath(SourceFile);
    if Execute then
      Result := FileName;
  finally
    Free;
  end;
end;

// RTF and TeX: Lazarus' SynEdit has no exporters for them (see CodeExport)
procedure TEditor.ExportToRTF;
var
  SaveFileName: String;
  Options: TExportOptions;
begin
  SaveFileName := AskExportFileName(fFileName, RTF_EXT, 'Rich Text Format (*.rtf)|*.rtf');
  if SaveFileName = '' then
    Exit;
  Options.Title := ExtractFileName(fFileName);
  Options.FontName := fText.Font.Name;
  Options.FontSize := Max(6, devEditor.Font.Size); // the editor's Font.Size may be 0, "default"
  Options.TabWidth := devEditor.TabSize;
  ExportRTF(CollectSource(SourceOfEditor(fText), True, True, False, Options.TextRGB, Options.BackRGB),
    Options, SaveFileName);
end;

procedure TEditor.ExportToTEX;
var
  SaveFileName: String;
  Options: TExportOptions;
begin
  SaveFileName := AskExportFileName(fFileName, TEX_EXT, 'TeX (*.tex)|*.tex');
  if SaveFileName = '' then
    Exit;
  Options.Title := ExtractFileName(fFileName);
  Options.FontName := fText.Font.Name;
  Options.FontSize := Max(6, devEditor.Font.Size); // the editor's Font.Size may be 0, "default"
  Options.TabWidth := devEditor.TabSize;
  ExportTeX(CollectSource(SourceOfEditor(fText), True, True, False, Options.TextRGB, Options.BackRGB),
    Options, SaveFileName);
end;

procedure TEditor.GotoLine;
begin
  with TGotoLineForm.Create(nil) do try
    if ShowModal = mrOK then
      SetCaretPosAndActivate(Line.Value, 1);
  finally
    Free;
  end;
end;

procedure TEditor.InsertString(Value: String; MoveCursor: boolean);
var
  NewCursorPos: TBufferCoord;
  Char, Line, I: integer;
  P: PChar;
begin
  // prevent lots of repaints
  fText.BeginUpdate;
  try
    NewCursorPos := fText.CaretXY;
    if MoveCursor then begin
      P := PChar(value);
      Char := fText.CaretX;
      Line := fText.CaretY;
      I := 0;
      while P[I] <> #0 do begin

        // Assume DOS newlines
        if (P[I] = #13) and (P[I + 1] = #10) then begin
          Inc(I, 2);
          Inc(Line);
          Char := 1;
        end else if (P[I] = '*') and (P[I + 1] = '|') and (P[I + 2] = '*') then begin
          NewCursorPos.Char := Char;
          NewCursorPos.Line := Line;
          Delete(value, I + 1, 3);
          break;
        end else begin
          Inc(Char);
          Inc(I);
        end;
      end;
    end;
    fText.SelText := value;

    // Update the cursor
    fText.CaretXY := NewCursorPos;

    // prevent lots of repaints
  finally
    fText.EndUpdate;
  end;
end;

procedure TEditor.SetErrorFocus(Col, Line: integer);
begin
  // Disable previous error focus
  if (fErrorLine <> -1) then begin
    fText.InvalidateGutterLine(fErrorLine);
    fText.InvalidateLine(fErrorLine);
  end;

  fErrorLine := -1;

  // Set new error focus; the line is marked after the caret moved there
  SetCaretPosAndActivate(Line, col);
  fErrorLine := Line;
  fErrorCaret := Point(fText.CaretX, fText.CaretY);

  // Redraw new error line
  fText.InvalidateGutterLine(fErrorLine);
  fText.InvalidateLine(fErrorLine);
end;

procedure TEditor.GotoActiveBreakpoint;
begin
  if fActiveLine <> -1 then
    SetCaretPosAndActivate(fActiveLine, 1);
end;

procedure TEditor.SetActiveBreakpointFocus(Line: integer);
begin
  if Line <> fActiveLine then begin

    // Disable previous active focus
    if fActiveLine <> -1 then begin
      fText.InvalidateGutterLine(fActiveLine);
      fText.InvalidateLine(fActiveLine);
    end;

    // Put the caret at the active breakpoint
    fActiveLine := Line;
    SetCaretPosAndActivate(fActiveLine, 1);

    // Invalidate new active line
    fText.InvalidateGutterLine(fActiveLine);
    fText.InvalidateLine(fActiveLine);
  end;
end;

procedure TEditor.RemoveBreakpointFocus;
begin
  if fActiveLine <> -1 then begin
    fText.InvalidateLine(fActiveLine);
    fText.InvalidateGutterLine(fActiveLine);
    fActiveLine := -1;
  end;
end;

procedure TEditor.UpdateCaption(const NewCaption: String);
begin
  if Assigned(fTabSheet) then begin
    if NewCaption <> fTabSheet.Caption then begin
      fTabSheet.Caption := NewCaption + CTAB_PADDING;
    end;
  end;
end;

// Before saving: switch legacy-encoded files to UTF-8 when they now contain
// characters beyond ASCII, as configured (never / ask / automatically / always)
procedure TEditor.UpdateEncoding(const FileName: string);
begin
  if (fEncoding = EncodingUTF8) or (fEncoding = EncodingUTF8BOM) or (fEncodingCorrection = sceNever) then
    Exit;
  if fEncodingCorrection = sceFixedUTF8 then
    fEncoding := EncodingUTF8
  else if HasNonASCII(fText.Lines.Text) then
    if (fEncodingCorrection = sceAuto) or
      (MessageDlg(Format(Lang[ID_MSG_FILESAVEENCODING], [FileName]), mtConfirmation, [mbYes, mbNo], 0) = mrYes) then
      fEncoding := EncodingUTF8;
end;

procedure TEditor.SetFileName(const value: String);
begin
  if value <> fFileName then begin
    fFileName := value;
    UpdateCaption(ExtractFileName(fFileName));
  end;
end;

procedure TEditor.InsertDefaultText;
var
  tmp: TStrings;
begin
  if devEditor.DefaultCode and FileExists(devDirs.Config + DEV_DEFAULTCODE_FILE) then begin
    tmp := TStringList.Create;
    try
      tmp.LoadFromFile(devDirs.Config + DEV_DEFAULTCODE_FILE);
      InsertString(ParseMacros(tmp.Text), false);
    finally
      tmp.Free;
    end;
  end;
end;

procedure TEditor.SetCaretPosAndActivate(Line, Col: integer);
begin
  // Lines from the compiler, gdb or the parser may be past the end of a file
  // that changed since
  Line := Max(1, Min(Line, fText.Lines.Count));
  Col := Max(1, Col);

  // Open up the closed folds around the focused line until we can see the line we're looking for
  fText.UncollapseAroundLine(Line);

  // fText needs to be focused for TopLine and LinesInWindow to be correct
  if not fText.Focused then
    Self.Activate;

  // Position the caret, call EnsureCursorPosVisibleEx after setting block
  fText.SetCaretXYCentered(True,BufferCoord(Col, Line));
end;

procedure TEditor.CompletionKeyPress(Sender: TObject; var Key: Char);
begin
  // We received a key from the completion box...
  if fCompletionBox.Enabled then begin
    if fText.IsIdentChar(Key) then begin // Continue filtering
      fText.SelText := Key;
      fCompletionBox.Search(GetWordAtPosition(fText.CaretXY, wpCompletion), fFileName);
    end else if Key = Char(VK_BACK) then begin
      fText.ExecuteCommand(ecDeleteLastChar, #0, nil); // Simulate backspace in editor
      fCompletionBox.Search(GetWordAtPosition(fText.CaretXY, wpCompletion), fFileName);
    end else if Key = Char(VK_ESCAPE) then begin
      fCompletionBox.Hide;
    end else if CharInSet(Key, [Char(VK_RETURN), '(']) then begin // Ending chars, don't insert
      CompletionInsert('');
      fCompletionBox.Hide;
    end else begin
      CompletionInsert(Key);
      fCompletionBox.Hide;
    end;
  end;
end;

procedure TEditor.HandleSymbolCompletion(var Key: Char);
var
  Attr: TSynHighlighterAttributes;
  Token: String;
  HighlightPos: TBufferCoord;

  procedure HandleParentheseCompletion;
  begin
    InsertString(')', false);
    if FunctionTipAllowed then
      fFunctionTip.Activated := true;
    fParenthCompleteState := scsInserted;
  end;

  procedure HandleParentheseSkip;
  begin
    if fParenthCompleteState = scsFinished then begin
      fText.CaretXY := BufferCoord(fText.CaretX + 1, fText.CaretY); // skip over
      fParenthCompleteState := scsSkipped;
      Key := #0; // remove key press
    end;
  end;

  procedure HandleArrayCompletion;
  begin
    InsertString(']', false);
    fArrayCompleteState := scsInserted;
  end;

  procedure HandleArraySkip;
  begin
    if fArrayCompleteState = scsFinished then begin
      fText.CaretXY := BufferCoord(fText.CaretX + 1, fText.CaretY); // skip over
      fArrayCompleteState := scsSkipped;
      Key := #0; // remove key press
    end;
  end;

  procedure HandleMultilineCommentCompletion;
  begin
    if (fText.CaretX > 1) and (fText.LineText[fText.CaretX - 1] = '/') then
      InsertString('*/', false);
  end;

  procedure HandleBraceCompletion;
  var
    LineBeforeCaret, Indent, MoreIndent: String;
    IndentCount, TabCount: integer;
  begin
    // Determine what word is before us
    LineBeforeCaret := Trim(Copy(fText.LineText, 1, fText.CaretX - 1));

    // Determine current indent
    IndentCount := fText.LeftSpaces(fText.LineText);

    // Get indentation string
    if eoTabsToSpaces in fText.Options then
      Indent := System.StringOfChar(#32, IndentCount)
    else begin
      // Use tabs as much as possible, add remaining indent using spaces
      TabCount := IndentCount div fText.TabWidth;
      Indent := System.StringOfChar(#9, TabCount) + System.StringOfChar(#32, IndentCount - fText.TabWidth * TabCount);
    end;

    // For case, do the following:
    //{ + enter + indent + tab + break; + enter + }
    if StartsStr('case', LineBeforeCaret) or
      StartsStr('default', LineBeforeCaret) then begin

      // Get extra indentation string
      if eoTabsToSpaces in fText.Options then
        MoreIndent := System.StringOfChar(#32, IndentCount + fText.TabWidth)
      else
        MoreIndent := System.StringOfChar(#9, (IndentCount + fText.TabWidth) div fText.TabWidth);

      InsertString('{' + #13#10 + MoreIndent + 'break;' + #13#10 + Indent + '}', false);
      fText.CaretXY := BufferCoord(fText.CaretX + 1, fText.CaretY);
      Key := #0; // cancel original key insertion

      // For other valid block starts, do the following:
      // { + enter + indent + }
    end else if EndsStr(')', LineBeforeCaret) or
      SameStr('', LineBeforeCaret) or
      EndsStr('else', LineBeforeCaret) or
      EndsStr('try', LineBeforeCaret) or
      EndsStr('catch', LineBeforeCaret) or
      StartsStr('namespace', LineBeforeCaret) or
      EndsStr('do', LineBeforeCaret) then begin

      InsertString('{' + #13#10 + Indent + '}', false);
      fText.CaretXY := BufferCoord(fText.CaretX + 1, fText.CaretY);
      Key := #0; // cancel original key insertion

      // For structs and derivatives, do the following:
      // { + enter + indent + }; <-- SAME EXCEPT FOR THE SEMICOLON
    end else if
      StartsStr('struct', LineBeforeCaret) or
      StartsStr('union', LineBeforeCaret) or
      StartsStr('class', LineBeforeCaret) or
      StartsStr('enum', LineBeforeCaret) or
      StartsStr('typedef ', LineBeforeCaret) then begin

      InsertString('{' + #13#10 + Indent + '};', false);
      fText.CaretXY := BufferCoord(fText.CaretX + 1, fText.CaretY);
      Key := #0; // cancel original key insertion
    end else begin
      InsertString('}', false);
      fBraceCompleteState := scsInserted;
    end;
  end;

  procedure HandleBraceSkip;
  begin
    if fBraceCompleteState = scsFinished then begin
      fText.CaretXY := BufferCoord(fText.CaretX + 1, fText.CaretY); // skip over
      fBraceCompleteState := scsSkipped;
      Key := #0; // remove key press
    end;
  end;

  procedure HandleLocalIncludeCompletion;
  begin
    if StartsStr('#include', fText.LineText) then begin
      InsertString('"', false);
      fText.CaretXY := BufferCoord(fText.CaretX + 1, fText.CaretY); // skip over
      Key := #0;
    end;
  end;

  procedure HandleGlobalIncludeCompletion;
  begin
    if StartsStr('#include', fText.LineText) then
      InsertString('>', false);
  end;

  procedure HandleSingleQuoteCompletion;
  begin
    InsertString('''', false);
    //fSingleQuoteCompleteState := scsTyped;
  end;

  procedure HandleDoubleQuoteCompletion;
  begin
    InsertString('"', false);
    //fDoubleQuoteCompleteState := scsTyped;
  end;

begin
  if not devEditor.CompleteSymbols or fText.SelAvail then
    Exit;

  // Find the end of the first nonblank line above us
  HighlightPos := BufferCoord(fText.CaretX - 1, fText.CaretY);
  while (HighlightPos.Line > 1) and (Length(fText.Lines[HighlightPos.Line - 1]) = 0) do // not past line 1
    Dec(HighlightPos.Line);
  HighlightPos.Char := Length(fText.Lines[HighlightPos.Line - 1]);

  // Check if that line is highlighted as string or character or comment
  if fText.GetHighlighterAttriAtRowCol(HighlightPos, Token, Attr) then
    if (Attr = fText.Highlighter.StringAttribute) or (Attr = fText.Highlighter.CommentAttribute) or SameStr(Attr.Name,
      'Character') then
      Exit;

  case Key of
    '(': begin
        if devEditor.ParentheseComplete then
          HandleParentheseCompletion;
      end;
    ')': begin
        if devEditor.ParentheseComplete then
          HandleParentheseSkip;
      end;
    '[': begin
        if devEditor.ArrayComplete then
          HandleArrayCompletion;
      end;
    ']': begin
        if devEditor.ParentheseComplete then
          HandleArraySkip;
      end;
    '*': begin
        if devEditor.CommentComplete then
          HandleMultilineCommentCompletion;
      end;
    '{': begin
        if devEditor.BraceComplete then
          HandleBraceCompletion;
      end;
    '}': begin
        if devEditor.BraceComplete then
          HandleBraceSkip;
      end;
    '<': begin
        if devEditor.IncludeComplete then // include <>
          HandleGlobalIncludeCompletion;
      end;
    '''': begin
        if devEditor.SingleQuoteComplete then // characters
          HandleSingleQuoteCompletion;
      end;
    '"': begin
        if devEditor.IncludeComplete then // include ""
          HandleLocalIncludeCompletion;
        if devEditor.DoubleQuoteComplete then // strings
          HandleDoubleQuoteCompletion;
      end;
  else begin
      fParenthCompleteState := scsSkipped;
      fArrayCompleteState := scsSkipped;
      fBraceCompleteState := scsSkipped;
      //fSingleQuoteCompleteState := scsSkipped;
      //fDoubleQuoteCompleteState := scsSkipped;
    end;
  end;
end;

procedure TEditor.HandleCodeCompletion(var Key: Char);
begin
  if fCompletionBox.Enabled then begin

    // Use a timer to show the completion window when we just typed a few parent-member linking chars
    case Key of
      '.': fCompletionTimer.Enabled := True;
      '>': if (fText.CaretX > 1) and (Length(fText.LineText) > 1) and (fText.LineText[fText.CaretX - 1] = '-') then
          fCompletionTimer.Enabled := True;
      ':': if (fText.CaretX > 1) and (Length(fText.LineText) > 1) and (fText.LineText[fText.CaretX - 1] = ':') then
          fCompletionTimer.Enabled := True;
    else
      fCompletionTimer.Enabled := False;
    end;

    // Stop code completion timer if the cursor moves
    fCompletionInitialPosition := BufferCoord(fText.CaretX + 1, fText.CaretY);
  end;
end;

procedure TEditor.EditorKeyPress(Sender: TObject; var Key: Char);
begin
  // Don't offer completion functions for plain text files
  if not Assigned(fText.Highlighter) then
    Exit;

  // Doing this here instead of in EditorKeyDown to be able to delete some key messages
  HandleSymbolCompletion(Key);

  // Spawn code completion window if we are allowed to
  HandleCodeCompletion(Key);
end;

procedure TEditor.EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  p: TBufferCoord;
  DeletedChar, NextChar: Char;
  S: String;
  Reason: THandPointReason;

  procedure UndoSymbolCompletion;
  begin
    if devEditor.DeleteSymbolPairs then begin
      if (devEditor.ArrayComplete and (DeletedChar = '[') and (NextChar = ']')) or
        (devEditor.ParentheseComplete and (DeletedChar = '(') and (NextChar = ')')) or
        (devEditor.BraceComplete and (DeletedChar = '{') and (NextChar = '}')) or
        (devEditor.SingleQuoteComplete and (DeletedChar = '''') and (NextChar = '''')) or
        (devEditor.DoubleQuoteComplete and (DeletedChar = '"') and (NextChar = '"')) then begin
        fText.LineText := Copy(S, 1, fText.CaretX - 1) + Copy(S, fText.CaretX + 1, MaxInt);
      end;
    end;
  end;
begin
  // Ctrl + '+' and Ctrl + '-' (main keyboard or keypad) zoom, like the wheel
  if (Shift * [ssCtrl, ssAlt] = [ssCtrl]) and (Key in [VK_ADD, VK_OEM_PLUS, VK_SUBTRACT, VK_OEM_MINUS]) then begin
    if Key in [VK_ADD, VK_OEM_PLUS] then
      MainForm.ZoomEditors(120)
    else
      MainForm.ZoomEditors(-120);
    Key := 0;
    Exit;
  end;

  // Don't offer completion functions for plain text files
  if not Assigned(fText.Highlighter) then
    Exit;

  // See if we can undo what has been inserted by HandleSymbolCompletion
  case (Key) of
    VK_CONTROL: begin
        Reason := HandpointAllowed(p, Shift);
        if Reason <> hprNone then
          fText.Cursor := crHandPoint
        else
          fText.Cursor := crIBeam;
      end;
    VK_ESCAPE: begin // Update function tip
        if ttoHideOnEsc in fFunctionTip.Options then begin
          fFunctionTip.ReleaseHandle;
          fFunctionTip.ForceHide := true;
        end;
      end;
    VK_DELETE: begin // remove completed character
        if not fText.SelAvail then begin
          S := fText.LineText;
          if fText.CaretX < Length(S) then begin
            DeletedChar := S[fText.CaretX];
            NextChar := S[fText.CaretX + 1];
            UndoSymbolCompletion;
          end;
        end;
      end;
    VK_BACK: begin // remove completed character
        if not fText.SelAvail then begin
          S := fText.LineText;
          if (fText.CaretX > 1) and (fText.CaretX <= Length(S)) then begin
            DeletedChar := S[fText.CaretX - 1];
            NextChar := S[fText.CaretX];
            UndoSymbolCompletion;
          end;
        end;
      end;
  end;
end;

procedure TEditor.EditorKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_CONTROL) then
    fText.Cursor := crIBeam;
end;

procedure TEditor.CompletionTimer(Sender: TObject);
begin
  // Don't show the completion box if the cursor has moved during the timer rundown
  if (fText.CaretX <> fCompletionInitialPosition.Char) or
    (fText.CaretY <> fCompletionInitialPosition.Line) then
    Exit;

  ShowCompletion;
end;

procedure TEditor.InitCompletion;
begin
  fCompletionBox := MainForm.CodeCompletion;
  fCompletionBox.Enabled := devCodeCompletion.Enabled;
  fCompletionBox.Color := devCodeCompletion.BackColor;

  if devEditor.ShowFunctionTip then begin
    if not Assigned(fFunctionTipTimer) then
      fFunctionTipTimer := TTimer.Create(nil);
    fFunctionTipTimer.Enabled := True;
    fFunctionTipTimer.OnTimer := FunctionTipTimer;
    fFunctionTipTimer.Interval := 1000;
  end else begin
    fFunctionTip.ReleaseHandle; // hide
    FreeAndNil(fFunctionTipTimer); // remove timer, because we only have a limited number avaiable
  end;

  // The other stuff is fully completion dependant
  if fCompletionBox.Enabled then begin
    fCompletionBox.Width := devCodeCompletion.Width;
    fCompletionBox.Height := devCodeCompletion.Height;

    if not Assigned(fCompletionTimer) then
      fCompletionTimer := TTimer.Create(nil);
    fCompletionTimer.Enabled := False;
    fCompletionTimer.OnTimer := CompletionTimer;
    fCompletionTimer.Interval := devCodeCompletion.Delay;
  end else begin
    FreeAndNil(fCompletionTimer);
  end;
end;

procedure TEditor.ShowCompletion;
var
  P: TPoint;
  M: TMemoryStream;
  s: String;
  attr: TSynHighlighterAttributes;
begin
  fCompletionTimer.Enabled := False;

  // Position it at the top of the next line
  P := fText.RowColumnToPixels(fText.DisplayXY);
  Inc(P.Y, fText.LineHeight + 2);
  fCompletionBox.Position := fText.ClientToScreen(P);

  // Only scan when cursor is placed after a symbol, inside a word, or inside whitespace
  if (fText.GetHighlighterAttriAtRowCol(BufferCoord(fText.CaretX - 1, fText.CaretY), s, attr)) then
    if (attr <> fText.Highlighter.SymbolAttribute) and
      (attr <> fText.Highlighter.WhitespaceAttribute) and
      (attr <> fText.Highlighter.IdentifierAttribute) then
      Exit;

  M := TMemoryStream.Create;
  try
    fText.Lines.SaveToStream(M);

    // Reparse whole file (not function bodies) if it has been modified
    // use stream, don't read from disk (not saved yet)
    if fText.Modified then begin
      MainForm.CppParser.ParseFile(fFileName, InProject, False, True, M);
    end;

    // Scan the current function body
    fCompletionBox.CurrentStatement := MainForm.CppParser.FindAndScanBlockAt(fFileName, fText.CaretY, M);
  finally
    M.Free;
  end;

  // Redirect key presses to completion box if applicable
  fCompletionBox.OnKeyPress := CompletionKeyPress;

  // Filter the whole statement list
  fCompletionBox.Search(GetWordAtPosition(fText.CaretXY, wpCompletion), fFileName);
end;

procedure TEditor.DestroyCompletion;
begin
  FreeAndNil(fCompletionTimer);
  FreeAndNil(fFunctionTipTimer);
end;

function TEditor.GetWordAtPosition(P: TBufferCoord; Purpose: TWordPurpose): String;
var
  WordBegin, WordEnd, ParamBegin, ParamEnd, len: integer;
  s: String;
begin
  result := '';
  if (p.Line >= 1) and (p.Line <= fText.Lines.Count) then begin
    s := fText.Lines[p.Line - 1];
    len := Length(s);

    WordBegin := p.Char - 1;
    WordEnd := p.Char - 1;

    // Copy forward until end of word
    if Purpose in [wpEvaluation, wpInformation] then begin
      while (WordEnd + 1 <= len) do begin
        if (Purpose = wpEvaluation) and (s[WordEnd + 1] = '[') then begin
          if not FindComplement(s, '[', ']', WordEnd, 1) then
            break;
        end else if fText.IsIdentChar(s[WordEnd + 1]) then
          Inc(WordEnd)
        else
          break;
      end;
    end;

    // Copy backward until end of word
    if Purpose in [wpCompletion, wpEvaluation, wpInformation] then begin
      while (WordBegin > 0) and (WordBegin <= len) do begin
        if (s[WordBegin] = ']') then begin
          if not FindComplement(s, ']', '[', WordBegin, -1) then
            break
          else
            Dec(WordBegin); // step over [
        end else if fText.IsIdentChar(s[WordBegin]) then begin
          Dec(WordBegin);
        end else if CharInSet(s[WordBegin], ['.', ':', '~']) then begin // allow destructor signs
          Dec(WordBegin);
        end else if (WordBegin > 1) and (s[WordBegin - 1] = '-') and (s[WordBegin] = '>') then begin
          Dec(WordBegin, 2);
        end else if (WordBegin > 1) and (s[WordBegin] = ')') then begin
          if not FindComplement(s, ')', '(', WordBegin, -1) then
            break
          else
            Dec(WordBegin); // step over (
        end else
          break;
      end;
    end;
  end;

  // Get end result
  Result := Copy(S, WordBegin + 1, WordEnd - WordBegin);

  // Strip function parameters
  while true do begin
    ParamBegin := Pos('(', Result);
    if ParamBegin > 0 then begin
      ParamEnd := ParamBegin;
      if FindComplement(Result, '(', ')', ParamEnd, 1) then begin
        Delete(Result, ParamBegin, ParamEnd - ParamBegin + 1);
      end else
        break;
    end else
      break;
  end;

  // Strip array stuff
  if not (Purpose = wpEvaluation) then
    while true do begin
      ParamBegin := Pos('[', Result);
      if ParamBegin > 0 then begin
        ParamEnd := ParamBegin;
        if FindComplement(Result, '[', ']', ParamEnd, 1) then begin
          Delete(Result, ParamBegin, ParamEnd - ParamBegin + 1);
        end else
          break;
      end else
        break;
    end;
end;

procedure TEditor.CompletionInsert(const append: String);
var
  Statement: PStatement;
  FuncAddOn: String;
  WordEndPos: TBufferCoord;
begin
  Statement := fCompletionBox.SelectedStatement;
  if not Assigned(Statement) then
    Exit;

  // if we are inserting a function,
  WordEndPos := fText.WordEnd;
  if Statement^._Kind in [skFunction, skConstructor, skDestructor] then begin

    // If the argument list is already there, don't add another ()
    if (Length(fText.LineText) = 0) or (WordEndPos.Char > Length(fText.LineText)) or
      (fText.LineText[WordEndPos.Char] <> '(') then begin
      FuncAddOn := '()';
    end else
      FuncAddOn := '';
  end else
    FuncAddOn := '';

  // replace the part of the word that's already been typed
  fText.BlockBegin := fText.WordStart;
  fText.BlockEnd := WordEndPos;
  fText.SelText := Statement^._Command + FuncAddOn + append;

  // Move caret inside the ()'s, only when the user has something to do there...
  if (FuncAddOn <> '') and (Statement^._Args <> '()') and (Statement^._Args <> '(void)') then begin

    fText.CaretX := fText.CaretX - Length(FuncAddOn) - Length(append) + 1;

    // immediately activate function hint
    if devEditor.ShowFunctionTip and Assigned(fText.Highlighter) then begin
      fText.SetFocus;
      fFunctionTip.Show;
    end;
  end;
end;

procedure TEditor.EditorMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  s: String;
  p: TBufferCoord;
  st: PStatement;
  M: TMemoryStream;
  Reason: THandPointReason;
  IsIncludeLine: boolean;

  procedure ShowFileHint;
  var
    FileName: String;
  begin
    FileName := MainForm.CppParser.GetHeaderFileName(fFileName, s);
    if (FileName <> '') and FileExists(FileName) then
      fText.Hint := FileName + ' - Ctrl+Click for more info'
    else
      fText.Hint := '';
  end;

  procedure ShowDebugHint;
  begin
    // Hovering only looks: gdb would run a call, an assignment or ++ in the
    // program (a selection like f() or x = 5); the Evaluate tab still can
    if MayChangeProgram(s) then
      Exit;

    // Add to list
    if devData.WatchHint then
      MainForm.Debugger.AddWatchVar(s);

    // Evaluate s
    fCurrentEvalWord := s; // remember name when debugger finishes
    MainForm.Debugger.CancelHandlers(Self); // only the latest word
    MainForm.Debugger.Evaluate(s, OnMouseOverEvalReady);
  end;

  procedure ShowParserHint;
  begin
    // This piece of code changes the parser database, possibly making hints and code completion invalid...
    M := TMemoryStream.Create;
    try
      fText.Lines.SaveToStream(M);
      st := MainForm.CppParser.FindStatementOf(fFileName, s, p.Line, M);
    finally
      M.Free;
    end;

    if Assigned(st) then begin
      fText.Hint := MainForm.CppParser.PrettyPrintStatement(st) + ' - ' + ExtractFileName(st^._FileName) + ' (' +
        IntToStr(st^._Line) + ') - Ctrl+Click for more info';
      fText.Hint := StringReplace(fText.Hint, '|', #5, [rfReplaceAll]);
      // vertical bar is used to split up short and long hint versions...
    end;
  end;

  procedure CancelHint;
  begin
    MainForm.Debugger.CancelHandlers(Self);

    // disable editor hint
    Application.CancelHint;
    fCurrentWord := '';
    fText.Hint := '';

    // disable page control hint
    MainForm.CurrentPageHint := '';
    fTabSheet.PageControl.Hint := '';
  end;
begin
  // Leverage Ctrl-Clickability to determine if we can show any information
  Reason := HandpointAllowed(p, Shift);

  // Get subject
  IsIncludeLine := False;
  case Reason of
    // When hovering above a preprocessor line, determine if we want to show an include or a identifier hint
    hprPreprocessor: begin
        s := fText.Lines[p.Line - 1];
        IsIncludeLine := MainForm.CppParser.IsIncludeLine(s); // show filename hint
        if not IsIncludeLine then
          s := fText.GetWordAtRowCol(p);
      end;
    hprIdentifier: begin
        if MainForm.Debugger.Executing then
          s := GetWordAtPosition(p, wpEvaluation) // debugging
        else if devEditor.ParserHints and not fCompletionBox.Visible then
          s := GetWordAtPosition(p, wpInformation) // information during coding
        else
          s := '';
      end;
    hprSelection: begin
        s := fText.SelText; // when a selection is available, always only use that
      end;
    hprNone: begin
        fText.Cursor := crIBeam; // nope
        CancelHint;
      end;
  end;

  // Don't rescan the same stuff over and over again (that's slow)
  if s = fCurrentWord then
    Exit; // do NOT remove hint when subject stays the same

  // Remove hint
  CancelHint;
  fCurrentWord := s;

  // We are allowed to change the cursor
  if (ssCtrl in Shift) then
    fText.Cursor := crHandPoint
  else
    fText.Cursor := crIBeam;

  // Determine what to do with subject
  case Reason of
    hprPreprocessor: begin
        if IsIncludeLine then
          ShowFileHint
        else if devEditor.ParserHints and not fCompletionBox.Visible then
          ShowParserHint;
      end;
    hprIdentifier, hprSelection: begin
        if MainForm.Debugger.Executing then
          ShowDebugHint
        else if devEditor.ParserHints and not fCompletionBox.Visible then
          ShowParserHint;
      end;
  end;
end;

procedure TEditor.IndentSelection;
begin
  if FText.BlockBegin.Line <> FText.BlockEnd.Line then
    fText.ExecuteCommand(ecBlockIndent, #0, nil)
  else
    fText.ExecuteCommand(ecTab, #0, nil);
end;

procedure TEditor.UnindentSelection;
begin
  if fText.BlockBegin.Line <> fText.BlockEnd.Line then
    fText.ExecuteCommand(ecBlockUnIndent, #0, nil)
  else
    fText.ExecuteCommand(ecShiftTab, #0, nil);
end;

procedure TEditor.EditorMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  p: TDisplayCoord;
  line, FileName: String;
  e: TEditor;
begin
  // if ctrl+clicked
  if (ssCtrl in Shift) and (Button = mbLeft) and not fText.SelAvail then begin

    p := fText.PixelsToRowColumn(X, Y);
    if P.Row <= fText.Lines.Count then begin

      // reset the cursor
      fText.Cursor := crIBeam;

      // Try to open the header
      line := fText.Lines[p.Row - 1];
      if MainForm.CppParser.IsIncludeLine(Line) then begin
        FileName := MainForm.CppParser.GetHeaderFileName(fFileName, line);
        e := MainForm.EditorList.GetEditorFromFileName(FileName);
        if Assigned(e) then begin
          e.SetCaretPosAndActivate(1, 1);
        end;
      end else
        MainForm.actGotoImplDeclEditorExecute(self);
    end;
  end;
end;

function TEditor.HandpointAllowed(var MousePos: TBufferCoord; ShiftState: TShiftState): THandPointReason;
var
  s: String;
  HLAttr: TSynHighlighterAttributes;
begin
  Result := hprNone;

  // Only allow in the text area...
  if fText.GetPositionOfMouse(mousepos) then begin

    // Only allow hand points in highlighted areas
    if fText.GetHighlighterAttriAtRowCol(mousepos, s, HLAttr) then begin

      // Only allow Identifiers, Preprocessor directives, and selection
      if Assigned(HLAttr) then begin
        if fText.SelAvail then begin
          // do not allow when dragging selection
          if fText.InSelection(MousePos) and not (ssLeft in ShiftState) then
            Result := hprSelection; // allow selection
        end else if HLAttr.Name = 'Identifier' then
          Result := hprIdentifier // allow identifiers if no selection is present
        else if HLAttr.Name = 'Preprocessor' then
          Result := hprPreprocessor; // and preprocessor line if no selection is present
      end;
    end;
  end;
end;

function TEditor.Save: boolean;
begin
  Result := True;

  // We will be changing files. Stop monitoring
  MainForm.FileMonitor.BeginUpdate;
  try
    // Is this file read-only?
    if FileExists(fFileName) and (FileGetAttr(fFileName) and faReadOnly <> 0) then begin

      // Yes, ask the user if he wants us to fix that
      if MessageDlg(Format(Lang[ID_MSG_FILEISREADONLY], [fFileName]), mtConfirmation, [mbYes, mbNo], 0) = mrNo then
        Exit;

      // Yes, remove read-only attribute
      if FileSetAttr(fFileName, FileGetAttr(fFileName) and not faReadOnly) <> 0 then begin
        MessageDlg(Format(Lang[ID_MSG_FILEREADONLYERROR], [fFileName]), mtError, [mbOk], 0);
        Exit;
      end;
    end;

    // Filename already present? Save without dialog
    if (not fNew) and fText.Modified then begin

      // Save contents directly
      try
        UpdateEncoding(fFileName);
        WriteTextFile(fFileName, fText.Lines.Text, fEncoding);
        fText.Modified := false;
      except
        MessageDlg(Format(Lang[ID_ERR_SAVEFILE], [fFileName]), mtError, [mbOk], 0);
        Result := False;
      end;

      MainForm.CppParser.ParseFile(fFileName, InProject);
    end else if fNew then
      Result := SaveAs; // we need a file name, use dialog

  finally
    MainForm.FileMonitor.EndUpdate;
  end;
end;

function TEditor.SaveAs: boolean;
var
  UnitIndex: integer;
  SaveFileName: String;
begin
  Result := True;
  with TSaveDialog.Create(nil) do try
    Title := Lang[ID_NV_SAVEAS];
    Filter := BuildFilter([FLT_CS, FLT_CPPS, FLT_HEADS]);
    Options := Options + [ofOverwritePrompt];

    // select appropriate filter
    if GetFileTyp(fFileName) in [utcHead, utcppHead] then begin
      FilterIndex := 4; // .h
      DefaultExt := 'h';
    end else begin
      if Assigned(MainForm.Project) and fInProject then begin
        if MainForm.Project.Options.useGPP then begin
          FilterIndex := 3; // .cpp
          DefaultExt := 'cpp';
        end else begin
          FilterIndex := 2; // .c
          DefaultExt := 'c';
        end;
      end else begin
        FilterIndex := 3; // .cpp
        DefaultExt := 'cpp';
      end;
    end;

    // Set save box options
    FileName := ExtractFileName(fFileName);
    if (fFileName <> '') then
      InitialDir := ExtractFilePath(fFileName)
    else if Assigned(MainForm.Project) then
      InitialDir := MainForm.Project.Directory;

    // Open the save box
    if Execute then
      SaveFileName := FileName // prevent collision between TEditor.FileName and Dialog.FileName
    else begin
      Result := False;
      Exit;
    end;
  finally
    Free;
  end;

  // Remove *old* file from statement list
  MainForm.CppParser.InvalidateFile(FileName);

  // Try to save to disk
  try
    UpdateEncoding(SaveFileName);
    WriteTextFile(SaveFileName, fText.Lines.Text, fEncoding);
    fText.Modified := False;
    fNew := False;
  except
    MessageDlg(Format(Lang[ID_ERR_SAVEFILE], [SaveFileName]), mtError, [mbOk], 0);
    Result := False;
  end;

  // Update highlighter
  devEditor.AssignEditor(fText, SaveFileName);

  // Update project information
  if Assigned(MainForm.Project) and Self.InProject then begin
    UnitIndex := MainForm.Project.Units.IndexOf(FileName); // index of *old* filename
    if UnitIndex <> -1 then
      MainForm.Project.SaveUnitAs(UnitIndex, SaveFileName); // save as new filename
  end else
    fTabSheet.Caption := ExtractFileName(SaveFileName) + CTAB_PADDING;

  // Update window captions
  MainForm.UpdateAppTitle;

  // Update class browser, redraw once
  MainForm.ClassBrowser.BeginUpdate;
  try
    MainForm.CppParser.ParseFile(SaveFileName, InProject);
    MainForm.ClassBrowser.CurrentFile := SaveFileName;
  finally
    MainForm.ClassBrowser.EndUpdate;
  end;

  // Set new file name
  FileName := SaveFileName;
end;


{ TSynEditPrintHelper }

{ TSynEditEx }

constructor TSynEditEx.Create(AOwner: TComponent);
var
  DeleteLineIndex: Integer;
begin
  inherited Create(AOwner);
  FeoAddIndent := False;

  DeleteLineIndex := Keystrokes.FindCommand(ecDeleteLine);
  if DeleteLineIndex <> -1 then
    Keystrokes.Delete(DeleteLineIndex);

  DeleteLineIndex := Keystrokes.FindCommand(ecDeleteEOL);
  if DeleteLineIndex <> -1 then
    Keystrokes.Delete(DeleteLineIndex);

  // macOS: Command and Option with the arrows and backspace
  AddMacKeystrokes(Keystrokes);

  // Breakpoints and output line numbers follow every insertion/deletion
  ViewedTextBuffer.AddChangeHandler(senrLineCount, LineCountChanged);
end;

destructor TSynEditEx.Destroy;
begin
  ViewedTextBuffer.RemoveChangeHandler(senrLineCount, LineCountChanged);
  inherited;
end;

procedure TSynEditEx.LineCountChanged(Sender: TSynEditStrings; AIndex, ACount: Integer);
begin
  // AIndex is 0-based; ACount > 0 for inserted lines, < 0 for deleted ones
  if (ACount > 0) and Assigned(FOnLinesInserted) then
    FOnLinesInserted(AIndex + 1, ACount)
  else if (ACount < 0) and Assigned(FOnLinesDeleted) then
    FOnLinesDeleted(AIndex + 1, -ACount);
end;

function TSynEditEx.GetCaretX: Integer;
begin
  Result := LogicalCaretXY.X;
end;

procedure TSynEditEx.SetCaretX(Value: Integer);
begin
  LogicalCaretXY := Point(Value, CaretY);
end;

function TSynEditEx.GetCaretXY: TBufferCoord;
begin
  Result := LogicalCaretXY;
end;

procedure TSynEditEx.SetCaretXY(const Value: TBufferCoord);
begin
  LogicalCaretXY := Value;
end;

function TSynEditEx.GetBlockBegin: TBufferCoord;
begin
  Result := TCustomSynEdit(Self).BlockBegin;
end;

procedure TSynEditEx.SetBlockBegin(const Value: TBufferCoord);
begin
  TCustomSynEdit(Self).BlockBegin := Value;
end;

function TSynEditEx.GetBlockEnd: TBufferCoord;
begin
  Result := TCustomSynEdit(Self).BlockEnd;
end;

procedure TSynEditEx.SetBlockEnd(const Value: TBufferCoord);
begin
  TCustomSynEdit(Self).BlockEnd := Value;
end;

function TSynEditEx.GetDisplayXY: TDisplayCoord;
begin
  Result := TCustomSynEdit(Self).CaretXY; // Lazarus' CaretXY is physical
end;

function TSynEditEx.BufferToDisplayPos(const P: TBufferCoord): TDisplayCoord;
begin
  Result := LogicalToPhysicalPos(P);
end;

function TSynEditEx.DisplayToBufferPos(const P: TDisplayCoord): TBufferCoord;
begin
  Result := PhysicalToLogicalPos(P);
end;

function TSynEditEx.PixelsToRowColumn(X, Y: Integer): TDisplayCoord;
begin
  Result := inherited PixelsToRowColumn(Point(X, Y));
end;

function TSynEditEx.GetPositionOfMouse(out P: TBufferCoord): Boolean;
var
  Pt, Phys: TPoint;
begin
  Pt := ScreenToClient(Mouse.CursorPos);
  Result := PtInRect(ClientRect, Pt) and (Pt.X >= Gutter.Width);
  if not Result then
    Exit;
  Phys := inherited PixelsToRowColumn(Pt);
  Result := (Phys.Y >= 1) and (Phys.Y <= Lines.Count);
  if Result then
    P := PhysicalToLogicalPos(Phys);
end;

function TSynEditEx.WordStart: TBufferCoord;
var
  S: string;
  X: Integer;
begin
  S := LineText;
  X := Min(CaretX, Length(S) + 1);
  while (X > 1) and IsIdentChar(S[X - 1]) do
    Dec(X);
  Result := BufferCoord(X, CaretY);
end;

function TSynEditEx.WordEnd: TBufferCoord;
var
  S: string;
  X: Integer;
begin
  S := LineText;
  X := Max(CaretX, 1);
  while (X <= Length(S)) and IsIdentChar(S[X]) do
    Inc(X);
  Result := BufferCoord(X, CaretY);
end;

function TSynEditEx.GetMatchingBracketEx(const P: TBufferCoord): TBufferCoord;
var
  Found: TPoint;
begin
  Found := FindMatchingBracketLogical(P, False, False, False, False);
  if Found.Y < 1 then
    Found := Point(0, 0); // what the Delphi SynEdit returned
  Result := Found;
end;

function TSynEditEx.LeftSpaces(const Line: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(Line) do
    if Line[I] = #9 then
      Result := (Result div TabWidth + 1) * TabWidth
    else if Line[I] = #32 then
      Inc(Result)
    else
      Break;
end;

function TSynEditEx.InSelection(const P: TBufferCoord): Boolean;
var
  B, E: TBufferCoord;
begin
  // IsPointInSelection is private in Lazarus' SynEdit
  Result := SelAvail;
  if not Result then
    Exit;
  B := BlockBegin;
  E := BlockEnd;
  Result := ((P.Line > B.Line) or ((P.Line = B.Line) and (P.Char >= B.Char))) and
    ((P.Line < E.Line) or ((P.Line = E.Line) and (P.Char < E.Char)));
end;

procedure TSynEditEx.SetCaretAndSel(const ACaret, ABegin, AEnd: TBufferCoord);
begin
  // SetCaretAndSelection is private in Lazarus' SynEdit; the caret goes first
  // because moving it drops the selection
  LogicalCaretXY := ACaret;
  TCustomSynEdit(Self).BlockBegin := ABegin;
  TCustomSynEdit(Self).BlockEnd := AEnd;
end;

function TSynEditEx.SelLength: Integer;
begin
  Result := UTF8Length(SelText);
end;

function TSynEditEx.WordAtCursor: string;
begin
  Result := GetWordAtRowCol(LogicalCaretXY);
end;

function TSynEditEx.IsScrolling: Boolean;
begin
  Result := False; // Lazarus' SynEdit has no scrolling state to query
end;

procedure TSynEditEx.InvalidateGutterLine(Line: Integer);
begin
  InvalidateGutterLines(Line, Line);
end;

// Folds come from the highlighter (TSynCppFoldSyn); the folded view hides
// their lines. TCustomSynEdit's FoldAll and UnfoldAll are deprecated.
procedure TSynEditEx.UncollapseAroundLine(Line: Integer);
begin
  TSynEditFoldedView(FoldedTextBuffer).UnFoldAtTextIndexCollapsed(Line - 1);
end;

procedure TSynEditEx.CollapseAll;
begin
  TSynEditFoldedView(FoldedTextBuffer).FoldAll;
  Invalidate;
end;

procedure TSynEditEx.UncollapseAll;
begin
  TSynEditFoldedView(FoldedTextBuffer).UnfoldAll;
  Invalidate;
end;

procedure TSynEditEx.SetCaretXYCentered(ForceToMiddle: Boolean; const Value: TBufferCoord);
begin
  BeginUpdate;
  try
    LogicalCaretXY := Value;
    TCustomSynEdit(Self).BlockBegin := LogicalCaretXY; // drop the selection
    if ForceToMiddle then
      TopLine := Max(1, CaretY - LinesInWindow div 2)
    else
      EnsureCursorPosVisible;
  finally
    EndUpdate;
  end;
end;

procedure TSynEditEx.CommandProcessor(Command: TSynEditorCommand; AChar: TUTF8Char; Data: pointer;
  ASkipHooks: THookedCommandFlags);
var
  Temp, Indent, CurLine: string;
  BackCounter, I, X, Width: Integer;
  Attr: TSynHighlighterAttributes;
begin
  if FeoAddIndent and (Command = ecLineBreak) and not ReadOnly then begin
    // Remember the last non-empty line above the new one
    Temp := LineText;
    if eoAutoIndent in Options then begin
      BackCounter := CaretY;
      repeat
        Dec(BackCounter);
        Temp := Lines[BackCounter];
      until (BackCounter = 0) or (Temp <> '');
    end;

    inherited CommandProcessor(Command, AChar, Data, ASkipHooks);

    // After { or : (outside comments) indent one more level
    if (Temp <> '') and GetHighlighterAttriAtRowCol(Point(Length(Temp), CaretY - 1), Temp, Attr) then
      if (Attr <> Highlighter.CommentAttribute) and (Temp <> '') and CharInSet(Temp[Length(Temp)], ['{', ':']) then begin
        if eoTabsToSpaces in Options then
          Indent := StringOfChar(' ', TabWidth)
        else
          Indent := #9;
        CurLine := LineText;
        X := 1;
        while (X <= Length(CurLine)) and CharInSet(CurLine[X], [#9, #32]) do
          Inc(X);
        TextBetweenPoints[Point(X, CaretY), Point(X, CaretY)] := Indent;
        LogicalCaretXY := Point(X + Length(Indent), CaretY);
      end;
    Exit;
  end;

  // Typing } as the first character of a line removes one level of indent
  if FeoAddIndent and (Command = ecChar) and (AChar = '}') and not ReadOnly then begin
    CurLine := LineText;
    if Trim(CurLine) = '' then begin
      I := Min(CaretX - 1, Length(CurLine));
      Width := 0;
      while (I > 0) and (Width < TabWidth) do begin
        if CurLine[I] = #9 then
          Inc(Width, TabWidth)
        else if CurLine[I] = #32 then
          Inc(Width)
        else
          Break;
        Dec(I);
      end;
      if I < CaretX - 1 then begin
        TextBetweenPoints[Point(I + 1, CaretY), Point(CaretX, CaretY)] := '';
        LogicalCaretXY := Point(I + 1, CaretY);
      end;
    end;
  end;

  inherited CommandProcessor(Command, AChar, Data, ASkipHooks);
end;

procedure TSynEditEx.ExecuteCommand(Command: TSynEditorCommand; const AChar: TUTF8Char; Data: pointer);
begin
  case Command of
    ecMoveSelDown: MoveLines(True);
    ecMoveSelUp: MoveLines(False);
    ecDuplicateLine: DuplicateLine;
    ecComment: DoComment;
    ecUncomment: DoUnComment;
    ecToggleComment: DoToggleComment;
    ecCommentInline: DoCommentInline;
  else
    inherited ExecuteCommand(Command, AChar, Data);
  end;
end;

// Moves the lines touched by the selection (or the caret line) one line down
// or up. TextBetweenPoints records undo information itself.
procedure TSynEditEx.MoveLines(Down: Boolean);
var
  OrigBegin, OrigEnd, OrigCaret: TBufferCoord;
  First, Last, Delta: Integer;
  S: string;
begin
  if ReadOnly or (Lines.Count = 0) then
    Exit;
  OrigBegin := BlockBegin;
  OrigEnd := BlockEnd;
  OrigCaret := CaretXY;
  First := OrigBegin.Line;
  Last := OrigEnd.Line;
  if Down and (Last >= Lines.Count) then
    Exit;
  if not Down and (First <= 1) then
    Exit;

  BeginUndoBlock;
  try
    if Down then begin
      // Take the line below the block and put it above
      S := Lines[Last]; // line Last + 1
      TextBetweenPoints[Point(Length(Lines[Last - 1]) + 1, Last), Point(Length(S) + 1, Last + 1)] := '';
      TextBetweenPoints[Point(1, First), Point(1, First)] := S + LineEnding;
      Delta := 1;
    end else begin
      // Take the line above the block and put it below
      S := Lines[First - 2]; // line First - 1
      TextBetweenPoints[Point(1, First - 1), Point(1, First)] := '';
      TextBetweenPoints[Point(Length(Lines[Last - 2]) + 1, Last - 1),
        Point(Length(Lines[Last - 2]) + 1, Last - 1)] := LineEnding + S;
      Delta := -1;
    end;
    SetCaretAndSel(Point(OrigCaret.Char, OrigCaret.Line + Delta),
      Point(OrigBegin.Char, OrigBegin.Line + Delta), Point(OrigEnd.Char, OrigEnd.Line + Delta));
  finally
    EndUndoBlock;
  end;
end;

procedure TSynEditEx.DuplicateLine;
var
  L: Integer;
  S: string;
begin
  if ReadOnly or (Lines.Count = 0) then
    Exit;
  L := CaretY;
  S := Lines[L - 1];
  TextBetweenPoints[Point(Length(S) + 1, L), Point(Length(S) + 1, L)] := LineEnding + S;
  CaretXY := BufferCoord(1, L); // like seen in the Delphi editor
end;

procedure TSynEditEx.DoComment;
var
  OrigBlockBegin, OrigBlockEnd, OrigCaret: TBufferCoord;
  EndLine, I: integer;
begin
  if ReadOnly then
    Exit;
  OrigBlockBegin := BlockBegin;
  OrigBlockEnd := BlockEnd;
  OrigCaret := CaretXY;

  // Ignore the last line the cursor is placed on
  if OrigBlockEnd.Char = 1 then
    EndLine := max(OrigBlockBegin.Line, OrigBlockEnd.Line - 1)
  else
    EndLine := OrigBlockEnd.Line;

  BeginUndoBlock;
  try
    for I := OrigBlockBegin.Line to EndLine do
      TextBetweenPoints[Point(1, I), Point(1, I)] := '//';
  finally
    EndUndoBlock;
  end;

  // Move selection and caret along with the text
  if OrigBlockBegin.Char > 1 then
    Inc(OrigBlockBegin.Char, 2);
  if OrigBlockEnd.Char > 1 then
    Inc(OrigBlockEnd.Char, 2);
  if OrigCaret.Char > 1 then
    Inc(OrigCaret.Char, 2);
  SetCaretAndSel(OrigCaret, OrigBlockBegin, OrigBlockEnd);
end;

procedure TSynEditEx.DoUnComment;
var
  OrigBlockBegin, OrigBlockEnd, OrigCaret: TBufferCoord;
  EndLine, I, J: integer;
  S: string;
begin
  if ReadOnly then
    Exit;
  OrigBlockBegin := BlockBegin;
  OrigBlockEnd := BlockEnd;
  OrigCaret := CaretXY;

  // Ignore the last line the cursor is placed on
  if OrigBlockEnd.Char = 1 then
    EndLine := max(OrigBlockBegin.Line, OrigBlockEnd.Line - 1)
  else
    EndLine := OrigBlockEnd.Line;

  BeginUndoBlock;
  try
    for I := OrigBlockBegin.Line to EndLine do begin
      S := Lines[I - 1];
      // Find // after blanks only
      J := 1;
      while (J + 1 <= Length(S)) and CharInSet(S[J], [#0..#32]) do
        Inc(J);
      if (J + 1 <= Length(S)) and (S[J] = '/') and (S[J + 1] = '/') then begin
        TextBetweenPoints[Point(J, I), Point(J + 2, I)] := '';
        if (I = OrigBlockBegin.Line) and (OrigBlockBegin.Char > 1) then
          Dec(OrigBlockBegin.Char, 2);
        if (I = OrigBlockEnd.Line) and (OrigBlockEnd.Char > 1) then
          Dec(OrigBlockEnd.Char, 2);
        if (I = OrigCaret.Line) and (OrigCaret.Char > 1) then
          Dec(OrigCaret.Char, 2);
      end;
    end;
  finally
    EndUndoBlock;
  end;
  SetCaretAndSel(OrigCaret, OrigBlockBegin, OrigBlockEnd);
end;

procedure TSynEditEx.DoToggleComment;
var
  BeginIndex, EndIndex, I: Integer;
begin
  if ReadOnly then
    Exit;

  // Ignore the last line the cursor is placed on
  BeginIndex := BlockBegin.Line - 1;
  if BlockEnd.Char = 1 then
    EndIndex := max(0, BlockEnd.Line - 2)
  else
    EndIndex := BlockEnd.Line - 1;

  // if everything is commented, then uncomment
  for I := BeginIndex to EndIndex do
    if Pos('//', TrimLeft(Lines[I])) <> 1 then begin // not fully commented
      DoComment; // comment everything
      Exit;
    end;
  DoUncomment;
end;

procedure TSynEditEx.DoCommentInline;
var
  Temp: string;
  StartPos, EndPos, I: Integer;
  OrigBlockBegin, OrigBlockEnd: TBufferCoord;
begin
  if ReadOnly or not SelAvail then
    Exit;
  Temp := SelText;

  // Check if the selection starts with /* after blanks
  StartPos := -1;
  I := 1;
  while I <= Length(Temp) do begin
    if CharInSet(Temp[I], [#9, #32]) then
      Inc(I)
    else if ((I + 1) <= Length(Temp)) and (Temp[I] = '/') and (Temp[I + 1] = '*') then begin
      StartPos := I;
      Break;
    end else
      Break;
  end;

  // Check if the selection ends with */ before blanks
  EndPos := -1;
  if StartPos <> -1 then begin
    I := Length(Temp);
    while I > 0 do begin
      if CharInSet(Temp[I], [#9, #32]) then
        Dec(I)
      else if ((I - 1) > 0) and (Temp[I] = '/') and (Temp[I - 1] = '*') then begin
        EndPos := I;
        Break;
      end else
        Break;
    end;
  end;

  // Keep selection
  OrigBlockBegin := BlockBegin;
  OrigBlockEnd := BlockEnd;

  // Toggle based on current comment status
  if (StartPos <> -1) and (EndPos <> -1) then begin
    SelText := Copy(Temp, StartPos + 2, EndPos - StartPos - 3);
    BlockBegin := OrigBlockBegin;
    BlockEnd := BufferCoord(OrigBlockEnd.Char - 4, OrigBlockEnd.Line);
  end else begin
    SelText := '/*' + Temp + '*/';
    BlockBegin := OrigBlockBegin;
    BlockEnd := BufferCoord(OrigBlockEnd.Char + 4, OrigBlockEnd.Line);
  end;
end;

end.

