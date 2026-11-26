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

unit Project;

interface

uses
  FileTransactions, WindowsGameCore, devPlatform, IniFiles, SysUtils, System.UITypes, Dialogs, ComCtrls, Editor, Contnrs, SynExportHTML, Classes, Controls,
  Version, Forms, Templates, ProjectTypes, LCLIntf, LCLType;

type
  TProjUnit = class;
  TProject = class;

  TUnitList = class
  private
    fList: TList;
    function GetCount: integer;
    function GetItem(index: integer): TProjUnit;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(aunit: TProjUnit): integer;
    procedure Remove(index: integer);
    function IndexOf(const FileName: String): integer; overload;
    function IndexOf(Editor: TEditor): integer; overload;
    property Items[index: integer]: TProjUnit read GetItem; default;
    property Count: integer read GetCount;
    function Exists(aunit: TProjUnit): boolean;
  end;

  TProjUnit = class
  private
    fParent: TProject;
    fEditor: TEditor;
    fFileName: String;
    fNew: boolean;
    fNode: TTreeNode;
    fFolder: String;
    fCompile: boolean;
    fCompileCpp: boolean;
    fOverrideBuildCmd: boolean;
    fBuildCmd: String;
    fLink: boolean;
    fPriority: integer;
    function GetModified: boolean;
    procedure SetModified(value: boolean);
    function Save: boolean;
  public
    constructor Create(aOwner: TProject);
    destructor Destroy; override;
    property Editor: TEditor read fEditor write fEditor;
    property FileName: String read fFileName write fFileName;
    property New: boolean read fNew write fNew;
    property Modified: boolean read GetModified write SetModified;
    property Node: TTreeNode read fNode write fNode;
    property Parent: TProject read fParent write fParent;
    property Folder: String read fFolder write fFolder;
    property Compile: boolean read fCompile write fCompile;
    property CompileCpp: boolean read fCompileCpp write fCompileCpp;
    property OverrideBuildCmd: boolean read fOverrideBuildCmd write fOverrideBuildCmd;
    property BuildCmd: String read fBuildCmd write fBuildCmd;
    property Link: boolean read fLink write fLink;
    property Priority: integer read fPriority write fPriority;
    procedure Assign(Source: TProjUnit);
  end;

  TProject = class
  private
    fUnits: TUnitList;
    fOptions: TProjOptions;
    finiFile: TAtomicIniFile;
    fFileName: String;
    fName: String;
    fNode: TTreeNode;
    fModified: boolean;
    fFolders: TStringList;
    fFolderNodes: TObjectList;
    function GetDirectory: String;
    function GetExecutableName: String;
    procedure SetFileName(const value: String);
    function GetModified: boolean;
    function GetMakeFileName: String;
    procedure SetModified(value: boolean);
    procedure SortUnitsByPriority;
  public
    property Options: TProjOptions read fOptions write fOptions;
    property Name: String read fName write fName;
    property FileName: String read fFileName write SetFileName;
    property Node: TTreeNode read fNode write fNode;
    property Directory: String read GetDirectory;
    property Executable: String read GetExecutableName;
    property Units: TUnitList read fUnits write fUnits;
//    property INIFile: TMemIniFile read fINIFile write fINIFile;
    property Modified: boolean read GetModified write SetModified;
    property MakeFileName: String read GetMakeFileName;
    constructor Create(const nFileName, nName: String);
    destructor Destroy; override;
    function NewUnit(NewProject: boolean; ParentNode: TTreeNode; const CustomFileName: String = ''): integer;
    function AddUnit(const InFileName: String; ParentNode: TTreeNode; Rebuild: Boolean): TProjUnit;
    function GetFolderPath(Node: TTreeNode): String;
    procedure UpdateFolders;
    procedure AddFolder(const s: String);
    function OpenUnit(index: integer): TEditor;
    procedure CloseUnit(index: integer);
    procedure SaveUnitAs(i: integer; sFileName: String); // save single [UnitX]
    function SaveAll(const NewFileName: String = ''): Boolean;
    procedure LoadLayout; // load all [UnitX]
    procedure LoadUnitLayout(e: TEditor; Index: integer); // load single [UnitX] cursor positions
    procedure SaveLayout; // save all [UnitX]
    procedure SaveUnitLayout(e: TEditor; Index: integer); // save single [UnitX] cursor positions
    function MakeProjectNode: TTreeNode;
    function MakeNewFileNode(const s: String; IsFolder: boolean; NewParent: TTreeNode): TTreeNode;
    // What the project runs besides gcc, one line each for the user, and the
    // same as raw text (to remember that the user trusted exactly that)
    procedure ListOwnCommands(Lines: TStrings; out Raw: String);
    procedure ResolveCompatibility;
    procedure LoadOptions;
    procedure SaveOptions;
    function SaveUnits: Boolean;
    procedure Open;
    function FileAlreadyExists(const s: String): boolean;
    function RemoveFolder(Node: TTreeNode): boolean;
    function RemoveEditor(index: integer; DoClose: boolean): boolean;
    function GetUnitFromString(const s: String): integer;
    procedure RebuildNodes;
    function ListUnitStr(Separator: char): String;
    procedure ExportToHTML;
    function ShowOptions: Integer;
    function OptionsCopy: TProject;
    constructor CreateOptionsCopy(Source: TProject);
    function AssignTemplate(const aFileName: String; aTemplate: TTemplate): boolean;
    function FolderNodeFromName(const name: String): TTreeNode;
    procedure CreateFolderNodes;
    procedure UpdateNodeIndexes;
    procedure SetNodeValue(value: TTreeNode);
    procedure CheckProjectFileForUpdate;
    function GetCompilerOption(const OptionString: String): Integer;
    procedure SetCompilerOption(const OptionString: String; Value: Integer);
    procedure SaveToLog;
  end;

implementation

uses
  main, MultiLangSupport, devCFG, ProjectOptionsFrm, DataFrm, Utils, RemoveUnitFrm, SynEdit,
  EditorList, FileUtil, StrUtils;

{ TProjUnit }

constructor TProjUnit.Create(aOwner: TProject);
begin
  inherited Create;
  fEditor := nil;
  fNode := nil;
  fParent := aOwner;
end;

destructor TProjUnit.Destroy;
begin
  if Assigned(fEditor) then begin
    MainForm.EditorList.ForceCloseEditor(fEditor);
    fEditor := nil;
  end;
  fNode := nil;
  inherited;
end;

function TProjUnit.Save: boolean;
begin
  MainForm.FileMonitor.BeginUpdate;
  try
    try
      result := true;
      if not Assigned(fEditor) and not FileExists(fFileName) then begin // file is neither open, nor saved
        AtomicWriteFile(fFileName, '');
      end else if Assigned(fEditor) and (Modified or fEditor.New) then begin
        result := fEditor.Save;
        if Result and FileExists(fEditor.FileName) then
          FileSetDate(fEditor.FileName, DateTimeToFileDate(Now));
      end;
    except
      result := false;
    end;
  finally
    MainForm.FileMonitor.EndUpdate;
  end;

  // Update node text
  if Assigned(fNode) then
    fNode.Text := ExtractFileName(fFileName);
end;

function TProjUnit.GetModified: boolean;
begin
  if Assigned(fEditor) then
    result := fEditor.Text.Modified
  else
    result := FALSE;
end;

procedure TProjUnit.SetModified(value: boolean);
begin
  // Mark the change in the coupled editor
  if Assigned(fEditor) then
    fEditor.Text.Modified := value;

  // If modified is set to true, mark project as modified too
  if Value then
    fParent.Modified := True;
end;

procedure TProjUnit.Assign(Source: TProjUnit);
begin
  fEditor := Source.fEditor;
  fFileName := Source.fFileName;
  fNew := Source.fNew;
  Modified := Source.Modified;
  fNode := Source.fNode;
  fParent := Source.fParent;
  fFolder := Source.fFolder;
  fCompile := Source.fCompile;
  fCompileCpp := Source.fCompileCpp;
  fOverrideBuildCmd := Source.fOverrideBuildCmd;
  fBuildCmd := Source.fBuildCmd;
  fLink := Source.fLink;
  fPriority := Source.fPriority;
end;

{ TProject }

constructor TProject.Create(const nFileName, nName: String);
begin
  inherited Create;
  fNode := nil;
  fFolders := TStringList.Create;
  fFolders.Duplicates := dupIgnore;
  fFolders.Sorted := True;
  fFolderNodes := TObjectList.Create(false);
  fUnits := TUnitList.Create;
  fFileName := nFileName;
  finiFile := TAtomicIniFile.Create(fFileName);
  fOptions := TProjOptions.Create;
  if nName = DEV_INTERNAL_OPEN then
    Open
  else begin
    fName := nName;
    fIniFile.WriteString('Project', 'filename', nFileName);
    fIniFile.WriteString('Project', 'name', nName);
    fNode := MakeProjectNode;
  end;
