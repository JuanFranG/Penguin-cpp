{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    Tests GdbMI, the reader of gdb's machine interface, without gdb: lines
    as gdb 13-15 writes them, and those lines cut and damaged (the reader
    must never fail, and never leak). Run it through build.sh --run.
    Exit code 1 if any check fails.
}

program gdbmitest;

{$MODE DELPHI}

uses
  Classes, SysUtils, GdbMI;

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

const
  Breakpoint = '^done,bkpt={number="1",type="breakpoint",disp="keep",enabled="y",addr="0x0000000000001151",' +
    'func="main",file="hola mundo.c",fullname="/home/u/curso/hola mundo.c",line="5",thread-groups=["i1"],' +
    'times="0",original-location="/home/u/curso/hola mundo.c:5"}';
  Stopped = '*stopped,reason="breakpoint-hit",disp="keep",bkptno="1",frame={addr="0x0000555555555151",' +
    'func="main",args=[],file="hola mundo.c",fullname="/home/u/curso/hola mundo.c",line="5",' +
    'arch="i386:x86-64"},thread-id="1",stopped-threads="all",core="3"';
  Stack = '^done,stack=[frame={level="0",addr="0x0000555555555139",func="suma",file="hola.c",' +
    'fullname="/tmp/hola.c",line="3",arch="i386:x86-64"},frame={level="1",addr="0x000055555555516a",' +
    'func="main",file="hola.c",fullname="/tmp/hola.c",line="9",arch="i386:x86-64"}]';
  Children = '^done,numchild="2",children=[child={name="var1.x",exp="x",numchild="0",value="1",type="int",' +
    'thread-id="1"},child={name="var1.y",exp="y",numchild="0",value="2",type="int",thread-id="1"}],has_more="0"';
  Error = '12^error,msg="No symbol \"cuenta\" in current context."';
  Console = '~"Hola \"mundo\"\n\tcon \\ y acentos: \303\241\303\261\n"';
  Exited = '*stopped,reason="exited-normally"';

procedure TestRecords;
var
  R: TMIRecord;
