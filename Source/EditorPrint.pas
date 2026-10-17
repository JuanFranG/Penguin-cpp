{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    Takes an editor's text with its highlighter colors and styles for
    printing (see PdfPrint).
}

unit EditorPrint;

{$MODE DELPHI}

interface

uses
  Classes, SysUtils, Graphics, SynEdit, SynEditHighlighter, PdfPrint;

type
  TEditorPrintOptions = record
    Title: String;
    Colors: Boolean; // the scheme's colors and background
    Highlight: Boolean; // bold and italic as in the editor
    WordWrap: Boolean;
    LineNumbers: Boolean;
    LineNumbersInMargin: Boolean;
    SelectionOnly: Boolean;
    TabWidth: Integer;
  end;

  // What is printed: an editor's text, colors and selection
  TPrintSource = record
    Lines: TStrings;
    Highlighter: TSynCustomHighlighter; // nil for plain text
    FontName: String;
    TextColor, BackColor: TColor; // when the highlighter has none
    HasSelection: Boolean;
    SelStart, SelEnd: TPoint; // logical (byte) positions, from 1
  end;

// An editor's text, highlighter, colors and selection
function SourceOfEditor(Editor: TCustomSynEdit): TPrintSource;

// The lines (or the selected part) as runs of one color and style. Without
// Colors every run is black; without Highlight none is bold or italic.
// TextRGB and BackRGB are the colors where the highlighter gives none.
function CollectSource(const Source: TPrintSource; Colors, Highlight, SelectionOnly: Boolean;
  out TextRGB, BackRGB: Cardinal): TPrintLines;

// Writes the editor's text (or its selection) to a PDF; returns the pages
function PrintEditorToPDF(Editor: TCustomSynEdit; const Options: TEditorPrintOptions; const FileName: String): Integer;

// The same, from the editor's data (the tests use it without an editor)
function PrintSourceToPDF(const Source: TPrintSource; const Options: TEditorPrintOptions; const FileName: String): Integer;

implementation

uses
  Math, SynEditTextBuffer;

function ToRGB(Color: TColor): Cardinal;
var
  C: Longint;
begin
  C := ColorToRGB(Color); // $BBGGRR
  Result := ((C and $FF) shl 16) or (C and $FF00) or ((C shr 16) and $FF);
end;

function SourceOfEditor(Editor: TCustomSynEdit): TPrintSource;
begin
  Result.Lines := Editor.Lines;
  Result.Highlighter := Editor.Highlighter;
  Result.FontName := Editor.Font.Name;
  Result.TextColor := Editor.Font.Color;
  Result.BackColor := Editor.Color;
  Result.HasSelection := Editor.SelAvail;
  Result.SelStart := Editor.BlockBegin;
  Result.SelEnd := Editor.BlockEnd;
end;

function PrintEditorToPDF(Editor: TCustomSynEdit; const Options: TEditorPrintOptions; const FileName: String): Integer;
begin
  Result := PrintSourceToPDF(SourceOfEditor(Editor), Options, FileName);
end;

function CollectSource(const Source: TPrintSource; Colors, Highlight, SelectionOnly: Boolean;
  out TextRGB, BackRGB: Cardinal): TPrintLines;
var
  Lines: TPrintLines;
  Copy_: TSynEditStringList;
  HL: TSynCustomHighlighter;
  Attr: TSynHighlighterAttributes;
  First, Last, I, ByteFrom, ByteTo, BytePos, TokLen: Integer;
  StartPt, EndPt: TPoint;
  TextColor, BackColor: TColor;
  Token, Part: String;

  procedure AddSegment(const AText: String; AColor: TColor; AStyle: TFontStyles);
  var
    Seg: TPrintSegment;
  begin
    if AText = '' then
      Exit;
    Seg.Text := AText;
    if Colors and (AColor <> clNone) and (AColor <> clDefault) then
      Seg.RGB := ToRGB(AColor)
    else if Colors then
      Seg.RGB := ToRGB(TextColor)
    else
      Seg.RGB := 0; // black
    Seg.Bold := Highlight and (fsBold in AStyle);
    Seg.Italic := Highlight and (fsItalic in AStyle);
    SetLength(Lines[High(Lines)].Segments, Length(Lines[High(Lines)].Segments) + 1);
    Lines[High(Lines)].Segments[High(Lines[High(Lines)].Segments)] := Seg;
  end;

