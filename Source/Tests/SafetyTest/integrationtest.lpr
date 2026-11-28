program integrationtest;
{$mode delphi}
uses cthreads, SafetyInterfaces, Forms, Classes, SysUtils, BaseUnix, Dialogs,
 InterfaceBase, LCLType, Controls, main, Editor, Project, devCFG, FileTransactions,
 MultiLangSupport, Version, Compiler, devExec, ProjectOptionsFrm, ProjectTypes, WindowsGameFrm, Types, WindowsGameCore, devPlatform, Process, LCLIntf, FileUtil, WindowsSetupFrm, ExtCtrls, StdCtrls, IniFiles, AboutFrm, UpdateCheckFrm, Graphics, Math, SynGutterLineNumber, SynEditCompat, DataFrm, EditorOptFrm, NewProjectFrm, NewTemplateFrm, IncrementalFrm, ClangFormatterOptionsFrm, RemoveUnitFrm;
{$R ../../penguin-cpp.res}
type TProbeCompiler=class(TCompiler)
 procedure BeginCommand(const Command:String);
end;
TSetupReplacementThread=class(TThread)
 protected procedure Execute; override;
end;
TRunner=class
 procedure Run(Data:PtrInt);
end;
TCallbacks=class
 ReplacementThread:TThread;
 LogText,ExpectedRelease:String;
 UpdateLinksValid:Boolean;
 Successes,Ends,SetupTicks,LayoutStage:Integer; SetupFailureShown,LayoutValid:Boolean;
 procedure InspectUpdateDialog(Sender:TObject);
 procedure InspectCompatibilityDialog(Sender:TObject);
 procedure CancelSetupOnError(Sender:TObject);
 destructor Destroy; override;
 procedure Success;
 procedure Finish;
 procedure Log(const Text:String);
 procedure Diagnostic(const Line,Col,Name,Message:String);
end;
procedure TProbeCompiler.BeginCommand(const Command:String);
begin LaunchThread(Command,'') end;
function ControlsFit(Parent:TWinControl):Boolean;
var I,J:Integer; Item,Other:TControl; Overlap:TRect;
begin
 Result:=False;
 for I:=0 to Parent.ControlCount-1 do begin
  Item:=Parent.Controls[I]; if not Item.Visible then Continue;
  if (Item.Left<0) or (Item.Top<0) or (Item.Left+Item.Width>Parent.ClientWidth) or
    (Item.Top+Item.Height>Parent.ClientHeight) then begin WriteLn('Outside: ',Item.Name,' ',Item.Left,',',Item.Top,' ',Item.Width,'x',Item.Height,' parent ',Parent.Name,' ',Parent.ClientWidth,'x',Parent.ClientHeight); Exit end;
  for J:=0 to I-1 do begin
   Other:=Parent.Controls[J];
   if Other.Visible and IntersectRect(Overlap,Item.BoundsRect,Other.BoundsRect) then begin WriteLn('Overlap: ',Parent.Name,'/',Item.Name,' with ',Other.Name); Exit end;
  end;
  if (Item is TPanel) and not ControlsFit(TWinControl(Item)) then Exit;
 end;
 Result:=True;
end;
procedure SaveFormImage(Form:TCustomForm; const Name:String);
var Image:TBitmap; PNG:TPortableNetworkGraphic; Folder:String;
begin
 Folder:=GetEnvironmentVariable('PENGUIN_GUI_SCREENSHOTS'); if Folder='' then Exit;
 ForceDirectories(Folder); Image:=Form.GetFormImage; PNG:=TPortableNetworkGraphic.Create;
 try PNG.Assign(Image); PNG.SaveToFile(IncludeTrailingPathDelimiter(Folder)+Name+'.png');
 finally PNG.Free; Image.Free end;
end;
procedure TCallbacks.InspectUpdateDialog(Sender:TObject);
var F:TCustomForm; Repo,Notes,Retry:TComponent;
begin
 Inc(SetupTicks); F:=Screen.ActiveCustomForm;
 if not Assigned(F) or (F.ClassName<>'TUpdateForm') then Exit;
 Repo:=F.FindComponent('RepositoryLink'); Notes:=F.FindComponent('ReleaseNotesLink');
 Retry:=F.FindComponent('RetryButton');
 if (Retry is TButton) and TButton(Retry).Enabled then begin
  UpdateLinksValid:=(Repo is TLabel) and (Notes is TLabel) and ControlsFit(F);
  if UpdateLinksValid then
   UpdateLinksValid:=(TLabel(Repo).Hint=DEVCPP_REPOSITORY_URL) and
    (TLabel(Notes).Hint=ExpectedRelease) and Assigned(TLabel(Notes).OnClick) and
    (TLabel(Notes).Cursor=crHandPoint) and (TLabel(Notes).Caption=Lang[80018]);
  if ExpectedRelease=DEVCPP_RELEASE_URL then SaveFormImage(F,'updates-offline')
  else SaveFormImage(F,'updates-new');
  F.ModalResult:=mrCancel; TTimer(Sender).Enabled:=False;
 end else if SetupTicks>100 then begin F.ModalResult:=mrCancel; TTimer(Sender).Enabled:=False end;
end;
procedure TCallbacks.InspectCompatibilityDialog(Sender:TObject);
var Form:TCustomForm; I:Integer; Selector:TComponent;
begin
 Form:=Screen.ActiveCustomForm;
 if not Assigned(Form) or (Form.ClassName<>'TGameForm') then Exit;
 if LayoutStage=0 then begin
  LayoutValid:=ControlsFit(Form);
  Selector:=Form.FindComponent('ConsoleProfile');
  LayoutValid:=LayoutValid and (Selector is TComboBox);
  if Selector is TComboBox then begin
   LayoutValid:=LayoutValid and (TComboBox(Selector).Items.Count=4) and
    (Pos('UTF-8',TComboBox(Selector).Items[0])>0) and (Pos('437',TComboBox(Selector).Items[1])>0) and
    (Pos('1252',TComboBox(Selector).Items[2])>0);
   TComboBox(Selector).ItemIndex:=Ord(wcOEM437);
  end;
  Inc(LayoutStage);
  for I:=0 to Form.ComponentCount-1 do
   if (Form.Components[I] is TButton) and (TButton(Form.Components[I]).Caption=Lang[80223]) then
    begin TButton(Form.Components[I]).Click; Break end;
 end else begin
  LayoutValid:=LayoutValid and (Form.ClientHeight>500) and ControlsFit(Form);
  Form.ModalResult:=mrCancel; TTimer(Sender).Enabled:=False;
 end;
end;
procedure TSetupReplacementThread.Execute;
var UntilTime:QWord;
begin
 UntilTime:=GetTickCount64+5000;
 while not Terminated and (GetTickCount64<UntilTime) do Sleep(10);
end;
destructor TCallbacks.Destroy;
begin
 if Assigned(ReplacementThread) then begin
  ReplacementThread.Terminate; ReplacementThread.WaitFor; ReplacementThread.Free;
 end;
 inherited Destroy;
