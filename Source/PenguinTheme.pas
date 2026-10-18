{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    The colors of the Penguin cpp icon for the whole application: menus,
    toolbars, buttons and dialogs, light or dark like the editor's color
    scheme (PenguinPalette colors the IDE's own panels). Qt5 lets an
    application set its palette; with GTK2 they follow the desktop's theme,
    and this does nothing.
}

unit PenguinTheme;

{$MODE DELPHI}

interface

// Applies the light or the dark palette to the application (Qt5 only)
procedure ApplyApplicationPalette(Dark: Boolean);

implementation

{$IFDEF LCLQt5}
uses
  Graphics, qt5, qtobjects, PenguinPalette;

var
  StyleSet: Boolean = False;

procedure SetRole(P: QPaletteH; Group: QPaletteColorGroup; Role: QPaletteColorRole; Color: TColor);
var
  C: TQColor;
begin
  ColorRefToTQColor(ColorToRGB(Color), C);
  QPalette_setColor(P, Group, Role, @C);
end;

procedure SetAll(P: QPaletteH; Role: QPaletteColorRole; Color: TColor);
begin
  SetRole(P, QPaletteActive, Role, Color);
  SetRole(P, QPaletteInactive, Role, Color);
  SetRole(P, QPaletteDisabled, Role, Color);
end;

procedure ApplyApplicationPalette(Dark: Boolean);
var
  P: QPaletteH;
  StyleName: WideString;
  Style: QStyleH;
  Back, Panel, Text, Link: TColor;
begin
  // Fusion draws everything from the palette, the same on every desktop; the
  // desktop's own style may keep some of its colors
  if not StyleSet then begin
    StyleName := 'Fusion';
    Style := QStyleFactory_create(@StyleName);
    if Assigned(Style) then
      QApplication_setStyle(Style);
    StyleSet := True;
  end;

  if Dark then begin
    Back := PenguinNavy; // windows, menus, buttons
    Panel := PenguinInk; // text fields and lists
    Text := PenguinLightBlue;
    Link := PenguinYellow;
  end else begin
    Back := PenguinLightBlue;
    Panel := clWhite;
    Text := PenguinInk;
    Link := PenguinNavy;
  end;

  P := QPalette_Create();
  try
    SetAll(P, QPaletteWindow, Back);
    SetAll(P, QPaletteWindowText, Text);
    SetAll(P, QPaletteBase, Panel);
    SetAll(P, QPaletteAlternateBase, Back);
    SetAll(P, QPaletteText, Text);
    SetAll(P, QPaletteButton, Back);
    SetAll(P, QPaletteButtonText, Text);
    SetAll(P, QPaletteBrightText, PenguinYellow);
    SetAll(P, QPaletteHighlight, PenguinMidBlue);
    SetAll(P, QPaletteHighlightedText, clWhite);
    SetAll(P, QPaletteToolTipBase, Panel);
    SetAll(P, QPaletteToolTipText, Text);
    SetAll(P, QPaletteLink, Link);
    SetAll(P, QPaletteLinkVisited, PenguinMidBlue);
    // The 3D shades of buttons, frames and scroll bars
    if Dark then begin
      SetAll(P, QPaletteLight, PenguinMidBlue);
      SetAll(P, QPaletteMidlight, PenguinNavy);
      SetAll(P, QPaletteMid, PenguinInk);
      SetAll(P, QPaletteDark, PenguinInk);
      SetAll(P, QPaletteShadow, clBlack);
    end else begin
      SetAll(P, QPaletteLight, clWhite);
      SetAll(P, QPaletteMidlight, PenguinLightBlue);
      SetAll(P, QPaletteMid, PenguinMidBlue);
      SetAll(P, QPaletteDark, PenguinNavy);
      SetAll(P, QPaletteShadow, PenguinInk);
    end;
    // Disabled items: the middle blue reads on both
    SetRole(P, QPaletteDisabled, QPaletteWindowText, PenguinMidBlue);
    SetRole(P, QPaletteDisabled, QPaletteText, PenguinMidBlue);
    SetRole(P, QPaletteDisabled, QPaletteButtonText, PenguinMidBlue);

    // The LCL clears its cache of system colors (clWindow, clBtnFace...) on
    // this change, so forms and controls follow it
    QApplication_setPalette(P);
  finally
    QPalette_Destroy(P);
  end;
end;

{$ELSE}

procedure ApplyApplicationPalette(Dark: Boolean);
begin
  // GTK2 and the others: the desktop's theme
end;

{$ENDIF}

end.
