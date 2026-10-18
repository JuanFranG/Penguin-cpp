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

unit Compiler;

interface

uses
  LCLIntf, LCLType, SysUtils, Dialogs, StdCtrls, Controls, ComCtrls, Forms, devRun, Version,
  Project, Utils, ProjectTypes, Classes, Graphics, devCFG;

type
  TLogEntryEvent = procedure(const Msg: String) of object;
  TOutputEvent = procedure(const _Line, _Col, _Unit, _Message: String) of object;
  TResOutputEvent = procedure(const _Line, _Col, _Unit, _Message: String) of object;
  TCompEndEvent = procedure of object;
  TCompSuccessEvent = procedure of object;
  TRunEndEvent = procedure of object;

  // Quotes one argument (a folder with -I or -L) for where it goes: a command
  // split by Process.CommandToList, or a Makefile recipe run by /bin/sh
  TArgQuote = function(const Arg: String): String;

  TTarget = (ctInvalid, ctNone, ctFile, ctProject);

  TCompiler = class
  private
    fOnLogEntry: TLogEntryEvent;
    fOnOutput: TOutputEvent;
    fOnResOutput: TResOutputEvent;
    fOnCompEnd: TCompEndEvent;
    fOnCompSuccess: TCompSuccessEvent;
    fOnRunEnd: TRunEndEvent;
    fProject: TProject;
    fSourceFile: String;
    fRunParams: String;
    fMakefile: String;
    fTarget: TTarget;
    fErrCount: integer;
    fCheckSyntax: Boolean;
    fWarnCount: integer;
    fStartTime: cardinal;
    fShowOutputInfo: boolean;
    fCompilerSet: TdevCompilerSet;
    procedure DoLogEntry(const msg: String);
    procedure DoOutput(const s1, s2, s3, s4: String);
    procedure DoResOutput(const s1, s2, s3, s4: String);
    function GetMakeFile: String;
    function GetCompiling: Boolean;
    procedure RunTerminate(Sender: TObject);
    procedure RunConsoleProgram(const FileToRun, Params, Dir: String);
    procedure InitProgressForm;
    procedure ProcessProgressForm(const Line: String);
    procedure EndProgressForm;
  public
    procedure BuildMakeFile;
    procedure CheckSyntax;
    procedure Compile;
    procedure Run;
    procedure Clean;
    procedure RebuildAll;
    property Compiling: Boolean read GetCompiling;
    property Project: TProject read fProject write fProject;
    property OnLogEntry: TLogEntryEvent read fOnLogEntry write fOnLogEntry;
    property OnOutput: TOutputEvent read fOnOutput write fOnOutput;
    property OnResOutput: TResOutputEvent read fOnResOutput write fOnResOutput;
    property OnCompEnd: TCompEndEvent read fOnCompEnd write fOnCompEnd;
    property OnCompSuccess: TCompSuccessEvent read fOnCompSuccess write fOnCompSuccess;
    property OnRunEnd: TRunEndEvent read fOnRunEnd write fOnRunEnd;
    property SourceFile: String read fSourceFile write fSourceFile;
    property CompilerSet: TdevCompilerSet read fCompilerSet write fCompilerSet;
    property RunParams: String read fRunParams write fRunParams; // only for nonproject compilations
    property MakeFile: String read GetMakeFile;
    property Target: TTarget read fTarget write fTarget;
    property WarningCount: integer read fWarnCount;
    property ErrorCount: integer read fErrCount;
    procedure AbortThread;
    procedure StopAndWait; // before the IDE closes
  protected
    fCompileParams: String;
    fCppCompileParams: String;
    fMakeParams: String;
    fLibrariesParams: String;
    fIncludesParams: String;
    fCppIncludesParams: String;
    fBinDirs: String;
    fDevRun: TDevRun;
    fAbortThread: boolean;
    procedure CreateStandardMakeFile; // executable creation
    procedure CreateStaticMakeFile; // static library creation
    procedure CreateDynamicMakeFile; // dynamic library creation
    procedure GetCompileParams;
    procedure GetLibrariesParams(Quote: TArgQuote = nil);
    procedure GetIncludesParams(Quote: TArgQuote = nil);
    function CheckMakeNames: Boolean;
    procedure LaunchThread(const s, dir: String);
    procedure ThreadCheckAbort(var AbortThread: boolean);
    procedure OnCompilationTerminated(Sender: TObject);
    procedure OnLineOutput(Sender: TObject; const Line: String);
    procedure ProcessOutput(const line: String);
    procedure NewMakeFile(var F: TextFile); // create a fits-all makefile
    procedure WriteMakeHeader(var F: TextFile); // append commented header
    procedure WriteMakeDefines(var F: TextFile); // append definitions
    procedure WriteMakeTarget(var F: TextFile); // append target definitions (PHONY, all)
    procedure WriteMakeIncludes(var F: TextFile); // append list of includes
    procedure WriteMakeClean(var F: TextFile); // append cleaning rules
    procedure WriteMakeObjFilesRules(var F: TextFile); // append linkage rules
  end;

implementation

uses
  UITypes, MultiLangSupport, Macros, devExec, main, StrUtils, Process, devPlatform;

procedure TCompiler.DoLogEntry(const msg: String);
begin
  if Assigned(fOnLogEntry) then
    fOnLogEntry(msg);
end;

procedure TCompiler.DoOutput(const s1, s2, s3, s4: String);
begin
  if Assigned(fOnOutput) then
    fOnOutput(s1, s2, s3, s4);
end;

procedure TCompiler.DoResOutput(const s1, s2, s3, s4: String);
begin
  if Assigned(fOnResOutput) then
    fOnResOutput(s1, s2, s3, s4);
end;

function TCompiler.GetMakeFile: String;
begin
  if not FileExists(fMakeFile) then
    BuildMakeFile;
  result := fMakefile;
end;

procedure TCompiler.BuildMakeFile;
begin
  if not Assigned(fProject) then begin
    fMakeFile := '';
    Exit;
  end else if fProject.Options.UseCustomMakefile then begin
    fMakefile := fProject.Options.CustomMakefile;
    Exit;
  end;

  // Names make cannot hold: no Makefile, and Compile stops (fMakefile = '')
  if not CheckMakeNames then begin
    fMakefile := '';
    Exit;
  end;

  case fProject.Options.typ of
    dptStat: CreateStaticMakeFile;
    dptDyn: CreateDynamicMakeFile;
  else
    CreateStandardMakeFile;
  end;

  if FileExists(fMakeFile) then
    FileSetDate(fMakefile, DateTimeToFileDate(Now)); // fix the "Clock skew detected" warning ;)
end;

{ Makefiles

  A file name goes to two places with different rules. In a rule (target:
  prerequisites) make reads it: $ is written $$ and a space \ . In a recipe
  /bin/sh runs it after make: besides $$, it goes in single quotes, with ' as
  '\'', so $(...), `...`, ; or quotes in a name are text, never code. Some
  characters make cannot take in a name at all (CheckMakeNames). }

