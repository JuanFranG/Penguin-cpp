{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    Tests MakeNames, the file names in project Makefiles: first the
    functions, then a real project built, run and cleaned with make and cc.
    Its files have names with spaces, an apostrophe, $(...), backquotes and
    a subfolder, and its object folder is relative ("obj"); the Makefile has
    the shape Compiler.pas writes (CreateStandardMakefile). Nothing in the
    names may run, and every object must land in obj/ (a relative object
    folder once sent them to ../../../../main.o).
    Run it through build.sh --run. Exit code 1 if any check fails.
}

program makefiletest;

{$MODE DELPHI}

uses
  SysUtils, Classes, Process, MakeNames;

var
  Failures: Integer = 0;

procedure Check(Condition: Boolean; const Name: String; const Detail: String = '');
begin
  if Condition then
    WriteLn('  [OK]   ', Name)
  else begin
    WriteLn('  [FAIL] ', Name, ' ', Detail);
    Inc(Failures);
  end;
end;

procedure TestNames;
const
  P = '/home/u/curso/proyecto.dev';
begin
  WriteLn('Names:');
  Check(MakeRuleName('main file$x.c') = 'main\ file$$x.c', 'rule: space and $', MakeRuleName('main file$x.c'));
  Check(MakeShellArg('it''s $(x).c') = '''it''\''''s $$(x).c''', 'recipe: quotes and $', MakeShellArg('it''s $(x).c'));
  Check(MakeUnsafe('a:b.c') and MakeUnsafe('a;b.c') and MakeUnsafe('a%b.c') and MakeUnsafe('a' + #10 + 'b.c'),
    'make cannot take : ; % or a line break');
  Check(not MakeUnsafe('it''s $(x) `y` (1).c'), 'quotes, $, () and backquotes are fine');
  Check(MakeSourceName(P, '/home/u/curso/src/util.c') = 'src/util.c', 'source in a subfolder',
    MakeSourceName(P, '/home/u/curso/src/util.c'));
  Check(MakeObjectName(P, '/home/u/curso/src/util.c', '', '.o') = 'src/util.o', 'object next to its source',
    MakeObjectName(P, '/home/u/curso/src/util.c', '', '.o'));
  Check(MakeObjectName(P, '/home/u/curso/main.c', 'obj', '.o') = 'obj/main.o', 'relative object folder',
    MakeObjectName(P, '/home/u/curso/main.c', 'obj', '.o'));
  Check(MakeObjectName(P, '/home/u/curso/main.c', '../build', '.o') = '../build/main.o', 'object folder above',
    MakeObjectName(P, '/home/u/curso/main.c', '../build', '.o'));
  Check(MakeObjectName(P, '/home/u/curso/main.c', '/home/u/curso/obj', '.o') = 'obj/main.o',
    'absolute object folder', MakeObjectName(P, '/home/u/curso/main.c', '/home/u/curso/obj', '.o'));
end;

function Run(const Dir, Exe: String; const Args: array of String; out Output: String): Boolean;
begin
  Result := RunCommandInDir(Dir, Exe, Args, Output, [poStderrToOutPut]);
end;

function Found(const Exe: String): Boolean;
begin
  Result := ExeSearch(Exe, GetEnvironmentVariable('PATH')) <> '';
end;

procedure WriteText(const FileName, Text: String);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := Text;
    L.SaveToFile(FileName);
  finally
    L.Free;
  end;
end;

procedure TestProject(const Dir: String);
const
  ObjFolder = 'obj';
  // file name, function it defines, value it returns
  Sources: array[0..4] of String = ('main file.c', 'it''s.c', '$(touch pwned).c', '`touch pwned2`.c',
    'src' + PathDelim + 'util.c');
var
  ProjectFile, Program_, Make, Output, Objects, LinkObjects, Rules, Obj, Src: String;
  I: Integer;
begin
  WriteLn('Project built with make:');
  if not (Found('make') and Found('cc')) then begin
    WriteLn('  (skipped: make or cc is not installed)');
    Exit;
  end;
  ProjectFile := Dir + 'proyecto de prueba.dev';
  Program_ := Dir + 'mi programa';
  ForceDirectories(Dir + 'src');
  ForceDirectories(Dir + ObjFolder); // Compiler.NewMakeFile creates it too

  WriteText(Dir + Sources[0],
    '#include <stdio.h>' + LineEnding +
    'int f1(void); int f2(void); int f3(void); int f4(void);' + LineEnding +
    'int main(void) { printf("%d\n", f1() + f2() + f3() + f4()); return 0; }');
  WriteText(Dir + Sources[1], 'int f1(void) { return 1; }');
  WriteText(Dir + Sources[2], 'int f2(void) { return 20; }');
  WriteText(Dir + Sources[3], 'int f3(void) { return 300; }');
  WriteText(Dir + Sources[4], 'int f4(void) { return 4000; }');

  Objects := '';
  LinkObjects := '';
  Rules := '';
  for I := 0 to High(Sources) do begin
    Src := MakeSourceName(ProjectFile, Dir + Sources[I]);
    Obj := MakeObjectName(ProjectFile, Dir + Sources[I], ObjFolder, '.o');
    Check(not MakeUnsafe(Src) and not MakeUnsafe(Obj), 'make can take ' + Src);
    Objects := Objects + ' ' + MakeRuleName(Obj);
    LinkObjects := LinkObjects + ' ' + MakeShellArg(Obj);
    Rules := Rules + LineEnding + MakeRuleName(Obj) + ': ' + MakeRuleName(Src) + LineEnding +
      #9'$(CC) -c ' + MakeShellArg(Src) + ' -o ' + MakeShellArg(Obj) + ' $(CFLAGS)' + LineEnding;
  end;
  Make :=
    '# Project: proyecto de prueba' + LineEnding +
    'CPP      = c++' + LineEnding +
    'CC       = cc' + LineEnding +
    'OBJ      =' + Objects + LineEnding +
    'BIN      = ' + MakeRuleName(ExtractRelativePath(ProjectFile, Program_)) + LineEnding +
    'LIBS     = ' + LineEnding +
    'INCS     = ' + LineEnding +
    'CFLAGS   = $(INCS) ' + LineEnding +
    LineEnding +
    '.PHONY: all all-before all-after clean clean-custom' + LineEnding +
    LineEnding +
    'all: all-before $(BIN) all-after' + LineEnding +
    LineEnding +
    'clean: clean-custom' + LineEnding +
    #9'rm -f' + LinkObjects + ' ' + MakeShellArg(ExtractRelativePath(ProjectFile, Program_)) + LineEnding +
    LineEnding +
    '$(BIN): $(OBJ)' + LineEnding +
    #9'$(CC)' + LinkObjects + ' -o ' + MakeShellArg(ExtractRelativePath(ProjectFile, Program_)) + ' $(LIBS)' +
    LineEnding + Rules;
  WriteText(Dir + 'Makefile.test', Make);

  Check(Run(Dir, 'make', ['-f', 'Makefile.test', 'all'], Output), 'make all', Output);
  for I := 0 to High(Sources) do
    Check(FileExists(Dir + ObjFolder + PathDelim + ChangeFileExt(ExtractFileName(Sources[I]), '.o')),
      'object of ' + Sources[I] + ' in obj/');
  Check(FileExists(Program_), 'the program was linked');
  Check(Run(Dir, Program_, [], Output) and (Trim(Output) = '4321'), 'the program runs', QuotedStr(Output));
  Check(not FileExists(Dir + 'pwned') and not FileExists(Dir + 'pwned2'), 'nothing in the names ran');
  Check(Run(Dir, 'make', ['-f', 'Makefile.test', 'clean'], Output), 'make clean', Output);
  Check(not FileExists(Program_) and not FileExists(Dir + ObjFolder + PathDelim + 'main file.o'),
    'clean removes the program and the objects');
  Check(FileExists(Dir + Sources[2]) and FileExists(Dir + Sources[4]), 'clean keeps the sources');
end;

procedure RemoveTree(const Dir: String);
var
  R: TSearchRec;
begin
  if FindFirst(Dir + '*', faAnyFile, R) = 0 then begin
    repeat
      if (R.Name = '.') or (R.Name = '..') then
        Continue;
      if (R.Attr and faDirectory) <> 0 then
        RemoveTree(Dir + R.Name + PathDelim)
      else
        DeleteFile(Dir + R.Name);
    until FindNext(R) <> 0;
    FindClose(R);
  end;
  RemoveDir(Dir);
end;

var
  Dir: String;
begin
  TestNames;
  Dir := IncludeTrailingPathDelimiter(GetTempDir) + 'penguin-makefiletest-' + IntToStr(GetProcessID) + PathDelim;
  ForceDirectories(Dir);
  try
    TestProject(Dir);
  finally
    RemoveTree(Dir);
  end;
  WriteLn;
  if Failures > 0 then begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
  WriteLn('All checks passed');
end.
