{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    Checks every form (.lfm) of the IDE against the classes it is loaded
    into; see LfmChecks.pas. Run it through check.sh, which writes the
    files included below (build/units.inc, build/classes.inc) and the list
    of checks. Exit code 1 if any check fails.
}

program lfmcheck;

{$MODE DELPHI}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Classes, SysUtils,
  // LCL units that declare the component classes of the forms
  Controls, StdCtrls, ExtCtrls, ComCtrls, Buttons, Menus, ActnList, Dialogs, ExtDlgs, Spin, Grids,
  ValEdit, CheckLst, ColorBox, ImgList, SynEdit, SynHighlighterCpp,
  // the IDE's units
  {$I build/units.inc}
  LfmChecks;

begin
  // forms find their component classes through the class registry
  RegisterClasses([
    {$I build/classes.inc}
  ]);
  Halt(RunChecks(ParamStr(1)));
end.