end;

destructor TProject.Destroy;
begin
  fFolders.Free;
  fFolderNodes.Free;
  fIniFile.Free;
  fUnits.Free;
  if Assigned(fNode) and (not fNode.Deleting) then
    fNode.Free;
  fOptions.Free;
  inherited;
end;

function TProject.GetCompilerOption(const OptionString: String): Integer;
var
  OptionStruct: PCompilerOption;
  OptionIndex: integer;
begin
  Result := 0;
  if (fOptions.CompilerSet < 0) or (fOptions.CompilerSet >= devCompilerSets.Count) then
    Exit; // no compiler installed

  // Does the option exist?
  if devCompilerSets[fOptions.CompilerSet].FindOption(OptionString, OptionStruct, OptionIndex) then begin
    // Can it be found in the project options list? (a project saved with
    // another compiler set may have fewer)
    if (OptionIndex >= 0) and (OptionIndex < Length(fOptions.CompilerOptions)) then begin
      result := fOptions.CompilerOptions[OptionIndex];
    end;
  end;
end;

procedure TProject.SetCompilerOption(const OptionString: String; value: Integer);
var
  OptionStruct: PCompilerOption;
  OptionIndex: integer;
begin
  if (fOptions.CompilerSet < 0) or (fOptions.CompilerSet >= devCompilerSets.Count) then
    Exit; // no compiler installed

  // Does the option exist?
  if devCompilerSets[fOptions.CompilerSet].FindOption(OptionString, OptionStruct, OptionIndex) then begin
    // Can it be found in the project options list?
    if (OptionIndex >= 0) and (OptionIndex < Length(fOptions.CompilerOptions)) then begin
      if (fOptions.CompilerOptions[OptionIndex] <> value) then begin
        fOptions.CompilerOptions[OptionIndex] := Value;
        SetModified(true);
      end;
    end;
  end;
end;

function TProject.GetMakeFileName: String;
begin
  if fOptions.UseCustomMakefile then
    Result := fOptions.CustomMakefile
  else
    Result := Directory + DEV_MAKE_FILE;
end;

procedure TProject.SaveToLog;
var
  temp: String;
  temp2: String;
  i: integer;
  logfile: TextFile;