end;
procedure TCallbacks.CancelSetupOnError(Sender:TObject);
var F:TCustomForm; Details:TComponent;
begin
 Inc(SetupTicks); F:=Screen.ActiveCustomForm;
 if Assigned(F) and (F.ClassName='TSetupForm') then begin
  Details:=F.FindComponent('SetupErrorDetails');
  if (Details is TMemo) and TMemo(Details).Visible then begin
   if not Assigned(ReplacementThread) then ReplacementThread:=TSetupReplacementThread.Create(False);
   WriteLn('Setup error details: ',TMemo(Details).Text);
   SetupFailureShown:=TMemo(Details).ReadOnly and (Pos('Compiler unavailable',TMemo(Details).Text)>0) and ControlsFit(F);
   F.ModalResult:=mrCancel; TTimer(Sender).Enabled:=False;
  end else if SetupTicks>4000 then F.ModalResult:=mrCancel;
 end;
end;
procedure TCallbacks.Success; begin Inc(Successes) end;
procedure TCallbacks.Finish; begin Inc(Ends) end;
procedure TCallbacks.Log(const Text:String); begin LogText:=LogText+Text+LineEnding; WriteLn(Text) end;
procedure TCallbacks.Diagnostic(const Line,Col,Name,Message:String); begin WriteLn(Name,':',Line,':',Message) end;
var C:TProbeCompiler; Hooks:TCallbacks;
Dir,SourceRoot:String; E:TEditor; P:TProject; OptionsDialog:TProjectOptionsFrm; OriginalCompile:Boolean; Values:TCompilerOptionsValues;
procedure Check(Value:Boolean; const Name:String);
begin if not Value then raise Exception.Create(Name); WriteLn('[OK] ',Name) end;
procedure AllLanguagesTest;
var Files,English:TStringList; Search:TSearchRec; I,J,ID,Checked:Integer; Text:String;
begin
 Files:=TStringList.Create; English:=TStringList.Create;
 try
  English.LoadFromFile(devDirs.Lang+'English.lng');
  if FindFirst(devDirs.Lang+'*.lng',faAnyFile,Search)=0 then begin
   repeat Files.Add(Search.Name) until FindNext(Search)<>0;
   FindClose(Search);
  end;
  Files.Sort;
  Check(Files.Count>=32,'all bundled language files are present');
  for I:=0 to Files.Count-1 do begin
   devData.Ini.WriteString('Options','Language','""'+Files[I]+'""');
   devData.ReadSelf;
   Check(devData.Language=Files[I],'nested legacy preference resolves: '+Files[I]);
   Lang.Open(devData.Language); Checked:=0;
   for J:=0 to English.Count-1 do
    if TryStrToInt(English.Names[J],ID) and (English.ValueFromIndex[J]<>'') then begin
     Text:=Lang[ID];
     if (Text='') or (Pos('translation missing',Text)>0) then
      Check(False,Files[I]+' missing translation and fallback: '+IntToStr(ID));
     Inc(Checked);
    end;
   Check(Checked>1000,'complete language and fallback coverage: '+Files[I]);
  end;
 finally
  devData.Language:='English.lng'; Lang.Open(devData.Language);
  English.Free; Files.Free;
 end;
end;
procedure WaitCompile;
var Start:QWord;
begin
 Start:=GetTickCount64;
 while C.Compiling and (GetTickCount64-Start<5000) do CheckSynchronize(10);
 Check(not C.Compiling,'compiler completes');
end;
procedure WaitMainCompile;
var Start:QWord;
begin
 Start:=GetTickCount64;
 repeat
  CheckSynchronize(10);
  MainForm.actCompileUpdate(MainForm.actCompile);
 until MainForm.actCompile.Enabled or (GetTickCount64-Start>5000);
 Check(MainForm.actCompile.Enabled,'IDE compilation completes');
end;
procedure NewAttempt;
begin
 C.Free; C:=TProbeCompiler.Create;
 C.OnCompSuccess:=Hooks.Success; C.OnCompEnd:=Hooks.Finish;
end;
function ReadText(const Name:String):String;
var L:TStringList;
begin L:=TStringList.Create;try L.LoadFromFile(Name);Result:=L.Text finally L.Free end end;
procedure SetReply(Value:Integer);
begin
 case Value of
  mrYes: DialogReply:=idButtonYes;
  mrNo: DialogReply:=idButtonNo;
  mrCancel: DialogReply:=idButtonCancel;
 else DialogReply:=idButtonOK end;
end;
procedure WelcomeLayoutTest;
var I:Integer; Buttons:array[0..2] of TControl; Bounds:TRect;
begin
 MainForm.Show;
 try
  for I:=0 to 1 do begin
   MainForm.WindowState:=wsNormal;
   if I=0 then MainForm.SetBounds(0,0,1024,768) else MainForm.SetBounds(0,0,1440,900);
   Application.ProcessMessages; Application.ProcessMessages;
   Buttons[0]:=MainForm.ButtonNewDocument; Buttons[1]:=MainForm.ButtonOpenDocument; Buttons[2]:=MainForm.ButtonOptions;
   Check(not MainForm.PanelRight.AutoSize,'welcome actions are not moved by panel autosizing');
   Check((Buttons[0].Top>=20) and (Buttons[0].Top=Buttons[1].Top) and (Buttons[1].Top=Buttons[2].Top) and
    (Buttons[0].Left+Buttons[0].Width<=Buttons[1].Left) and
    (Buttons[1].Left+Buttons[1].Width<=Buttons[2].Left) and
    (Buttons[2].Left+Buttons[2].Width<=MainForm.PanelRight.ClientWidth),
    'welcome New/Open/Options stay ordered inside their column after resizing');
   Check(not IntersectRect(Bounds,Buttons[0].BoundsRect,MainForm.ButtonChangeTheme.BoundsRect),
    'welcome primary and secondary actions do not overlap');
   SaveFormImage(MainForm,'welcome-'+IntToStr(I));
  end;
 finally MainForm.Hide end;
end;

procedure DialogRegressionTest;
var NewProject:TNewProjectForm; Search:TIncrementalForm; Formatter:TClangFormatterOptionsForm;
 OldTemplates,OldDir,OldFile,Before:String; Edit:TEditor;
