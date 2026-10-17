{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
}

unit SynEditCompat;

{$MODE DELPHI}

// Coordinate types of the Delphi SynEdit the IDE was written against.
// Lazarus' SynEdit uses TPoint everywhere (X = column, Y = line); these
// records convert to and from TPoint implicitly, so code written with
// .Char/.Line or .Column/.Row keeps working.
//   TBufferCoord  = logical position: character index in the line text
//   TDisplayCoord = physical position: screen column, tabs expanded

interface

uses
  Types, Graphics, SynEdit, SynGutterLineNumber;

type
  TBufferCoord = record
    Char: Integer;
    Line: Integer;
    class operator Implicit(const P: TPoint): TBufferCoord;
    class operator Implicit(const B: TBufferCoord): TPoint;
    class operator Equal(const A, B: TBufferCoord): Boolean;
    class operator NotEqual(const A, B: TBufferCoord): Boolean;
  end;

  TDisplayCoord = record
    Column: Integer;
    Row: Integer;
    class operator Implicit(const P: TPoint): TDisplayCoord;
    class operator Implicit(const D: TDisplayCoord): TPoint;
  end;

function BufferCoord(AChar, ALine: Integer): TBufferCoord;
function DisplayCoord(AColumn, ARow: Integer): TDisplayCoord;

// The Delphi gutter had one background and one font color; Lazarus' gutter is
// built from parts and the line numbers draw with the editor's font
procedure SetGutterColors(Editor: TCustomSynEdit; Background, Foreground: TColor);

// Line number options of the Delphi gutter, applied to the line number part
procedure ApplyGutter(Editor: TCustomSynEdit; AVisible, AAutoSize, AShowLineNumbers, ALeadingZeros,
  AZeroStart: Boolean; ADigitCount: Integer);

implementation

procedure ApplyGutter(Editor: TCustomSynEdit; AVisible, AAutoSize, AShowLineNumbers, ALeadingZeros,
  AZeroStart: Boolean; ADigitCount: Integer);
var
  I: Integer;
  Part: TSynGutterLineNumber;
begin
  Editor.Gutter.Visible := AVisible;
  Editor.Gutter.AutoSize := AAutoSize;
  for I := 0 to Editor.Gutter.Parts.Count - 1 do
    if Editor.Gutter.Parts[I] is TSynGutterLineNumber then begin
      Part := TSynGutterLineNumber(Editor.Gutter.Parts[I]);
      Part.Visible := AShowLineNumbers;
      Part.LeadingZeros := ALeadingZeros;
      Part.ZeroStart := AZeroStart;
      Part.DigitCount := ADigitCount;
    end;
end;

procedure SetGutterColors(Editor: TCustomSynEdit; Background, Foreground: TColor);
var
  I: Integer;
begin
  Editor.Gutter.Color := Background;
  for I := 0 to Editor.Gutter.Parts.Count - 1 do
    if Editor.Gutter.Parts[I] is TSynGutterLineNumber then
      TSynGutterLineNumber(Editor.Gutter.Parts[I]).MarkupInfo.Foreground := Foreground;
end;

function BufferCoord(AChar, ALine: Integer): TBufferCoord;
begin
  Result.Char := AChar;
  Result.Line := ALine;
end;

function DisplayCoord(AColumn, ARow: Integer): TDisplayCoord;
begin
  Result.Column := AColumn;
  Result.Row := ARow;
end;

class operator TBufferCoord.Implicit(const P: TPoint): TBufferCoord;
begin
  Result.Char := P.X;
  Result.Line := P.Y;
end;

class operator TBufferCoord.Implicit(const B: TBufferCoord): TPoint;
begin
  Result.X := B.Char;
  Result.Y := B.Line;
end;

class operator TBufferCoord.Equal(const A, B: TBufferCoord): Boolean;
begin
  Result := (A.Char = B.Char) and (A.Line = B.Line);
end;

class operator TBufferCoord.NotEqual(const A, B: TBufferCoord): Boolean;
begin
  Result := (A.Char <> B.Char) or (A.Line <> B.Line);
end;

class operator TDisplayCoord.Implicit(const P: TPoint): TDisplayCoord;
begin
  Result.Column := P.X;
  Result.Row := P.Y;
end;

class operator TDisplayCoord.Implicit(const D: TDisplayCoord): TPoint;
begin
  Result.X := D.Column;
  Result.Y := D.Row;
end;

end.
