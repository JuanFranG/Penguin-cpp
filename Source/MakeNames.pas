{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    File names in the Makefiles of projects (used by Compiler.pas; no LCL, so
    Tests/MakefileTest can build and run real Makefiles with them).

    A file name goes to two places with different rules. In a rule (target:
    prerequisites) make reads it: $ is written $$ and a space \ . In a recipe
    /bin/sh runs it after make: besides $$, it goes in single quotes, with ' as
    '\'', so $(...), `...`, ; or quotes in a name are text, never code. Some
    characters make cannot take in a name at all (MakeUnsafe).
}

unit MakeNames;

{$MODE DELPHI}

interface

const
  // Line breaks and tabs; % (pattern rules); : ; = | and # (rule syntax:
  // recipe on the same line, variable assignment, order-only prerequisites,
  // comment); \ ; and * ? [ ] (make expands them as wildcards)
  MakeUnsafeChars = [#0..#31, '%', ':', ';', '=', '|', '#', '\', '*', '?', '[', ']'];

// True when make cannot take S as a file name
function MakeUnsafe(const S: String): Boolean;

// A file name in a rule
function MakeRuleName(const S: String): String;

// A file name or argument in a recipe
function MakeShellArg(const S: String): String;

// A source file relative to the project file's folder (the Makefile's)
function MakeSourceName(const ProjectFile, SourceFile: String): String;

// Its object file: next to it, or in ObjectFolder, which may be relative to
// the project's folder ("obj"). ExtractRelativePath needs both names
// absolute; with a relative one it climbs to / ("../../../../main.o")
function MakeObjectName(const ProjectFile, SourceFile, ObjectFolder, ObjExt: String): String;

implementation

uses
  SysUtils;

function MakeUnsafe(const S: String): Boolean;
var
  I: integer;
begin
  for I := 1 to Length(S) do
    if S[I] in MakeUnsafeChars then
      Exit(True);
  Result := False;
end;

function MakeRuleName(const S: String): String;
begin
  Result := StringReplace(S, '$', '$$', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '\ ', [rfReplaceAll]);
end;

function MakeShellArg(const S: String): String;
begin
  Result := StringReplace(S, '$', '$$', [rfReplaceAll]);
  Result := '''' + StringReplace(Result, '''', '''\''''', [rfReplaceAll]) + '''';
end;

function MakeSourceName(const ProjectFile, SourceFile: String): String;
begin
  Result := ExtractRelativePath(ProjectFile, SourceFile);
end;

function MakeObjectName(const ProjectFile, SourceFile, ObjectFolder, ObjExt: String): String;
var
  Folder: String;
begin
  if ObjectFolder = '' then
    Exit(ChangeFileExt(MakeSourceName(ProjectFile, SourceFile), ObjExt));
  Folder := ObjectFolder;
  if Folder[1] <> PathDelim then // relative to the project's folder
    Folder := ExtractFilePath(ProjectFile) + Folder;
  Folder := IncludeTrailingPathDelimiter(ExpandFileName(Folder));
  Result := ExtractRelativePath(ProjectFile, Folder + ChangeFileExt(ExtractFileName(SourceFile), ObjExt));
end;

end.
