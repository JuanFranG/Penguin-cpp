{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    The colors of the Penguin cpp icon, for the IDE's own panels: the welcome
    screen, the project and class trees, and the message lists. Menus, buttons
    and dialogs are drawn by the widget set and follow the desktop theme.
}

unit PenguinPalette;

{$MODE DELPHI}

interface

uses
  SysUtils, Graphics;

const
  // TColor is $00BBGGRR
  PenguinLightBlue = TColor($00FCEEDA); // #DAEEFC
  PenguinNavy = TColor($005E3918); // #18395E
  PenguinInk = TColor($00432509); // #092543
  PenguinMidBlue = TColor($00C28957); // #5789C2
  PenguinYellow = TColor($000BB5FD); // #FDB50B

type
  TPanelPalette = record
    Dark: Boolean;
    Back: TColor; // panel background
    Text: TColor;
    Link: TColor; // version number, documentation link
    Chip: TColor; // hotkey boxes, tree lines
    ChipText: TColor;
    Selection: TColor;
    SelectionText: TColor;
    Hint: TColor; // compiler hints (yellow does not read on light blue)
    Args: TColor; // function arguments in the class browser
    Secondary: TColor; // types in the class browser, inherited members
  end;

// Whether a color is dark enough to need light text on it
function IsDarkColor(Color: TColor): Boolean;

// Whether a saved color scheme is dark, from the value of its "Space"
// attribute ("foreground, background, bold, italic, underline")
function SpaceIsDark(const SpaceValue: String): Boolean;

// The light palette, or the dark one when the editor's background is dark, so
// the panels around the editor match its color scheme
function PanelPaletteFor(EditorBackground: TColor): TPanelPalette;

implementation

function IsDarkColor(Color: TColor): Boolean;
var
  RGB: Longint;
begin
  if (Color = clNone) or (Color = clDefault) then
    Exit(False);
  RGB := ColorToRGB(Color);
  // Perceived brightness (ITU-R BT.601), 0..255
  Result := (299 * Red(RGB) + 587 * Green(RGB) + 114 * Blue(RGB)) div 1000 < 128;
end;

function SpaceIsDark(const SpaceValue: String): Boolean;
var
  P: Integer;
  Back: String;
begin
  P := Pos(',', SpaceValue);
  if P = 0 then
    Exit(False);
  Back := Trim(Copy(SpaceValue, P + 1, MaxInt));
  P := Pos(',', Back);
  if P > 0 then
    Back := Trim(Copy(Back, 1, P - 1));
  Result := IsDarkColor(StringToColorDef(Back, clNone));
end;

function PanelPaletteFor(EditorBackground: TColor): TPanelPalette;
begin
  Result.Dark := IsDarkColor(EditorBackground);
  Result.Chip := PenguinMidBlue;
  Result.ChipText := clWhite;
  Result.Selection := PenguinMidBlue;
  Result.SelectionText := clWhite;
  if Result.Dark then begin
    Result.Back := PenguinInk;
    Result.Text := PenguinLightBlue;
    Result.Link := PenguinYellow;
    Result.Hint := PenguinYellow;
    Result.Args := PenguinYellow;
    Result.Secondary := PenguinMidBlue;
  end else begin
    Result.Back := PenguinLightBlue;
    Result.Text := PenguinInk;
    Result.Link := PenguinNavy;
    Result.Hint := PenguinNavy;
    Result.Args := clMaroon;
    Result.Secondary := clGray;
  end;
end;

end.