begin
 MainForm.Show; Application.ProcessMessages;
 OldTemplates:=devDirs.Templates; devDirs.Templates:=SourceRoot+'/Templates/';
 NewProject:=nil;
 try
  NewProject:=TNewProjectForm.Create(MainForm); NewProject.Show; Application.ProcessMessages;
  Check((NewProject.ProjView.Columns.Count>0) and (NewProject.ProjView.Items.Count>0),
   'new project shows named templates in a native list with columns');
  Check(Assigned(NewProject.ProjView.Selected) and NewProject.btnOK.Enabled and Assigned(NewProject.GetTemplate),
   'selected project template can be used immediately');
 finally NewProject.Free; devDirs.Templates:=OldTemplates end;
 Edit:=MainForm.EditorList.NewEditor(Dir+'search-sample.cpp',False,False);
 Edit.Text.Text:='int search_token = 1;';
 Search:=TIncrementalForm.Create(MainForm);
 try
  Search.Editor:=Edit.Text; Search.Edit.Text:='search_token';
  Check(Search.Edit.Color=clWindow,'search text set before Show keeps its normal background');
  Search.Show; Application.ProcessMessages;
  Check((Search.ClientHeight>=Search.Edit.Top+Search.Edit.Height) and
   (Search.Edit.Left+Search.Edit.Width<Search.btnPrev.Left) and
   (Search.btnPrev.Left+Search.btnPrev.Width<Search.btnNext.Left) and
   (Search.btnNext.Left+Search.btnNext.Width<=Search.ClientWidth),
   'incremental search keeps input and both buttons inside a non-overlapping window');
 finally Search.Free; MainForm.EditorList.ForceCloseEditor(Edit) end;
 Edit:=MainForm.EditorList.NewEditor(Dir+'formatter-sample.cpp',False,False);
 Edit.Text.Text:='int format_test = 1;';
 OldDir:=devFormatterClang.ClangDir; OldFile:=devFormatterClang.ClangFile;
 ForceDirectories(Dir+'formatter-bin');
 AtomicWriteFile(Dir+'formatter-bin/clang-format','#!/bin/sh'+LineEnding+'echo FORMATTER_FAILED >&2'+LineEnding+'exit 2'+LineEnding);
 fpChmod(Dir+'formatter-bin/clang-format',&700);
 devFormatterClang.ClangDir:=ExtractRelativePath(devDirs.Exec,Dir+'formatter-bin/'); devFormatterClang.ClangFile:='clang-format';
 Formatter:=nil;
 try
  Formatter:=TClangFormatterOptionsForm.Create(MainForm);
  Before:=ReadText(FormatterTempFile('DummyInput.cpp'));
  Formatter.CommandChange(nil);
  Check((devFormatterClang.LastExitCode=2) and not Formatter.btnExecute.Enabled,
   'failed formatter preview disables execution');
  Check((Pos('format_test',Formatter.synExample.Text)>0) and
   (Pos('FORMATTER_FAILED',Formatter.synExample.Text)=0) and
   (ReadText(FormatterTempFile('DummyInput.cpp'))=Before),
   'formatter error never replaces the sample source or scratch file');
 finally
  Formatter.Free;
  devFormatterClang.ClangDir:=OldDir; devFormatterClang.ClangFile:=OldFile;
  MainForm.EditorList.ForceCloseEditor(Edit);
 end;
end;

procedure EditorAppearanceTest;
const Counts:array[0..3] of Integer=(9,99,999,10000);
 Sizes:array[1..3] of Integer=(6,24,72);
var Edit:TEditor; Part:TSynGutterLineNumber; I,J,K,Digits,Before,BaseSize,X,Y,Row,Delta:Integer;
 Image:TBitmap; FoundMark:Boolean; Options:TEditorOptForm;
begin
 Check(Pos('"',devEditor.Font.Name)=0,'editor font recovers legacy wrapping quotes');
 Check(devEditor.Font.Size=15,'nested font settings load even without an Editor parent section');
 Check(Screen.Fonts.IndexOf(devEditor.Font.Name)>=0,'editor font is available on this platform');
 Check(MainForm.LeftPageControl.Width<=MainForm.ClientWidth div 3,
  'oversized saved project sidebar preserves space for the editor');
 AtomicWriteFile(Dir+'appearance.cpp','#include <iostream>'+LineEnding+'int main() { return 0; }');
 MainForm.Show;
 MainForm.OpenFile(Dir+'appearance.cpp');
 Edit:=MainForm.EditorList.FileIsOpen(Dir+'appearance.cpp');
 Check(Assigned(Edit) and not MainForm.MainPanel.Visible,'opening C++ shows the editor instead of the welcome overlay');
 try
  Application.ProcessMessages;
  Options:=TEditorOptForm.Create(MainForm);
  try
   Check((Options.edEditorSize.MinValue=6) and (Options.edEditorSize.MaxValue=72),
    'font options use the same size limits as keyboard and wheel zoom');
   Check(Options.edGutterWidth.MaxValue=12,'gutter width control stays within the supported digit range');
   Check(not Options.cbGutterFnt.Enabled and not Options.cboGutterFont.Enabled and
    not Options.edGutterSize.Enabled and (Options.edGutterSize.Value=Options.edEditorSize.Value),
    'line number font options reflect the native shared editor font');
  finally Options.Free end;
  Edit.Text.Canvas.Font.Assign(Edit.Text.Font);
  Check(Abs(Edit.Text.Canvas.TextWidth('MMMMMMMM')-Edit.Text.Canvas.TextWidth('iiiiiiii'))<=2,
   'opened C++ file uses monospaced glyph widths');
  Part:=nil;
  for I:=0 to Edit.Text.Gutter.Parts.Count-1 do begin
   WriteLn('Gutter part: ',Edit.Text.Gutter.Parts[I].ClassName,' left=',
    Edit.Text.Gutter.Parts[I].Left,' width=',Edit.Text.Gutter.Parts[I].Width);
   if Edit.Text.Gutter.Parts[I] is TSynGutterLineNumber then
    Part:=TSynGutterLineNumber(Edit.Text.Gutter.Parts[I]);
  end;
  Check(Assigned(Part),'line number gutter is present');
  WriteLn('Gutter minimum digits: saved=',devEditor.GutterSize,' actual=',Part.DigitCount);
  BaseSize:=devEditor.Font.Size;
  for I:=Low(Counts) to High(Counts) do begin
   Edit.Text.Lines.BeginUpdate;
   try
    Edit.Text.Lines.Clear;
    for J:=1 to Counts[I] do Edit.Text.Lines.Add('int value = 0;');
   finally Edit.Text.Lines.EndUpdate end;
   Application.ProcessMessages;
   Digits:=Max(Part.DigitCount,Length(IntToStr(Counts[I])));
   Before:=Edit.Text.Gutter.Width;
   for K:=1 to 3 do begin
    Delta:=(Sizes[K]-BaseSize)*120;
    MainForm.ZoomEditors(Delta); Application.ProcessMessages;
    WriteLn('Gutter metrics: lines=',Counts[I],' size=',devEditor.Font.Size,
     ' char=',Edit.Text.CharWidth,' numbers=',Part.Width,' gutter=',Edit.Text.Gutter.Width);
    Check(Part.Width<=Digits*Edit.Text.CharWidth+3,'number column fits digit count after zoom');
    X:=GutterMarkLeft(Edit.Text,dmMain.GutterImages.Width);
    Check((X>=0) and (X+dmMain.GutterImages.Width<=Part.Left),
     'breakpoint icons remain outside the number column at every zoom');
    MainForm.ZoomEditors(-Delta); Application.ProcessMessages;
    Check((devEditor.Font.Size=BaseSize) and (Abs(Edit.Text.Gutter.Width-Before)<=1),
     'repeated zoom returns to original gutter width without accumulated growth');
   end;
  end;
  ApplyGutter(Edit.Text,True,False,True,False,False,4);
  Application.ProcessMessages;
  Check(Edit.Text.Gutter.AutoSize and not Part.AutoSize,'fixed digit count still allows total gutter width to follow font zoom');
  Check(Part.Width<=4*Edit.Text.CharWidth+3,'fixed digit count takes effect immediately without a zoom');
  Before:=Part.Width;
  MainForm.ZoomEditors(9*120); Application.ProcessMessages;
  WriteLn('Fixed gutter metrics: before=',Before,' after=',Part.Width,' char=',Edit.Text.CharWidth,' digits=',Part.DigitCount);
  Check((Part.Width>Before) and (Part.Width<=4*Edit.Text.CharWidth+3),'fixed gutter width follows four digits when zooming');
  MainForm.ZoomEditors(-9*120); Application.ProcessMessages;
  ApplyGutter(Edit.Text,True,True,True,False,False,devEditor.GutterSize);
  Application.ProcessMessages;
  Check(Part.AutoSize and (Part.Width<=5*Edit.Text.CharWidth+3),'automatic gutter resumes fitting the actual line count');
  Edit.Text.Lines.Text:='int f() {'+LineEnding+'  int x = 1;'+LineEnding+
   '  return x;'+LineEnding+'}'+LineEnding+LineEnding+'int value = 0;';
  Edit.Text.CollapseAll; Application.ProcessMessages;
  Row:=Edit.Text.TextXYToScreenXY(Point(1,6)).Y;
  Check(Row<6,'folding changes the visible row of the breakpoint line');
  Edit.ToggleBreakpoint(6);
  Image:=TBitmap.Create;
  try
   Image.SetSize(Edit.Text.Gutter.Width,Edit.Text.ClientHeight);
   Image.Canvas.Brush.Color:=clFuchsia; Image.Canvas.FillRect(Rect(0,0,Image.Width,Image.Height));
   Edit.Text.OnPaint(Edit.Text,Image.Canvas);
   FoundMark:=False;
   for Y:=(Row-1)*Edit.Text.LineHeight to Min(Row*Edit.Text.LineHeight-1,Image.Height-1) do
    for X:=0 to Part.Left-1 do
     if Image.Canvas.Pixels[X,Y]<>clFuchsia then FoundMark:=True;
   Check(FoundMark,'breakpoint icon follows its logical line after folding');
  finally Image.Free; Edit.ToggleBreakpoint(6); Edit.Text.UncollapseAll end;
  Edit.Text.Lines.Text:='#include <iostream>'+LineEnding+'int main() { return 0; }';
  SaveFormImage(MainForm,'editor-appearance');
 finally
  Edit.Text.Modified:=False; MainForm.EditorList.CloseEditor(Edit); MainForm.Hide;
 end;