begin
  WriteLn('Records:');
  R := ParseMILine(Breakpoint);
  try
    Check((R.Kind = mrResult) and (R.RecordClass = 'done') and (R.Token = -1), 'result record ^done');
    Check(R.Results.Get('bkpt.number') = '1', 'tuple value bkpt.number');
    Check(R.Results.Get('bkpt.file') = 'hola mundo.c', 'file name with a space');
    Check(R.Results.GetInt('bkpt.line') = 5, 'GetInt');
    Check((R.Results.Find('bkpt.thread-groups') <> nil) and (R.Results.Find('bkpt.thread-groups').Kind = mvList) and
      (R.Results.Find('bkpt.thread-groups')[0].Text = 'i1'), 'list of values');
  finally
    R.Free;
  end;

  R := ParseMILine(Stopped);
  try
    Check((R.Kind = mrExec) and (R.RecordClass = 'stopped'), 'exec record *stopped');
    Check(R.Results.Get('reason') = 'breakpoint-hit', 'reason');
    Check(R.Results.Get('frame.fullname') = '/home/u/curso/hola mundo.c', 'frame.fullname');
    Check((R.Results.Find('frame.args') <> nil) and (R.Results.Find('frame.args').Count = 0), 'empty list');
  finally
    R.Free;
  end;

  R := ParseMILine(Stack);
  try
    Check(R.Results.Find('stack').Count = 2, 'list of results: two frames');
    Check((R.Results.Find('stack')[1].Name = 'frame') and (R.Results.Find('stack')[1].Get('func') = 'main'),
      'second frame is main');
  finally
    R.Free;
  end;

  R := ParseMILine(Children);
  try
    Check((R.Results.GetInt('numchild') = 2) and (R.Results.Find('children')[1].Get('exp') = 'y'),
      'variable object children');
  finally
    R.Free;
  end;

  R := ParseMILine(Error);
  try
    Check((R.Kind = mrResult) and (R.RecordClass = 'error') and (R.Token = 12), 'error with token 12');
    Check(R.Results.Get('msg') = 'No symbol "cuenta" in current context.', 'escaped quotes in a message',
      R.Results.Get('msg'));
  finally
    R.Free;
  end;

  R := ParseMILine(Console);
  try
    Check(R.Kind = mrConsole, 'console stream ~');
    Check(R.Text = 'Hola "mundo"' + #10#9 + 'con \ y acentos: ' + #$C3#$A1#$C3#$B1 + #10,
      'escapes and UTF-8 in octal', QuotedStr(R.Text));
  finally
    R.Free;
  end;

  R := ParseMILine('(gdb) ');
  Check(R.Kind = mrPrompt, 'prompt');
  R.Free;
  R := ParseMILine('=thread-group-added,id="i1"');
  Check((R.Kind = mrNotify) and (R.Results.Get('id') = 'i1'), 'notify record =');
  R.Free;
  R := ParseMILine('^running');
  Check((R.Kind = mrResult) and (R.RecordClass = 'running') and (R.Results.Count = 0), 'result without results');
  R.Free;
  R := ParseMILine(Exited);
  Check(R.Results.Get('reason') = 'exited-normally', 'program exited');
  R.Free;
  R := ParseMILine('Hola desde el programa');
  Check((R.Kind = mrOther) and (R.Text = 'Hola desde el programa'), 'other text stays as it is');
  R.Free;
  R := ParseMILine('@"salida\n"' + #13);
  Check((R.Kind = mrTarget) and (R.Text = 'salida' + #10), 'target stream, line ending in CR');
  R.Free;
end;

procedure TestQuote;
var
  R: TMIRecord;
  S: String;
begin
  WriteLn('MIQuote:');
  S := 'mi "programa"\ con' + #10 + 'salto y ' + #$C3#$B1;
  Check(MIQuote('a b') = '"a b"', 'spaces stay in one argument');
  // Quoting and reading back gives the same text
  R := ParseMILine('~' + MIQuote(S));
  Check(R.Text = S, 'round trip through a C string', QuotedStr(R.Text));
  R.Free;
end;

// Cuts and damages: never an exception, every record freed (heaptrc)
procedure TestDamaged;
const
  Lines: array[0..6] of String = (Breakpoint, Stopped, Stack, Children, Error, Console, Exited);
  Junk = '"{}[],=\^*~0';
var
  I, J, N: Integer;
  S: String;
  R: TMIRecord;
  Crashed: Boolean;
begin
  WriteLn('Damaged lines:');
  Crashed := False;
  N := 0;
  RandSeed := 2026;
  try
    for I := 0 to High(Lines) do begin
      for J := 0 to Length(Lines[I]) do begin // every cut
        R := ParseMILine(Copy(Lines[I], 1, J));
        R.Free;
        Inc(N);
      end;
      for J := 1 to 300 do begin // random damage
        S := Lines[I];
        S[1 + Random(Length(S))] := Junk[1 + Random(Length(Junk))];
        if Random(2) = 0 then
          Delete(S, 1 + Random(Length(S)), 1 + Random(5));
        R := ParseMILine(S);
        R.Free;
        Inc(N);
      end;
    end;
  except
    on E: Exception do begin
      Crashed := True;
      WriteLn('  ', E.ClassName, ': ', E.Message);
    end;
  end;
  Check(not Crashed, IntToStr(N) + ' cut or damaged lines read without failing');

  R := ParseMILine('^done,bkpt={number="1",file="a.c",line="5"');
  Check((R.Kind = mrResult) and (R.Results.Get('bkpt.number') = '1'),
    'a cut tuple keeps what was read');
  R.Free;
end;

procedure TestValues;
var
  M: TStringList;
  N, V: String;
begin
  WriteLn('Values as gdb prints them:');
  M := TStringList.Create;
  try
    Check(SplitGdbValue('{x = 1, p = {a = 2, b = 3}, s = "a, {b}", c = 44 ' + #39 + ',' + #39 + '}', M) and
      (M.Count = 4) and (M[1] = 'p = {a = 2, b = 3}') and (M[2] = 's = "a, {b}"'),
      'members of a struct, strings and characters kept whole', M.CommaText);
    M.Clear;
    Check(SplitGdbValue('{1, 2, 0 <repeats 14 times>}', M) and (M.Count = 3) and (M[2] = '0 <repeats 14 times>'),
      'array elements', M.CommaText);
    M.Clear;
    Check(SplitGdbValue('{m = std::map<int, int> with 0 elements, v = 5}', M) and (M.Count = 2),
      'a comma inside <...> does not split', M.CommaText);
    M.Clear;
    Check(not SplitGdbValue('42', M) and not SplitGdbValue('{}', M) and (M.Count = 0), 'no members');
    Check(not SplitGdbValue('0x601040 <arr> "{x, y}"', M), 'a pointer to a string is not a struct');
  finally
    M.Free;
  end;
  SplitGdbMember('p = {a = 2, b = 3}', N, V);
  Check((N = 'p') and (V = '{a = 2, b = 3}'), 'name and value of a member', N + '|' + V);
  SplitGdbMember('"x = y"', N, V);
  Check((N = '') and (V = '"x = y"'), 'an array element has no name', N + '|' + V);
end;

begin
  TestRecords;
  TestQuote;
  TestValues;
  TestDamaged;
  WriteLn;
  if Failures > 0 then begin
    WriteLn(Failures, ' check(s) failed');
    Halt(1);
  end;
  WriteLn('All checks passed');
end.
