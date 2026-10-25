{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    What macOS does differently, in one place; on other systems these do
    nothing (or what they did before):
      - the IDE's fonts (Heebo, Source Code Pro) are registered for the
        process from the data folder: a Mac has no package that installs them;
      - light or dark windows, menus and dialogs follow the editor's color
        scheme (NSAppearance; Qt's palette is Linux only);
      - shortcuts use the Command key where Linux uses Ctrl, except those
        macOS keeps for itself (Command-Space: Spotlight, Command-Tab: switch
        apps, Command-H: hide, Command-M: minimize, Command-Q: quit);
      - the editor gets the Mac's cursor keys (Command and Option with the
        arrows and backspace): a Mac keyboard has no Home or End.
}
unit MacSupport;

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SysUtils, LCLType, Menus, ActnList, SynEditKeyCmds;

// Registers the .ttf files in DataDir/Fonts and its subfolders for this
// process (macOS); elsewhere the package installs them
procedure RegisterAppFonts(const DataDir: String);

// Light or dark windows, menus and dialogs (macOS)
procedure SetDarkAppearance(Dark: Boolean);

// The modifier of the usual shortcuts: Command on macOS, Ctrl elsewhere
function CommandShift: TShiftState;

// On macOS, the Ctrl shortcuts of Owner's actions and menu items become
// Command shortcuts (see above for the ones that stay)
procedure UseCommandKey(Owner: TComponent);

// On macOS, adds the Mac's cursor and deletion keys to an editor's keys
procedure AddMacKeystrokes(Keys: TSynEditKeyStrokes);

implementation

{$IFDEF DARWIN}
uses
  LCLProc;

// A few C functions of macOS, declared here: FPC's Cocoa headers (CocoaAll)
// stop it with an internal error when it writes debug information for their
// Objective-C classes (dbgdwarf, 200609171), and the IDE is built with it.
const
  kCFStringEncodingUTF8 = $08000100;
  kCTFontManagerScopeProcess = 1;

function CFStringCreateWithCString(Alloc: Pointer; CStr: PAnsiChar; Encoding: LongWord): Pointer; cdecl;
  external name 'CFStringCreateWithCString';
function CFURLCreateFromFileSystemRepresentation(Alloc: Pointer; Buffer: PAnsiChar; BufLen: PtrInt;
  IsDirectory: Boolean): Pointer; cdecl; external name 'CFURLCreateFromFileSystemRepresentation';
procedure CFRelease(CF: Pointer); cdecl; external name 'CFRelease';
function CTFontManagerRegisterFontsForURL(FontURL: Pointer; Scope: LongWord; Error: PPointer): Boolean; cdecl;
  external name 'CTFontManagerRegisterFontsForURL';
function objc_getClass(Name: PAnsiChar): Pointer; cdecl; external name 'objc_getClass';
function sel_registerName(Name: PAnsiChar): Pointer; cdecl; external name 'sel_registerName';
procedure objc_msgSend; cdecl; external name 'objc_msgSend';

{$LINKFRAMEWORK CoreFoundation}
{$LINKFRAMEWORK CoreText}

type
  // objc_msgSend must be called with the exact types of each message (arm64)
  TMsgSend0 = function(Obj, Sel: Pointer): Pointer; cdecl;
  TMsgSend1 = function(Obj, Sel, Arg: Pointer): Pointer; cdecl;
  TMsgSendBool1 = function(Obj, Sel, Arg: Pointer): Boolean; cdecl;

procedure RegisterAppFonts(const DataDir: String);
var
  Files: TStringList;
  Rec: TSearchRec;
  Dirs: TStringList;
  Dir, FontFile: String;
  URL: Pointer;
  I: Integer;
begin
  Files := TStringList.Create;
  Dirs := TStringList.Create;
  try
    // Fonts/ and the folders under it (Heebo/static, Source_Code_Pro)
    Dirs.Add(IncludeTrailingPathDelimiter(DataDir) + 'Fonts');
    I := 0;
    while I < Dirs.Count do begin
      Dir := IncludeTrailingPathDelimiter(Dirs[I]);
      if FindFirst(Dir + '*', faAnyFile, Rec) = 0 then
        try
          repeat
            if (Rec.Name = '.') or (Rec.Name = '..') then
              Continue;
            if (Rec.Attr and faDirectory) <> 0 then
              Dirs.Add(Dir + Rec.Name)
            else if SameText(ExtractFileExt(Rec.Name), '.ttf') and (Pos('Variable', Rec.Name) = 0) then
              Files.Add(Dir + Rec.Name);
          until FindNext(Rec) <> 0;
        finally
          FindClose(Rec);
        end;
      Inc(I);
    end;
    for FontFile in Files do begin
      URL := CFURLCreateFromFileSystemRepresentation(nil, PAnsiChar(FontFile), Length(FontFile), False);
      if Assigned(URL) then begin
        // False when it is already there (the same font twice): nothing to do
        CTFontManagerRegisterFontsForURL(URL, kCTFontManagerScopeProcess, nil);
        CFRelease(URL);
      end;
    end;
  finally
    Dirs.Free;
    Files.Free;
  end;
