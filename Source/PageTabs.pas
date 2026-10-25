{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    Left-aligned tabs for a page control. Cocoa's own tabs (NSTabView) are
    always centered, which leaves the file tabs in the middle of the editor
    and the message tabs in the middle of the window. On macOS the page
    controls hide their tabs and keep room above them, where a strip drawn
    here is placed: it reads the pages each time it paints, so it always
    shows what the page control has, and it acts on the page control as its
    tabs would (select, right-click menu, close).
}
unit PageTabs;

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ComCtrls, Graphics, Forms, Menus, LCLType;

type
  TPageTabCloseEvent = procedure(Sender: TObject; Page: TTabSheet) of object;

  TPageTabStrip = class(TCustomControl)
  private
    fPages: TPageControl;
    fOnClose: TPageTabCloseEvent;
    fTabs: array of TRect;   // where each page's tab was drawn (empty: not shown)
    fCloses: array of TRect; // and its close box
    fSignature: String;      // what was drawn, to know when to draw again
    function Signature: String;
    function TabAt(X, Y: Integer; out OnClose: Boolean): Integer;
    procedure Select(Index: Integer);
    procedure IdleCheck(Sender: TObject; var Done: Boolean);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent; APages: TPageControl; AOnClose: TPageTabCloseEvent); reintroduce;
    destructor Destroy; override;
  end;

// On macOS, hides Pages' centered tabs and puts a left-aligned strip above
// it. With OnClose, each tab has a close box (and a middle click closes it).
// Elsewhere it does nothing and returns nil.
function AttachTabStrip(Pages: TPageControl; OnClose: TPageTabCloseEvent = nil): TPageTabStrip;

implementation

const
  PadX = 12;     // text margin inside a tab
  CloseSize = 14; // the close box

function AttachTabStrip(Pages: TPageControl; OnClose: TPageTabCloseEvent): TPageTabStrip;
begin
{$IFDEF DARWIN}
  Result := TPageTabStrip.Create(Pages.Owner, Pages, OnClose);
{$ELSE}
  Result := nil;
{$ENDIF}
end;

constructor TPageTabStrip.Create(AOwner: TComponent; APages: TPageControl; AOnClose: TPageTabCloseEvent);
var
  H: Integer;
begin
  inherited Create(AOwner);
  fPages := APages;
  fOnClose := AOnClose;
  H := Abs(Screen.SystemFont.Height);
  if H < 10 then
    H := 13;
  H := H * 2 + 6; // one line of text with room around it

  // The page control keeps a band above its pages; the strip lives there and
  // is placed again whenever the page control moved (anchoring it to the
  // page control kept the place it had before the band was made)
  fPages.ShowTabs := False;
  fPages.BorderSpacing.Top := fPages.BorderSpacing.Top + H;
  Parent := fPages.Parent;
  Height := H;
  Application.AddOnIdleHandler(@IdleCheck);
end;

destructor TPageTabStrip.Destroy;
begin
  Application.RemoveOnIdleHandler(@IdleCheck);
  inherited Destroy;
end;

function TPageTabStrip.Signature: String;
var
  I: Integer;
begin
  Result := IntToStr(fPages.ActivePageIndex) + '|' + IntToStr(fPages.Width) + '|';
  for I := 0 to fPages.PageCount - 1 do
    if fPages.Pages[I].TabVisible then
      Result := Result + fPages.Pages[I].Caption + #1;
end;

// Pages come and go, captions change ("[*]"), the control moves, resizes,
// goes to a floating window or hides: follow it, and draw again when anything
// shown changed
procedure TPageTabStrip.IdleCheck(Sender: TObject; var Done: Boolean);
var
  S: String;
  Wanted: Boolean;
begin
  if Parent <> fPages.Parent then
    Parent := fPages.Parent;
  if (Left <> fPages.Left) or (Top <> fPages.Top - Height) or (Width <> fPages.Width) then
    SetBounds(fPages.Left, fPages.Top - Height, fPages.Width, Height);
  Wanted := fPages.Visible and (fPages.Width > 0) and (fPages.PageCount > 0);
  if Visible <> Wanted then
    Visible := Wanted;
  S := Signature;
  if S <> fSignature then begin
    fSignature := S;
    Invalidate;
  end;
end;

procedure TPageTabStrip.Paint;
var
  I, X, W, First, Total, Active: Integer;
  R, C: TRect;
  Title: String;
  Widths: array of Integer;
