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

unit CodeInsList;

interface

uses
  LCLIntf, LCLType, Classes;

type
  PCodeIns = ^TCodeIns;
  TCodeIns = record
    Caption: String;
    Line: String;
    Desc: String;
    Sep: integer;
  end;

  TCodeInsList = class(TObject)
  private
    fFile: String;
    fList: TList;
    procedure SetItem(index: integer; Value: PCodeIns);
    function GetItem(index: integer): PCodeIns;
    function GetCount: integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadCode;
    procedure SaveCode;
    function AddItem(Value: PCodeIns): integer;
    procedure AddItemByValues(const menutext, description, code: String; section: integer);
    procedure Delete(index: integer);
    procedure Clear;
    property Items[index: integer]: PCodeins read GetItem write SetItem; default;
    property Count: integer read GetCount;
  end;

implementation

uses
  SysUtils, IniFiles, devCFG, Utils, Version, MultiLangSupport;

{ TCodeInsList }

constructor TCodeInsList.Create;
begin
  inherited Create;
  fList := TList.Create;
  fFile := devDirs.Config + DEV_CODEINS_FILE;
end;

destructor TCodeInsList.Destroy;
var
  I: integer;
begin
  for I := 0 to fList.Count - 1 do
    Dispose(PCodeIns(fList[I]));
  fList.Free;
  inherited Destroy;
end;

function TCodeInsList.AddItem(Value: PCodeIns): integer;
begin
  result := fList.Add(Value);
end;

procedure TCodeInsList.AddItemByValues(const menutext, description, code: String; section: integer);
var
  assembleditem: PCodeIns;
begin
  new(assembleditem);
  assembleditem^.Caption := menutext;
  assembleditem^.Line := code;
  assembleditem^.Desc := description;
  assembleditem^.Sep := section;
  fList.Add(assembleditem);
end;

procedure TCodeInsList.Clear;
var
  I: integer;
begin
  for I := 0 to fList.Count - 1 do
    Dispose(PCodeIns(fList[I])); // Free pointed memory first!
  fList.Clear;
end;

procedure TCodeInsList.Delete(index: integer);
begin
  if (index < 0) or (index > fList.Count - 1) then
    exit;

  // Free pointed memory first!
  Dispose(PCodeIns(fList[index]));
  fList.Delete(index);
end;

function TCodeInsList.GetCount: integer;
begin
  result := fList.Count;
end;

function TCodeInsList.GetItem(index: integer): PCodeIns;
begin
  if (index < 0) or (index > fList.Count - 1) then
    result := nil
  else
    result := PCodeIns(fList[index]);
end;

procedure TCodeInsList.SetItem(index: integer; Value: PCodeIns);
begin
  fList[index] := Value;
end;

procedure TCodeInsList.LoadCode;
var
  Item: PCodeIns;
  tmp: TStringList;
  I: integer;
begin
  if devData.First then begin
    // Generic C
    AddItemByValues('for()', 'for loop', 'for(*|*;;) {' + #13#10 + '}', 2);
    AddItemByValues('while()', 'while loop', 'while(*|*) {' + #13#10 + '}', 2);
    AddItemByValues('do-while()', 'do-while loop', 'do {' + #13#10 + '} while(*|*);', 2);
    AddItemByValues('if()', 'if statement', 'if(*|*) {' + #13#10 + '}', 2);
    AddItemByValues('switch()', 'switch statement', 'switch(*|*) {' + #13#10 + '	default:' + #13#10 + '}', 2);

    // C++
    AddItemByValues('Class', 'Class',

      'class *|* {' + #13#10 +
      '	// Private section' + #13#10 +
      '	public:' + #13#10 +
      '		// Public Declarations' + #13#10 +
      '	protected:' + #13#10 +
      '		// Protected Declarations' + #13#10 +
      '};', 2);

    AddItemByValues('Class Header Template', 'Class',

      '#ifndef SOMETHING_H' + #13#10 +
      '#define SOMETHING_H' + #13#10#13#10 +
      'class *|* {' + #13#10 +
      '	// Private section' + #13#10 +
      '	public:' + #13#10 +
      '		// Public Declarations' + #13#10 +
      '	protected:' + #13#10 +
      '		// Protected Declarations' + #13#10 +
      '};' + #13#10 + #13#10 +
      '#endif', 2);

    // Preprocessor
    AddItemByValues('#ifdef', 'Preprocessor if', '#ifdef *|*' + #13#10#13#10 + '#endif', 3);
    AddItemByValues('#ifndef', 'Preprocessor !if', '#ifndef *|*' + #13#10#13#10 + '#endif', 3);
    AddItemByValues('#ifdef/else', 'Preprocessor if-else', '#ifdef *|*' + #13#10#13#10 + '#elif' + #13#10#13#10 +
      '#endif', 3);
    AddItemByValues('#ifndef/else', 'Preprocessor !if-else', '#ifndef *|*' + #13#10#13#10 + '#elif' + #13#10#13#10 +
      '#endif', 3);

    // Save to disk as defaults
    SaveCode;

  end else if FileExists(fFile) then begin // no first time launch? load from disk
    with TINIFile.Create(fFile) do try
      tmp := TStringList.Create;
      Clear;
      try
        ReadSections(tmp);
        for I := 0 to tmp.Count - 1 do begin
          new(Item);
          Item^.Caption := StringReplace(tmp[I], '_', ' ', [rfReplaceAll]);
          Item^.Desc := ReadString(tmp[I], 'Desc', '');
          Item^.Line := StrtoCodeIns(ReadString(tmp[I], 'Line', ''));
          Item^.Sep := ReadInteger(tmp[I], 'Sep', 0);
          AddItem(Item);
        end;
      finally
        tmp.free;
      end;
    finally
      free;
    end;
  end;
end;

procedure TCodeInsList.SaveCode;
var
  I: integer;
  section: String;
  item: PCodeIns;
begin
  DeleteFile(fFile);
  if fList.Count = 0 then
    Exit;

  with TINIFile.Create(fFile) do try
    for I := 0 to pred(fList.Count) do begin
      item := PCodeIns(fList[I]);
      section := StringReplace(item^.Caption, ' ', '_', [rfReplaceAll]);
      WriteString(section, 'Desc', item^.Desc);
      WriteString(section, 'Line', CodeInstoStr(item^.Line));
      WriteInteger(section, 'Sep', item^.Sep);
    end;
  finally
    Free;
  end;
end;

end.