begin
  temp := '';

  // The commented line below is used by the project logger
  if Options.LogOutputEnabled then begin

    // Formatted log
    if (MainForm.CompilerOutput.Items.Count > 0) then begin
      AssignFile(logfile, IncludeTrailingPathDelimiter(Options.LogOutput) + 'Formatted Compiler Output.txt');
      try
        if FileExists(IncludeTrailingPathDelimiter(Options.LogOutput) + 'Formatted Compiler Output.txt') = false then begin
          Rewrite(logfile);
          Write(logfile, DateTimeToStr(Now) + ': Creating log...' + #13#10#13#10);
        end else begin
          Reset(logfile);
          Append(logfile);
          Write(logfile, #13#10 + DateTimeToStr(Now) + ': Appending to log...' + #13#10#13#10);
        end;

        for i := 0 to pred(MainForm.CompilerOutput.Items.Count) do begin
          temp2 := MainForm.CompilerOutput.Items[i].Caption + #10 + MainForm.CompilerOutput.Items[i].SubItems.Text;
          temp2 := StringReplace(temp2, #10, #9, []);
          temp2 := StringReplace(temp2, #13#10, #9, []);
          temp2 := StringReplace(temp2, #13#10, #9, []);
          temp := temp + temp2;
        end;
        Write(logfile, temp);
      finally
        CloseFile(logfile);
      end;
    end;

    // Raw log
    if Length(MainForm.LogOutput.Text) > 0 then begin
      AssignFile(logfile, IncludeTrailingPathDelimiter(Options.LogOutput) + 'Raw Build Output.txt');
      try
        if FileExists(IncludeTrailingPathDelimiter(Options.LogOutput) + 'Raw Build Output.txt') = false then begin
          Rewrite(logfile);
          Write(logfile, DateTimeToStr(Now) + ': Creating log...' + #13#10#13#10);
        end else begin
          Reset(logfile);
          Append(logfile);
          Write(logfile, #13#10 + DateTimeToStr(Now) + ': Appending to log...' + #13#10#13#10);
        end;
        Write(logfile, MainForm.LogOutput.Lines.Text);
      finally
        CloseFile(logfile);
      end;
    end;
  end;
end;

function TProject.MakeProjectNode: TTreeNode;
begin
  MakeProjectNode := MainForm.ProjectView.Items.Add(nil, Name);
  MakeProjectNode.SelectedIndex := 0;
  MakeProjectNode.ImageIndex := 0;
  MainForm.ProjectView.FullExpand;
end;

function TProject.MakeNewFileNode(const s: String; IsFolder: boolean; NewParent: TTreeNode): TTreeNode;
begin
  MakeNewFileNode := MainForm.ProjectView.Items.AddChild(NewParent, s);


  if IsFolder then begin
    MakeNewFileNode.SelectedIndex := 4;
    MakeNewFileNode.ImageIndex := 4;
  end else begin
    MakeNewFileNode.SelectedIndex := 1;
    MakeNewFileNode.ImageIndex := 1;
  end;
end;

// A project from someone else can make the build run anything: its own
// Makefile or build commands, options with shell code (they end up in the
// Makefile, run by /bin/sh), or gcc options that run or load programs.
procedure TProject.ListOwnCommands(Lines: TStrings; out Raw: String);

  function RunsCode(const S: String): Boolean;
  const
    ShellChars = ['$', '`', ';', '|', '&', '<', '>', #10, #13];
  var
    I: integer;
    W: String;
  begin
    for I := 1 to Length(S) do
      if S[I] in ShellChars then
        Exit(True);
    // -wrapper and -fplugin run or load programs, -specs and @file read more
    // options from a file, -B picks where gcc finds its own programs
    for I := 1 to WordCount(StringReplace(S, '_@@_', ' ', [rfReplaceAll]), [' ', #9]) do begin
      W := ExtractWord(I, StringReplace(S, '_@@_', ' ', [rfReplaceAll]), [' ', #9]);
      if StartsText('-wrapper', W) or StartsText('-fplugin', W) or StartsText('-specs', W) or
        StartsStr('-B', W) or StartsStr('@', W) then
        Exit(True);
    end;
    Result := False;
  end;

  procedure Add(const Line, Value: String);
  begin
    Lines.Add('- ' + Format(Line, [Value]));
    Raw := Raw + Line + '=' + Value + #10;
  end;

var
  I: integer;
begin
  Raw := '';
  if fOptions.UseCustomMakefile then
    Add(Lang[ID_PRJRUNS_MAKEFILE], fOptions.CustomMakefile);
  for I := 0 to fOptions.MakeIncludes.Count - 1 do
    Add(Lang[ID_PRJRUNS_MAKEINCLUDE], fOptions.MakeIncludes[I]);
  for I := 0 to Units.Count - 1 do
    if Units[I].OverrideBuildCmd and (Trim(Units[I].BuildCmd) <> '') then
      Add(Lang[ID_PRJRUNS_BUILDCMD], ExtractFileName(Units[I].FileName));
  if (fOptions.typ = dptDyn) and (fOptions.HostApplication <> '') then
    Add(Lang[ID_PRJRUNS_HOST], fOptions.HostApplication);
  if RunsCode(fOptions.CompilerCmd) then
    Add(Lang[ID_PRJRUNS_OPTIONS], StringReplace(fOptions.CompilerCmd, '_@@_', ' ', [rfReplaceAll]));
  if RunsCode(fOptions.CppCompilerCmd) then
    Add(Lang[ID_PRJRUNS_OPTIONS], StringReplace(fOptions.CppCompilerCmd, '_@@_', ' ', [rfReplaceAll]));
  if RunsCode(fOptions.LinkerCmd) then
    Add(Lang[ID_PRJRUNS_OPTIONS], StringReplace(fOptions.LinkerCmd, '_@@_', ' ', [rfReplaceAll]));
  if RunsCode(fOptions.CmdLineArgs) then // gdb starts the program through the shell
    Add(Lang[ID_PRJRUNS_ARGS], fOptions.CmdLineArgs);
end;

function TProject.NewUnit(NewProject: boolean; ParentNode: TTreeNode; const CustomFileName: String): integer;
var
  NewUnit: TProjUnit;
  s: String;
begin
  NewUnit := TProjUnit.Create(Self);

  // Select folder to add unit to
  if not Assigned(ParentNode) then
    ParentNode := Node; // project root node

  with NewUnit do
  try
    // Find unused 'new' filename
    if Length(CustomFileName) = 0 then begin
      repeat
        s := Directory + Lang[ID_Untitled] + IntToStr(dmMain.GetNewFileNumber);
      until not FileAlreadyExists(s);

      // Or use provided filename
    end else begin
      if ExtractFilePath(CustomFileName) = '' then // just filename, no path
        s := Directory + CustomFileName
      else
        s := CustomFileName;
    end;

    // Add
      Result := fUnits.Add(NewUnit);

    // Set all properties
    FileName := s;
    New := True;
    Editor := nil;
    Folder := GetFolderPath(ParentNode);
    Node := MakeNewFileNode(ExtractFileName(FileName), False, ParentNode);
    Node.Data := Pointer(PtrInt(result));
    Compile := True;
    CompileCpp := Self.Options.useGPP;
    Link := True;
    Priority := 1000;
    OverrideBuildCmd := False;
    BuildCmd := '';
    Modified := True;
  except
    result := -1;
    NewUnit.Free;
  end;
end;

{ begin XXXKF changed }

function TProject.AddUnit(const InFileName: String; ParentNode: TTreeNode; Rebuild: Boolean): TProjUnit;
var
  NewUnit: TProjUnit;
begin
  result := nil;
  NewUnit := TProjUnit.Create(Self);
  with NewUnit do try

    // Don't add if it already exists
    if FileAlreadyExists(InFileName) then begin
      MessageDlg(Format(Lang[ID_MSG_FILEINPROJECT], [InFileName, Self.FileName]) + #13#10 + Lang[ID_SPECIFY], mtError,
        [mbOK], 0);
      NewUnit.Free;
      Exit;
    end;

    // Add
    Result := NewUnit;

    // Set all properties
    FileName := InFileName;
    New := False;
    Editor := nil;
    Folder := GetFolderPath(ParentNode);
    Node := MakeNewFileNode(ExtractFileName(FileName), false, ParentNode);
    Node.Data := Pointer(PtrInt(fUnits.Add(NewUnit)));

    // Determine compilation flags
    case GetFileTyp(InFileName) of
      utcSrc, utcppSrc, utcHead, utcppHead: begin
          Compile := True;
          CompileCpp := Self.Options.useGPP;
          Link := True;
        end;
      utResSrc: begin
          Compile := True;
          CompileCpp := Self.Options.useGPP;
          Link := False;
        end;
    else begin
        Compile := False;
        CompileCpp := False;
        Link := False;
      end;
    end;
    Priority := 1000;
    OverrideBuildCmd := False;
    BuildCmd := '';
    if Rebuild then
      RebuildNodes;
    Modified := True;
  except
    result := nil;
    NewUnit.Free;
  end;
end;

procedure TProject.LoadOptions;
begin
  with finiFile do begin
    fName := ReadString('Project', 'name', '');
    fOptions.Icon := ReadString('Project', 'icon', '');
    fOptions.Ver := ReadInteger('Project', 'Ver', 0);
    if (fOptions.Ver > 0) then begin // ver > 0 is at least a v5 project
      if (fOptions.Ver < 2) then begin
        fOptions.Ver := 2;
        MessageDlg(Lang[ID_MSG_PLEASEUPDATEPROJECT], MtInformation, [MbOK], 0);
      end;

      fOptions.typ := ReadInteger('Project', 'type', 0);
      fOptions.CompilerCmd := ReadString('Project', 'Compiler', '');
      fOptions.CppCompilerCmd := ReadString('Project', 'CppCompiler', '');
      fOptions.LinkerCmd := ReadString('Project', 'Linker', '');
      fOptions.ObjFiles.DelimitedText := ReadString('Project', 'ObjFiles', '');
      fOptions.Libs.DelimitedText := ReadString('Project', 'Libs', '');
      fOptions.Includes.DelimitedText := ReadString('Project', 'Includes', '');
      fOptions.PrivateResource := ReadString('Project', 'PrivateResource', '');
      fOptions.ResourceIncludes.DelimitedText := ReadString('Project', 'ResourceIncludes', '');
      fOptions.MakeIncludes.DelimitedText := ReadString('Project', 'MakeIncludes', '');
      fOptions.UseGpp := ReadBool('Project', 'IsCpp', FALSE);
      fOptions.ExeOutput := ReadString('Project', 'ExeOutput', '');
      fOptions.ObjectOutput := ReadString('Project', 'ObjectOutput', '');
      fOptions.LogOutput := ReadString('Project', 'LogOutput', '');
      fOptions.LogOutputEnabled := ReadBool('Project', 'LogOutputEnabled', FALSE);
      fOptions.OverrideOutput := ReadBool('Project', 'OverrideOutput', FALSE);
      fOptions.OverridenOutput := ReadString('Project', 'OverrideOutputName', '');
      fOptions.HostApplication := ReadString('Project', 'HostApplication', '');
      fOptions.UseCustomMakefile := ReadBool('Project', 'UseCustomMakefile', FALSE);
      fOptions.CustomMakefile := ReadString('Project', 'CustomMakefile', '');
      fOptions.CmdLineArgs := ReadString('Project', 'CommandLine', '');
      fFolders.CommaText := ReadString('Project', 'Folders', '');
      fOptions.IncludeVersionInfo := ReadBool('Project', 'IncludeVersionInfo', False);
      fOptions.SupportXPThemes := ReadBool('Project', 'SupportXPThemes', False);
      fOptions.CompilerSet := ReadInteger('Project', 'CompilerSet', devCompilerSets.DefaultSetIndex);
      if fOptions.CompilerSet >= devCompilerSets.Count then begin // TODO: change from indices to names
        MessageDlg(Lang[ID_MSG_COMPILERNOTFOUND], mtError, [mbOk], 0);
        fOptions.CompilerSet := devCompilerSets.DefaultSetIndex;
      end;
      fOptions.CompilerOptions := TCompilerOptionsValues.FromString(ReadString('Project', 'CompilerSettings', ''));
      fOptions.VersionInfo.Major := ReadInteger('VersionInfo', 'Major', 0);
      fOptions.VersionInfo.Minor := ReadInteger('VersionInfo', 'Minor', 1);
      fOptions.VersionInfo.Release := ReadInteger('VersionInfo', 'Release', 1);
      fOptions.VersionInfo.Build := ReadInteger('VersionInfo', 'Build', 1);
      fOptions.VersionInfo.LanguageID := ReadInteger('VersionInfo', 'LanguageID', $0409);
      fOptions.VersionInfo.CharsetID := ReadInteger('VersionInfo', 'CharsetID', $04E4);
      fOptions.VersionInfo.CompanyName := ReadString('VersionInfo', 'CompanyName', '');
      fOptions.VersionInfo.FileVersion := ReadString('VersionInfo', 'FileVersion', '0.1');
      fOptions.VersionInfo.FileDescription := ReadString('VersionInfo', 'FileDescription',
        'Developed using the Penguin cpp IDE');
      fOptions.VersionInfo.InternalName := ReadString('VersionInfo', 'InternalName', '');
      fOptions.VersionInfo.LegalCopyright := ReadString('VersionInfo', 'LegalCopyright', '');
      fOptions.VersionInfo.LegalTrademarks := ReadString('VersionInfo', 'LegalTrademarks', '');
      fOptions.VersionInfo.OriginalFilename := ReadString('VersionInfo', 'OriginalFilename',
        ExtractFilename(Executable));
      fOptions.VersionInfo.ProductName := ReadString('VersionInfo', 'ProductName', Name);
      fOptions.VersionInfo.ProductVersion := ReadString('VersionInfo', 'ProductVersion', '0.1.1.1');
      fOptions.VersionInfo.AutoIncBuildNr := ReadBool('VersionInfo', 'AutoIncBuildNr', False);
      fOptions.VersionInfo.SyncProduct := ReadBool('VersionInfo', 'SyncProduct', False);
    end else begin // dev-c < 4
      fOptions.Ver := -1;
      if not ReadBool('Project', 'NoConsole', TRUE) then
        fOptions.typ := dptCon
      else if ReadBool('Project', 'IsDLL', FALSE) then
        fOptions.Typ := dptDyn
      else
        fOptions.typ := dptGUI;

      fOptions.PrivateResource := ReadString('Project', 'PrivateResource', '');
      fOptions.ResourceIncludes.DelimitedText := ReadString('Project', 'ResourceIncludes', '');
      fOptions.ObjFiles.Add(ReadString('Project', 'ObjFiles', ''));
      fOptions.Includes.Add(ReadString('Project', 'IncludeDirs', ''));
      fOptions.CompilerCmd := ReadString('Project', 'CompilerOptions', '');
      fOptions.usegpp := ReadBool('Project', 'Use_GPP', FALSE);
      fOptions.ExeOutput := ReadString('Project', 'ExeOutput', '');
      fOptions.ObjectOutput := ReadString('Project', 'ObjectOutput', '');
      fOptions.OverrideOutput := ReadBool('Project', 'OverrideOutput', FALSE);
      fOptions.OverridenOutput := ReadString('Project', 'OverrideOutputName', '');
      fOptions.HostApplication := ReadString('Project', 'HostApplication', '');
    end;
  end;
  ReadWindowsGameConfig(finiFile, fOptions.WindowsGame);
end;

procedure TProject.SaveOptions;
var IconPath: String;
begin
  IconPath := fOptions.Icon;
  if (IconPath <> '') and (IconPath[1] = PathDelim) then
    IconPath := ExtractRelativePath(Directory, IconPath);
  WriteWindowsGameConfig(finiFile, fOptions.WindowsGame);
  with finiFile do begin
    WriteString('Project', 'FileName', ExtractRelativePath(Directory, fFileName));
    WriteString('Project', 'Name', fName);
    WriteInteger('Project', 'Type', fOptions.typ);
    WriteInteger('Project', 'Ver', 2); // Is 2 as of Dev-C++ 5.2.0.3
    WriteString('Project', 'ObjFiles', fOptions.ObjFiles.DelimitedText);
    WriteString('Project', 'Includes', fOptions.Includes.DelimitedText);
    WriteString('Project', 'Libs', fOptions.Libs.DelimitedText);
    WriteString('Project', 'PrivateResource', fOptions.PrivateResource);
    WriteString('Project', 'ResourceIncludes', fOptions.ResourceIncludes.DelimitedText);
    WriteString('Project', 'MakeIncludes', fOptions.MakeIncludes.DelimitedText);
    WriteString('Project', 'Compiler', fOptions.CompilerCmd);
    WriteString('Project', 'CppCompiler', fOptions.CppCompilerCmd);
    WriteString('Project', 'Linker', fOptions.LinkerCmd);
    WriteBool('Project', 'IsCpp', fOptions.UseGpp);
    WriteString('Project', 'Icon', IconPath);
    WriteString('Project', 'ExeOutput', fOptions.ExeOutput);
    WriteString('Project', 'ObjectOutput', fOptions.ObjectOutput);
    WriteString('Project', 'LogOutput', fOptions.LogOutput);
    WriteBool('Project', 'LogOutputEnabled', fOptions.LogOutputEnabled);
    WriteBool('Project', 'OverrideOutput', fOptions.OverrideOutput);
    WriteString('Project', 'OverrideOutputName', fOptions.OverridenOutput);
    WriteString('Project', 'HostApplication', fOptions.HostApplication);
    WriteBool('Project', 'UseCustomMakefile', fOptions.UseCustomMakefile);
    WriteString('Project', 'CustomMakefile', fOptions.CustomMakefile);
    WriteString('Project', 'CommandLine', fOptions.CmdLineArgs);
    WriteString('Project', 'Folders', fFolders.CommaText);
    WriteBool('Project', 'IncludeVersionInfo', fOptions.IncludeVersionInfo);
    WriteBool('Project', 'SupportXPThemes', fOptions.SupportXPThemes);
    WriteInteger('Project', 'CompilerSet', fOptions.CompilerSet);
    WriteString('Project', 'CompilerSettings', fOptions.CompilerOptions.ToString);

    WriteInteger('VersionInfo', 'Major', fOptions.VersionInfo.Major);
    WriteInteger('VersionInfo', 'Minor', fOptions.VersionInfo.Minor);
    WriteInteger('VersionInfo', 'Release', fOptions.VersionInfo.Release);
    WriteInteger('VersionInfo', 'Build', fOptions.VersionInfo.Build);
    WriteInteger('VersionInfo', 'LanguageID', fOptions.VersionInfo.LanguageID);
    WriteInteger('VersionInfo', 'CharsetID', fOptions.VersionInfo.CharsetID);
    WriteString('VersionInfo', 'CompanyName', fOptions.VersionInfo.CompanyName);
    WriteString('VersionInfo', 'FileVersion', fOptions.VersionInfo.FileVersion);
    WriteString('VersionInfo', 'FileDescription', fOptions.VersionInfo.FileDescription);
    WriteString('VersionInfo', 'InternalName', fOptions.VersionInfo.InternalName);
    WriteString('VersionInfo', 'LegalCopyright', fOptions.VersionInfo.LegalCopyright);
    WriteString('VersionInfo', 'LegalTrademarks', fOptions.VersionInfo.LegalTrademarks);
    WriteString('VersionInfo', 'OriginalFilename', fOptions.VersionInfo.OriginalFilename);
    WriteString('VersionInfo', 'ProductName', fOptions.VersionInfo.ProductName);
    WriteString('VersionInfo', 'ProductVersion', fOptions.VersionInfo.ProductVersion);
    WriteBool('VersionInfo', 'AutoIncBuildNr', fOptions.VersionInfo.AutoIncBuildNr);
    WriteBool('VersionInfo', 'SyncProduct', fOptions.VersionInfo.SyncProduct);

    if fOptions.Ver <= 0 then begin
      //delete outdated dev4 project options
      DeleteKey('Project', 'NoConsole');
      DeleteKey('Project', 'IsDLL');
      DeleteKey('Project', 'ResFiles');
      DeleteKey('Project', 'IncludeDirs');
      DeleteKey('Project', 'CompilerOptions');
      DeleteKey('Project', 'Use_GPP');
    end;
  end;

  fINIFile.UpdateFile; // force flush
end;

function TProject.SaveUnits: Boolean;
var
  Count: integer;
  idx: integer;
begin
  Result := False;
  Count := 0;
  for idx := 0 to pred(fUnits.Count) do begin
    with fUnits[idx] do begin

      if not fUnits[idx].Save then Exit;

      // saved new file or an existing file add to project file
      if not (New and Modified) then begin
        finifile.WriteString('Unit' + IntToStr(Count + 1), 'FileName', ExtractRelativePath(Directory,
          fUnits[idx].FileName));
        Inc(Count);
      end;
      case GetFileTyp(fUnits[idx].FileName) of
        utcHead, utcppHead, utcSrc, utcppSrc: finifile.WriteBool('Unit' + IntToStr(idx + 1), 'CompileCpp', CompileCpp);
        utResSrc: if Folder = '' then
            Folder := 'Resources';
      end;
      finifile.WriteString('Unit' + IntToStr(idx + 1), 'Folder', Folder);
      finifile.WriteBool('Unit' + IntToStr(idx + 1), 'Compile', Compile);
      finifile.WriteBool('Unit' + IntToStr(idx + 1), 'Link', Link);
      finifile.WriteInteger('Unit' + IntToStr(idx + 1), 'Priority', Priority);
      finifile.WriteBool('Unit' + IntToStr(idx + 1), 'OverrideBuildCmd', OverrideBuildCmd);
      finifile.WriteString('Unit' + IntToStr(idx + 1), 'BuildCmd', BuildCmd);
    end;
  end;
  finifile.WriteInteger('Project', 'UnitCount', Count);
  Result := True;
end;

function TProject.FolderNodeFromName(const name: String): TTreeNode;
var
  i: integer;
begin
  FolderNodeFromName := fNode;
  if name <> '' then
    for i := 0 to pred(fFolders.Count) do begin
      if CompareText(AnsiDequotedStr(fFolders[i], '"'), AnsiDequotedStr(name, '"')) = 0 then begin
        FolderNodeFromName := TTreeNode(fFolderNodes[i]);
        break;
      end;
    end;
end;

procedure TProject.CreateFolderNodes;
var
  idx: integer;
  findnode, node: TTreeNode;
  s: String;
  I, C: integer;
begin
  fFolderNodes.Clear;
  for idx := 0 to pred(fFolders.Count) do begin
    node := fNode;
    S := fFolders[idx];
    I := Pos('/', S);
    while I > 0 do begin
      findnode := nil;
      for C := 0 to Node.Count - 1 do
        if node.Items[C].Text = Copy(S, 1, I - 1) then begin
          findnode := node.Items[C];
          Break;
        end;
      if not Assigned(findnode) then
        node := MakeNewFileNode(Copy(S, 1, I - 1), True, node)
      else
        node := findnode;
      node.Data := Pointer(-1);
      Delete(S, 1, I);
      I := Pos('/', S);
    end;
    node := MakeNewFileNode(S, True, Node);
    node.Data := Pointer(-1);
    fFolderNodes.Add(node);
  end;
end;

procedure TProject.UpdateNodeIndexes;
var
  idx: integer;
begin
  for idx := 0 to fUnits.Count - 1 do
    fUnits[idx].Node.Data := Pointer(PtrInt(idx));
end;

procedure TProject.Open;
var
  ucount,
    i: integer;
  NewUnit: TProjUnit;
begin
{$WARN SYMBOL_PLATFORM OFF}
  if FileExists(FileName) and (FileGetAttr(FileName) and faReadOnly <> 0) then begin
    // file is read-only
    if MessageDlg(Format(Lang[ID_MSG_FILEISREADONLY], [FileName]), mtConfirmation, [mbYes, mbNo], 0) = mrYes then
      if FileSetAttr(FileName, FileGetAttr(FileName) - faReadOnly) <> 0 then begin
        MessageDlg(Format(Lang[ID_MSG_FILEREADONLYERROR], [FileName]), mtError, [mbOk], 0);
      end;
  end;
{$WARN SYMBOL_PLATFORM ON}

  LoadOptions;
  fNode := MakeProjectNode;

  CheckProjectFileForUpdate;

  uCount := fIniFile.ReadInteger('Project', 'UnitCount', 0);

  CreateFolderNodes;

  for i := 0 to pred(uCount) do
  begin
    NewUnit := TProjUnit.Create(Self);

    with NewUnit do
    begin
      FileName := ExpandFileto(finifile.ReadString('Unit' + IntToStr(i + 1), 'FileName', ''), Directory);

      if not FileExists(FileName) then
      begin
        Application.MessageBox(PChar(Format(Lang[ID_ERR_FILENOTFOUND], [FileName])), 'Error', MB_ICONERROR);
        SetModified(TRUE);
      end
      else
      begin
        Folder := finifile.ReadString('Unit' + IntToStr(i + 1), 'Folder', '');
        Compile := finifile.ReadBool('Unit' + IntToStr(i + 1), 'Compile', True);

        if finifile.ReadInteger('Unit' + IntToStr(i + 1), 'CompileCpp', 2) = 2 then
          // check if feature not present in this file
          CompileCpp := Self.Options.useGPP
        else
          CompileCpp := finifile.ReadBool('Unit' + IntToStr(i + 1), 'CompileCpp', False);

        Link := finifile.ReadBool('Unit' + IntToStr(i + 1), 'Link', True);
        Priority := finifile.ReadInteger('Unit' + IntToStr(i + 1), 'Priority', 1000);
        OverrideBuildCmd := finifile.ReadBool('Unit' + IntToStr(i + 1), 'OverrideBuildCmd', False);
        BuildCmd := finifile.ReadString('Unit' + IntToStr(i + 1), 'BuildCmd', '');

        Editor := nil;
        New := FALSE;
        fParent := self;

        Node := MakeNewFileNode(ExtractFileName(FileName), False, FolderNodeFromName(Folder));
        if not fUnits.Exists(NewUnit) then
          Node.Data := Pointer(PtrInt(fUnits.Add(NewUnit)));
      end;
    end;
  end;

  case devData.AutoOpen of
    0: begin
        for i := 0 to pred(fUnits.Count) do
          OpenUnit(i); // Open all
        if fUnits.Count > 0 then
          fUnits[0].Editor.Activate; // Show first
      end;
    1:
      if fUnits.Count > 0 then
        OpenUnit(0).Activate; // Open and show first
    2:
      LoadLayout; // Open previous selection
  end;

  RebuildNodes;
end;

{ end XXXKF changed }

procedure TProject.LoadLayout;
var
  layIni: TIniFile;
  TopLeft {, TopRight}: integer;
  sl: TStringList;
  idx, currIdx: integer;
begin
  sl := TStringList.Create;
  try
    layIni := TIniFile.Create(ChangeFileExt(Filename, '.layout'));
    try
      // Remember focus for left and right page controls
      TopLeft := layIni.ReadInteger('Editors', 'Focused', -1);
      //TopRight := layIni.ReadInteger('Editors', 'FocusedRight', -1);

      // read order of open files and open them accordingly
      sl.CommaText := layIni.ReadString('Editors', 'Order', '');
    finally
      layIni.Free;
    end;

    for idx := 0 to sl.Count - 1 do
    begin
      currIdx := StrToIntDef(sl[idx], -1);
      OpenUnit(currIdx);
    end;
  finally
    sl.Free;
  end;

  // Set focus for left and right page controls
  if (TopLeft <> -1) and (TopLeft < fUnits.Count) and Assigned(fUnits[TopLeft].Editor) then
    fUnits[TopLeft].Editor.Activate;
  //if (TopRight <> -1) and (TopRight < fUnits.Count) and Assigned(fUnits[TopRight].Editor) then
  //  fUnits[TopRight].Editor.Activate;
end;

procedure TProject.LoadUnitLayout(e: TEditor; Index: integer);
var
  layIni: TIniFile;
begin
  layIni := TIniFile.Create(ChangeFileExt(Filename, '.layout'));
  try
    if Assigned(e) then begin
      e.Text.CaretY := layIni.ReadInteger('Editor_' + IntToStr(Index), 'CursorRow', 1);
      e.Text.CaretX := layIni.ReadInteger('Editor_' + IntToStr(Index), 'CursorCol', 1);
      e.Text.TopLine := layIni.ReadInteger('Editor_' + IntToStr(Index), 'TopLine', 1);
      e.Text.LeftChar := layIni.ReadInteger('Editor_' + IntToStr(Index), 'LeftChar', 1);
    end;
  finally
    layIni.Free;
  end;
end;

procedure TProject.SaveLayout;
var
  layIni: TAtomicIniFile;
  I: Integer;
  sl: TStringList;
  S: String;
  e, e2: TEditor;
begin
  s := ChangeFileExt(Filename, '.layout');
  layIni := TAtomicIniFile.Create(s);
  try
    sl := TStringList.Create;
    try
      // Write list of open project files
      for I := 0 to MainForm.EditorList.PageCount - 1 do begin
        e := MainForm.EditorList[i];
        if Assigned(e) and e.InProject then
          sl.Add(IntToStr(fUnits.IndexOf(e)));
      end;
      layIni.WriteString('Editors', 'Order', sl.CommaText);

      // Remember what files were visible
      MainForm.EditorList.GetVisibleEditors(e, e2);
      if Assigned(e) then
        layIni.WriteInteger('Editors', 'Focused', fUnits.IndexOf(e));
      //if Assigned(e2) then
      //  layIni.WriteInteger('Editors', 'FocusedRight', fUnits.IndexOf(e2));
    finally
      sl.Free;
    end;

    // save editor info
    for I := 0 to pred(fUnits.Count) do
      with fUnits[I] do begin
        // save info on open state
        if Assigned(editor) then begin
          layIni.WriteInteger('Editor_' + IntToStr(I), 'CursorCol', Editor.Text.CaretX);
          layIni.WriteInteger('Editor_' + IntToStr(I), 'CursorRow', Editor.Text.CaretY);
          layIni.WriteInteger('Editor_' + IntToStr(I), 'TopLine', Editor.Text.TopLine);
          layIni.WriteInteger('Editor_' + IntToStr(I), 'LeftChar', Editor.Text.LeftChar);
          //   layIni.WriteBool('Editor_' + IntToStr(I), 'PageControl', e.TabSheet.PageControl =
          //     MainForm.EditorList.LeftPageControl);
        end;

        // remove old data from project file
        fIniFile.DeleteKey('Unit' + IntToStr(I + 1), 'Open');
        fIniFile.DeleteKey('Unit' + IntToStr(I + 1), 'Top');
        fIniFile.DeleteKey('Unit' + IntToStr(I + 1), 'CursorCol');
        fIniFile.DeleteKey('Unit' + IntToStr(I + 1), 'CursorRow');
        fIniFile.DeleteKey('Unit' + IntToStr(I + 1), 'TopLine');
        fIniFile.DeleteKey('Unit' + IntToStr(I + 1), 'LeftChar');
      end;
    layIni.UpdateFile;
  finally
    layIni.Free;
  end;
end;

procedure TProject.SaveUnitLayout(e: TEditor; Index: integer);
var
  layIni: TAtomicIniFile;
begin
  layIni := TAtomicIniFile.Create(ChangeFileExt(Filename, '.layout'));
  try
    if Assigned(e) then begin
      layIni.WriteInteger('Editor_' + IntToStr(Index), 'CursorCol', e.Text.CaretX);
      layIni.WriteInteger('Editor_' + IntToStr(Index), 'CursorRow', e.Text.CaretY);
      layIni.WriteInteger('Editor_' + IntToStr(Index), 'TopLine', e.Text.TopLine);
      layIni.WriteInteger('Editor_' + IntToStr(Index), 'LeftChar', e.Text.LeftChar);
      //   layIni.WriteBool('Editor_' + IntToStr(Index), 'PageControl', e.TabSheet.PageControl =
      //     MainForm.EditorList.LeftPageControl);
    end;
    layIni.UpdateFile;
  finally
    layIni.Free;
  end;
end;

function TProject.SaveAll(const NewFileName: String): Boolean;
var OldName: String;
begin
  Result := False;
  OldName := fFileName;
  try
    if NewFileName <> '' then begin
      fFileName := ExpandFileName(NewFileName);
      fIniFile.Rename(fFileName, False);
    end;
    try
      if not SaveUnits then Exit;
      SaveLayout;
      SaveOptions;
      SetModified(False);
      Result := True;
    except
      on E: Exception do
        MessageDlg(Format(Lang[ID_ERR_SAVEFILE], [fFileName]) + LineEnding + E.Message,
          mtError, [mbOK], 0);
    end;
  finally
    if not Result then begin
      fFileName := OldName;
      fIniFile.Rename(OldName, False);
    end;
  end;
end;

function TProject.RemoveFolder(Node: TTreeNode): boolean;
  procedure RemoveFolderRecurse(Node: TTreeNode);
  var
    I, EditorIndex: integer;
    ChildNode: TTreeNode;
  begin
    // Recursively remove folders
    for I := Node.Count - 1 downto 0 do begin
      ChildNode := Node.Items[i];

      // Remove folder inside folder
      if (ChildNode.Data = Pointer(-1)) and (ChildNode.Level > 0) then
        RemoveFolderRecurse(ChildNode)

        // Or remove editors at this level
      else if (ChildNode.Data <> Pointer(-1)) and (ChildNode.Level > 0) then begin

        // Remove editor in folder from project
        EditorIndex := PtrInt(ChildNode.Data);
        if not RemoveEditor(EditorIndex, true) then
          Exit;
      end;
    end;

    Node.Delete;
  end;
begin
  Result := False;

  // Sanity check
  if not Assigned(Node) then
    Exit;

  // Check if this is actually a folder
  if (Node.Data <> Pointer(-1)) or (Node.Level < 1) then
    Exit;

  // Let this function call itself
  RemoveFolderRecurse(Node);

  // Update list of folders (sets modified)
  UpdateFolders;
end;

function TProject.RemoveEditor(index: integer; DoClose: boolean): boolean;
begin
  result := False;

  // Attempt to close it
  if DoClose and Assigned(fUnits.GetItem(index).fEditor) then
    if not MainForm.EditorList.CloseEditor(fUnits.GetItem(index).fEditor) then
      Exit;

  result := true;

  { this causes problems if the project isn't saved after this, since the erase happens phisically at this moment }
  //if not fUnits.GetItem(index).fNew then
  finifile.EraseSection('Unit' + inttostr(index + 1));
  with fUnits.GetItem(index) do begin
    if Assigned(fNode) then
      fNode.Delete;
    fNode := nil;
    // Not closed: the editor stays open, as a file outside the project
    if Assigned(fEditor) then begin
      fEditor.InProject := False;
      fEditor := nil;
    end;
    Free; // the list only drops it
  end;
  fUnits.Remove(index);

  UpdateNodeIndexes;
  SetModified(TRUE);
end;

function TProject.FileAlreadyExists(const s: String): boolean;
begin
  if fUnits.IndexOf(s) > -1 then
    result := true
  else
    result := false;
end;

function TProject.OpenUnit(index: integer): TEditor;
begin
  result := nil;
  if (index < 0) or (index > pred(fUnits.Count)) then
    exit;

  with fUnits[index] do begin
    if FileName <> '' then begin
      try
        SetCurrentDir(Directory);
        fEditor := MainForm.EditorList.FileIsOpen(ExpandFileName(FileName));
        if fEditor = nil then
          fEditor := MainForm.EditorList.NewEditor(ExpandFileName(FileName), true, false);
        LoadUnitLayout(fEditor, index);
        Result := fEditor;
      except
        MessageDlg(Format(Lang[ID_ERR_OPENFILE], [Filename]), mtError, [mbOK], 0);
      end;
    end;
  end;
end;

procedure TProject.CloseUnit(index: integer);
begin
  with fUnits[index] do begin
    if Assigned(fEditor) then begin
      SaveUnitLayout(fEditor, index);
      MainForm.EditorList.ForceCloseEditor(fEditor);
      fEditor := nil;
    end;
  end;
end;

procedure TProject.SaveUnitAs(i: integer; sFileName: String);
begin
  if (i < 0) or (i > pred(fUnits.Count)) then
    exit;

  with fUnits[i] do begin
    if FileExists(FileName) then
      New := FALSE;
    FileName := sFileName; // fix bug #559694
    if Editor <> nil then begin
      Editor.UpdateCaption(ExtractFileName(sFileName));
      // project units are referenced with relative paths.
      Editor.FileName := GetRealPath(sFileName, Directory);
    end;
    Node.Text := ExtractFileName(sFileName);
    New := False;
    fInifile.WriteString('Unit' + IntToStr(i + 1), 'FileName', ExtractRelativePath(Directory, sFileName));
  end;
  Modified := true;
end;

function TProject.GetUnitFromString(const s: String): integer;
begin
  result := fUnits.Indexof(ExpandFileto(s, Directory));
end;

procedure TProject.ResolveCompatibility;
var I: Integer; Dirs: TStringList;
begin
  case fOptions.WindowsGame.Mode of
    cmNative: fOptions.WindowsGame.Enabled := False;
    cmWindows: fOptions.WindowsGame.Enabled := True;
    cmAutomatic: begin
      fOptions.WindowsGame.Enabled := False;
      Dirs := TStringList.Create;
      try
        for I := 0 to fOptions.Includes.Count-1 do
          Dirs.Add(ExpandFileto(fOptions.Includes[I], Directory));
        for I := 0 to fUnits.Count-1 do
          if fUnits[I].Compile and FileNeedsWindows(fUnits[I].FileName, Dirs) then begin
            fOptions.WindowsGame.Enabled := True; Break;
          end;
        if not DeveloperToolsInstalled and (fOptions.WindowsGame.Toolchain <> '') then
          fOptions.WindowsGame.Enabled := True;
      finally Dirs.Free end;
    end;
  end;
end;

function TProject.GetExecutableName: String;
var
  ExeFileName, ExePath: String;
begin
  ResolveCompatibility;
  // Determine filename ('hello.exe')
  if fOptions.OverrideOutput and (fOptions.OverridenOutput <> '') then begin
    ExeFileName := fOptions.OverridenOutput;
  end else begin
    if fOptions.typ = dptStat then
      ExeFileName := ChangeFileExt(ExtractFileName(Filename), LIB_EXT)
    else if fOptions.typ = dptDyn then
      ExeFileName := ChangeFileExt(ExtractFileName(Filename), DLL_EXT)
    else if fOptions.WindowsGame.Enabled then
      ExeFileName := ChangeFileExt(ExtractFileName(Filename), '.exe')
    else
      ExeFileName := ChangeFileExt(ExtractFileName(Filename), EXE_EXT);
  end;

  // Determine file path ('X;\Hello\');
  if Length(Options.ExeOutput) > 0 then
    ExePath := IncludeTrailingPathDelimiter(ExpandFileto(Options.ExeOutput, Directory))
  else
    ExePath := IncludeTrailingPathDelimiter(Directory);

  // Compute result
  Result := GetRealPath(ExePath + ExeFileName);
end;

function TProject.GetDirectory: String;
begin
  result := ExtractFilePath(FileName);
end;

function TProject.ListUnitStr(Separator: char): String;
var
  I: integer;
begin
  Result := '';
  for I := 0 to fUnits.Count - 1 do
    result := result + '"' + ExpandFileName(fUnits[I].FileName) + '"' + Separator;
end;

procedure TProject.SetFileName(const value: String);
begin
  if fFileName <> value then begin
    fFileName := value;
    SetModified(True);
    finiFile.Rename(value, FALSE);
  end;
end;

function TProject.GetModified: boolean;
var
  I: integer;
begin
  // Project file modified? Done
  if fModified then
    Result := True // quick exit avoids loop over all units

    // Otherwise, check all units
  else begin
    for I := 0 to fUnits.Count - 1 do begin
      if fUnits[I].Modified then begin
        Result := True;
        Exit; // don't bother checking others
      end;
    end;

    // Not modified
    Result := False;
  end;
end;

procedure TProject.SetModified(value: boolean);
begin
  // Dirty state describes memory, including changes to a read-only project.
  fModified := value;
end;

procedure TProject.SetNodeValue(value: TTreeNode);
begin
  fNode := Value;
end;

procedure TProject.ExportToHTML;
  function ConvertFilename(const Filename, FinalPath, Extension: String): String;
  begin
    Result := ExtractRelativePath(Directory, Filename);
    Result := StringReplace(Result, '.', '_', [rfReplaceAll]);
    Result := StringReplace(Result, '\', '_', [rfReplaceAll]);
    Result := StringReplace(Result, '/', '_', [rfReplaceAll]);
    Result := IncludeTrailingPathDelimiter(FinalPath) + Result + Extension;
  end;
var
  I: integer;
  sl: TStringList;
  fName, UnitName: String;
  Size: integer;
  SizeStr: String;
  link: String;
  BaseDir: String;
  hFile: integer;
  SynExporterHTML: TSynExporterHTML;
begin
  SynExporterHTML := TSynExporterHTML.Create(nil);
  with TSaveDialog.Create(nil) do try

    Filter := SynExporterHTML.DefaultFilter;
    Title := Lang[ID_NV_EXPORT];
    DefaultExt := HTML_EXT;
    FileName := ChangeFileExt(fFileName, HTML_EXT);
    Options := Options + [ofOverwritePrompt];

    if not Execute then begin
      SynExporterHTML.Free;
      Exit;
    end;

    fName := FileName; // project html filename
  finally
    Free;
  end;

  BaseDir := ExtractFilePath(fName);
  CreateDir(BaseDir + pd + 'files');

  sl := TStringList.Create;
  try
    sl.Add('<html>');
    sl.Add('<head><title>Penguin cpp project: ' + Self.Name + '</title></head>');
    sl.Add('<body bgcolor=#FFFFFF>');
    sl.Add('<h2>Project: ' + Self.Name + '</h2>');
    sl.Add('<b>Index of files:</b>');
    sl.Add('<hr width="80%"/>');
    sl.Add('<table align="center" cellspacing="20">');
    sl.Add('<tr><td><b><u>Filename</u></b></td><td><b><u>Location</u></b></td><td><b><u>Size</u></b></td></tr>');

    // Use this one to export files to HTML (copy from TEditor.ExportToHTML)
    SynExporterHTML.Options := SynExporterHTML.Options - [heoFragmentOnly]; // a whole page
    SynExporterHTML.ExportAsText := True;
    SynExporterHTML.UseBackground := True;
    SynExporterHTML.Font := devEditor.Font;

    for I := 0 to Units.Count - 1 do begin
      UnitName := Units[I].FileName;

      hFile := FileOpen(UnitName, fmOpenRead);
      if hFile > 0 then begin
        Size := FileSeek(hFile, 0, 2);
        if Size < 1024 then
          SizeStr := IntToStr(Size) + ' ' + Lang[ID_BYTES]
        else if Size < 1024 * 1024 then
          SizeStr := FloatToStr(Size / 1024) + ' KiB'
        else if Size < 1024 * 1024 * 1024 then
          SizeStr := FloatToStr((Size / 1024) / 1024) + ' MiB'
        else
          SizeStr := FloatToStr(((Size / 1024) / 1024) / 1024) + ' GiB';

        FileClose(hFile);
      end else
        SizeStr := 'Unknown';

      // Add string to main overview
      link := ExtractFilename(ConvertFilename(ExtractRelativePath(Directory, UnitName), BaseDir, HTML_EXT));
      sl.Add(#9 + '<tr><td><a href="files' + pd + link + '">' + ExtractFilename(UnitName) + '</a></td><td>' +
        ExpandFilename(UnitName) + '</td><td>' + SizeStr + '</td></tr>');
    end;

    sl.Add('</table>');
    sl.Add('<hr width="80%"/>');
    sl.Add('<p align="center"><font size="1">Exported by <a href="https://github.com/JuanFranG/Penguin-cpp">' + DEVCPP + '</a> v' +
      DEVCPP_VERSION + '</font></p>');
    sl.Add('</body>');
    sl.Add('</html>');
    sl.SaveToFile(fName);

    // export project files
    for I := 0 to Units.Count - 1 do begin
      UnitName := Units[I].FileName;

      // Load from disk
      sl.LoadFromFile(UnitName);

      // Save to disk as HTML
      SynExporterHTML.Title := UnitName;
      SynExporterHTML.Highlighter := dmMain.GetHighlighter(ExtractFilename(UnitName));
      SynExporterHTML.ExportAll(sl);

      UnitName := ConvertFilename(ExtractRelativePath(Directory, UnitName), BaseDir + pd + 'files', HTML_EXT);
      SynExporterHTML.SaveToFile(UnitName);
    end;
  finally
    sl.Free;
    SynExporterHTML.Free;
  end;
end;

constructor TProject.CreateOptionsCopy(Source: TProject);
var I: Integer; U, Original: TProjUnit;
begin
  inherited Create;
  fFileName := Source.FileName; fName := Source.Name;
  fFolders := TStringList.Create; fFolders.Assign(Source.fFolders);
  fFolderNodes := TObjectList.Create(False); fUnits := TUnitList.Create;
  fIniFile := TAtomicIniFile.Create(fFileName);
  fOptions := TProjOptions.Create; fOptions.Assign(Source.Options);
  for I := 0 to Source.Units.Count-1 do begin
    Original := Source.Units[I]; U := TProjUnit.Create(Self);
    U.FileName := Original.FileName; U.Folder := Original.Folder;
    U.Compile := Original.Compile; U.CompileCpp := Original.CompileCpp; U.Link := Original.Link;
    U.Priority := Original.Priority; U.OverrideBuildCmd := Original.OverrideBuildCmd;
    U.BuildCmd := Original.BuildCmd;
    fUnits.Add(U);
  end;
end;

function TProject.OptionsCopy: TProject;
begin Result := TProject.CreateOptionsCopy(Self) end;

function TProject.ShowOptions: Integer;
begin
  with TProjectOptionsFrm.Create(MainForm) do try

    // Apply current settings
    SetInterface(Self);

    // Tell the sender what the result was
    Result := ShowModal;
    if Result = mrOk then begin

      // Save new settings to RAM
      GetInterface(Self);

      // Ask the user to save to disk when closing
      SetModified(TRUE);

      // Rebuild unit tree
      SortUnitsByPriority;
      RebuildNodes;

      // Update the project's main node caption
      if edProjectName.Text <> '' then begin
        fName := edProjectName.Text;
        fNode.Text := fName;
      end;
    end;

  finally
    Free;
  end;
end;

function TProject.AssignTemplate(const aFileName: String; aTemplate: TTemplate): boolean;
var
  I: integer;
  s, s2: String;
  OriginalIcon, DestIcon: String;
begin
  result := TRUE;
  try
    if aTemplate.Version = -1 then begin
      fName := format(Lang[ID_NEWPROJECT], [dmmain.GetNewProjectNumber]);
      fNode.Text := fName;
      if Assigned(finiFile) then
        finiFile.Rename(aFileName, false)
      else
        fIniFile := TAtomicIniFile.Create(aFileName);
      NewUnit(FALSE, nil);
      with fUnits[fUnits.Count - 1] do begin
        Editor := MainForm.EditorList.NewEditor(FileName, True, True);
        Editor.InsertDefaultText;
        Editor.Activate;
      end;
      exit;
    end;

    fName := aTemplate.Name;
    if Assigned(finiFile) then
      finiFile.Rename(aFileName, false)
    else
      fIniFile := TAtomicIniFile.Create(aFileName);
    fOptions.Assign(aTemplate.Options);

    // Copy icon to project directory
    if Length(fOptions.Icon) > 0 then begin
      OriginalIcon := ValidateFile(fOptions.Icon, ExtractFilePath(aTemplate.FileName), true);
      if OriginalIcon <> '' then begin // file found!
        DestIcon := ExpandFileTo(ExtractFileName(ChangeFileExt(FileName, '.ico')), Directory);
        CopyFile(OriginalIcon, DestIcon);
        fOptions.Icon := DestIcon;
      end else
        fOptions.Icon := '';
    end;

    // Add list of files
    if aTemplate.Version > 0 then begin
      for I := 0 to pred(aTemplate.UnitCount) do begin

        // Pick file contents
        if aTemplate.Options.useGPP then
          s := aTemplate.Units[I].CppText
        else
          s := aTemplate.Units[I].CText;

        // Add to project list
        if aTemplate.Options.useGPP then
          NewUnit(FALSE, nil, aTemplate.Units[I].CppName)
        else
          NewUnit(FALSE, nil, aTemplate.Units[I].CName);

        // Create an editor
        with fUnits[fUnits.Count - 1] do begin
          Editor := MainForm.EditorList.NewEditor(FileName, True, True);
          try
            // Set filename depending on C/C++ choice
            if (Length(aTemplate.Units[I].CppName) > 0) and (aTemplate.Options.useGPP) then begin
              Editor.FileName := aTemplate.Units[I].CppName;
              fUnits[fUnits.Count - 1].FileName := aTemplate.Units[I].CppName;
            end else if Length(aTemplate.Units[I].CName) > 0 then begin
              Editor.FileName := aTemplate.Units[I].CName;
              fUnits[fUnits.Count - 1].FileName := aTemplate.Units[I].CName;
            end;

            // if file isn't found blindly inserts text of unit
            s2 := ValidateFile(s, ExtractFilePath(aTemplate.FileName)); // next to the template
            if s2 <> '' then begin
              Editor.Text.Lines.LoadFromFile(s2);
            end else if s <> '' then begin
              s := StringReplace(s, '#13#10', #13#10, [rfReplaceAll]);
              Editor.InsertString(s, FALSE);
            end;

            // Always mark modified. We haven't saved yet
            Editor.Text.Modified := TRUE;
            Editor.Activate;
          except
            Editor.Free;
          end;
        end;
      end;

      // Old style...
    end else begin
      NewUnit(FALSE, nil);
      with fUnits[fUnits.Count - 1] do begin
        Editor := MainForm.EditorList.NewEditor(FileName, TRUE, True);
        if fOptions.useGPP then
          s := aTemplate.OldData.CppText
        else
          s := aTemplate.OldData.CText;
        s := ValidateFile(s, ExtractFilePath(aTemplate.FileName));
        if s <> '' then begin
          Editor.Text.Lines.LoadFromFile(s);
          Editor.Text.Modified := TRUE;
        end;
        Editor.Activate;
      end;
    end;
  except
    result := FALSE;
  end;
end;

{ begin XXXKF changed }

procedure TProject.RebuildNodes;
var
  idx: integer;
  oldPaths: TStrings;
  tempnode: TTreeNode;
begin
  MainForm.ProjectView.Items.BeginUpdate;
  try
    // Remember if folder nodes were expanded or collapsed
    // Create a list of expanded folder nodes
    oldPaths := TStringList.Create;
    with MainForm.ProjectView do
      for idx := 0 to Items.Count - 1 do begin
        tempnode := Items[idx];
        if tempnode.Expanded and (tempnode.Data = Pointer(-1)) then // data=pointer(-1) - it's folder
          oldPaths.Add(GetFolderPath(tempnode));
      end;

    // Delete everything
    fNode.DeleteChildren;

    // Recreate everything
    CreateFolderNodes;

    for idx := 0 to pred(fUnits.Count) do
    begin
      fUnits[idx].Node := MakeNewFileNode(ExtractFileName(fUnits[idx].FileName), False,
      FolderNodeFromName(fUnits[idx].Folder));
      fUnits[idx].Node.Data := Pointer(PtrInt(idx));
    end;

    for idx := 0 to pred(fFolders.Count) do
      TTreeNode(fFolderNodes[idx]).AlphaSort;

    Node.AlphaSort;

    // expand nodes expanded before recreating the project tree
    fNode.Collapse(True);
    with MainForm.ProjectView do
      for idx := 0 to Items.Count - 1 do begin
        tempnode := Items[idx];
        if (tempnode.Data = Pointer(-1)) then //it's a folder
          if oldPaths.IndexOf(GetFolderPath(tempnode)) >= 0 then
            tempnode.Expand(False);
      end;
    //FreeAndNil(oldPaths);

    oldPaths.Free;

    fNode.Expand(False);
  finally
    MainForm.ProjectView.Items.EndUpdate;
  end;
end;

procedure TProject.UpdateFolders;
  procedure RunNode(Node: TTreeNode);
  var
    I: integer;
  begin
    for I := 0 to Node.Count - 1 do
      if Node.Items[I].Data = Pointer(-1) then begin
        fFolders.Add(GetFolderPath(Node.Items[I]));
        if Node.Items[I].HasChildren then
          RunNode(Node.Items[I]);
      end;
  end;
var
  idx: integer;
begin
  fFolders.Clear;
  RunNode(fNode);
  for idx := 0 to Units.Count - 1 do
    Units[idx].Folder := GetFolderPath(Units[idx].Node.Parent);
  SetModified(TRUE);
end;

function TProject.GetFolderPath(Node: TTreeNode): String;
begin
  Result := '';
  if not Assigned(Node) then
    Exit;

  if Node.Data <> Pointer(-1) then // not a folder
    Exit;

  while Node.Data = Pointer(-1) do begin
    Result := Format('%s/%s', [Node.Text, Result]);
    Node := Node.Parent;
  end;
  Delete(Result, Length(Result), 1); // remove last '/'
end;

procedure TProject.AddFolder(const s: String);
begin
  if fFolders.IndexOf(s) = -1 then begin
    fFolders.Add(s);
    RebuildNodes;
    MainForm.ProjectView.Select(FolderNodeFromName(s));
    FolderNodeFromName(s).MakeVisible;
    SetModified(TRUE);
  end;
end;

procedure TProject.CheckProjectFileForUpdate;
var
  oldRes: String;
  sl: TStringList;
  i, uCount: integer;
begin
  uCount := fIniFile.ReadInteger('Project', 'UnitCount', 0);

  // Normalize legacy resource entries in memory; opening never writes the project.
  oldRes := finifile.ReadString('Project', 'Resources', '');
  if oldRes <> '' then begin
    sl := TStringList.Create;
    try
      sl.Delimiter := ';';
      sl.StrictDelimiter := True;
      sl.DelimitedText := oldRes;
      for i := 0 to sl.Count - 1 do begin
        if Trim(sl[i]) = '' then Continue;
        Inc(uCount);
        finifile.WriteString('Unit' + IntToStr(uCount), 'FileName', sl[i]);
        finifile.WriteString('Unit' + IntToStr(uCount), 'Folder', 'Resources');
        finifile.WriteBool('Unit' + IntToStr(uCount), 'Compile', True);
        finifile.WriteBool('Unit' + IntToStr(uCount), 'Link', False);
      end;
      fIniFile.WriteInteger('Project', 'UnitCount', uCount);
      oldRes := finifile.ReadString('Project', 'Folders', '');
      if oldRes <> '' then
        oldRes := oldRes + ',Resources'
      else
        oldRes := 'Resources';
      fIniFile.WriteString('Project', 'Folders', oldRes);
      fFolders.Add('Resources');
    finally
      sl.Free;
    end;
  end;

  finifile.DeleteKey('Project', 'Resources');
  finifile.DeleteKey('Project', 'Focused');
  finifile.DeleteKey('Project', 'Order');
  finifile.DeleteKey('Project', 'DebugInfo');
  finifile.DeleteKey('Project', 'ProfileInfo');
end;

procedure TProject.SortUnitsByPriority;
var
  I: integer;
  tmpU: TProjUnit;
  Again: boolean;
begin
  repeat
    I := 0;
    Again := False;
    while I < Units.Count - 1 do begin
      if Units[I + 1].Priority < Units[I].Priority then begin
        tmpU := TProjUnit.Create(Self);
        tmpU.Assign(Units[I]);
        Units[I].Assign(Units[I + 1]);
        Units[I + 1].Assign(tmpU);
        tmpU.Free;
        Again := True;
      end;
      Inc(I);
    end;
  until not Again;
end;

{ TUnitList }

constructor TUnitList.Create;
begin
  inherited Create;
  fList := TList.Create;
end;

destructor TUnitList.Destroy;
var
  I: integer;
begin
  for I := 0 to fList.Count - 1 do
    TProjUnit(fList[I]).Free;
  fList.Free;
  inherited;
end;

function TUnitList.Exists(aunit: TProjUnit): boolean;
var I : integer;
begin
  result := false;
  for I := 0 to fList.Count - 1 do
    begin
     If TProjUnit(fList[I]).FileName = aunit.FileName then
     begin
       result := true;
       exit
     end;
    end;

end;

function TUnitList.Add(aunit: TProjUnit): integer;
begin
  result := fList.Add(aunit);
end;

procedure TUnitList.Remove(index: integer);
begin
  fList.Delete(index);
  fList.Pack;
  fList.Capacity := fList.Count;
end;

function TUnitList.GetCount: integer;
begin
  result := fList.Count;
end;

function TUnitList.GetItem(index: integer): TProjUnit;
begin
  result := TProjUnit(fList[index]);
end;

function TUnitList.IndexOf(Editor: TEditor): integer;
begin
  result := IndexOf(editor.FileName);
end;

function TUnitList.IndexOf(const FileName: String): integer;
var
  s1, s2: String;
begin
  for result := 0 to fList.Count - 1 do begin
    s1 := GetRealPath(TProjUnit(fList[result]).FileName, TProjUnit(fList[result]).fParent.Directory);
    s2 := GetRealPath(FileName, TProjUnit(fList[result]).fParent.Directory);
    if SameText(s1, s2) then
      exit;
  end;
  result := -1;
end;

end.

