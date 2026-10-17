{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    Export of highlighted source to RTF and TeX. Delphi's SynEdit had
    exporters for both; Lazarus' only has HTML. These take the same colored
    runs that printing uses (EditorPrint.CollectSource).
}

unit CodeExport;

{$MODE DELPHI}

interface

uses
  Classes, SysUtils, PdfPrint;

type
  TExportOptions = record
    Title: String;
    FontName: String; // the editor's font; the reader falls back to a monospaced one
    FontSize: Integer; // points
    TextRGB: Cardinal; // $RRGGBB, where a run has no color
    BackRGB: Cardinal; // page color; white leaves the page alone
    TabWidth: Integer;
  end;

// Rich Text Format, for word processors (LibreOffice Writer, Word)
procedure ExportRTF(const Lines: TPrintLines; const Options: TExportOptions; const FileName: String);

// A LaTeX document that compiles on its own (pdflatex, with xcolor and alltt)
procedure ExportTeX(const Lines: TPrintLines; const Options: TExportOptions; const FileName: String);

implementation

{ UTF-8 }

// Next code point of S from byte I (which moves past it); invalid bytes are
// taken as Latin-1, as the editor does for files that are not UTF-8
function NextCodePoint(const S: String; var I: Integer): Cardinal;
var
  B: Byte;
  Extra, K: Integer;
begin
  B := Ord(S[I]);
  Inc(I);
  if B < $80 then
    Exit(B);
  if (B and $E0) = $C0 then begin
    Result := B and $1F;
    Extra := 1;
  end else if (B and $F0) = $E0 then begin
    Result := B and $0F;
    Extra := 2;
  end else if (B and $F8) = $F0 then begin
    Result := B and $07;
    Extra := 3;
  end else
    Exit(B);
  if I + Extra - 1 > Length(S) then
    Exit(B);
  for K := 0 to Extra - 1 do
    if (Ord(S[I + K]) and $C0) <> $80 then
      Exit(B);
  for K := 1 to Extra do begin
    Result := (Result shl 6) or (Ord(S[I]) and $3F);
    Inc(I);
  end;
end;

// Tabs to spaces, from column Col (0-based, updated) to the next tab stop
function ExpandTabs(const S: String; TabWidth: Integer; var Col: Integer): String;
var
  I: Integer;
begin
  Result := '';
  if TabWidth < 1 then
    TabWidth := 4;
  for I := 1 to Length(S) do
    if S[I] = #9 then begin
      Result := Result + StringOfChar(' ', TabWidth - Col mod TabWidth);
      Inc(Col, TabWidth - Col mod TabWidth);
    end else begin
      Result := Result + S[I];
      if (Ord(S[I]) and $C0) <> $80 then
        Inc(Col);
    end;
end;

procedure SaveText(const Text, FileName: String);
var
  F: TFileStream;
begin
  F := TFileStream.Create(FileName, fmCreate);
  try
    if Text <> '' then
      F.WriteBuffer(Text[1], Length(Text));
  finally
    F.Free;
  end;
end;

{ RTF }

