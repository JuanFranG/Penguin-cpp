{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    Printing. Delphi's SynEdit printed through the Windows printer; Lazarus'
    SynEdit has no printing. Here the source is laid out on A4 pages as a PDF
    (fcl-pdf, part of Free Pascal) and sent to CUPS with lp, which every Linux
    desktop has and which prints PDF directly. The same PDF is what "Save as
    PDF" keeps. Nothing here depends on the widget set, so GTK2 and Qt6 print
    the same way.
}

unit PdfPrint;

{$MODE DELPHI}

interface

uses
  Classes, SysUtils;

type
  // A run of text with one color and style; RGB is $RRGGBB
  TPrintSegment = record
    Text: String; // UTF-8, may contain tabs
    RGB: Cardinal;
    Bold, Italic: Boolean;
  end;

  TPrintLine = record
    Number: Integer; // line number in the file
    Segments: array of TPrintSegment;
  end;

  TPrintLines = array of TPrintLine;

  TPdfPrintOptions = record
    Title: String; // file name, in the page header
    LineNumbers: Boolean;
    NumbersInMargin: Boolean; // in the left margin instead of the text area
    WordWrap: Boolean; // otherwise long lines are cut at the right margin
    PaintBackground: Boolean;
    BackRGB: Cardinal; // page color with PaintBackground
    TextRGB: Cardinal; // header, footer and line numbers
    TabWidth: Integer;
    FontFamily: String; // the editor's font, if it can be embedded
    FontSize: Integer; // points
  end;

// Lays out Lines on A4 pages and saves them as a PDF. Returns the number of
// pages; raises an exception if the file cannot be written.
function WritePrintPDF(const Lines: TPrintLines; const Options: TPdfPrintOptions; const FileName: String): Integer;

// The CUPS printers and the default one; empty when CUPS is not installed
procedure GetPrinters(Printers: TStrings; out DefaultPrinter: String);

// Sends a PDF to a CUPS printer. Error has lp's message when it fails.
function PrintPDF(const FileName, Printer, Title: String; Copies: Integer; out Error: String): Boolean;

implementation

uses
  Process, Math, fppdf;

const
  PageWidth = 210.0; // A4, millimeters
  PageHeight = 297.0;
  MarginTop = 12.0;
  MarginBottom = 14.0;
  MarginLeft = 15.0;
  MarginRight = 12.0;
  PointToMM = 25.4 / 72;
  CharWidthEm = 0.6; // advance of the monospaced fonts used (DejaVu Sans Mono, Liberation Mono, Courier)

// Runs a tool with its arguments as separate strings (no shell); returns the
// exit code, or -1 if it could not be started. CLocale gives English output,
// for the outputs that are parsed.
function RunTool(const Exe: String; const Params: array of String; out Output: String;
  CLocale: Boolean = True): Integer;
var
  P: TProcess;
  I: Integer;
  Path, Chunk: String;
  Count: Integer;
  Running: Boolean;
begin
  Output := '';
  Path := ExeSearch(Exe, GetEnvironmentVariable('PATH'));
  if Path = '' then
    Exit(-1);
  P := TProcess.Create(nil);
  try
    P.Executable := Path;
    for I := 0 to High(Params) do
      P.Parameters.Add(Params[I]);
    if CLocale then begin
      for I := 1 to GetEnvironmentVariableCount do
        if Pos('LC_ALL=', GetEnvironmentString(I)) <> 1 then
          P.Environment.Add(GetEnvironmentString(I));
      P.Environment.Add('LC_ALL=C');
    end;
    P.Options := [poUsePipes, poStderrToOutPut];
    try
      P.Execute;
    except
      Exit(-1);
    end;
    P.CloseInput;
    // Read until it exits, then whatever it wrote right before exiting
    repeat
      Running := P.Running;
      repeat
        Count := P.Output.NumBytesAvailable;
        if Count > 0 then begin
          SetLength(Chunk, Count);
          Count := P.Output.Read(Chunk[1], Count);
          Output := Output + Copy(Chunk, 1, Count);
        end;
      until Count <= 0;
      if Running then
        Sleep(5);
    until not Running;
    P.WaitOnExit;
    Result := P.ExitCode;
  finally
    P.Free;
  end;
end;

procedure GetPrinters(Printers: TStrings; out DefaultPrinter: String);
var
  Output: String;
  Lines: TStringList;
  I, P: Integer;