begin
  // Range of lines, and of bytes in the first and last one (logical positions)
  First := 1;
  Last := Source.Lines.Count;
  StartPt := Point(1, 1);
  EndPt := Point(MaxInt, Last);
  if SelectionOnly and Source.HasSelection then begin
    StartPt := Source.SelStart;
    EndPt := Source.SelEnd;
    First := StartPt.Y;
    Last := EndPt.Y;
    if (EndPt.X = 1) and (Last > First) then
      Dec(Last); // a selection of whole lines ends at the start of the next
  end;

  // The editor's colors when there is no attribute color
  TextColor := Source.TextColor;
  BackColor := Source.BackColor;
  if Assigned(Source.Highlighter) then begin
    if Source.Highlighter.WhitespaceAttribute.Foreground <> clNone then
      TextColor := Source.Highlighter.WhitespaceAttribute.Foreground;
    if Source.Highlighter.WhitespaceAttribute.Background <> clNone then
      BackColor := Source.Highlighter.WhitespaceAttribute.Background;
  end;
  if TextColor = clDefault then
    TextColor := clBlack;
  if BackColor = clDefault then
    BackColor := clWhite;
  TextRGB := ToRGB(TextColor);
  BackRGB := ToRGB(BackColor);

  Lines := nil;
  Copy_ := nil;
  HL := nil;
  try
    // Tokens from a copy of the highlighter: the editor's is shared by all
    // open files, and scanning other lines with it would disturb them
    if Assigned(Source.Highlighter) then begin
      Copy_ := TSynEditStringList.Create;
      Copy_.Assign(Source.Lines);
      HL := TSynCustomHighlighterClass(Source.Highlighter.ClassType).Create(nil);
      HL.Assign(Source.Highlighter);
      HL.AttachToLines(Copy_);
      HL.CurrentLines := Copy_;
      HL.ScanRanges;
    end;

    for I := First to Last do begin
      SetLength(Lines, Length(Lines) + 1);
      Lines[High(Lines)].Number := I;
      Lines[High(Lines)].Segments := nil;

      // Bytes of this line to print
      ByteFrom := 1;
      ByteTo := MaxInt;
      if I = StartPt.Y then
        ByteFrom := StartPt.X;
      if I = EndPt.Y then
        ByteTo := EndPt.X - 1;

      if Assigned(HL) then begin
        HL.StartAtLineIndex(I - 1);
        BytePos := 1;
        while not HL.GetEol do begin
          Token := HL.GetToken;
          TokLen := Length(Token);
          // The part of the token inside ByteFrom..ByteTo
          if (BytePos + TokLen > ByteFrom) and (BytePos <= ByteTo) then begin
            Part := Copy(Token, Max(1, ByteFrom - BytePos + 1),
              Min(ByteTo, BytePos + TokLen - 1) - Max(BytePos, ByteFrom) + 1);
            Attr := HL.GetTokenAttribute;
            if Assigned(Attr) then
              AddSegment(Part, Attr.Foreground, Attr.Style)
            else
              AddSegment(Part, clNone, []);
          end;
          Inc(BytePos, TokLen);
          HL.Next;
        end;
      end else
        AddSegment(Copy(Source.Lines[I - 1], ByteFrom, ByteTo - ByteFrom + 1), clNone, []);
    end;
  finally
    if Assigned(HL) then begin
      HL.DetachFromLines(Copy_);
      HL.Free;
    end;
    Copy_.Free;
  end;
  Result := Lines;
end;

function PrintSourceToPDF(const Source: TPrintSource; const Options: TEditorPrintOptions; const FileName: String): Integer;
var
  Lines: TPrintLines;
  TextRGB, BackRGB: Cardinal;
  PdfOptions: TPdfPrintOptions;
begin
  Lines := CollectSource(Source, Options.Colors, Options.Highlight, Options.SelectionOnly, TextRGB, BackRGB);
  PdfOptions.Title := Options.Title;
  PdfOptions.LineNumbers := Options.LineNumbers;
  PdfOptions.NumbersInMargin := Options.LineNumbersInMargin;
  PdfOptions.WordWrap := Options.WordWrap;
  PdfOptions.PaintBackground := Options.Colors and (BackRGB <> $FFFFFF);
  PdfOptions.BackRGB := BackRGB;
  if Options.Colors then
    PdfOptions.TextRGB := TextRGB
  else
    PdfOptions.TextRGB := $404040;
  PdfOptions.TabWidth := Options.TabWidth;
  PdfOptions.FontFamily := Source.FontName;
  PdfOptions.FontSize := 9;
  Result := WritePrintPDF(Lines, PdfOptions, FileName);
end;

end.