function RTFText(const S: String): String;
var
  I: Integer;
  C: Cardinal;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do begin
    C := NextCodePoint(S, I);
    case C of
      Ord('\'), Ord('{'), Ord('}'):
        Result := Result + '\' + Chr(C);
      32..91, 93..122, 124, 126:
        Result := Result + Chr(C);
      $10000..$10FFFF: begin // as a UTF-16 surrogate pair, each a signed 16-bit \u
          Dec(C, $10000);
          Result := Result + Format('\u%d?\u%d?', [SmallInt($D800 + (C shr 10)), SmallInt($DC00 + (C and $3FF))]);
        end;
    else
      Result := Result + Format('\u%d?', [SmallInt(C)]);
    end;
  end;
end;

procedure ExportRTF(const Lines: TPrintLines; const Options: TExportOptions; const FileName: String);
var
  Colors: TList;
  Out_, Body: TStringBuilder;
  L, S, Col, I: Integer;

  function ColorIndex(RGB: Cardinal): Integer; // 1-based in \colortbl
  begin
    Result := Colors.IndexOf(Pointer(PtrUInt(RGB)));
    if Result < 0 then
      Result := Colors.Add(Pointer(PtrUInt(RGB)));
    Inc(Result);
  end;

var
  Back: Integer;
  RGB: Cardinal;
begin
  Colors := TList.Create;
  Out_ := TStringBuilder.Create;
  Body := TStringBuilder.Create;
  try
    ColorIndex(Options.TextRGB);
    Back := 0;
    if Options.BackRGB <> $FFFFFF then
      Back := ColorIndex(Options.BackRGB);

    for L := 0 to High(Lines) do begin
      Col := 0;
      for S := 0 to High(Lines[L].Segments) do
        with Lines[L].Segments[S] do begin
          Body.Append('{');
          if Bold then
            Body.Append('\b');
          if Italic then
            Body.Append('\i');
          Body.Append('\cf').Append(ColorIndex(RGB));
          if Back > 0 then // \chcbpat for Word, \highlight for LibreOffice
            Body.Append('\chcbpat').Append(Back).Append('\highlight').Append(Back);
          Body.Append(' ').Append(RTFText(ExpandTabs(Text, Options.TabWidth, Col))).Append('}');
        end;
      Body.Append('\par').Append(LineEnding);
    end;

    Out_.Append('{\rtf1\ansi\deff0\uc1').Append(LineEnding);
    Out_.Append('{\fonttbl{\f0\fmodern\fcharset0 ').Append(RTFText(Options.FontName)).Append(';}}').Append(LineEnding);
    Out_.Append('{\colortbl;');
    for I := 0 to Colors.Count - 1 do begin
      RGB := Cardinal(PtrUInt(Colors[I]));
      Out_.Append(Format('\red%d\green%d\blue%d;', [(RGB shr 16) and $FF, (RGB shr 8) and $FF, RGB and $FF]));
    end;
    Out_.Append('}').Append(LineEnding);
    Out_.Append('{\info{\title ').Append(RTFText(Options.Title)).Append('}}').Append(LineEnding);
    Out_.Append('\paperw11906\paperh16838\margl1134\margr1134\margt1134\margb1134').Append(LineEnding); // A4, 2 cm
    Out_.Append('\pard\plain\f0\fs').Append(Options.FontSize * 2).Append(LineEnding);
    Out_.Append(Body.ToString);
    Out_.Append('}').Append(LineEnding);
    SaveText(Out_.ToString, FileName);
  finally
    Body.Free;
    Out_.Free;
    Colors.Free;
  end;
end;

{ TeX }

// Inside alltt only \, { and } are special; the rest is taken as it is.
// pdflatex's utf8 input knows the Latin letters; anything else (emoji,
// symbols) would stop the document from compiling, so it becomes '?'.
function TeXText(const S: String): String;
var
  I, From: Integer;
  C: Cardinal;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do begin
    From := I;
    C := NextCodePoint(S, I);
    case C of
      Ord('\'): Result := Result + '\textbackslash{}';
      Ord('{'): Result := Result + '\{';
      Ord('}'): Result := Result + '\}';
      32..91, 93..122, 124, 126, $A0..$17F:
        Result := Result + Copy(S, From, I - From);
    else
      Result := Result + '?';
    end;
  end;
end;

// Text for the document's title, outside alltt
function TeXTitle(const S: String): String;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    case S[I] of
      '\': Result := Result + '\textbackslash{}';
      '{', '}', '$', '&', '#', '_', '%': Result := Result + '\' + S[I];
      '~': Result := Result + '\textasciitilde{}';
      '^': Result := Result + '\textasciicircum{}';
    else
      Result := Result + S[I];
    end;
end;

function TeXColor(RGB: Cardinal): String;
begin
  Result := Format('%d,%d,%d', [(RGB shr 16) and $FF, (RGB shr 8) and $FF, RGB and $FF]);
end;

procedure ExportTeX(const Lines: TPrintLines; const Options: TExportOptions; const FileName: String);
var
  Out_: TStringBuilder;
  L, S, Col: Integer;
  Run: String;
begin
  Out_ := TStringBuilder.Create;
  try
    Out_.Append('% ').Append(Options.Title).Append(' - exported by Penguin cpp').Append(LineEnding);
    Out_.Append('\documentclass[a4paper]{article}').Append(LineEnding);
    Out_.Append('\usepackage[utf8]{inputenc}').Append(LineEnding);
    Out_.Append('\usepackage[T1]{fontenc}').Append(LineEnding);
    Out_.Append('\usepackage{lmodern}').Append(LineEnding);
    Out_.Append('\usepackage[margin=2cm]{geometry}').Append(LineEnding);
    Out_.Append('\usepackage{xcolor}').Append(LineEnding);
    Out_.Append('\usepackage{alltt}').Append(LineEnding);
    Out_.Append('\title{').Append(TeXTitle(Options.Title)).Append('}').Append(LineEnding); // for \maketitle, if wanted
    Out_.Append('\begin{document}').Append(LineEnding);
    if Options.BackRGB <> $FFFFFF then
      Out_.Append('\pagecolor[RGB]{').Append(TeXColor(Options.BackRGB)).Append('}').Append(LineEnding);
    Out_.Append('\begin{alltt}\small').Append(LineEnding);
    for L := 0 to High(Lines) do begin
      Col := 0;
      for S := 0 to High(Lines[L].Segments) do
        with Lines[L].Segments[S] do begin
          Run := TeXText(ExpandTabs(Text, Options.TabWidth, Col));
          if Trim(Run) = '' then begin // spaces need no color
            Out_.Append(Run);
            Continue;
          end;
          if Bold then
            Run := '\textbf{' + Run + '}';
          if Italic then
            Run := '\textit{' + Run + '}';
          Out_.Append('\textcolor[RGB]{').Append(TeXColor(RGB)).Append('}{').Append(Run).Append('}');
        end;
      Out_.Append(LineEnding);
    end;
    Out_.Append('\end{alltt}').Append(LineEnding);
    Out_.Append('\end{document}').Append(LineEnding);
    SaveText(Out_.ToString, FileName);
  finally
    Out_.Free;
  end;
end;

end.