begin
  Printers.Clear;
  DefaultPrinter := '';
  Lines := TStringList.Create;
  try
    if RunTool('lpstat', ['-e'], Output) = 0 then begin
      Lines.Text := Output;
      for I := 0 to Lines.Count - 1 do
        if Trim(Lines[I]) <> '' then
          Printers.Add(Trim(Lines[I]));
    end;
    // "system default destination: NAME"
    if RunTool('lpstat', ['-d'], Output) = 0 then begin
      P := Pos('destination:', Output);
      if P > 0 then
        DefaultPrinter := Trim(Copy(Output, P + Length('destination:'), MaxInt));
    end;
  finally
    Lines.Free;
  end;
end;

function PrintPDF(const FileName, Printer, Title: String; Copies: Integer; out Error: String): Boolean;
var
  Output: String;
  Code: Integer;
begin
  // In the user's language: the message is shown as it comes
  Code := RunTool('lp', ['-d', Printer, '-n', IntToStr(Copies), '-t', Title, FileName], Output, False);
  Result := Code = 0;
  if Code = -1 then
    Error := 'lp (CUPS) is not installed'
  else
    Error := Trim(Output);
end;

{ Fonts }

// A TrueType file for the family and style (':bold', ':italic'...), from
// fontconfig. fcl-pdf embeds TrueType only, not OpenType/CFF or collections.
function FindFontFile(const Family, Style: String): String;
var
  Output: String;
begin
  Result := '';
  if RunTool('fc-match', ['-f', '%{file}', Family + Style], Output) <> 0 then
    Exit;
  Output := Trim(Output);
  if SameText(ExtractFileExt(Output), '.ttf') and FileExists(Output) then
    Result := Output;
end;

type
  TFontStyle = (fsRegular, fsBold, fsItalic, fsBoldItalic);

  TPdfFonts = record
    Files: array[TFontStyle] of String; // '' for the PDF standard Courier
    Index: array[TFontStyle] of Integer; // in the document, -1 until used
  end;

procedure FindFonts(const EditorFamily: String; out Fonts: TPdfFonts);
const
  Styles: array[TFontStyle] of String = ('', ':bold', ':italic', ':bold:italic');
  Fallbacks: array[0..2] of String = ('DejaVu Sans Mono', 'Liberation Mono', 'monospace');
var
  Families: TStringList;
  I: Integer;
  S: TFontStyle;
begin
  for S := Low(TFontStyle) to High(TFontStyle) do begin
    Fonts.Files[S] := '';
    Fonts.Index[S] := -1;
  end;
  Families := TStringList.Create;
  try
    if EditorFamily <> '' then
      Families.Add(EditorFamily);
    for I := Low(Fallbacks) to High(Fallbacks) do
      Families.Add(Fallbacks[I]);
    // The first family with a TrueType regular face
    for I := 0 to Families.Count - 1 do begin
      Fonts.Files[fsRegular] := FindFontFile(Families[I], '');
      if Fonts.Files[fsRegular] <> '' then begin
        for S := fsBold to High(TFontStyle) do begin
          Fonts.Files[S] := FindFontFile(Families[I], Styles[S]);
          if Fonts.Files[S] = '' then
            Fonts.Files[S] := Fonts.Files[fsRegular];
        end;
        Break;
      end;
    end;
  finally
    Families.Free;
  end;
end;

function UseFont(Doc: TPDFDocument; var Fonts: TPdfFonts; Style: TFontStyle): Integer;
const
  StdNames: array[TFontStyle] of String = ('Courier', 'Courier-Bold', 'Courier-Oblique', 'Courier-BoldOblique');
begin
  if Fonts.Index[Style] < 0 then begin
    if Fonts.Files[Style] = '' then
      Fonts.Index[Style] := Doc.AddFont(StdNames[Style])
    else
      Fonts.Index[Style] := Doc.AddFont(Fonts.Files[Style], 'PenguinMono' + IntToStr(Ord(Style)));
  end;
  Result := Fonts.Index[Style];
end;

{ Text }

function IsContinuationByte(C: Char): Boolean; inline;
begin
  Result := (Ord(C) and $C0) = $80;
end;

// Characters (code points) in UTF-8 text
function CharCount(const S: String): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(S) do
    if not IsContinuationByte(S[I]) then
      Inc(Result);
end;