begin
  fSignature := Signature;
  SetLength(fTabs, fPages.PageCount);
  SetLength(fCloses, fPages.PageCount);
  SetLength(Widths, fPages.PageCount);
  Canvas.Font.Assign(Font);
  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(ClientRect);

  // The width of each tab, and where to start so that the active one shows
  Total := 0;
  for I := 0 to fPages.PageCount - 1 do begin
    fTabs[I] := Rect(0, 0, 0, 0);
    fCloses[I] := Rect(0, 0, 0, 0);
    Widths[I] := 0;
    if not fPages.Pages[I].TabVisible then
      Continue;
    Widths[I] := Canvas.TextWidth(fPages.Pages[I].Caption) + 2 * PadX;
    if Assigned(fOnClose) then
      Inc(Widths[I], CloseSize + 6);
    Inc(Total, Widths[I] + 2);
  end;
  Active := fPages.ActivePageIndex;
  First := 0;
  if (Total > ClientWidth) and (Active > 0) then begin
    X := 0;
    for I := Active downto 0 do begin
      Inc(X, Widths[I] + 2);
      if X > ClientWidth then
        Break;
      First := I;
    end;
  end;

  X := 4;
  for I := First to fPages.PageCount - 1 do begin
    if Widths[I] = 0 then
      Continue;
    W := Widths[I];
    R := Rect(X, 3, X + W, ClientHeight);
    Title := fPages.Pages[I].Caption;
    if I = Active then begin
      Canvas.Brush.Color := clWindow;
      Canvas.Pen.Color := clBtnShadow;
      Canvas.Rectangle(R.Left, R.Top, R.Right, R.Bottom + 1);
      Canvas.Brush.Color := clHighlight;
      Canvas.FillRect(Rect(R.Left + 1, R.Top + 1, R.Right - 1, R.Top + 3));
      Canvas.Font.Style := [fsBold];
    end else
      Canvas.Font.Style := [];
    Canvas.Font.Color := clBtnText;
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(R.Left + PadX, R.Top + (R.Bottom - R.Top - Canvas.TextHeight(Title)) div 2, Title);
    Canvas.Brush.Style := bsSolid;
    if Assigned(fOnClose) then begin
      C := Rect(R.Right - PadX div 2 - CloseSize, R.Top + (R.Bottom - R.Top - CloseSize) div 2, 0, 0);
      C.Right := C.Left + CloseSize;
      C.Bottom := C.Top + CloseSize;
      Canvas.Pen.Color := clGrayText;
      Canvas.Line(C.Left + 3, C.Top + 3, C.Right - 3, C.Bottom - 3);
      Canvas.Line(C.Right - 4, C.Top + 3, C.Left + 2, C.Bottom - 3);
      fCloses[I] := C;
    end;
    fTabs[I] := R;
    X := R.Right + 2;
    if X > ClientWidth then
      Break;
  end;
  // A line under the tabs, where the pages start
  Canvas.Pen.Color := clBtnShadow;
  Canvas.Line(0, ClientHeight - 1, ClientWidth, ClientHeight - 1);
end;

function TPageTabStrip.TabAt(X, Y: Integer; out OnClose: Boolean): Integer;
var
  I: Integer;
begin
  OnClose := False;
  for I := 0 to High(fTabs) do
    if PtInRect(fTabs[I], Point(X, Y)) then begin
      OnClose := PtInRect(fCloses[I], Point(X, Y));
      Exit(I);
    end;
  Result := -1;
end;

procedure TPageTabStrip.Select(Index: Integer);
begin
  if fPages.ActivePageIndex <> Index then begin
    fPages.ActivePageIndex := Index;
    // Setting it from code does not tell the page control's owner
    if Assigned(fPages.OnChange) then
      fPages.OnChange(fPages);
  end;
  Invalidate;
end;

procedure TPageTabStrip.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Index: Integer;
  OnClose: Boolean;
  P: TPoint;
begin
  inherited MouseDown(Button, Shift, X, Y);
  Index := TabAt(X, Y, OnClose);
  if Index = -1 then
    Exit;
  if Assigned(fOnClose) and ((Button = mbMiddle) or ((Button = mbLeft) and OnClose)) then begin
    fOnClose(Self, fPages.Pages[Index]);
    Invalidate;
    Exit;
  end;
  Select(Index);
  if (Button = mbRight) and Assigned(fPages.PopupMenu) then begin
    P := ClientToScreen(Point(X, Y));
    fPages.PopupMenu.PopUp(P.X, P.Y);
  end;
end;

end.