end;

procedure ReleaseLinksTest;
var About:TAboutForm; Timer:TTimer; Hook:TCallbacks; OldPath,Script:String; I:Integer;
begin
 About:=TAboutForm.Create(MainForm);
 try
  About.Show; Application.ProcessMessages; SaveFormImage(About,'about');
  About.ClientWidth:=640; Application.ProcessMessages;
  Check((About.paBanner.Width=About.ClientWidth) and (About.imgBanner.Width=About.paBanner.ClientWidth) and
   About.imgBanner.Proportional and not About.paBanner.ParentBackground and (About.paBanner.Color=$00FCEEDA),
   'About header fills available width while preserving image proportions');
  SaveFormImage(About,'about-wide');
  About.ClientWidth:=480; Application.ProcessMessages;
  Check((Pos(DEVCPP_VERSION,About.lblVersion.Caption)>0) and Assigned(About.lblVersion.OnClick) and
   (Pos(DEVCPP_RELEASE_URL,About.lblVersion.Hint)=1),'About version links to its own release notes');
  Check((About.lblCreator.Caption=DEVCPP_CREATOR) and
   (Pos('/COPYING.txt',About.lblLicense.Hint)>0) and ControlsFit(About) and ControlsFit(About.grpLinks),
   'About is compact, credits its creator and links the license without overlap');
  Check((About.lblRepositoryURL.Hint=DEVCPP_REPOSITORY_URL) and
   (About.lblRepositoryURL.Left+About.lblRepositoryURL.Width<=About.grpLinks.ClientWidth),
   'About repository hyperlink fits its group');
 finally About.Free end;
 OldPath:=ChildPath; ForceDirectories(Dir+'update-tools'); Script:=Dir+'update-tools/curl';
 Timer:=TTimer.Create(nil); Hook:=TCallbacks.Create;
 try
  ChildPath:=Dir+'update-tools'+PathSeparator+GetEnvironmentVariable('PATH');
  for I:=0 to 1 do begin
   if I=0 then begin
    AtomicWriteFile(Script,'#!/bin/sh'+LineEnding+'printf %s https://github.com/JuanFranG/Penguin-cpp/releases/tag/v0.5.6'+LineEnding);
    Hook.ExpectedRelease:='https://github.com/JuanFranG/Penguin-cpp/releases/tag/v0.5.6';
   end else begin
    AtomicWriteFile(Script,'#!/bin/sh'+LineEnding+'exit 7'+LineEnding);
    Hook.ExpectedRelease:=DEVCPP_RELEASE_URL;
   end;
   fpChmod(Script,&700); Hook.SetupTicks:=0; Hook.UpdateLinksValid:=False;
   Timer.Interval:=80; Timer.OnTimer:=Hook.InspectUpdateDialog; Timer.Enabled:=True;
   Check(not ShowUpdateCheck,'closing update check does not request installation');
   Check(Hook.UpdateLinksValid,'update links work for available release and network failure without overlap');
  end;
 finally ChildPath:=OldPath; Timer.Free; Hook.Free end;
end;

procedure CompatibilityLayoutTest;
var Config:TWindowsGameConfig; Timer:TTimer; Hook:TCallbacks;
begin
 DiscoverWindowsGameConfig(SourceRoot+'/',Config);
 Timer:=TTimer.Create(nil); Hook:=TCallbacks.Create;
 try
  Timer.Interval:=80; Timer.OnTimer:=Hook.InspectCompatibilityDialog; Timer.Enabled:=True;
  Check(not ConfigureWindowsGame(Config),'compatibility profile selection can be cancelled');
  Check(Hook.LayoutValid,'Cocoa compatibility controls fit without overlap in compact and advanced views');
  Check(Config.ConsoleProfile=wcUTF8,'cancel does not persist the selected console profile');
 finally Timer.Free; Hook.Free end;
end;

procedure SetupErrorTest;
var Config:TWindowsGameConfig; Timer:TTimer; Hook:TCallbacks;
begin
 DiscoverWindowsGameConfig(SourceRoot+'/',Config); Config.Toolchain:=Dir+'missing-compiler';
 Timer:=TTimer.Create(nil); Hook:=TCallbacks.Create;
 try
  Timer.Interval:=50; Timer.OnTimer:=Hook.CancelSetupOnError; Timer.Enabled:=True;
  Check(not EnsureWindowsEnvironment(Config,GetUserDataDir,True),'failed setup remains recoverable and can be cancelled');
  Check(Assigned(Hook.ReplacementThread) and not Hook.ReplacementThread.Finished,
   'closing setup does not join another thread that reused the completed worker handle');
  Check(Hook.SetupFailureShown,'setup displays a readable copyable error instead of only a log path');
 finally Timer.Free; Hook.Free end;
end;

procedure WindowsBuildTests;
var Config:TWindowsGameConfig; ProjectCopy:TProject; Commands,Text:TStringList;
  Repo,Resources,Probe,Marker,Output,OldDir,ManagedPrefix,Server:String; Recovery:TSearchRec; Monitor:TTimer; Watcher:TCallbacks; Native:TdevCompilerSet;
  procedure RunProbe(const Executable,Page:String);
  var Exe:String;
  begin
    Marker:=Dir+'runtime-marker'; DeleteFile(Marker);
    Check(WindowsGameCommand(Config,Executable,'','',Commands)=wgOK,'Windows probe command');
    Exe:=Commands[0]; Commands.Delete(0); Commands.Add(Marker); Commands.Add(Page);
    Check(RunCommand(Exe,Commands.ToStringArray,Output) and FileExists(Marker),
      'compiled executable has the selected CRT console profile');
  end;
