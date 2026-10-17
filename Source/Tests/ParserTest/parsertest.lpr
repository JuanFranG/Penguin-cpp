{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    Console test for the C++ parser (Source/VCL/ClassBrowsing) without the IDE.
    It asks the system compiler for its include paths and predefined macros,
    parses one file with all its headers and checks that expected symbols exist
    (--expect) and that excluded ones don't (--reject). Exit code 1 on failure.

    usage: parsertest [--cxx COMPILER] [--expect NAME]... [--reject NAME]... [--list] [--no-system] FILE
}

program parsertest;

{$MODE DELPHI}

uses
  Classes, SysUtils, Process,
  CBUtils, StatementList, CppTokenizer, CppPreprocessor, CppParser;

var
  Compiler: String = 'c++';
  FileName: String = '';
  ListAll: Boolean = False;
  ParseSystem: Boolean = True;
  Expected, Rejected: TStringList;

procedure Fail(const Msg: String);
begin
  WriteLn(StdErr, 'error: ', Msg);
  Halt(2);
end;

procedure ParseArgs;
var
  I: Integer;
begin
  I := 1;
  while I <= ParamCount do begin
    if (ParamStr(I) = '--cxx') and (I < ParamCount) then begin
      Inc(I);
      Compiler := ParamStr(I);
    end else if (ParamStr(I) = '--expect') and (I < ParamCount) then begin
      Inc(I);
      Expected.Add(ParamStr(I));
    end else if (ParamStr(I) = '--reject') and (I < ParamCount) then begin
      Inc(I);
      Rejected.Add(ParamStr(I));
    end else if ParamStr(I) = '--list' then
      ListAll := True
    else if ParamStr(I) = '--no-system' then
      ParseSystem := False
    else
      FileName := ParamStr(I);
    Inc(I);
  end;
  if FileName = '' then
    Fail('usage: parsertest [--cxx COMPILER] [--expect NAME]... [--reject NAME]... [--list] [--no-system] FILE');
  FileName := ExpandFileName(FileName);
  if not FileExists(FileName) then
    Fail('file not found: ' + FileName);
end;

// Runs "<compiler> <args>" on an empty C++ input and returns stdout+stderr
function RunCompiler(const Args: array of String): String;
var
  AllArgs: array of String;
  I: Integer;
begin
  SetLength(AllArgs, Length(Args) + 3);
  for I := 0 to High(Args) do
    AllArgs[I] := Args[I];
  AllArgs[Length(Args)] := '-x';
  AllArgs[Length(Args) + 1] := 'c++';
  AllArgs[Length(Args) + 2] := '/dev/null';
  if not RunCommand(Compiler, AllArgs, Result, [poStderrToOutPut]) then
    Fail('could not run ' + Compiler);
end;

// gcc/clang print the search list between these two markers, one path per line
procedure GetIncludePaths(List: TStrings);
var
  Lines: TStringList;
  I: Integer;
  InList: Boolean;
  S: String;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := RunCompiler(['-E', '-v']);
    InList := False;
    for I := 0 to Lines.Count - 1 do begin
      S := Trim(Lines[I]);
      if StartsText('#include <...> search starts here', S) then
        InList := True
      else if StartsText('End of search list', S) then
        InList := False
      else if InList and (S <> '') and (Pos('(framework directory)', S) = 0) then
        List.Add(ExcludeTrailingPathDelimiter(S));
    end;
  finally
    Lines.Free;
  end;
end;

function FindStatement(Parser: TCppParser; const Name: String): PStatement;
var
  Node: PStatementNode;
begin
  Node := Parser.Statements.FirstNode;
  while Assigned(Node) do begin
    if Node^.Data^._Command = Name then
      Exit(Node^.Data);
    Node := Node^.NextNode;
  end;
  Result := nil;
end;

procedure Run;
var
  Tokenizer: TCppTokenizer;
  Preprocessor: TCppPreprocessor;
  Parser: TCppParser;
  Paths, Defines: TStringList;
  Node: PStatementNode;
  Statement: PStatement;
  Started: QWord;
  I, InFile, Missing: Integer;
