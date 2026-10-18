{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    Checks the IDE's forms (.lfm) against the classes they are loaded into,
    using RTTI only (no window is created, so it also runs without a display).
    The input is the list of checks written by lfmparse.py, one per line,
    tab separated:
      C  lfm  line  class                           a component class
      P  lfm  line  rootclass  class  path  value  [params]
                                                    a property or event; params
                                                    is the parameter list of the
                                                    method named by value, as
                                                    declared (kind:type,...|result)
      I  lfm  line  rootclass  class  collection  path  value
                                                    a collection item property
      X  lfm  line  message                         a problem lfmparse.py found
                                                    (image data the LCL can't read)
    Every class, property, enumeration/set value and event handler must exist;
    otherwise the window would raise an exception when it is opened.
    An event handler must also take the parameters of the event type: the
    LCL finds it by name only, and one written for a Delphi event with other
    parameters gets the wrong ones and writes over memory.
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

// Lazarus and Delphi names of the same type
function CanonicalType(const T: String): String;
begin
  Result := LowerCase(T);
  if Result = 'integer' then
    Result := 'longint'
  else if Result = 'cardinal' then
    Result := 'longword'
  else if Result = 'string' then
    Result := 'ansistring'
  else if Result = 'tgraphicscolor' then
    Result := 'tcolor';
end;

function CanonicalSignature(const S: String): String;
var
  Parts: TStringList;
  I, P: Integer;
  Res: String;
begin
  P := Pos('|', S);
  Res := CanonicalType(Copy(S, P + 1, MaxInt));
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ',';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := Copy(S, 1, P - 1);
    Result := '';
    for I := 0 to Parts.Count - 1 do begin
      P := Pos(':', Parts[I]);
      if I > 0 then
        Result := Result + ',';
      Result := Result + Copy(Parts[I], 1, P) + CanonicalType(Copy(Parts[I], P + 1, MaxInt));
    end;
  finally
    Parts.Free;
  end;
  Result := Result + '|' + Res;
end;

// The parameters of a method type, in the form lfmparse.py writes them
function EventSignature(T: PTypeInfo): String;
var
  D: PTypeData;
  P: PByte;
  I: Integer;
  Flags: TParamFlags;
  Kind, TypeName: String;
begin
  D := GetTypeData(T);
  P := @D^.ParamList[0];
  Result := '';
  for I := 1 to D^.ParamCount do begin
    Move(P^, Flags, SizeOf(Flags));
    Inc(P, SizeOf(Flags));
    Inc(P, P^ + 1); // ParamName
    SetString(TypeName, PChar(P + 1), P^);
    Inc(P, P^ + 1);
    // on CPUs that need aligned data (ARM, AArch64), each parameter starts
    // at the alignment of its flags; on x86-64 they follow each other
{$IFDEF FPC_REQUIRES_PROPER_ALIGNMENT}
    if I < D^.ParamCount then
      P := Align(P, SizeOf(Flags));
{$ENDIF}
    if Flags * [pfHidden, pfSelf, pfHigh, pfVmt, pfResult] <> [] then
      Continue;
    if pfVar in Flags then
      Kind := 'var'
    else if pfOut in Flags then
      Kind := 'out'
    else if pfConstRef in Flags then
      Kind := 'constref'
    else if pfConst in Flags then
      Kind := 'const'
    else
      Kind := '';
    if pfArray in Flags then
      TypeName := 'array of ' + TypeName;
    if Result <> '' then
      Result := Result + ',';
    Result := Result + Kind + ':' + LowerCase(TypeName);
  end;
  Result := Result + '|';
  if D^.MethodKind in [mkFunction, mkClassFunction] then begin
    SetString(TypeName, PChar(P + 1), P^);
    Result := Result + LowerCase(TypeName);
  end;
end;

function SplitSet(const S: String): TStringList;
begin
  Result := TStringList.Create;
  Result.Delimiter := ',';
  Result.StrictDelimiter := True;
  Result.DelimitedText := StringReplace(StringReplace(S, '[', '', []), ']', '', []);
end;

// Walks Path (Font.Style ...) from Cls; checks the value of enum/set/event properties
procedure CheckPath(const Where: String; RootCls, Cls: TClass; const Path, Value: String;
  const Params: String = '');
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
            Problem(Where, 'event handler not found: ' + RootCls.ClassName + '.' + Value + ' (' + Path + ')')
          else if (Params <> '') and
            (CanonicalSignature(Params) <> CanonicalSignature(EventSignature(PI^.PropType))) then
            Problem(Where, RootCls.ClassName + '.' + Value + ' has the parameters (' + Params +
              '), but ' + Path + ' is ' + PI^.PropType^.Name + ' (' + EventSignature(PI^.PropType) + ')');
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
          if F.Count >= 8 then
            CheckPath(Where, RootCls, Cls, F[5], F[6], F[7])
          else
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