// Byte index where character number N (from 1) starts, or Length + 1
function CharStart(const S: String; N: Integer): Integer;
begin
  Result := 1;
  while (Result <= Length(S)) and (N > 1) do begin
    Inc(Result);
    while (Result <= Length(S)) and IsContinuationByte(S[Result]) do
      Inc(Result);
    Dec(N);
  end;
end;

// Count characters from character First; MaxInt for the rest of the text
function CopyChars(const S: String; First, Count: Integer): String;
var
  A: Integer;
begin
  A := CharStart(S, First);
  if Count >= Length(S) then
    Result := Copy(S, A, MaxInt)
  else
    Result := Copy(S, A, CharStart(S, First + Count) - A);
end;

// The PDF standard fonts only have Latin-1: without a TrueType font, other
// characters print as '?'
function AsciiOnly(const S: String): String;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    if Ord(S[I]) < 128 then
      Result := Result + S[I]
    else if not IsContinuationByte(S[I]) then
      Result := Result + '?';
end;

type
  TRowSegment = record
    Column: Integer; // from 0
    Text: String;
    RGB: Cardinal;
    Style: TFontStyle;
  end;

  TRow = record
    Number: Integer; // 0 for the continuation of a wrapped line
    Segments: array of TRowSegment;
  end;

  TRows = array of TRow;

// Expands tabs and splits the lines into rows that fit Columns characters
function LayoutRows(const Lines: TPrintLines; Columns, TabWidth: Integer; WordWrap: Boolean): TRows;
var
  Rows: TRows;
  Row: TRow;
  Col, L, S, I, Take: Integer;
  Expanded, Ch: String;
  Style: TFontStyle;

  procedure AddRowSegment(const T: String; RGB: Cardinal);
  begin
    SetLength(Row.Segments, Length(Row.Segments) + 1);
    Row.Segments[High(Row.Segments)].Column := Col;
    Row.Segments[High(Row.Segments)].Text := T;
    Row.Segments[High(Row.Segments)].RGB := RGB;
    Row.Segments[High(Row.Segments)].Style := Style;
    Inc(Col, CharCount(T));
  end;

  procedure EndRow;
  begin
    SetLength(Rows, Length(Rows) + 1);
    Rows[High(Rows)] := Row;
    Row.Number := 0;
    Row.Segments := nil;
    Col := 0;
  end;

begin
  Rows := nil;
  if TabWidth < 1 then
    TabWidth := 4;
  for L := 0 to High(Lines) do begin
    Row.Number := Lines[L].Number;
    Row.Segments := nil;
    Col := 0;
    for S := 0 to High(Lines[L].Segments) do begin
      with Lines[L].Segments[S] do begin
        if Bold and Italic then
          Style := fsBoldItalic
        else if Bold then
          Style := fsBold
        else if Italic then
          Style := fsItalic
        else
          Style := fsRegular;

        // Tabs to spaces, up to the next tab stop of the whole line
        Expanded := '';
        I := 1;
        while I <= Length(Text) do begin
          if Text[I] = #9 then
            Expanded := Expanded + StringOfChar(' ', TabWidth - (Col + CharCount(Expanded)) mod TabWidth)
          else begin
            Ch := Text[I];
            while (I < Length(Text)) and IsContinuationByte(Text[I + 1]) do begin
              Inc(I);
              Ch := Ch + Text[I];
            end;
            Expanded := Expanded + Ch;
          end;
          Inc(I);
        end;

        // Into rows
        while Expanded <> '' do begin
          if Col >= Columns then begin
            if not WordWrap then
              Break; // cut at the right margin
            EndRow;
          end;
          Take := Columns - Col;
          if CharCount(Expanded) <= Take then begin
            AddRowSegment(Expanded, RGB);
            Expanded := '';
          end else begin
            AddRowSegment(CopyChars(Expanded, 1, Take), RGB);
            Expanded := CopyChars(Expanded, Take + 1, MaxInt);
          end;
        end;
      end;
    end;
    EndRow;
  end;
  Result := Rows;
end;