begin
  Paths := TStringList.Create;
  Defines := TStringList.Create;
  Tokenizer := TCppTokenizer.Create(nil);
  Preprocessor := TCppPreprocessor.Create(nil);
  Parser := TCppParser.Create(nil);
  try
    GetIncludePaths(Paths);
    Defines.Text := RunCompiler(['-dM', '-E']);
    WriteLn('Compiler:  ', Compiler, ' (', Paths.Count, ' include dirs, ', Defines.Count, ' predefined macros)');
    for I := 0 to Paths.Count - 1 do
      WriteLn('  -I ', Paths[I]);

    Parser.Tokenizer := Tokenizer;
    Parser.Preprocessor := Preprocessor;
    Parser.Enabled := True;
    Parser.ParseLocalHeaders := True;
    Parser.ParseGlobalHeaders := ParseSystem;
    for I := 0 to Paths.Count - 1 do
      Parser.AddIncludePath(Paths[I]);
    for I := 0 to Defines.Count - 1 do
      if StartsStr('#define', Defines[I]) then
        Parser.AddHardDefineByLine(Defines[I]);

    WriteLn('Parsing:   ', FileName);
    Started := GetTickCount64;
    Parser.ParseFile(FileName, True, False, False);
    WriteLn('Done in ', GetTickCount64 - Started, ' ms: ', Parser.ScannedFiles.Count, ' files scanned, ',
      Parser.Statements.Count, ' statements');

    // Statements declared in the file itself
    WriteLn;
    WriteLn('Statements in ', ExtractFileName(FileName), ':');
    InFile := 0;
    Node := Parser.Statements.FirstNode;
    while Assigned(Node) do begin
      Statement := Node^.Data;
      if ListAll or (Statement^._FileName = FileName) then begin
        WriteLn(Format('  %5d  %-12s %s', [Statement^._Line, Parser.StatementKindStr(Statement^._Kind),
          Parser.PrettyPrintStatement(Statement)]));
        Inc(InFile);
      end;
      Node := Node^.NextNode;
    end;
    if InFile = 0 then
      WriteLn('  (none)');

    // Symbols that must have been found, mostly from system headers
    Missing := 0;
    if Parser.LastError <> '' then begin
      WriteLn;
      WriteLn('Parser stopped early: ', Parser.LastError);
      Inc(Missing);
    end;
    if Expected.Count > 0 then begin
      WriteLn;
      WriteLn('Expected symbols:');
      for I := 0 to Expected.Count - 1 do begin
        Statement := FindStatement(Parser, Expected[I]);
        if Assigned(Statement) then
          WriteLn(Format('  [OK]      %-16s %s  (%s:%d)', [Expected[I], Parser.StatementKindStr(Statement^._Kind),
            ExtractFileName(Statement^._FileName), Statement^._Line]))
        else begin
          WriteLn(Format('  [MISSING] %s', [Expected[I]]));
          Inc(Missing);
        end;
      end;
    end;
    // Symbols that must NOT be there, e.g. from #if branches that are not taken
    if Rejected.Count > 0 then begin
      WriteLn;
      WriteLn('Rejected symbols:');
      for I := 0 to Rejected.Count - 1 do begin
        Statement := FindStatement(Parser, Rejected[I]);
        if Assigned(Statement) then begin
          WriteLn(Format('  [FOUND]   %-16s (%s:%d)', [Rejected[I], ExtractFileName(Statement^._FileName),
            Statement^._Line]));
          Inc(Missing);
        end else
          WriteLn(Format('  [OK]      %s', [Rejected[I]]));
      end;
    end;
    if Missing > 0 then
      Halt(1);
  finally
    Parser.Free;
    Preprocessor.Free;
    Tokenizer.Free;
    Defines.Free;
    Paths.Free;
  end;
end;

begin
  Expected := TStringList.Create;
  Rejected := TStringList.Create;
  try
    ParseArgs;
    Run;
  finally
    Rejected.Free;
    Expected.Free;
  end;
end.