end;

procedure SetDarkAppearance(Dark: Boolean);
var
  App, Name, Appearance, SetSel: Pointer;
begin
  // [NSApp setAppearance: [NSAppearance appearanceNamed: ...]] (macOS 10.14)
  App := TMsgSend0(@objc_msgSend)(objc_getClass('NSApplication'), sel_registerName('sharedApplication'));
  if not Assigned(App) then
    Exit;
  if Dark then
    Name := CFStringCreateWithCString(nil, 'NSAppearanceNameDarkAqua', kCFStringEncodingUTF8)
  else
    Name := CFStringCreateWithCString(nil, 'NSAppearanceNameAqua', kCFStringEncodingUTF8);
  try
    Appearance := TMsgSend1(@objc_msgSend)(objc_getClass('NSAppearance'), sel_registerName('appearanceNamed:'), Name);
    SetSel := sel_registerName('setAppearance:');
    if Assigned(Appearance) and TMsgSendBool1(@objc_msgSend)(App, sel_registerName('respondsToSelector:'), SetSel) then
      TMsgSend1(@objc_msgSend)(App, SetSel, Appearance);
  finally
    CFRelease(Name);
  end;
end;

function CommandShift: TShiftState;
begin
  Result := [ssMeta];
end;

// Command instead of Ctrl, but not where macOS answers first
function MacShortCut(Value: TShortCut): TShortCut;
var
  Key: Word;
begin
  Result := Value;
  if (Value and scCtrl) = 0 then
    Exit;
  Key := Value and $FF;
  if Key in [VK_SPACE, VK_TAB, VK_H, VK_M, VK_Q] then
    Exit;
  Result := (Value and not scCtrl) or scMeta;
end;

procedure UseCommandKey(Owner: TComponent);
var
  I, J: Integer;
  Action: TCustomAction;
  Item: TMenuItem;
  Texts: TStringList;
begin
  Texts := TStringList.Create;
  try
  for I := 0 to Owner.ComponentCount - 1 do
    if Owner.Components[I] is TCustomAction then begin
      Action := TCustomAction(Owner.Components[I]);
      Action.ShortCut := MacShortCut(Action.ShortCut);
      if Action.SecondaryShortCuts.Count > 0 then begin
        // Read-only one by one: the list is made again
        Texts.Clear;
        for J := 0 to Action.SecondaryShortCuts.Count - 1 do
          Texts.Add(ShortCutToText(MacShortCut(Action.SecondaryShortCuts.ShortCuts[J])));
        Action.SecondaryShortCuts.Clear;
        for J := 0 to Texts.Count - 1 do
          Action.SecondaryShortCuts.Add(Texts[J]);
      end;
    end else if Owner.Components[I] is TMenuItem then begin
      Item := TMenuItem(Owner.Components[I]);
      if not Assigned(Item.Action) then
        Item.ShortCut := MacShortCut(Item.ShortCut);
    end;
  finally
    Texts.Free;
  end;
end;

procedure AddMacKeystrokes(Keys: TSynEditKeyStrokes);

  procedure Add(ACommand: TSynEditorCommand; AKey: Word; AShift: TShiftState);
  var
    Index: Integer;
    Item: TSynEditKeyStroke;
  begin
    // A Linux key on the same combination (Alt+Shift+arrows: column
    // selection) gives way
    Index := Keys.FindKeycode(AKey, AShift);
    if Index <> -1 then
      Keys.Delete(Index);
    Item := Keys.Add;
    Item.Command := ACommand;
    Item.Key := AKey;
    Item.Shift := AShift;
  end;

begin
  Add(ecLineStart, VK_LEFT, [ssMeta]);
  Add(ecLineEnd, VK_RIGHT, [ssMeta]);
  Add(ecEditorTop, VK_UP, [ssMeta]);
  Add(ecEditorBottom, VK_DOWN, [ssMeta]);
  Add(ecWordLeft, VK_LEFT, [ssAlt]);
  Add(ecWordRight, VK_RIGHT, [ssAlt]);
  Add(ecSelLineStart, VK_LEFT, [ssMeta, ssShift]);
  Add(ecSelLineEnd, VK_RIGHT, [ssMeta, ssShift]);
  Add(ecSelEditorTop, VK_UP, [ssMeta, ssShift]);
  Add(ecSelEditorBottom, VK_DOWN, [ssMeta, ssShift]);
  Add(ecSelWordLeft, VK_LEFT, [ssAlt, ssShift]);
  Add(ecSelWordRight, VK_RIGHT, [ssAlt, ssShift]);
  Add(ecDeleteLastWord, VK_BACK, [ssAlt]);
  Add(ecDeleteBOL, VK_BACK, [ssMeta]);
end;

{$ELSE}

procedure RegisterAppFonts(const DataDir: String);
begin
end;

procedure SetDarkAppearance(Dark: Boolean);
begin
end;

function CommandShift: TShiftState;
begin
  Result := [ssCtrl];
end;

procedure UseCommandKey(Owner: TComponent);
begin
end;

procedure AddMacKeystrokes(Keys: TSynEditKeyStrokes);
begin
end;

{$ENDIF}

end.