begin
 if GetEnvironmentVariable('PENGUIN_TEST_WINDOWS_TOOLCHAIN')='' then begin
  WriteLn('[SKIP] Windows compiler integration: no test toolchain configured'); Exit;
 end;
 Repo:=SourceRoot; OldDir:=GetCurrentDir; Resources:=Dir+'resources/'; ProjectCopy:=nil;
 ForceDirectories(Resources+'Compat/windows/tools/bin');
 fpSymlink(PChar(ExpandFileName(GetEnvironmentVariable('PENGUIN_TEST_WINDOWS_MAKE'))),
  PChar(Resources+'Compat/windows/tools/bin/make'));
 Check(CopyFile(Repo+'/Compat/windows/console-startup.c',Resources+'Compat/windows/console-startup.c'),'copy console support fixture');
 Check(CopyFile(Repo+'/Compat/windows/self-test.cpp',Resources+'Compat/windows/self-test.cpp'),'copy setup self-test fixture');
 DiscoverWindowsGameConfig(Resources,Config); Config.Mode:=cmWindows; Config.Enabled:=True;
 Config.Toolchain:=ExpandFileName(GetEnvironmentVariable('PENGUIN_TEST_WINDOWS_TOOLCHAIN'));
 Config.Runner:=ExpandFileName(GetEnvironmentVariable('PENGUIN_TEST_WINDOWS_RUNNER'));
 Config.Prefix:=ExpandFileName(GetEnvironmentVariable('PENGUIN_TEST_WINDOWS_PREFIX'));
 Native:=devCompilerSets.DefaultSet;
 ManagedPrefix:=WindowsDefaultPrefix(GetUserDataDir); ForceDirectories(ManagedPrefix);
 AtomicWriteFile(ManagedPrefix+'/partial-user-data','preserve this');
 Server:=ExtractFilePath(Config.Runner)+'wineserver';
 Check(RunCommand('/usr/bin/env',['WINEPREFIX='+ManagedPrefix,Server,'-p10'],Output),'start an isolated server for partial-prefix recovery');
 Config.Prefix:='';
 Monitor:=TTimer.Create(nil); Watcher:=TCallbacks.Create;
 Monitor.Interval:=50; Monitor.OnTimer:=Watcher.CancelSetupOnError; Monitor.Enabled:=True;
 Check(EnsureWindowsEnvironment(Config,GetUserDataDir,True),'partial prefix recovers through the real setup worker');
 Check(WindowsEnvironmentIsReady(Config,GetUserDataDir),'recovered environment passes the real self-test');
 Check(FindFirst(ManagedPrefix+'.incomplete-*',faDirectory,Recovery)=0,'partial prefix has a recovery backup');
 Check(FileExists(ExtractFilePath(ManagedPrefix)+Recovery.Name+'/partial-user-data'),'recovery backup preserves the original data'); FindClose(Recovery);
 Config.Prefix:=ExpandFileName(GetEnvironmentVariable('PENGUIN_TEST_WINDOWS_PREFIX'));
 Commands:=TStringList.Create; Text:=TStringList.Create; Hooks:=TCallbacks.Create;
 try
  Probe:=Dir+'stand alone $(touch injected).cpp';
  Text.Text := '#include <windows.h>'+LineEnding+'#include <stdio.h>'+LineEnding+
    '#include <stdlib.h>'+LineEnding+'#include <wchar.h>'+LineEnding+'#include <locale.h>'+LineEnding+'#include <string.h>'+LineEnding+
    'int main(int n,char **v){ wchar_t w=0; if(n<3)return 9; '+
    'if(atoi(v[2])==0){if(strcmp(setlocale(LC_CTYPE,0),"C"))return 5;}else if(atoi(v[2])==437){if(mbtowc(&w,"\xda",1)!=1||w!=0x250c)return 8;}'+
    'else {if(mbtowc(&w,"\xc3\xb1",2)!=2||w!=0xf1)return 7;}'+
    'FILE*f=fopen(v[1],"wb");if(!f)return 6;fputs("CONSOLE_BUILD_OK",f);fclose(f);return 0;}';
  Text.SaveToFile(Probe);
  C:=TProbeCompiler.Create;
  try
   C.CompilerSet:=Native; C.StandaloneConfig:=Config; C.Target:=ctFile; C.SourceFile:=Probe;
   C.OnCompSuccess:=Hooks.Success; C.OnCompEnd:=Hooks.Finish; C.OnLogEntry:=Hooks.Log; C.OnOutput:=Hooks.Diagnostic;
   Check(C.Compile,'standalone Windows compilation starts'); WaitCompile;
   Check(C.Succeeded and FileExists(ChangeFileExt(Probe,'.exe')),'standalone Windows console support links');
   RunProbe(ChangeFileExt(Probe,'.exe'),'65001');
   Check(not FileExists(Dir+'injected'),'console build preserves literal shell metacharacters');
   Config.ConsoleProfile:=wcOEM437; C.StandaloneConfig:=Config;
   Check(C.Compile,'standalone OEM compilation starts'); WaitCompile;
   Check(C.Succeeded,'standalone OEM console support links'); RunProbe(ChangeFileExt(Probe,'.exe'),'437');
   Config.ConsoleProfile:=wcProgram; C.StandaloneConfig:=Config;
   Check(C.Compile,'standalone program-controlled build starts'); WaitCompile;
   Check(C.Succeeded,'program-controlled standalone links'); RunProbe(ChangeFileExt(Probe,'.exe'),'0');
   Config.ConsoleProfile:=wcOEM437;
  finally C.Free end;
  ProjectCopy:=TProject.Create(Dir+'Windows console.dev','Console integration'); MainForm.Project:=ProjectCopy;
  ProjectCopy.Options.WindowsGame:=Config; ProjectCopy.Options.typ:=dptCon; ProjectCopy.Options.useGPP:=True;
  ProjectCopy.Options.CompilerSet:=devCompilerSets.DefaultSetIndex;
  ProjectCopy.Options.CompilerOptions:=Copy(Native.INIOptions); ProjectCopy.Options.ObjectOutput:=Dir+'obj with spaces';
  ProjectCopy.AddUnit(Probe,ProjectCopy.Node,False); ProjectCopy.ResolveCompatibility;
  C:=TProbeCompiler.Create;
  try
   C.CompilerSet:=Native; C.Project:=ProjectCopy; C.Target:=ctProject;
   C.OnCompSuccess:=Hooks.Success; C.OnCompEnd:=Hooks.Finish; C.OnLogEntry:=Hooks.Log; C.OnOutput:=Hooks.Diagnostic;
   Check(C.Compile,'Windows project compilation starts'); WaitCompile;
   Check(C.Succeeded,'generated Makefile builds console support'); RunProbe(ProjectCopy.Executable,'437');
   ProjectCopy.Options.WindowsGame.ConsoleProfile:=wcUTF8; Config.ConsoleProfile:=wcUTF8;
   Check(C.Compile,'Windows project profile change starts'); WaitCompile;
   Check(C.Succeeded,'profile change relinks the Windows project'); RunProbe(ProjectCopy.Executable,'65001');
   ProjectCopy.Options.WindowsGame.ConsoleProfile:=wcProgram; Config.ConsoleProfile:=wcProgram;
   Check(C.Compile,'project program-controlled build starts'); WaitCompile;
   Check(C.Succeeded,'program-controlled project relinks without startup support'); RunProbe(ProjectCopy.Executable,'0');
   C.Clean; WaitCompile;
   Check(not FileExists(ProjectCopy.Executable+'.penguin-console.win.o'),'Clean removes console support from an earlier profile');
  finally C.Free end;
 finally
  MainForm.Project:=nil; ProjectCopy.Free; Commands.Free; Text.Free; Hooks.Free;
  RunCommand('/usr/bin/env',['WINEPREFIX='+ManagedPrefix,Server,'-k'],Output);
  RunCommand('/usr/bin/env',['WINEPREFIX='+ManagedPrefix,Server,'-w'],Output);
  Monitor.Free; Watcher.Free;
  SetCurrentDir(OldDir);
 end;
