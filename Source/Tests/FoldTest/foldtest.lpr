{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    Checks where SynHighlighterCppFold opens and closes folds: braces, not
    braces in strings or comments, //#region, and a stray closing brace.
    With a file name as argument, also checks that its folds are balanced.
    Exits with 1 on a failure.
}
program foldtest;

{$MODE DELPHI}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, SysUtils, Classes, SynEditTextBuffer, SynHighlighterCppFold;

type
  TExpect = record
    Line: String;
    Open, Close, EndLevel: Integer;
  end;

const
  Sample: array[0..15] of TExpect = (
    (Line: '#include <cstdio>'; Open: 0; Close: 0; EndLevel: 0),
    (Line: '//#region helpers'; Open: 1; Close: 0; EndLevel: 1),
    (Line: 'int f(int x)'; Open: 0; Close: 0; EndLevel: 1),
    (Line: '{'; Open: 1; Close: 0; EndLevel: 2),
    (Line: '  if (x) { return 1; }'; Open: 0; Close: 0; EndLevel: 2), // opens and closes
    (Line: '  const char *s = "{ no }";'; Open: 0; Close: 0; EndLevel: 2), // in a string
    (Line: '  /* { not this'; Open: 0; Close: 0; EndLevel: 2), // in a comment
    (Line: '     } either */'; Open: 0; Close: 0; EndLevel: 2),
    (Line: '  for (;;) {'; Open: 1; Close: 0; EndLevel: 3),
    (Line: '    x--;'; Open: 0; Close: 0; EndLevel: 3),
    (Line: '  }'; Open: 0; Close: 1; EndLevel: 2),
    (Line: '  return 0;'; Open: 0; Close: 0; EndLevel: 2),
    (Line: '}'; Open: 0; Close: 1; EndLevel: 1),
    (Line: '//#endregion'; Open: 0; Close: 1; EndLevel: 0),
    (Line: '}'; Open: 0; Close: 0; EndLevel: 0), // stray: closes nothing
    (Line: 'int g() { return 2; }'; Open: 0; Close: 0; EndLevel: 0)
  );

var
  Failures: Integer = 0;

procedure Check(Lines: TSynEditStringList; const Name: String; Balanced: Boolean);
var
  HL: TSynCppFoldSyn;
  I, Opens, Closes: Integer;
begin
  HL := TSynCppFoldSyn.Create(nil);
  try
    HL.AttachToLines(Lines);
    HL.CurrentLines := Lines;
    HL.ScanRanges;
    Opens := 0;
    Closes := 0;
    for I := 0 to Lines.Count - 1 do begin
      Inc(Opens, HL.FoldBlockOpeningCount(I));
      Inc(Closes, HL.FoldBlockClosingCount(I));
      if not Balanced and ((HL.FoldBlockOpeningCount(I) <> Sample[I].Open) or
        (HL.FoldBlockClosingCount(I) <> Sample[I].Close) or (HL.FoldBlockEndLevel(I) <> Sample[I].EndLevel)) then begin
        WriteLn(Format('FAIL %s line %d "%s": open %d close %d level %d, expected %d %d %d',
          [Name, I, Lines[I], HL.FoldBlockOpeningCount(I), HL.FoldBlockClosingCount(I),
          HL.FoldBlockEndLevel(I), Sample[I].Open, Sample[I].Close, Sample[I].EndLevel]));
        Inc(Failures);
      end;
    end;
    if Balanced and ((Opens <> Closes) or (HL.FoldBlockEndLevel(Lines.Count - 1) <> 0)) then begin
      WriteLn(Format('FAIL %s: %d folds open, %d close, level %d at the end',
        [Name, Opens, Closes, HL.FoldBlockEndLevel(Lines.Count - 1)]));
      Inc(Failures);
    end;
    WriteLn(Format('%s: %d lines, %d folds', [Name, Lines.Count, Opens]));
    HL.DetachFromLines(Lines);
  finally
    HL.Free;
  end;
end;

var
  Lines: TSynEditStringList;
  I: Integer;
begin
  Application.Initialize;
  Lines := TSynEditStringList.Create;
  try
    for I := Low(Sample) to High(Sample) do
      Lines.Add(Sample[I].Line);
    Check(Lines, 'sample', False);
    if ParamCount > 0 then begin
      Lines.Clear;
      Lines.LoadFromFile(ParamStr(1));
      Check(Lines, ExtractFileName(ParamStr(1)), True);
    end;
  finally
    Lines.Free;
  end;
  if Failures > 0 then begin
    WriteLn(Failures, ' failure(s)');
    ExitCode := 1;
  end else
    WriteLn('OK');
end.
