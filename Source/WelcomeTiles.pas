{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    The welcome screen's buttons, drawn here on macOS. Cocoa draws a button
    with an icon its own way: the icon against the top edge (out of the
    bezel), and no heed of Margin or Spacing. A tile shows the button it
    stands for (Source, hidden): its caption, its icon and its click, read
    each time, so translations and actions stay the button's own. Large
    tiles put the icon above the caption, small ones beside it; a caption
    that does not fit takes two lines.
}
unit WelcomeTiles;

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Buttons, Forms, LCLType, LCLIntf;

type
  TWelcomeTile = class(TCustomControl)
  private
    fSource: TBitBtn;
    fHot: Boolean;
    fLarge: Boolean;
    fImageIndex: Integer;
    procedure IdleFollow(Sender: TObject; var Done: Boolean);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure Click; override;
  public
    // AImageIndex: the button's icon in its Images (the LCL gives the
    // button's ImageIndex back as -1 at run time)
    constructor Create(ASource: TBitBtn; ALarge: Boolean; AImageIndex: Integer); reintroduce;
    destructor Destroy; override;
    // Takes the place the button has now
    procedure Follow;
  end;

// On macOS, a tile over Source, which is hidden; elsewhere nil
function ReplaceWelcomeButton(Source: TBitBtn; Large: Boolean; ImageIndex: Integer): TWelcomeTile;

implementation

function ReplaceWelcomeButton(Source: TBitBtn; Large: Boolean; ImageIndex: Integer): TWelcomeTile;
begin
{$IFDEF DARWIN}
  Result := TWelcomeTile.Create(Source, Large, ImageIndex);
{$ELSE}
  Result := nil;
{$ENDIF}
end;

constructor TWelcomeTile.Create(ASource: TBitBtn; ALarge: Boolean; AImageIndex: Integer);
begin
  inherited Create(ASource.Owner);
  fSource := ASource;
  fLarge := ALarge;
  fImageIndex := AImageIndex;
  Parent := fSource.Parent;
  Cursor := crHandPoint;
  Follow;
  fSource.Visible := False;
  // The welcome screen places its buttons again on every resize; a hidden
  // button says nothing when it moves (no OnChangeBounds)
  Application.AddOnIdleHandler(@IdleFollow);
end;

destructor TWelcomeTile.Destroy;
begin
  Application.RemoveOnIdleHandler(@IdleFollow);
  inherited Destroy;
end;

procedure TWelcomeTile.IdleFollow(Sender: TObject; var Done: Boolean);
begin
  if (Left <> fSource.Left) or (Top <> fSource.Top) or (Width <> fSource.Width) or (Height <> fSource.Height) then
    Follow;
end;

procedure TWelcomeTile.Follow;
begin
  SetBounds(fSource.Left, fSource.Top, fSource.Width, fSource.Height);
  Invalidate;
end;

procedure TWelcomeTile.Paint;
const
  Pad = 10;
var
  R, T: TRect;
  IconW, IconH, X, Y, TextH: Integer;
  HasIcon: Boolean;
  Flags: Cardinal;
  Title: String;
begin
  R := ClientRect;
  // The panel behind, then a rounded card
  Canvas.Brush.Color := Parent.Color;
  Canvas.FillRect(R);
  if fHot then
    Canvas.Brush.Color := clBtnFace
  else
    Canvas.Brush.Color := clWindow;
  Canvas.Pen.Color := clBtnShadow;
  Canvas.RoundRect(R.Left, R.Top, R.Right - 1, R.Bottom - 1, 12, 12);

  HasIcon := Assigned(fSource.Images) and (fImageIndex >= 0) and (fImageIndex < fSource.Images.Count);
  IconW := 0;
  IconH := 0;
  if HasIcon then begin
    IconW := fSource.Images.Width;
    IconH := fSource.Images.Height;
  end;
  Title := fSource.Caption;
  Canvas.Font.Assign(Font);
  Canvas.Font.Color := clWindowText;
  Canvas.Brush.Style := bsClear;
  Flags := DT_CENTER or DT_WORDBREAK or DT_NOPREFIX;

  if fLarge then begin
    // Icon and caption as one block, centered
    T := Rect(Pad, 0, Width - Pad, Height);
    TextH := DrawText(Canvas.Handle, PChar(Title), Length(Title), T, Flags or DT_CALCRECT);
    Y := (Height - IconH - 10 - TextH) div 2;
    if HasIcon then
      fSource.Images.Draw(Canvas, (Width - IconW) div 2, Y, fImageIndex);
    T := Rect(Pad, Y + IconH + 10, Width - Pad, Height - Pad);
    DrawText(Canvas.Handle, PChar(Title), Length(Title), T, Flags);
  end else begin
    // Icon on the left, the caption centered in the rest (two lines at most)
    X := Pad;
    if HasIcon then begin
      fSource.Images.Draw(Canvas, X, (Height - IconH) div 2, fImageIndex);
      Inc(X, IconW + 6);
    end;
    T := Rect(X, 0, Width - Pad, Height);
    TextH := DrawText(Canvas.Handle, PChar(Title), Length(Title), T, Flags or DT_CALCRECT);
    T := Rect(X, (Height - TextH) div 2, Width - Pad, Height);
    DrawText(Canvas.Handle, PChar(Title), Length(Title), T, Flags);
  end;
  Canvas.Brush.Style := bsSolid;
end;

procedure TWelcomeTile.MouseEnter;
begin
  inherited MouseEnter;
  fHot := True;
  Invalidate;
end;

procedure TWelcomeTile.MouseLeave;
begin
  inherited MouseLeave;
  fHot := False;
  Invalidate;
end;

procedure TWelcomeTile.Click;
begin
  inherited Click;
  fSource.Click;
end;

end.