function WritePrintPDF(const Lines: TPrintLines; const Options: TPdfPrintOptions; const FileName: String): Integer;
var
  Doc: TPDFDocument;
  Section: TPDFSection;
  Page: TPDFPage;
  Fonts: TPdfFonts;
  Rows: TRows;
  CharW, LineH, Left, TextLeft, TextWidth, HeaderH, Y, X: Double;
  NumCols, Columns, RowsPerPage, PageCount, PageNo, R, S, MaxNumber, I: Integer;
  Header, Footer, NumText: String;

  // fcl-pdf measures from the bottom of the page
  function PdfY(FromTop: Double): Double;
  begin
    Result := PageHeight - FromTop;
  end;

  procedure WriteAt(AX, AFromTop: Double; const AText: String; Style: TFontStyle; RGB: Cardinal);
  var
    T: String;
  begin
    if Fonts.Files[Style] = '' then
      T := AsciiOnly(AText)
    else
      T := AText;
    if Trim(T) = '' then
      Exit;
    Page.SetFont(UseFont(Doc, Fonts, Style), Options.FontSize);
    Page.SetColor(RGB, False);
    Page.WriteText(AX, PdfY(AFromTop), T);
  end;

begin
  FindFonts(Options.FontFamily, Fonts);

  CharW := Options.FontSize * CharWidthEm * PointToMM;
  LineH := Options.FontSize * 1.25 * PointToMM;
  HeaderH := 2.5 * LineH;

  // Room for the line numbers
  MaxNumber := 1;
  for I := 0 to High(Lines) do
    if Lines[I].Number > MaxNumber then
      MaxNumber := Lines[I].Number;
  if Options.LineNumbers then
    NumCols := Length(IntToStr(MaxNumber)) + 1
  else
    NumCols := 0;
  Left := MarginLeft;
  if Options.NumbersInMargin and (NumCols * CharW + 3 > Left) then
    Left := NumCols * CharW + 3;
  TextLeft := Left;
  if not Options.NumbersInMargin then
    TextLeft := Left + NumCols * CharW;
  TextWidth := PageWidth - MarginRight - TextLeft;
  Columns := Trunc(TextWidth / CharW);
  if Columns < 10 then
    Columns := 10;
  RowsPerPage := Trunc((PageHeight - MarginTop - MarginBottom - HeaderH) / LineH);

  Rows := LayoutRows(Lines, Columns, Options.TabWidth, Options.WordWrap);
  PageCount := (Length(Rows) + RowsPerPage - 1) div RowsPerPage;
  if PageCount = 0 then
    PageCount := 1; // an empty file prints its header

  Doc := TPDFDocument.Create(nil);
  try
    Doc.Options := Doc.Options + [poCompressFonts, poCompressText];
    Doc.Infos.Title := Options.Title;
    Doc.Infos.Producer := 'Penguin cpp';
    Doc.StartDocument;
    Section := Doc.Sections.AddSection;
    Header := Options.Title;
    for PageNo := 1 to PageCount do begin
      Page := Doc.Pages.AddPage;
      Page.PaperType := ptA4;
      Page.UnitOfMeasure := uomMillimeters;
      Section.AddPage(Page);

      if Options.PaintBackground then begin
        Page.SetColor(Options.BackRGB, False);
        Page.DrawRect(0, 0, PageWidth, PageHeight, 0, True, False);
      end;

      // Header: file name, and the page count on the right
      Y := MarginTop + LineH;
      WriteAt(Left, Y, Header, fsBold, Options.TextRGB);
      Footer := Format('%d / %d', [PageNo, PageCount]);
      WriteAt(PageWidth - MarginRight - Length(Footer) * CharW, Y, Footer, fsRegular, Options.TextRGB);
      Page.SetColor(Options.TextRGB, True);
      Page.DrawLine(Left, PdfY(Y + 0.6 * LineH), PageWidth - MarginRight, PdfY(Y + 0.6 * LineH), 0.2);

      // Rows
      for R := (PageNo - 1) * RowsPerPage to Min(PageNo * RowsPerPage, Length(Rows)) - 1 do begin
        Y := MarginTop + HeaderH + (R - (PageNo - 1) * RowsPerPage + 1) * LineH;
        if Options.LineNumbers and (Rows[R].Number > 0) then begin
          NumText := IntToStr(Rows[R].Number);
          X := TextLeft - (Length(NumText) + 1) * CharW;
          WriteAt(X, Y, NumText, fsRegular, Options.TextRGB);
        end;
        for S := 0 to High(Rows[R].Segments) do
          with Rows[R].Segments[S] do
            WriteAt(TextLeft + Column * CharW, Y, Text, Style, RGB);
      end;
    end;
    Doc.SaveToFile(FileName);
    Result := PageCount;
  finally
    Doc.Free;
  end;
end;

end.