const
  // Line breaks and tabs; % (pattern rules); : ; = | and # (rule syntax:
  // recipe on the same line, variable assignment, order-only prerequisites,
  // comment); \ ; and * ? [ ] (make expands them as wildcards)
  MakeUnsafeChars = [#0..#31, '%', ':', ';', '=', '|', '#', '\', '*', '?', '[', ']'];

function MakeUnsafe(const S: String): Boolean;
var
  I: integer;
begin
  for I := 1 to Length(S) do
    if S[I] in MakeUnsafeChars then
      Exit(True);
  Result := False;
end;

// A file name in a rule
function MakeRuleName(const S: String): String;
begin
  Result := StringReplace(S, '$', '$$', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '\ ', [rfReplaceAll]);
end;

// A file name or argument in a recipe
function MakeShellArg(const S: String): String;
begin
  Result := StringReplace(S, '$', '$$', [rfReplaceAll]);
  Result := '''' + StringReplace(Result, '''', '''\''''', [rfReplaceAll]) + '''';
end;

// An argument of a command split by Process.CommandToList (see Compile)
function CommandArg(const S: String): String;
begin
  Result := '"' + S + '"';
end;

// Source of unit I relative to the project (the Makefile's folder)
function UnitSource(Project: TProject; I: integer): String;
begin
  Result := ExtractRelativePath(Project.FileName, Project.Units[I].FileName);
end;

// Its object file: next to it, or in the project's object folder
function UnitObject(Project: TProject; I: integer): String;
begin
  if Project.Options.ObjectOutput <> '' then
    Result := ExtractRelativePath(Project.FileName, IncludeTrailingPathDelimiter(Project.Options.ObjectOutput) +
      ChangeFileExt(ExtractFileName(Project.Units[I].FileName), OBJ_EXT))
  else
    Result := ChangeFileExt(UnitSource(Project, I), OBJ_EXT);
end;

// Units that are compiled into objects: C and C++ sources (headers are not,
// and resource scripts are for Windows)
function UnitIsBuilt(Project: TProject; I: integer): Boolean;
begin
  Result := Project.Units[I].Compile and (GetFileTyp(Project.Units[I].FileName) in [utcSrc, utcppSrc]);
end;

// The object files to link, and the program, quoted for a recipe
function LinkObjects(Project: TProject): String;
var
  I: integer;
begin
  Result := '';
  for I := 0 to Project.Units.Count - 1 do
    if UnitIsBuilt(Project, I) and Project.Units[I].Link then
      Result := Result + ' ' + MakeShellArg(UnitObject(Project, I));
end;

// A program name that ends in ")" (Tarea (1)) is an archive member to make
// (archive(member)): it never sees the file and links it on every build.
// The result is right, so such names are not refused.
function ProgramArg(Project: TProject): String;
begin
  Result := MakeShellArg(ExtractRelativePath(Project.FileName, Project.Executable));
end;

function TCompiler.CheckMakeNames: Boolean;

  function Check(const Name: String): Boolean;
  begin
    Result := not MakeUnsafe(Name);
    if not Result then begin
      DoLogEntry(Format(Lang[ID_ERR_MAKEUNSAFENAME], [Name]));
      MessageDlg(Format(Lang[ID_ERR_MAKEUNSAFENAME], [Name]), mtError, [mbOK], 0);
    end;
  end;

var
  I: integer;
begin
  Result := False;
  if not Check(ExtractRelativePath(fProject.FileName, fProject.Executable)) then
    Exit;
  for I := 0 to fProject.Units.Count - 1 do
    if UnitIsBuilt(fProject, I) then
      if not Check(UnitSource(fProject, I)) or not Check(UnitObject(fProject, I)) then
        Exit;
  for I := 0 to fProject.Options.MakeIncludes.Count - 1 do
    if not Check(fProject.Options.MakeIncludes[I]) then
      Exit;
  Result := True;
end;

procedure TCompiler.NewMakeFile(var F: TextFile);
begin
  // Create OBJ output directory
  SetCurrentDir(fProject.Directory); // .dev file location
  if fProject.Options.ObjectOutput <> '' then
    ForceDirectories(fProject.Options.ObjectOutput);

  if not fProject.Options.ExeOutput.IsEmpty then
    ForceDirectories(fProject.Options.ExeOutput);

  // Should not return custom filename
  fMakefile := fProject.MakeFileName;

  // Write more information to the log file than before
  DoLogEntry(Lang[ID_LOG_BUILDINGMAKEFILE]);
  DoLogEntry('--------');
  DoLogEntry(Format(Lang[ID_LOG_MAKEFILENAME], [fMakefile]));

  // Create the actual file
  Assignfile(F, fMakefile);
  Rewrite(F);

  // Write header
  WriteMakeHeader(F);

  // Writes definition list
  WriteMakeDefines(F);

  // Write PHONY and all targets
  WriteMakeTarget(F);

  // Write list of includes
  WriteMakeIncludes(F);

  // Write clean command
  WriteMakeClean(F);
end;

procedure TCompiler.WriteMakeHeader(var F: TextFile);
begin
  // The name comes from the .dev file: one line, whatever it holds
  Writeln(F, '# Project: ' + StringReplace(StringReplace(fProject.Name, #13, ' ', [rfReplaceAll]), #10, ' ',
    [rfReplaceAll]));
  Writeln(F, '# Makefile created by ' + DEVCPP + ' ' + DEVCPP_VERSION);
  Writeln(F);
  if fCheckSyntax then begin
    Writeln(F, '# This Makefile is written for syntax check!');
    Writeln(F, '# Regenerate it if you want to use this Makefile to build.');
    Writeln(F);
  end;
end;

procedure TCompiler.WriteMakeDefines(var F: TextFile);
var
  Objects: String;
  I: integer;
begin
  // Object files, for the rules
  Objects := '';
  for I := 0 to fProject.Units.Count - 1 do
    if UnitIsBuilt(fProject, I) then
      Objects := Objects + ' ' + MakeRuleName(UnitObject(fProject, I));

  // Flags, with the folders quoted for /bin/sh
  GetCompileParams;
  GetLibrariesParams(MakeShellArg);
  GetIncludesParams(MakeShellArg);
  if fProject.Options.typ = dptDyn then begin // shared library: position independent code
    fCompileParams := fCompileParams + ' -fPIC';
    fCppCompileParams := fCppCompileParams + ' -fPIC';
  end;

  if (Pos(' -g3', fCompileParams) > 0) or (Pos('-g3', fCompileParams) = 1) then begin
    Writeln(F, 'CPP      = ' + fCompilerSet.gppName + ' -D__DEBUG__');
    Writeln(F, 'CC       = ' + fCompilerSet.gccName + ' -D__DEBUG__');
  end else begin
    Writeln(F, 'CPP      = ' + fCompilerSet.gppName);
    Writeln(F, 'CC       = ' + fCompilerSet.gccName);
  end;
  Writeln(F, 'OBJ      =' + Objects);
  Writeln(F, 'BIN      = ' + MakeRuleName(ExtractRelativePath(fProject.FileName, fProject.Executable)));
  Writeln(F, 'LIBS     = ' + fLibrariesParams);
  Writeln(F, 'INCS     = ' + fIncludesParams);
  Writeln(F, 'CXXINCS  = ' + fCppIncludesParams);
  Writeln(F, 'CXXFLAGS = $(CXXINCS) ' + fCppCompileParams);
  Writeln(F, 'CFLAGS   = $(INCS) ' + fCompileParams);
  Writeln(F);
end;

procedure TCompiler.WriteMakeTarget(var F: TextFile);
begin
  if fCheckSyntax then
    Writeln(F, '.PHONY: all all-before all-after clean clean-custom $(OBJ) $(BIN)')
  else
    Writeln(F, '.PHONY: all all-before all-after clean clean-custom');
  Writeln(F);
  Writeln(F, 'all: all-before $(BIN) all-after');
  Writeln(F);
end;

procedure TCompiler.WriteMakeIncludes(var F: TextFile);
var
  I: integer;
begin
  for I := 0 to fProject.Options.MakeIncludes.Count - 1 do
    Writeln(F, 'include ' + MakeRuleName(fProject.Options.MakeIncludes[I]));
  if fProject.Options.MakeIncludes.Count > 0 then
    Writeln(F);
end;

procedure TCompiler.WriteMakeObjFilesRules(var F: TextFile);
var
  I: integer;
  Source, ObjFile, BuildCmd: String;
begin
  for I := 0 to fProject.Units.Count - 1 do begin
    if not UnitIsBuilt(fProject, I) then
      Continue;
    Source := UnitSource(fProject, I);
    ObjFile := UnitObject(fProject, I);

    // objectfile: sourcefile
    Writeln(F);
    Writeln(F, MakeRuleName(ObjFile) + ': ' + MakeRuleName(Source));

    // Write custom build command
    if fProject.Units[I].OverrideBuildCmd and (fProject.Units[I].BuildCmd <> '') then begin
      BuildCmd := fProject.Units[I].BuildCmd;
      BuildCmd := StringReplace(BuildCmd, '<CRTAB>', #10#9, [rfReplaceAll]);
      Writeln(F, #9 + BuildCmd);

      // Or roll our own
    end else if fCheckSyntax then begin
      if fProject.Units[I].CompileCpp then
        Writeln(F, #9 + '$(CPP) -c ' + MakeShellArg(Source) + ' $(CXXFLAGS)')
      else
        Writeln(F, #9 + '$(CC) -c ' + MakeShellArg(Source) + ' $(CFLAGS)');
    end else begin
      if fProject.Units[I].CompileCpp then
        Writeln(F, #9 + '$(CPP) -c ' + MakeShellArg(Source) + ' -o ' + MakeShellArg(ObjFile) + ' $(CXXFLAGS)')
      else
        Writeln(F, #9 + '$(CC) -c ' + MakeShellArg(Source) + ' -o ' + MakeShellArg(ObjFile) + ' $(CFLAGS)');
    end;
  end;
  Writeln(F);
end;

procedure TCompiler.WriteMakeClean(var F: TextFile);
var
  I: integer;
  Files: String;
begin
  // rm -f with each name; Dev-C++ ran the IDE itself (INTERNAL_DEL) on $(OBJ)
  Files := '';
  for I := 0 to fProject.Units.Count - 1 do
    if UnitIsBuilt(fProject, I) then
      Files := Files + ' ' + MakeShellArg(UnitObject(fProject, I));
  Writeln(F, 'clean: clean-custom');
  Writeln(F, #9 + CLEAN_PROGRAM + Files + ' ' + ProgramArg(fProject));
  Writeln(F);
end;

procedure TCompiler.CreateStandardMakefile;
var
  F: TextFile;
begin
  try
    NewMakeFile(F);
    Writeln(F, '$(BIN): $(OBJ)');
    if not fCheckSyntax then
      if fProject.Options.useGPP then
        Writeln(F, #9 + '$(CPP)' + LinkObjects(fProject) + ' -o ' + ProgramArg(fProject) + ' $(LIBS)')
      else
        Writeln(F, #9 + '$(CC)' + LinkObjects(fProject) + ' -o ' + ProgramArg(fProject) + ' $(LIBS)');
    WriteMakeObjFilesRules(F);
  finally
    CloseFile(F);
  end;
end;

procedure TCompiler.CreateStaticMakeFile;
var
  F: TextFile;
begin
  try
    NewMakeFile(F);
    Writeln(F, '$(BIN): $(OBJ)');
    if not fCheckSyntax then begin
      Writeln(F, #9 + 'ar r ' + ProgramArg(fProject) + LinkObjects(fProject));
      Writeln(F, #9 + 'ranlib ' + ProgramArg(fProject));
    end;
    WriteMakeObjFilesRules(F);
  finally
    CloseFile(F);
  end;
end;

// A shared library (.so); the objects are built with -fPIC (WriteMakeDefines).
// Dev-C++ wrote a Windows DLL with its .def and import library.
procedure TCompiler.CreateDynamicMakeFile;
var
  F: TextFile;
begin
  try
    NewMakeFile(F);
    Writeln(F, '$(BIN): $(OBJ)');
    if not fCheckSyntax then begin
      if fProject.Options.useGPP then
        Writeln(F, #9 + '$(CPP) -shared' + LinkObjects(fProject) + ' -o ' + ProgramArg(fProject) + ' $(LIBS)')
      else
        Writeln(F, #9 + '$(CC) -shared' + LinkObjects(fProject) + ' -o ' + ProgramArg(fProject) + ' $(LIBS)');
    end;
    WriteMakeObjFilesRules(F);
  finally
    CloseFile(F);
  end;
end;

procedure TCompiler.GetCompileParams;
var
  I, val: integer;
  option: TCompilerOption;
begin
  // Force syntax checking when we have to
  if fCheckSyntax then begin
    fCompileParams := '-fsyntax-only';
    fCppCompileParams := '-fsyntax-only';
    fMakeParams := '';
  end else begin
    fCompileParams := '';
    fCppCompileParams := '';
    fMakeParams := '';
  end;

  // Walk all options
  for I := 0 to fCompilerSet.Options.Count - 1 do begin
    option := PCompilerOption(fCompilerSet.Options[I])^;

    // consider project specific options for the compiler, else global compiler options
    if (Assigned(fProject) and (I < Length(fProject.Options.CompilerOptions))) or (not Assigned(fProject) and
      (option.Value > 0)) then begin
      if option.IsC then begin
        if Assigned(option.Choices) then begin
          if Assigned(fProject) then
            val := fProject.Options.CompilerOptions[I]
          else
            val := option.Value;
          if (val > 0) and (val < option.Choices.Count) then
            fCompileParams := fCompileParams + ' ' + option.Setting +
              option.Choices.Values[option.Choices.Names[val]];
        end else if (Assigned(fProject) and (fProject.Options.CompilerOptions[I] = 1)) or (not
          Assigned(fProject)) then begin
          fCompileParams := fCompileParams + ' ' + option.Setting;
        end;
      end;
      if option.IsCpp then begin
        if Assigned(option.Choices) then begin
          if Assigned(fProject) then
            val := fProject.Options.CompilerOptions[I]
          else
            val := option.Value;
          if (val > 0) and (val < option.Choices.Count) then
            fCppCompileParams := fCppCompileParams + ' ' + option.Setting +
              option.Choices.Values[option.Choices.Names[val]];
        end else if (Assigned(fProject) and (fProject.Options.CompilerOptions[I] = 1)) or (not
          Assigned(fProject)) then begin
          fCppCompileParams := fCppCompileParams + ' ' + option.Setting;
        end;
      end;
       if (not option.IsC) AND (not option.IsCpp) AND (not option.IsLinker) then begin
        if option.Setting='-j' then
        begin
          if Assigned(option.Choices) then begin
            if Assigned(fProject) then
              val := fProject.Options.CompilerOptions[I]
            else
              val := option.Value;
            if (val > 0) and (val < option.Choices.Count) then
              fMakeParams := fMakeParams + ' ' + option.Setting +
                option.Choices.Values[option.Choices.Names[val]];
          end else if (Assigned(fProject) and (fProject.Options.CompilerOptions[I] = 1)) or (not
            Assigned(fProject)) then begin
            fMakeParams := fMakeParams + ' ' + option.Setting + option.Choices.Values[option.Choices.Names[val]];
          end;
        end;
      end;

    end;
  end;

  // Add custom commands inherited from Tools >> Compiler Options
  with fCompilerSet do begin
    if (Length(CompOpts) > 0) and AddtoComp then begin
      fCompileParams := fCompileParams + ' ' + CompOpts;
      fCppCompileParams := fCppCompileParams + ' ' + CompOpts;
    end;
  end;

  // Add custom commands at the end so the advanced user can control everything
  if Assigned(fProject) and (fTarget = ctProject) then begin
    if Length(fProject.Options.CompilerCmd) > 0 then
      fCompileParams := fCompileParams + ' ' + Trim(StringReplace(fProject.Options.CompilerCmd, '_@@_', ' ',
        [rfReplaceAll]));
    if Length(fProject.Options.CppCompilerCmd) > 0 then
      fCppCompileParams := fCppCompileParams + ' ' + Trim(StringReplace(fProject.Options.CppCompilerCmd, '_@@_', ' ',
        [rfReplaceAll]));
  end;

  fCompileParams := Trim(ParseMacros(fCompileParams));
  fCppCompileParams := Trim(ParseMacros(fCppCompileParams));
  fMakeParams := Trim(ParseMacros(fMakeParams));
end;

procedure TCompiler.CheckSyntax;
begin
  fCheckSyntax := True;
  Compile;
  fCheckSyntax := False;
end;

procedure TCompiler.Compile;
const
  // gcc, input, compileparams, includeparams, librariesparams
  cSyntaxCmdLine = '%s "%s" %s %s %s';
  // gcc, input, compileparams, includeparams, librariesparams
  cHeaderCmdLine = '%s "%s" %s %s %s';
  // gcc, input, output, compileparams, includeparams, librariesparams
  cSourceCmdLine = '%s "%s" -o "%s" %s %s %s';
  // make, makefile
  cMakeLine = '%s %s -f "%s" all';
var
  cmdline: String;
  s: String;
begin
  case Target of
    ctFile: begin
        // The commands are split into arguments at spaces outside quotes
        // (Process.CommandToList), so a " in the name would end the quoted
        // file name and turn the rest of it into options for gcc
        if Pos('"', fSourceFile) > 0 then begin
          MessageDlg(Format(Lang[ID_ERR_QUOTEDFILENAME], [fSourceFile]), mtError, [mbOK], 0);
          Exit;
        end;
        if GetFileTyp(fSourceFile) = utResSrc then begin
          MessageDlg(Lang[ID_ERR_NORESOURCES], mtInformation, [mbOK], 0);
          Exit;
        end;

        InitProgressForm;

        DoLogEntry(Lang[ID_LOG_COMPILINGFILE]);
        DoLogEntry('--------');
        DoLogEntry(Format(Lang[ID_LOG_SOURCEFILE], [fSourceFile]));
        DoLogEntry(Format(Lang[ID_LOG_COMPILERNAME], [fCompilerSet.Name]));
        DoLogEntry('');

        // Gather commands to pass to gcc/g++
        GetCompileParams;
        GetLibrariesParams;
        GetIncludesParams;

        // Determine command line to execute
        case GetFileTyp(fSourceFile) of
          utcSrc: begin
              s := fCompilerSet.gccName;
              if fCheckSyntax then
                cmdline := Format(cSyntaxCmdLine, [s, fSourceFile, fCompileParams, fIncludesParams, fLibrariesParams])
              else
                cmdline := Format(cSourceCmdLine, [s, fSourceFile, ChangeFileExt(fSourceFile, EXE_EXT), fCompileParams,
                  fIncludesParams, fLibrariesParams]);

              DoLogEntry(Lang[ID_LOG_PROCESSINGCSRC]);
              DoLogEntry('--------');
              DoLogEntry(Format(Lang[ID_LOG_GCCNAME],
                [IncludeTrailingPathDelimiter(fCompilerSet.BinDir[0]) + s]));
              DoLogEntry(Format(Lang[ID_LOG_COMMAND], [cmdLine]));
            end;
          utCppSrc: begin
              s := fCompilerSet.gppName;
              if fCheckSyntax then
                cmdline := Format(cSyntaxCmdLine, [s, fSourceFile, fCppCompileParams, fCppIncludesParams,
                  fLibrariesParams])
              else
                cmdline := Format(cSourceCmdLine, [s, fSourceFile, ChangeFileExt(fSourceFile, EXE_EXT),
                  fCppCompileParams, fCppIncludesParams, fLibrariesParams]);

              DoLogEntry(Lang[ID_LOG_PROCESSINGCPPSRC]);
              DoLogEntry('--------');
              DoLogEntry(Format(Lang[ID_LOG_GPPNAME],
                [IncludeTrailingPathDelimiter(fCompilerSet.BinDir[0]) + s]));
              DoLogEntry(Format(Lang[ID_LOG_COMMAND], [cmdLine]));
            end;
          utcHead, utcppHead: begin // any header files
              s := fCompilerSet.gppName;
              if fCheckSyntax then
                cmdline := Format(cSyntaxCmdLine, [s, fSourceFile, fCppCompileParams, fCppIncludesParams,
                  fLibrariesParams])
              else
                cmdline := Format(cHeaderCmdLine, [s, fSourceFile, fCompileParams, fIncludesParams,
                  fLibrariesParams]);

              DoLogEntry(Lang[ID_LOG_PROCESSINGHEADER]);
              DoLogEntry('--------');
              DoLogEntry(Format(Lang[ID_LOG_GCCNAME],
                [IncludeTrailingPathDelimiter(fCompilerSet.BinDir[0]) + s]));
              DoLogEntry(Format(Lang[ID_LOG_COMMAND], [cmdLine]));
            end;
        else begin
            s := fCompilerSet.gppName;
            if fCheckSyntax then
              cmdline := Format(cSyntaxCmdLine, [s, fSourceFile, fCppCompileParams, fCppIncludesParams,
                fLibrariesParams])
            else
              cmdline := Format(cHeaderCmdLine, [s, fSourceFile, fCompileParams, fIncludesParams, fLibrariesParams]);

            DoLogEntry(Lang[ID_LOG_PROCESSINGUNKNOWN]);
            DoLogEntry('--------');
            DoLogEntry(Format(Lang[ID_LOG_GCCNAME],
              [IncludeTrailingPathDelimiter(fCompilerSet.BinDir[0]) + s]));
            DoLogEntry(Format(Lang[ID_LOG_COMMAND], [cmdLine]));
          end;
        end;

        // Execute it
        LaunchThread(cmdline, ExtractFilePath(fSourceFile));
      end;
    ctProject: begin
        InitProgressForm;

        DoLogEntry(Lang[ID_LOG_PROJECTCOMPILE]);
        DoLogEntry('--------');
        DoLogEntry(Format(Lang[ID_LOG_PROJECTFILE], [fProject.FileName]));
        DoLogEntry(Format(Lang[ID_LOG_COMPILERNAME], [fCompilerSet.Name]));
        DoLogEntry('');

        // The path of the Makefile goes in double quotes (see the ctFile case)
        if Pos('"', fProject.FileName) > 0 then begin
          MessageDlg(Format(Lang[ID_ERR_QUOTEDFILENAME], [fProject.FileName]), mtError, [mbOK], 0);
          EndProgressForm;
          Exit;
        end;
        BuildMakeFile;
        if fMakeFile = '' then begin // a name make cannot take (CheckMakeNames)
          EndProgressForm;
          Exit;
        end;
        cmdline := Format(cMakeLine, [fCompilerSet.makeName, fMakeParams, fMakeFile]);

        DoLogEntry(Lang[ID_LOG_PROCESSINGMAKE]);
        DoLogEntry('--------');
        DoLogEntry(Format(Lang[ID_LOG_MAKEFILEPROC], [IncludeTrailingPathDelimiter(fCompilerSet.BinDir[0]) +
          fCompilerSet.MakeName]));
        DoLogEntry(Format(Lang[ID_LOG_COMMAND], [cmdLine]));
        DoLogEntry('');

        // Execute it
        LaunchThread(cmdline, ExtractFilePath(Project.FileName));
      end;
  end;
end;

procedure TCompiler.RunTerminate(Sender: TObject);
begin
  Application.Restore;

  OnRunEnd;

  MainForm.UpdateAppTitle;
end;

// Console programs run in a terminal window: on Linux nothing shows their
// output otherwise. Dev-C++'s ConsolePauser (Windows only) is a sh script
// here (devPlatform.BuildTerminalCommand). Without a terminal the program
// still runs, unseen, and the user is told.
procedure TCompiler.RunConsoleProgram(const FileToRun, Params, Dir: String);
var
  Command, Args: TStringList;
  Terminal: String;
begin
  Command := TStringList.Create;
  Args := TStringList.Create;
  try
    Command.Add(FileToRun);
    CommandToList(Params, Command); // appends the program's arguments
    if BuildTerminalCommand(Command, devData.ConsolePause, Lang[ID_RUN_EXITED], Lang[ID_RUN_PRESSENTER],
      Terminal, Args) then
      devExecutor.ExecuteAndWatch(Terminal, Args, Dir, RunTerminate)
    else begin
      MessageDlg(Lang[ID_RUN_NOTERMINAL], mtWarning, [mbOK], 0);
      devExecutor.ExecuteAndWatch(FileToRun, Params, Dir, True, INFINITE, RunTerminate);
    end;
  finally
    Args.Free;
    Command.Free;
  end;
end;

procedure TCompiler.Run;
var
  FileToRun: String;
begin
  case fTarget of
    ctNone:
      Exit;
    ctFile: begin
        // Determine file to execute
        case GetFileTyp(fSourceFile) of
          utcSrc, utcppSrc: begin
              FileToRun := ChangeFileExt(fSourceFile, EXE_EXT);
            end;
          //else begin
          //    Exit; // nothing to run...
          //  end;
        end;

        // Check if it exists
        if not FileExists(FileToRun) then begin
          if MainForm.actCompRun.Enabled then begin // suggest a compile
            if MessageDlg(Lang[ID_ERR_SRCNOTCOMPILEDSUGGEST], mtConfirmation, [mbYes, mbNo], 0) = mrYes then begin
              MainForm.actCompRunExecute(nil);
            end;
          end else
            MessageDlg(Lang[ID_ERR_SRCNOTCOMPILED], mtWarning, [mbOK], 0);
        end else begin

          if devData.MinOnRun then
            Application.Minimize;
          RunConsoleProgram(FileToRun, fRunParams, ExtractFilePath(fSourceFile));
          MainForm.UpdateAppTitle;
        end;
      end;
    ctProject: begin
        if fProject.Options.typ = dptStat then
          MessageDlg(Lang[ID_ERR_NOTEXECUTABLE], mtError, [mbOK], 0)
        else if not FileExists(fProject.Executable) then begin
          if MainForm.actCompRun.Enabled then begin // suggest a compile
            if MessageDlg(Lang[ID_ERR_PROJECTNOTCOMPILEDSUGGEST], mtConfirmation, [mbYes, mbNo], 0) = mrYes then begin
              MainForm.actCompRunExecute(nil); // move this to mainform?
            end;
          end else
            MessageDlg(Lang[ID_ERR_SRCNOTCOMPILED], mtWarning, [mbOK], 0);
        end else if fProject.Options.typ = dptDyn then begin
          if fProject.Options.HostApplication = '' then
            MessageDlg(Lang[ID_ERR_HOSTMISSING], mtWarning, [mbOK], 0)
          else if not FileExists(fProject.Options.HostApplication) then
            MessageDlg(Lang[ID_ERR_HOSTNOTEXIST], mtWarning, [mbOK], 0)
          else begin // execute DLL's host application
            if devData.MinOnRun then
              Application.Minimize;
            devExecutor.ExecuteAndWatch(fProject.Options.HostApplication, fRunParams,
              ExtractFileDir(fProject.Options.HostApplication), True, INFINITE, RunTerminate);
            MainForm.UpdateAppTitle;
          end;
        end else begin // execute normally
          if devData.MinOnRun then
            Application.Minimize;
          if fProject.Options.typ = dptGUI then // has its own windows
            devExecutor.ExecuteAndWatch(fProject.Executable, fProject.Options.CmdLineArgs,
              ExtractFileDir(fProject.Executable), True, INFINITE, RunTerminate)
          else
            RunConsoleProgram(fProject.Executable, fProject.Options.CmdLineArgs, ExtractFileDir(fProject.Executable));
          MainForm.UpdateAppTitle;
        end;
      end;
  end;
end;

// Whether a file is a compiled program: ELF ($7F 'E' 'L' 'F')
function IsProgramFile(const FileName: String): Boolean;
var
  F: TFileStream;
  Magic: array[0..3] of Char;
begin
  Result := False;
  try
    F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      Result := (F.Read(Magic, SizeOf(Magic)) = SizeOf(Magic)) and (Magic = #$7F'ELF');
    finally
      F.Free;
    end;
  except
    // unreadable: leave it alone
  end;
end;

procedure TCompiler.Clean;
const
  cCleanLine = '%s clean -f "%s"';
  cmsg = 'make clean';
var
  cmdLine: String;
  FileName: String;
begin
  case fTarget of
    ctFile: begin
        InitProgressForm;

        DoLogEntry(Lang[ID_LOG_CLEANINGFILE]);
        DoLogEntry('--------');
        DoLogEntry(Format(Lang[ID_LOG_SOURCEFILE], [fSourceFile]));
        DoLogEntry(Format(Lang[ID_LOG_COMPILERNAME], [fCompilerSet.Name]));
        DoLogEntry('');

        FileName := '';
        case GetFileTyp(fSourceFile) of
          utresSrc: begin
              FileName := ChangeFileExt(fSourceFile, OBJ_EXT);
            end;
          utcSrc: begin
              FileName := ChangeFileExt(fSourceFile, EXE_EXT);
            end;
          utcppSrc: begin
              FileName := ChangeFileExt(fSourceFile, EXE_EXT);
            end;
        else begin
            FileName := fSourceFile + GCH_EXT;
          end;
        end;
        // Programs have no extension on Linux: main.cpp builds main. Only
        // delete a program (ELF) by that name, not another file of the user's.
        if FileExists(FileName) and (not (GetFileTyp(fSourceFile) in [utcSrc, utcppSrc]) or IsProgramFile(FileName))
        then begin
          DoLogEntry(Format(Lang[ID_LOG_CLEANEDFILE], [FileName]));
          DeleteFile(FileName);
        end else
          DoLogEntry(Lang[ID_LOG_NOCLEANFILE]);
      end;
    ctProject: begin
        InitProgressForm;

        DoLogEntry(Lang[ID_LOG_CLEANINGPROJECT]);
        DoLogEntry('--------');
        DoLogEntry(Format(Lang[ID_LOG_PROJECTFILE], [fProject.FileName]));
        DoLogEntry(Format(Lang[ID_LOG_COMPILERNAME], [fCompilerSet.Name]));
        DoLogEntry('');

        // Try to create a makefile that cleans for the whole project...
        BuildMakeFile;
        if not FileExists(fMakefile) then begin
          DoLogEntry(Lang[ID_ERR_NOMAKEFILE]);
          DoLogEntry(Lang[ID_ERR_CLEANFAILED]);
          Application.MessageBox(PChar(Lang[ID_ERR_NOMAKEFILE]), PChar(Lang[ID_ERROR]), MB_OK or
            MB_ICONERROR);
          Exit;
        end;

        cmdLine := Format(cCleanLine, [fCompilerSet.makeName, fMakeFile]);

        DoLogEntry(Lang[ID_LOG_PROCESSINGMAKE]);
        DoLogEntry('--------');
        DoLogEntry(Format(Lang[ID_LOG_MAKEFILEPROC], [IncludeTrailingPathDelimiter(fCompilerSet.BinDir[0]) +
          fCompilerSet.MakeName]));
        DoLogEntry(Format(Lang[ID_LOG_COMMAND], [cmdLine]));
        DoLogEntry('');

        // Let make parse the makefile
        LaunchThread(cmdLine, fProject.Directory);
      end;
  end;
end;

procedure TCompiler.RebuildAll; // TODO: unite with TCompiler.Clean?
const
  cCleanLine = '%s -f "%s" clean all';
var
  cmdLine: String;
begin
  case Target of
    ctFile: begin
        Compile;
      end;
    ctProject: begin
        InitProgressForm;

        DoLogEntry(Lang[ID_LOG_REBUILDINGPROJECT]);
        DoLogEntry('--------');
        DoLogEntry(Format(Lang[ID_LOG_PROJECTFILE], [fProject.FileName]));
        DoLogEntry(Format(Lang[ID_LOG_COMPILERNAME], [fCompilerSet.Name]));
        DoLogEntry('');

        // Try to create a makefile for the whole project...
        BuildMakeFile;
        if not FileExists(fMakefile) then begin
          DoLogEntry(Lang[ID_ERR_NOMAKEFILE]);
          DoLogEntry(Lang[ID_ERR_CLEANFAILED]);
          Application.MessageBox(PChar(Lang[ID_ERR_NOMAKEFILE]), PChar(Lang[ID_ERROR]), MB_OK or
            MB_ICONERROR);
          Exit;
        end;

        cmdLine := Format(cCleanLine, [fCompilerSet.makeName, fMakeFile]);

        DoLogEntry(Lang[ID_LOG_PROCESSINGMAKE]);
        DoLogEntry('--------');
        DoLogEntry(Format(Lang[ID_LOG_MAKEFILEPROC],
          [IncludeTrailingPathDelimiter(fCompilerSet.BinDir[0]) + fCompilerSet.MakeName]));
        DoLogEntry(Format(Lang[ID_LOG_COMMAND], [cmdLine]));
        DoLogEntry('');

        // Let make parse the makefile
        LaunchThread(cmdLine, fProject.Directory);
      end;
  end;
end;

procedure TCompiler.LaunchThread(const s, dir: String);
begin
  if Assigned(fDevRun) then
    MessageDlg(Lang[ID_MSG_ALREADYCOMP], mtInformation, [mbOK], 0)
  else begin
    fAbortThread := False;
    fDevRun := TDevRun.Create(true);
    fDevRun.Command := s;
    fDevRun.Directory := dir;
    fDevRun.OnTerminate := OnCompilationTerminated;
    fDevRun.OnLineOutput := OnLineOutput;
    fDevRun.OnCheckAbort := ThreadCheckAbort;
    fDevRun.FreeOnTerminate := True;
    fDevRun.Start;

    MainForm.UpdateAppTitle;
  end;
end;

procedure TCompiler.ThreadCheckAbort(var AbortThread: boolean);
begin
  AbortThread := fAbortThread;
end;

// The compile thread calls back into this object (Synchronize, OnTerminate):
// stop it and let those calls run before the IDE frees it
procedure TCompiler.StopAndWait;
var
  Started: QWord;
begin
  if not Assigned(fDevRun) then
    Exit;
  AbortThread;
  Started := GetTickCount64;
  while Assigned(fDevRun) and (GetTickCount64 - Started < 5000) do
    CheckSynchronize(20);
end;

procedure TCompiler.AbortThread;
begin
  if not Assigned(fDevRun) then
    Exit;
  fAbortThread := True;
end;

procedure TCompiler.OnCompilationTerminated(Sender: TObject);
begin
  OnCompEnd;

  fDevRun := nil;

  MainForm.UpdateAppTitle;

  EndProgressForm;

  if (fErrCount = 0) and not fAbortThread then
    OnCompSuccess;
end;

procedure TCompiler.OnLineOutput(Sender: TObject; const Line: String);
var
  List: TStringList;
  I: integer;
begin
  DoLogEntry(Line);

  List := TStringList.Create;
  List.Text := Line;
  for I := 0 to List.Count - 1 do begin
    ProcessOutput(List.Strings[I]);
    ProcessProgressForm(List.Strings[I]);
  end;
  List.Free;
end;

procedure TCompiler.ProcessOutput(const line: String);
var
  OLine, OCol, OFile, OMsg, S: String;
  delim: integer;

  procedure GetFileName; // obtain delimiter AFTER (full) filename
  begin
    OMsg := Trim(OMsg);
    if (Length(OMsg) > 2) and (OMsg[2] = ':') then begin // full file path at start, ignore this one
      delim := FPos(':', OMsg, 3);
    end else begin // find first
      delim := FPos(':', OMsg, 1);
    end;

    if delim > 0 then begin
      OFile := Copy(OMsg, 1, delim - 1);
      Delete(OMsg, 1, delim);
    end;
  end;

  procedure GetLineNumber;
  begin
    OMsg := Trim(OMsg);
    delim := FPos(':', OMsg, 1);
    if delim = 0 then
      delim := FPos(',', OMsg, 1);
    if delim > 0 then begin
      OLine := Copy(OMsg, 1, delim - 1);
      if StrToIntDef(OLine, -1) = -1 then // don't accept
        OLine := ''
      else
        Delete(OMsg, 1, delim);
    end;
  end;

  procedure GetColNumber;
  begin
    OMsg := Trim(OMsg);
    delim := FPos(':', OMsg, 1);
    if delim = 0 then
      delim := FPos(',', OMsg, 1);
    if delim > 0 then begin
      OCol := Copy(OMsg, 1, delim - 1);
      if StrToIntDef(OCol, -1) = -1 then // don't accept
        OCol := ''
      else
        Delete(OMsg, 1, delim);
    end;
  end;

  procedure GetMessageType;
  begin
    OMsg := Trim(OMsg);
    delim := FPos(':', OMsg, 1);
    if delim > 0 then begin
      S := Copy(OMsg, 1, delim - 1);
      // gcc in English, or in Spanish when its translations are installed
      if SameStr(S, 'error') or SameStr(S, 'fatal error') or SameStr(S, 'error fatal') then begin
        Inc(fErrCount);
        Delete(OMsg, 1, delim + 1);
        OMsg := '[Error] ' + Trim(OMsg);
      end else if SameStr(S, 'warning') or SameStr(S, 'aviso') then begin
        Inc(fWarnCount);
        Delete(OMsg, 1, delim + 1);
        OMsg := '[Warning] ' + Trim(OMsg);
      end else if SameStr(S, 'info') then begin
        //Inc(fInfoCount);
        Delete(OMsg, 1, delim + 1);
        OMsg := '[Info] ' + Trim(OMsg);
      end else if SameStr(S, 'note') or SameStr(S, 'nota') then begin
        //Inc(fInfoCount);
        Delete(OMsg, 1, delim + 1);
        OMsg := '[Note] ' + Trim(OMsg);
      end;
    end;
  end;
begin
  OLine := '';
  OCol := '';
  OFile := '';
  OMsg := Trim(Line);

  // Ignore generic 'we are starting program x' messages
  if (Pos(fCompilerSet.gccName + ' ', Line) = 1) or
    (Pos(fCompilerSet.gppName + ' ', Line) = 1) or
    (Pos(fCompilerSet.makeName, Line) = 1) or // ignore all make errors for now
  (Pos(CLEAN_PROGRAM + ' ', Line) = 1) then
    Exit;

  // Direction strings
  if StartsStr('In file included from ', OMsg) then begin
    Delete(OMsg, 1, Length('In file included from '));

    GetFileName;
    GetLineNumber;
    GetColNumber;

    OMsg := 'In file included from ' + OFile;
    DoOutput(OLine, OCol, OFile, OMsg);
    Exit;
  end else if StartsStr('from ', OMsg) then begin
    Delete(OMsg, 1, Length('from '));

    GetFileName;
    GetLineNumber;
    GetColNumber;

    OMsg := '                 from ' + OFile;
    DoOutput(OLine, OCol, OFile, OMsg);
    Exit;
  end;

  // Ignore code snippets that GCC 4.8 produces
  if (Length(line) > 0) and (Line[1] = ' ') then // they always start with a space
    Exit;

  GetFileName; // assume regular main.cpp:line:col: message

  if SameStr(OFile, 'windres.exe') then begin // resource error
    GetFileName;
    GetLineNumber;
    Inc(fErrCount); // assume it's always an error

    DoResOutput(OLine, '', OFile, OMsg);
  end else begin
    GetLineNumber;
    GetColNumber;
    GetMessageType;

    DoOutput(OLine, OCol, OFile, OMsg);
  end;
end;

// Quote: CommandArg for a command (the default), MakeShellArg for a Makefile.
// The whole argument in quotes: -L"dir" would reach gcc with its quotes
// (Process.CommandToList only strips quotes around a whole word).
procedure TCompiler.GetLibrariesParams(Quote: TArgQuote = nil);
var
  i, val: integer;
  option: TCompilerOption;
begin
  if not Assigned(Quote) then
    Quote := CommandArg;

  // Add libraries
  fLibrariesParams := '';
  for i := 0 to fCompilerSet.LibDir.Count - 1 do
    fLibrariesParams := fLibrariesParams + ' ' + Quote('-L' + fCompilerSet.LibDir[i]);

  // Add global compiler linker extras
  if fCompilerSet.AddtoLink and (Length(fCompilerSet.LinkOpts) > 0) then
    fLibrariesParams := fLibrariesParams + ' ' + fCompilerSet.LinkOpts;

  // Add libs added via project
  if (fTarget = ctProject) and assigned(fProject) then begin
    for i := 0 to pred(fProject.Options.Libs.Count) do
      fLibrariesParams := fLibrariesParams + ' ' + Quote('-L' + fProject.Options.Libs[i]);

    // Add project compiler linker extras
    if Length(fProject.Options.LinkerCmd) > 0 then
      fLibrariesParams := fLibrariesParams + ' ' + StringReplace(fProject.Options.LinkerCmd, '_@@_', ' ', [rfReplaceAll])
  end;

  fLibrariesParams := Trim(fLibrariesParams);

  // Add project settings that need to be passed to the linker
  for I := 0 to fCompilerSet.Options.Count - 1 do begin
    option := PCompilerOption(fCompilerSet.Options[I])^;
    if (Assigned(fProject) and (I < Length(fProject.Options.CompilerOptions))) or (not Assigned(fProject) and
      (option.Value > 0)) then begin
      if option.IsLinker then
        if Assigned(option.Choices) then begin
          if Assigned(fProject) then
            val := fProject.Options.CompilerOptions[I]
          else
            val := option.Value;
          if (val > 0) and (val < option.Choices.Count) then
            fLibrariesParams := fLibrariesParams + ' ' + option.Setting +
              option.Choices.Values[option.Choices.Names[val]];
        end else if (Assigned(fProject) and (fProject.Options.CompilerOptions[I] = 1)) or (not
          Assigned(fProject)) then
          fLibrariesParams := fLibrariesParams + ' ' + option.Setting;
    end;
  end;

  fLibrariesParams := Trim(fLibrariesParams);
end;

procedure TCompiler.GetIncludesParams(Quote: TArgQuote = nil); // see GetLibrariesParams
var
  i: integer;
begin
  if not Assigned(Quote) then
    Quote := CommandArg;
  fIncludesParams := '';
  for i := 0 to fCompilerSet.CDir.Count - 1 do
    fIncludesParams := fIncludesParams + ' ' + Quote('-I' + fCompilerSet.CDir[i]);
  fCppIncludesParams := '';
  for i := 0 to fCompilerSet.CppDir.Count - 1 do
    fCppIncludesParams := fCppIncludesParams + ' ' + Quote('-I' + fCompilerSet.CppDir[i]);

  if (fTarget = ctProject) and assigned(fProject) then
    for i := 0 to pred(fProject.Options.Includes.Count) do
      if DirectoryExists(fProject.Options.Includes[i]) then begin
        fIncludesParams := fIncludesParams + ' ' + Quote('-I' + fProject.Options.Includes[i]);
        fCppIncludesParams := fCppIncludesParams + ' ' + Quote('-I' + fProject.Options.Includes[i]);
      end;

  fIncludesParams := Trim(fIncludesParams);
  fCppIncludesParams := Trim(fCppIncludesParams);
end;

function TCompiler.GetCompiling: Boolean;
begin
  Result := fDevRun <> nil;
end;

procedure TCompiler.InitProgressForm;
var
  numsourcefiles, I: integer;
begin
  // Count file types
  if Assigned(fProject) then begin
    numsourcefiles := 0;
    for I := 0 to fProject.Units.Count - 1 do
      if GetFileTyp(fProject.Units[I].FileName) in [utcSrc, utcppSrc] then
        Inc(numsourcefiles);

    MainForm.pbCompilation.Min := 0;
    MainForm.pbCompilation.Max := numsourcefiles + 3; // cleaning + all project units + linking output + private resource
    MainForm.pbCompilation.Position := 0;
  end else
    MainForm.pbCompilation.Max := 1; // just fSourceFile

  // Initialize counters
  fStartTime := GetTickCount64;
  fWarnCount := 0;
  fErrCount := 0;

  // Set some preferences
  fShowOutputInfo := not fCheckSyntax;
end;

procedure TCompiler.ProcessProgressForm(const Line: String);
var
  filename: String;
  I: integer;
  Done: boolean;
begin
  Done := false;

  // The compiler started to compile a new file
  if StartsStr(fCompilerSet.gppName + ' ', Line) or StartsStr(fCompilerSet.gccName + ' ', Line) then begin
    filename := '';
    if Assigned(fProject) then begin
      for I := 0 to fProject.Units.Count - 1 do begin
        filename := ExtractFilename(fProject.Units[I].FileName);
        if Pos(filename, Line) > 0 then begin
          MainForm.pbCompilation.StepIt;
          Done := true;
          break;
        end;
      end;
    end else if Pos(fSourceFile, Line) > 0 then begin
      MainForm.pbCompilation.StepIt;
      Done := true;
    end;

    if not Done then begin // might be the linker
      if Assigned(fProject) then
        filename := ExtractFileName(fProject.Executable)
      else
        filename := fSourceFile;

      if ContainsStr(Line, filename) then begin
        MainForm.pbCompilation.StepIt;
      end;
    end;
  end else if StartsStr(CLEAN_PROGRAM + ' ', Line) then begin // Cleaning obj files
    MainForm.pbCompilation.StepIt;
  end;
end;

procedure TCompiler.EndProgressForm;
var
  CompileTime: Extended; // fp
  FileName: String;
begin
  MainForm.pbCompilation.Position := 0;

  CompileTime := (GetTickCount64 - fStartTime) / 1000;

  DoLogEntry('');
  DoLogEntry(Lang[ID_LOG_COMPILERESULTS]);
  DoLogEntry('--------');
  DoLogEntry(Format(Lang[ID_LOG_ERRORS], [fErrCount]));
  DoLogEntry(Format(Lang[ID_LOG_WARNINGS], [fWarnCount]));

  // Check if the output file has been created
  if Assigned(fProject) then
    FileName := ExpandFileto(fProject.Executable, fProject.Directory)
  else begin
    case GetFileTyp(fSourceFile) of
      utresSrc: begin
          FileName := ChangeFileExt(fSourceFile, OBJ_EXT);
        end;
      utcSrc: begin
          FileName := ChangeFileExt(fSourceFile, EXE_EXT);
        end;
      utcppSrc: begin
          FileName := ChangeFileExt(fSourceFile, EXE_EXT);
        end;
      utcHead, utcppHead: begin
          FileName := fSourceFile + GCH_EXT;
        end;
    else begin
        FileName := fSourceFile;
      end;
    end;
  end;

  // Only show information if we managed to create the file and if it was the result of the current compilation
  if fShowOutputInfo and FileExists(FileName) then begin
    DoLogEntry(Format(Lang[ID_LOG_OUTPUTFILE], [FileName]));
    DoLogEntry(Format(Lang[ID_LOG_OUTPUTSIZE], [FormatFileSize(GetFileSize(FileName))]));
  end;
  DoLogEntry(Format(Lang[ID_LOG_COMPILETIME], [CompileTime]));

  if Assigned(fProject) then
    fProject.SaveToLog;
end;

end.

