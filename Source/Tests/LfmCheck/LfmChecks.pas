{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    Checks the IDE's forms (.lfm) against the classes they are loaded into,
    using RTTI only (no window is created, so it also runs without a display).
    The input is the list of checks written by lfmparse.py, one per line,
    tab separated:
      C  lfm  line  class                           a component class
      P  lfm  line  rootclass  class  path  value   a property or event
      I  lfm  line  rootclass  class  collection  path  value
                                                    a collection item property
      X  lfm  line  message                         a problem lfmparse.py found
                                                    (image data the LCL can't read)
    Every class, property, enumeration/set value and event handler must exist;
    otherwise the window would raise an exception when it is opened.
}

unit LfmChecks;

{$MODE DELPHI}

interface

// Returns the exit code: 0 when every check passes, 1 otherwise
function RunChecks(const FileName: String): Integer;

implementation

uses
  Classes, SysUtils, TypInfo, Controls, Forms, Graphics, ComCtrls, ImgList;

var
  Problems: Integer = 0;
  Instances: TStringList; // class name -> instance, to find collection item classes

procedure Problem(const Where, Msg: String);
begin
  WriteLn('  ', Where, ': ', Msg);
  Inc(Problems);
end;

// Properties the LCL streams through DefineProperties instead of RTTI
function IsDefinedProperty(Cls: TClass; const Name: String): Boolean;
begin
  Result :=
    ((SameText(Name, 'Left') or SameText(Name, 'Top')) and Cls.InheritsFrom(TComponent) and
      not Cls.InheritsFrom(TControl)) or
    (SameText(Name, 'Strings') and Cls.InheritsFrom(TStrings)) or
    (SameText(Name, 'Data') and (Cls.InheritsFrom(TGraphic) or Cls.InheritsFrom(TPicture))) or
    (SameText(Name, 'Bitmap') and Cls.InheritsFrom(TCustomImageList)) or
    (SameText(Name, 'Data') and Cls.InheritsFrom(TTreeNodes)) or
    (SameText(Name, 'ItemData') and Cls.InheritsFrom(TListItems));
end;

function SplitSet(const S: String): TStringList;
begin
  Result := TStringList.Create;
  Result.Delimiter := ',';
  Result.StrictDelimiter := True;
  Result.DelimitedText := StringReplace(StringReplace(S, '[', '', []), ']', '', []);
end;

// Walks Path (Font.Style ...) from Cls; checks the value of enum/set/event properties
procedure CheckPath(const Where: String; RootCls, Cls: TClass; const Path, Value: String);
var
  Parts: TStringList;
  I, J: Integer;
  PI: PPropInfo;
  Elements: TStringList;
  ElemType: PTypeInfo;
begin
  Parts := TStringList.Create;
  try
    Parts.Delimiter := '.';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := Path;
    for I := 0 to Parts.Count - 1 do begin
      PI := GetPropInfo(Cls, Parts[I]);
      if PI = nil then begin
        if not IsDefinedProperty(Cls, Parts[I]) then
          Problem(Where, 'unknown property ' + Cls.ClassName + '.' + Parts[I] + ' (' + Path + ')');
        Exit;
      end;
      if I < Parts.Count - 1 then begin
        if PI^.PropType^.Kind <> tkClass then begin
          Problem(Where, Path + ': ' + Parts[I] + ' is not an object');
          Exit;
        end;
        Cls := GetTypeData(PI^.PropType)^.ClassType;
        Continue;
      end;
      // last segment: validate the value where it is checkable
      case PI^.PropType^.Kind of
        tkMethod:
          if (Value <> '') and (RootCls.MethodAddress(Value) = nil) then
            Problem(Where, 'event handler not found: ' + RootCls.ClassName + '.' + Value + ' (' + Path + ')');
        tkEnumeration:
          if (Value <> '') and (Value[1] in ['A'..'Z', 'a'..'z', '_']) and
            (GetEnumValue(PI^.PropType, Value) < 0) and not SameText(PI^.PropType^.Name, 'Boolean') then
            Problem(Where, Path + ' = ' + Value + ': no such value in ' + PI^.PropType^.Name);
        tkSet:
          begin
            ElemType := GetTypeData(PI^.PropType)^.CompType;
            Elements := SplitSet(Value);
            try
              for J := 0 to Elements.Count - 1 do
                if (Trim(Elements[J]) <> '') and (GetEnumValue(ElemType, Trim(Elements[J])) < 0) then
                  Problem(Where, Path + ': no such value ' + Trim(Elements[J]) + ' in ' + ElemType^.Name);
            finally
              Elements.Free;
            end;
          end;
      end;
    end;
  finally
    Parts.Free;
  end;
end;

function InstanceOf(Cls: TClass): TComponent;
var
  I: Integer;
begin
  I := Instances.IndexOf(Cls.ClassName);
  if I >= 0 then
    Exit(TComponent(Instances.Objects[I]));
  Result := nil;
  if Cls.InheritsFrom(TCustomForm) or Cls.InheritsFrom(TDataModule) or Cls.InheritsFrom(TCustomFrame) then
    Exit; // these load their own .lfm when created
  try
    Result := TComponentClass(Cls).Create(nil);
  except
    Result := nil;
  end;
  Instances.AddObject(Cls.ClassName, Result);
end;

procedure CheckItem(const Where: String; RootCls, Cls: TClass; const Collection, Path, Value: String);
var
  Inst: TComponent;
  Obj: TObject;
begin
  if GetPropInfo(Cls, Collection) = nil then begin
    Problem(Where, 'unknown collection ' + Cls.ClassName + '.' + Collection);
    Exit;
  end;
  Inst := InstanceOf(Cls);
  if Inst = nil then
    Exit; // can't tell the item class; not checked
  Obj := GetObjectProp(Inst, Collection);
  if not (Obj is TCollection) then begin
    Problem(Where, Cls.ClassName + '.' + Collection + ' is not a collection');
    Exit;
  end;
  CheckPath(Where, RootCls, TCollection(Obj).ItemClass, Path, Value);
end;

function RunChecks(const FileName: String): Integer;
var
  Lines, F: TStringList;
  I: Integer;
  Where: String;
  Cls, RootCls: TClass;
begin
  Instances := TStringList.Create;
  Lines := TStringList.Create;
  F := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    F.Delimiter := #9;
    F.StrictDelimiter := True;
    for I := 0 to Lines.Count - 1 do begin
      F.DelimitedText := Lines[I];
      if F.Count < 4 then
        Continue;
      Where := F[1] + ':' + F[2];
      if F[0] = 'C' then begin
        if GetClass(F[3]) = nil then
          Problem(Where, 'unknown component class ' + F[3]);
      end else if (F[0] = 'P') and (F.Count >= 7) then begin
        RootCls := GetClass(F[3]);
        Cls := GetClass(F[4]);
        if (RootCls <> nil) and (Cls <> nil) then
          CheckPath(Where, RootCls, Cls, F[5], F[6]);
      end else if F[0] = 'X' then
        Problem(Where, F[3])
      else if (F[0] = 'I') and (F.Count >= 8) then begin
        RootCls := GetClass(F[3]);
        Cls := GetClass(F[4]);
        if (RootCls <> nil) and (Cls <> nil) then
          CheckItem(Where, RootCls, Cls, F[5], F[6], F[7]);
      end;
    end;
    WriteLn;
    WriteLn(Lines.Count, ' checks, ', Problems, ' problem(s)');
  finally
    F.Free;
    Lines.Free;
  end;
  Result := Ord(Problems > 0);
end;

end.
