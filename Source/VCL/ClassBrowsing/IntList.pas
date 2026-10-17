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

unit IntList;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

// Minimal growable list of integers used by the parser (skip list) and the
// preprocessor (#if branch stack). Replaces an earlier unit whose license
// only allowed non-commercial use.

interface

uses
  Classes, SysUtils;

type
  TIntList = class
  private
    FItems: array of Integer;
    FCount: Integer;
    function Get(Index: Integer): Integer;
    procedure Put(Index: Integer; Value: Integer);
    procedure CheckIndex(Index: Integer);
  public
    function Add(Value: Integer): Integer;
    procedure Clear;
    procedure Delete(Index: Integer);
    function IndexOf(Value: Integer): Integer;
    property Count: Integer read FCount;
    property Integers[Index: Integer]: Integer read Get write Put; default;
  end;

implementation

procedure TIntList.CheckIndex(Index: Integer);
begin
  if (Index < 0) or (Index >= FCount) then
    raise EListError.CreateFmt('List index out of bounds (%d)', [Index]);
end;

function TIntList.Get(Index: Integer): Integer;
begin
  CheckIndex(Index);
  Result := FItems[Index];
end;

procedure TIntList.Put(Index: Integer; Value: Integer);
begin
  CheckIndex(Index);
  FItems[Index] := Value;
end;

function TIntList.Add(Value: Integer): Integer;
begin
  if FCount = Length(FItems) then
    SetLength(FItems, 2 * FCount + 16);
  FItems[FCount] := Value;
  Result := FCount;
  Inc(FCount);
end;

procedure TIntList.Clear;
begin
  // Keep the allocated storage so the list can be reused cheaply
  FCount := 0;
end;

procedure TIntList.Delete(Index: Integer);
var
  I: Integer;
begin
  CheckIndex(Index);
  for I := Index to FCount - 2 do
    FItems[I] := FItems[I + 1];
  Dec(FCount);
end;

function TIntList.IndexOf(Value: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FItems[I] = Value then
      Exit(I);
  Result := -1;
end;

end.