end;

procedure LegacyResourceMigrationTest;
var Legacy:TProject; Before,Backup,Name:String; Ini:TMemIniFile;
begin
 Name:=Dir+'legacy-resources.dev'; Backup:=Name+'.bak';
 AtomicWriteFile(Dir+'resource with spaces.rc','1 RCDATA { 1 }');
 AtomicWriteFile(Name,'[Project]'+LineEnding+'Name=Legacy'+LineEnding+'Ver=2'+LineEnding+
  'Type=1'+LineEnding+'UnitCount=1'+LineEnding+
  'Resources="dialog.RC";"resource with spaces.rc";;'+LineEnding+
  '[Unit1]'+LineEnding+'FileName=resource-main.cpp'+LineEnding+'Compile=1'+LineEnding+'Link=1'+LineEnding);
 AtomicWriteFile(Backup,'existing user backup'); Before:=ReadText(Name);
 Legacy:=TProject.Create(Name,DEV_INTERNAL_OPEN); MainForm.Project:=Legacy;
 try
  Check((Legacy.Units.Count=3) and (ExtractFileName(Legacy.Units[1].FileName)='dialog.RC') and
   (ExtractFileName(Legacy.Units[2].FileName)='resource with spaces.rc'),
   'legacy resources become numbered units and preserve spaces');
  Check((ReadText(Name)=Before) and (Trim(ReadText(Backup))='existing user backup'),
   'opening legacy resource project preserves its file and existing backup');
  Check(Legacy.SaveAll,'explicit save commits the migrated resource units');
 finally MainForm.Project:=nil; Legacy.Free end;
 Ini:=TMemIniFile.Create(Name);
 try
  Check((Ini.ReadInteger('Project','UnitCount',0)=3) and (Ini.ReadString('Project','Icon','missing')='') and not Ini.ValueExists('Project','Resources') and
   (Ini.ReadString('Unit2','FileName','')='dialog.RC') and
   (Ini.ReadString('Unit3','FileName','')='resource with spaces.rc'),
   'saved legacy project retains all resources in valid UnitN sections');
 finally Ini.Free end;
 Legacy:=TProject.Create(Name,DEV_INTERNAL_OPEN); MainForm.Project:=Legacy;
 try Check(Legacy.Units.Count=3,'reopening migrated resource project does not duplicate units');
 finally MainForm.Project:=nil; Legacy.Free end;
end;

procedure LegacyResourceTests;
var Proj:TProject; Builder:TCompiler; Hook:TCallbacks; Config:TWindowsGameConfig;
    Ini:TMemIniFile; OriginalDir,Makefile,Custom:String; I:Integer;
 procedure WaitBuilder;
 var Start:QWord;
 begin
  Start:=GetTickCount64;
  while Builder.Compiling and (GetTickCount64-Start<15000) do CheckSynchronize(10);
  Check(not Builder.Compiling,'resource regression compiler completes');
 end;
