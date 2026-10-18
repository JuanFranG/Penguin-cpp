{
    This file is part of Penguin cpp, a port of Embarcadero Dev-C++
    Copyright (c) 2004 Bloodshed Software

    Penguin cpp is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Penguin cpp is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Dev-C++; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

program penguincpp;

{$MODE DELPHI}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, // the LCL widgetset
  Forms, SysUtils,
  main,
  MultiLangSupport,
  Version,
  Utils,
  devPlatform,
  Tests,
  LangFrm,
  Project,
  Templates,
  NewProjectFrm,
  RemoveUnitFrm,
  GotoLineFrm,
  PrintFrm,
  AboutFrm,
  Compiler,
  devRun,
  ProjectOptionsFrm,
  ToolFrm,
  ToolEditFrm,
  IconFrm,
  devCFG,
  DataFrm,
  EditorOptFrm,
  CodeInsList,
  IncrementalFrm,
  FindFrm,
  Editor,
  EnviroFrm,
  DebugReader,
  Debugger,
  EditorList,
  CFGData,
  ProjectTypes,
  Macros,
  devExec,
  NewTemplateFrm,
  FunctionSearchFrm,
  NewVarFrm,
  NewFunctionFrm,
  NewClassFrm,
  ProfileAnalysisFrm,
  FilePropertiesFrm,
  AddToDoFrm,
  ViewToDoFrm,
  ImportMSVCFrm,
  ImportCBFrm,
  CPUFrm,
  TipOfTheDayFrm,
  WindowListFrm,
  ParamsFrm,
  CompOptionsFrame,
  CompOptionsFrm,
  ProcessListFrm,
  ImageTheme,
  CharUtils,
  AStyleFormatterOptionsFrm,
  ClangFormatterOptionsFrm;

{$R *.res}

var
  INIFileName, ExeFolder: String;
begin
  devData.IsPortable := EndsText('portable', ChangeFileExt(ExtractFileName(ParamStr(0)), ''))
                        or FindCmdLineSwitch('portable', True)
                        or FindCmdLineSwitch('-portable', True);

  // Read INI filename
  INIFileName := ChangeFileExt(ExtractFileName(Application.ExeName), INI_EXT);
  ExeFolder := ExtractFilePath(Application.ExeName);

  // Did someone pass the -c command to us?
  if (ParamCount >= 2) and SameStr(ParamStr(1), '-c') then begin
    if not DirectoryExists(ParamStr(2)) then
      CreateDir(ParamStr(2));

    // Store the INI file in the directory given to us
    if not (ParamStr(2)[1] in AllowDirectorySeparators) and (ExtractFileDrive(ParamStr(2)) = '') then // relative path
      devData.INIFileName := ExeFolder + IncludeTrailingPathDelimiter(ParamStr(2)) + INIFileName
    else
      devData.INIFileName := IncludeTrailingPathDelimiter(ParamStr(2)) + INIFileName;
  end else begin
    // ~/.config/penguin-cpp/, or a config folder next to the program when portable
    if (not devData.IsPortable) and ForceDirectories(GetConfigDir) then
      devData.INIFileName := GetConfigDir + INIFileName
    else begin
      devData.INIFileName := ExeFolder + 'config' + PathDelim + INIFileName;
      ForceDirectories(ExtractFilePath(devData.INIFileName));
    end;
  end;

  // Load settings
  devData.ReadSelf;
  CreateOptions;

  // Create main window
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.Title := 'Penguin cpp';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