begin
 Check(MainForm.FindComponent('ImportItem')=nil,'incomplete importer has no menu entry');
 Check((MainForm.FindComponent('actRunTests')=nil) and (MainForm.FindComponent('actDonate')=nil),
   'obsolete test and donation actions are not loaded');
 OriginalDir:=GetCurrentDir; Hook:=TCallbacks.Create; Builder:=TCompiler.Create;
 Proj:=TProject.Create(Dir+'resources.dev','Resources'); MainForm.Project:=Proj;
 try
  AtomicWriteFile(Dir+'resource-main.cpp','int main() { return 0; }');
  AtomicWriteFile(Dir+'dialog.RC','1 RCDATA { 1 }');
  AtomicWriteFile(Dir+'linked.RES','resource bytes');
  Proj.AddUnit(Dir+'resource-main.cpp',Proj.Node,False);
  Proj.AddUnit(Dir+'dialog.RC',Proj.Node,False);
  Proj.AddUnit(Dir+'linked.RES',Proj.Node,False);
  Proj.Units[2].Compile:=False; Proj.Units[2].Link:=False;
  Config:=Proj.Options.WindowsGame; Config.Mode:=cmNative; Config.Enabled:=False;
  Proj.Options.WindowsGame:=Config; Proj.Options.useGPP:=True;
  Builder.CompilerSet:=devCompilerSets.CompilationSet; Builder.Target:=ctProject;
  Builder.Project:=Proj; Builder.OnLogEntry:=Hook.Log; Builder.OnCompSuccess:=Hook.Success;
  Makefile:=Dir+DEV_MAKE_FILE; AtomicWriteFile(Makefile,'previous makefile');
  SetReply(mrOK);
  Check(not Builder.Compile,'native project rejects an active RC instead of skipping it');
  Check((Pos('dialog.RC',LastDialog)>0) and not Builder.Compiling and not Builder.Succeeded and
    (Builder.ErrorCount=1) and (Hook.Successes=0),'resource rejection is visible and cannot trigger Run');
  Check(not Builder.RebuildAll,'Rebuild also rejects unsupported resources before cleaning');
  Builder.BuildMakeFile;
  Check(Trim(ReadText(Makefile))='previous makefile','rejected resource generation preserves existing Makefile');
  Proj.Units[1].Compile:=False; Proj.Units[2].Link:=True;
  Check(not Builder.Compile,'precompiled RES requested for linking is not silently dropped');
  Proj.Units[2].Link:=False;
  Proj.Options.ObjFiles.Add('linked.RES');
  Check(not Builder.Compile,'resource listed as an extra linker input is not silently dropped');
  Proj.Options.ObjFiles.Clear;
  Proj.Options.PrivateResource:='legacy_private.rc'; Proj.Options.Icon:='legacy.ico';
  Proj.Options.ResourceIncludes.Add('legacy-includes');
  Proj.Options.IncludeVersionInfo:=True; Proj.Options.SupportXPThemes:=True;
  Proj.Options.VersionInfo.AutoIncBuildNr:=True; Proj.Options.VersionInfo.Build:=7;
  Hook.LogText:='';
  Check(Builder.Compile,'native project with inactive resources can compile');
  WaitBuilder;
  Check(Builder.Succeeded and FileExists(Proj.Executable),'native source still builds with preserved Windows metadata');
  Check(Pos(Lang[ID_LOG_PRESERVEDRESOURCES],Hook.LogText)>0,'native build explains that Windows metadata is not applied');
  Check(Proj.SaveAll,'resource metadata project saves');
  Ini:=TMemIniFile.Create(Proj.FileName);
  try
   Check((Ini.ReadString('Project','PrivateResource','')='legacy_private.rc') and
    (Ini.ReadString('Project','Icon','')='legacy.ico') and
    (Pos('legacy-includes',Ini.ReadString('Project','ResourceIncludes',''))>0) and
    Ini.ReadBool('Project','IncludeVersionInfo',False) and Ini.ReadBool('Project','SupportXPThemes',False) and
    (Proj.Options.VersionInfo.Build=7) and (Ini.ReadInteger('VersionInfo','Build',-1)=7),'native build and save preserve resource metadata and build number');
  finally Ini.Free end;
  Config.Mode:=cmWindows; Proj.Options.WindowsGame:=Config;
  Check(not Builder.Compile,'Windows project rejects unsupported generated metadata before toolchain setup');
  Proj.Options.PrivateResource:=''; Proj.Options.Icon:='';
  Proj.Options.IncludeVersionInfo:=False; Proj.Options.SupportXPThemes:=False;
  Proj.Units[1].Compile:=True;
  Check(not Builder.Compile,'Windows project also rejects an active RC');
  // Cleaning remains available even when the source project contains resources.
  Config.Mode:=cmNative; Proj.Options.WindowsGame:=Config;
  Builder.Clean;
  WaitBuilder;
  // Custom native Makefiles own the resource pipeline, without generated-build promises.
  Config.Mode:=cmNative; Proj.Options.WindowsGame:=Config;
  Custom:=Dir+'custom-resource.mk';
  AtomicWriteFile(Custom,'all:'+LineEnding+#9+'touch custom-resource-built'+LineEnding);
  Proj.Options.UseCustomMakefile:=True; Proj.Options.CustomMakefile:=Custom;
  Builder.OnCompSuccess:=nil;
  Check(Builder.Compile,'native custom Makefile can provide its own resource pipeline');
  WaitBuilder;
  Check(Builder.Succeeded and FileExists(Dir+'custom-resource-built'),'native custom resource build actually runs without completion callbacks');
  Builder.Target:=ctFile; Builder.SourceFile:=Dir+'dialog.RC';
  for I:=0 to 1 do begin
   if I=0 then Config.Mode:=cmNative else Config.Mode:=cmWindows;
   Builder.StandaloneConfig:=Config;
   Check(not Builder.Compile,'standalone resource compilation is rejected consistently');
  end;
 finally
  Builder.Free; MainForm.Project:=nil; Proj.Free; Hook.Free; SetCurrentDir(OriginalDir);
 end;
end;

procedure TRunner.Run(Data:PtrInt);
begin
 try
  C:=TProbeCompiler.Create; Hooks:=TCallbacks.Create;
  try
   C.OnCompSuccess:=Hooks.Success; C.OnCompEnd:=Hooks.Finish;
   NewAttempt; C.BeginCommand('/bin/sh -c '+QuotedStr('exit 7')); WaitCompile;
   Check((not C.Succeeded) and (C.ErrorCount=1) and (Hooks.Successes=0),'silent nonzero compile cannot trigger run');
   NewAttempt; C.BeginCommand(Dir+'missing-compiler'); WaitCompile;
   Check((not C.Succeeded) and (Hooks.Successes=0),'missing compiler cannot trigger run');
   NewAttempt; C.BeginCommand('/bin/sh -c '+QuotedStr('printf '+QuotedStr('x.cpp:1:1: error: broken')+'; exit 0')); WaitCompile;
   Check((not C.Succeeded) and (C.ErrorCount>0),'final diagnostic without newline prevents success');
   NewAttempt; C.BeginCommand('/bin/sh -c '+QuotedStr('sleep 30')); C.StopAndWait;
   Check((not C.Compiling) and (not C.Succeeded),'stopped compile cannot trigger run');
   NewAttempt; C.BeginCommand('/bin/sh -c '+QuotedStr('exit 0')); WaitCompile;
   Check(C.Succeeded and (Hooks.Successes=1) and (Hooks.Ends=5),'only successful attempt calls success');
  finally C.Free; Hooks.Free end;
  AtomicWriteFile(Dir+'empty.cpp','previous');
  E:=MainForm.EditorList.NewEditor(Dir+'empty.cpp',False,False);
  E.Text.Text:=''; E.Text.Modified:=True;
  SetReply(mrCancel); DialogCount:=0;
  Check(not MainForm.EditorList.CloseEditor(E),'cancel closing emptied existing buffer');
  Check((DialogCount=1) and E.Text.Modified,'empty modified buffer prompts and survives');
  fpChmod(Dir+'empty.cpp',&444); SetReply(mrNo);
  Check(not E.Save,'declining read-only override returns failure');
  Check(E.Text.Modified and (Trim(ReadText(Dir+'empty.cpp'))='previous'),'failed save preserves buffer and disk');
  fpChmod(Dir+'empty.cpp',&644); Check(E.Save,'save empty file');
  Check((not E.Text.Modified) and (ReadText(Dir+'empty.cpp')=''),'successful empty save commits');
  E.Text.Text:='pending Save As'; E.Text.Modified:=True;
  SaveAccepted:=False;
  Check(not E.SaveAs,'cancel Save As reports failure');
  Check((E.FileName=Dir+'empty.cpp') and E.Text.Modified,'cancel Save As preserves identity and changes');
  SaveName:=Dir+'no-folder/new.cpp'; SaveAccepted:=True;
  Check(not E.SaveAs,'failed Save As reports failure');
  Check((E.FileName=Dir+'empty.cpp') and E.Text.Modified,'failed Save As preserves identity and changes');
  SaveName:=Dir+'new.cpp'; Check(E.SaveAs,'successful Save As');
  Check((E.FileName=SaveName) and not E.Text.Modified,'successful Save As commits identity');
  MainForm.EditorList.ForceCloseEditor(E);
  P:=TProject.Create(Dir+'project.dev','Test'); MainForm.Project:=P;
  P.AddUnit(Dir+'empty.cpp',P.Node,False);
  MainForm.Show; Application.ProcessMessages;
  MainForm.OpenFile(Dir+'empty.cpp'); E:=MainForm.EditorList.GetEditor;
  Check(E.InProject and (MainForm.GetCompileTarget=ctProject),'File Open recognises a project member and builds the whole project');
  E.InProject:=False; E:=P.OpenUnit(0);
  Check(E.InProject,'project navigation reclaims an already-open standalone editor');
  OriginalCompile:=P.Units[0].Compile;
  SetLength(P.Options.CompilerOptions,1); P.Options.CompilerOptions[0]:=1;
  OptionsDialog:=TProjectOptionsFrm.Create(MainForm);
  try
   OptionsDialog.SetInterface(P);
   OptionsDialog.fProjectCopy.Units[0].Compile:=not OriginalCompile;
   OptionsDialog.fProjectCopy.Units[0].BuildCmd:='temporary build command';
   OptionsDialog.fProjectCopy.Options.Libs.Add('temporary-directory');
   OptionsDialog.fProjectCopy.Options.CompilerOptions[0]:=9;
   Check((P.Units[0].Compile=OriginalCompile) and (P.Options.CompilerOptions[0]=1),'project options edit a detached copy');
   OptionsDialog.btnCancelClick(nil);
  finally OptionsDialog.Free end;
  Check((P.Units[0].Compile=OriginalCompile) and (P.Units[0].BuildCmd='') and
    (P.Options.Libs.IndexOf('temporary-directory')<0),'Cancel keeps project unit and directory settings');
  Values:=Copy(devCompilerSets[0].INIOptions);
  OptionsDialog:=TProjectOptionsFrm.Create(MainForm);
  try
   OptionsDialog.SetInterface(P);
   OptionsDialog.fProjectCopy.Units[0].Compile:=not OriginalCompile;
   OptionsDialog.lstDirList.Items.Add('accepted-directory');
   OptionsDialog.GetInterface(P);
  finally OptionsDialog.Free end;
  Check((P.Units[0].Compile<>OriginalCompile) and (P.Options.Libs.IndexOf('accepted-directory')>=0),'Accept commits the project options copy');
  Check(devCompilerSets[0].INIOptions.ToString=Values.ToString,'project options restore global compiler options');
  P.Units[0].Compile:=OriginalCompile; P.Options.Libs.Clear;
  MainForm.ProjectView.Selected:=P.Units[0].Node;
  InputValue:='no-folder/renamed.cpp';
  MainForm.actUnitRenameExecute(nil);
  Check((P.Units[0].FileName=Dir+'empty.cpp') and FileExists(Dir+'empty.cpp'),'failed rename preserves source and project reference');
  AtomicWriteFile(Dir+'target.cpp','target'); P.AddUnit(Dir+'target.cpp',P.Node,False);
  MainForm.ProjectView.Selected:=P.Units[0].Node; InputValue:='target.cpp'; SetReply(mrYes);
  MainForm.actUnitRenameExecute(nil);
  Check((P.Units.Count=1) and (P.Units[0].FileName=Dir+'target.cpp') and not FileExists(Dir+'empty.cpp'),'rename replaces target and updates project after success');
  AtomicWriteFile(Dir+'empty.cpp','restored');

  E.Text.Text:='pending'; E.Text.Modified:=True; P.Modified:=True;
  fpChmod(E.FileName,&644); SetReply(mrYes);
  // A directory cannot be atomically replaced by the project file.
  ForceDirectories(Dir+'blocked.dev');
  Check(not P.SaveAll(Dir+'blocked.dev'),'project Save As reports write failure');
  Check((P.FileName=Dir+'project.dev') and P.Modified,'failed project Save As keeps identity and dirty state');
  ForceDirectories(Dir+'project.dev'); SetReply(mrYes);
  MainForm.actCloseProjectExecute(nil);
  Check(MainForm.Project=P,'failed save prevents project close');
  RemoveDir(Dir+'project.dev');
  E.Text.Text:='keep this edit'; E.Text.Modified:=True; SetReply(mrCancel);
  MainForm.actCloseProjectExecute(nil);
  Check((MainForm.Project=P) and E.Text.Modified,'cancel project close retains project');
  DialogReply:=idButtonHelp; MainForm.actCloseProjectExecute(nil);
  Check((MainForm.Project=P) and E.Text.Modified,'unavailable dialog cannot discard project');
  SetReply(mrNo); MainForm.actCloseProjectExecute(nil);
  Check(MainForm.Project=nil,'discard project closes without committing dirty project metadata');
  Check(not FileExists(Dir+'project.dev'),'discard does not autosave project in destructor');
  LegacyResourceTests;
  LegacyResourceMigrationTest;
  AtomicWriteFile(Dir+'attempt.cpp','int main() { return 0; }');
  AtomicWriteFile(Dir+'attempt','#!/bin/sh'+LineEnding+'touch "'+Dir+'stale-ran"'); fpChmod(Dir+'attempt',&755);
  AtomicWriteFile(Dir+'open','#!/bin/sh'+LineEnding+'touch "'+Dir+'run-attempted"; exit 1'); fpChmod(Dir+'open',&755);
  AtomicWriteFile(Dir+'fakecpp','#!/bin/sh'+LineEnding+'exit 7'); fpChmod(Dir+'fakecpp',&755);
  E:=MainForm.EditorList.NewEditor(Dir+'attempt.cpp',False,False);
  Check(Assigned(devCompilerSets.CompilationSet),'native compiler available for IDE regression');
  devCompilerSets.CompilationSet.gppName:=Dir+'fakecpp';
  devCompilerSets.CompilationSet.BinDir.Insert(0,Dir);
  MainForm.actCompRunExecute(nil); WaitMainCompile;
  Check((MainForm.CompilerOutput.Items.Count>0) and not devExecutor.Running and
   not FileExists(Dir+'run-attempted') and not FileExists(Dir+'stale-ran'),'F11 failure does not run old executable');
  AtomicWriteFile(Dir+'fakecpp','#!/bin/sh'+LineEnding+'exit 0'); fpChmod(Dir+'fakecpp',&755);
  MainForm.actCompileExecute(nil); WaitMainCompile;
  Check((MainForm.CompilerOutput.Items.Count=0) and not devExecutor.Running and
   not FileExists(Dir+'run-attempted'),'F9 after failed F11 does not inherit Run');
  MainForm.EditorList.ForceCloseEditor(E);
  C:=TProbeCompiler.Create;
  try
   C.CompilerSet:=devCompilerSets.CompilationSet; C.Target:=ctFile; C.SourceFile:=Dir+'attempt.cpp';
   AtomicWriteFile(Dir+'attempt','notes'); C.Clean;
   Check(FileExists(Dir+'attempt'),'Clean preserves non-program file');
   AtomicWriteFile(Dir+'attempt',#$CF#$FA#$ED#$FE); C.Clean;
   Check(not FileExists(Dir+'attempt'),'Clean recognizes Mach-O');
  finally C.Free end;

  WelcomeLayoutTest;
  DialogRegressionTest;
  ReleaseLinksTest;
  CompatibilityLayoutTest;
  SetupErrorTest;
  WindowsBuildTests;
 except
  on X:Exception do begin WriteLn(StdErr,X.ClassName,': ',X.Message); DumpExceptionBackTrace(StdErr); Halt(1) end;
 end;
 MainForm.Close;
 Application.Terminate;
end;
var Runner:TRunner; LegacySettings:TStringList;
begin
 SourceRoot:=GetCurrentDir;
 Dir:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(2))); ForceDirectories(Dir);
 LegacySettings:=TStringList.Create;
 try
  LegacySettings.Text:='[Options]'+LineEnding+'First=0'+LineEnding+
   'Language=""English.lng""'+LineEnding+'ShowTipsOnStart=0'+LineEnding+'ProjectWidth=9000'+LineEnding+
   '[Directories]'+LineEnding+'Lang=""'+ExpandFileName('Lang')+PathDelim+'""'+LineEnding+
   '[Editor.Font]'+LineEnding+'Name="""Courier New"""'+LineEnding+'Size=15'+LineEnding+
   '[Editor.Gutterfont]'+LineEnding+'Name="""Courier New"""'+LineEnding+'Size=15';
  LegacySettings.SaveToFile(Dir+'config.ini');
 finally LegacySettings.Free end;
 devData.INIFileName:=Dir+'config.ini'; devData.ReadSelf; CreateOptions;
 Check(devData.Language='English.lng','legacy quoted language preference resolves before GUI startup');
 Check(FileExists(devDirs.Lang+'English.lng'),'legacy quoted resource directory resolves before GUI startup');
 devData.First:=False;
 devData.ShowTipsOnStart:=False;
 Application.Initialize;
 Application.ShowMainForm:=False;
 Application.CreateForm(TMainForm,MainForm);
 MainForm.OnShow:=nil;
 Check(Lang[80026]='About Penguin cpp','real GUI loads translated captions from a legacy configuration');
 AllLanguagesTest;
 EditorAppearanceTest;
 Runner:=TRunner.Create;
 Application.QueueAsyncCall(Runner.Run,0);
 Application.Run;
 Runner.Free;
end.
