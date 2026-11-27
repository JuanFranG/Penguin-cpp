program manualcapture;
{$mode delphi}
{$modeswitch objectivec1}
uses cthreads, SafetyInterfaces, Forms, Classes, SysUtils, Graphics, Controls,
 StdCtrls, ComCtrls, Process, main, devCFG, FileTransactions, MultiLangSupport, Editor,
 Project, AboutFrm, NewProjectFrm, ProjectOptionsFrm, EditorOptFrm, EnviroFrm,
 CompOptionsFrm, FindFrm, GotoLineFrm, FilePropertiesFrm, ParamsFrm, CPUFrm,
 ToolFrm, ToolEditFrm, WindowListFrm, AddToDoFrm, ViewToDoFrm, NewTemplateFrm,
 NewClassFrm, NewFunctionFrm, NewVarFrm, FunctionSearchFrm, RemoveUnitFrm,
 PrintFrm, IconFrm, IncrementalFrm, TipOfTheDayFrm, AStyleFormatterOptionsFrm,
 ClangFormatterOptionsFrm, ProcessListFrm, LangFrm, WindowsGameCore,
 WindowsGameFrm, WindowsSetupFrm, UpdateCheckFrm, ExtCtrls, ProfileAnalysisFrm, MacSupport, CocoaAll, CocoaUtils, PenguinPalette, PenguinTheme;
{$R ../../penguin-cpp.res}
type
 TCapture=class
  Timer:TTimer;
  ModalName:String;
  SetupWorking,SetupReady:Boolean;
  procedure Tick(Sender:TObject);
  procedure Run(Data:PtrInt);
 end;
var Root,Work,OutDir:String; Catalog:TStringList; Runner:TCapture;
procedure Save(F:TCustomForm; const Name:String);
var P:TPortableNetworkGraphic; Output:String; W:NSWindow;
begin
 NSApp.activateIgnoringOtherApps(True); F.BringToFront; Application.ProcessMessages; Application.ProcessMessages;
 W:=GetNSObjectWindow(NSObject(F.Handle)); W.makeKeyAndOrderFront(nil); Application.ProcessMessages; W.displayIfNeeded;
 if not RunCommand('/usr/sbin/screencapture',['-x','-o','-l',IntToStr(W.windowNumber),OutDir+Name+'.png'],Output) then
  raise Exception.Create('Native window capture failed: '+Output);
 P:=TPortableNetworkGraphic.Create;
 try
  P.LoadFromFile(OutDir+Name+'.png');
  Catalog.Add(Name+#9+F.ClassName+#9+StringReplace(F.Caption,#9,' ',[rfReplaceAll])+#9+IntToStr(P.Width)+#9+IntToStr(P.Height));
  Catalog.SaveToFile(OutDir+'captures.tsv');
  WriteLn('CAPTURE ',Name,' ',P.Width,'x',P.Height);
 finally P.Free end;
end;
procedure CaptureForm(C:TFormClass; const Name:String);
var F:TForm;
begin
 F:=nil;
 try
  F:=C.Create(MainForm);
  if F is TProjectOptionsFrm then TProjectOptionsFrm(F).SetInterface(MainForm.Project);
  if F is TFilePropertiesForm then TFilePropertiesForm(F).SetFile(Work+'main.cpp');
  if F is TNewTemplateForm then TNewTemplateForm(F).TempProject:=MainForm.Project;
  if F is TRemoveUnitForm then TRemoveUnitForm(F).UnitList.Items.Add(Work+'main.cpp');
  if F is TWindowListForm then begin
   with TWindowListForm(F).UnitList.Items.Add do begin Caption:='main.cpp'; SubItems.Add(Work+'main.cpp') end;
  end;
  if F is TToolForm then TToolForm(F).Controller:=TToolController.Create;
  F.Position:=poScreenCenter;
  F.Show; Application.ProcessMessages; Save(F,Name);
  if F is TEditorOptForm then begin
   TEditorOptForm(F).PagesMain.ActivePageIndex:=1;
   Save(F,'editor-fonts');
  end;
  F.Hide;
 except on E:Exception do WriteLn('SKIP ',Name,': ',E.Message) end;
 if Assigned(F) then F.Free;
end;
procedure TCapture.Tick(Sender:TObject);
var F:TCustomForm; C:TComponent;
begin
 F:=Screen.ActiveCustomForm;
 if not Assigned(F) then Exit;
 if F.ClassName='TSetupForm' then begin
  if not SetupWorking then begin SetupWorking:=True; Save(F,'setup-working') end;
  for C in F do
   if (C is TLabel) and (TLabel(C).Caption=Lang[80213]) and not SetupReady then begin
    SetupReady:=True; Save(F,'setup-ready');
   end;
 end else if (F.ClassName='TGameForm') then begin
  Save(F,ModalName); F.ModalResult:=mrCancel; Timer.Enabled:=False;
 end else if F.ClassName='TUpdateForm' then begin
  C:=F.FindComponent('RetryButton');
  if (C is TButton) and TButton(C).Enabled then begin
   Save(F,ModalName); F.ModalResult:=mrCancel; Timer.Enabled:=False;
  end;
 end;
end;
procedure TCapture.Run(Data:PtrInt);
var Config:TWindowsGameConfig; Output:String;
begin
 try
 MainForm.SetBounds(0,0,1200,760); MainForm.Show; Save(MainForm,'welcome');
 MainForm.OpenProject(Work+'Tutorial.dev'); MainForm.OpenFile(Work+'main.cpp');
 Application.ProcessMessages; Save(MainForm,'workspace');
 CaptureForm(TNewProjectForm,'new-project');
 CaptureForm(TProjectOptionsFrm,'project-options');
 CaptureForm(TEditorOptForm,'editor-options');
 CaptureForm(TEnviroForm,'environment');
 CaptureForm(TCompOptForm,'compiler');
 CaptureForm(TFindForm,'find');
 CaptureForm(TGotoLineForm,'go-to-line');
 CaptureForm(TFilePropertiesForm,'file-properties');
 CaptureForm(TParamsForm,'arguments');
 CaptureForm(TCPUForm,'cpu');
 RunCommand('/usr/bin/xcrun',['clang++','-fprofile-instr-generate',Work+'main.cpp','-o',Work+'Tutorial'],Output);
 RunCommand('/usr/bin/env',['LLVM_PROFILE_FILE='+Work+'default.profraw',Work+'Tutorial'],Output);
 CaptureForm(TProfileAnalysisForm,'profiler');
 CaptureForm(TToolForm,'tools');
 CaptureForm(TToolEditForm,'edit-tool');
 CaptureForm(TWindowListForm,'windows');
 CaptureForm(TAddToDoForm,'add-todo');
 CaptureForm(TViewToDoForm,'todo');
 CaptureForm(TNewTemplateForm,'template');
 CaptureForm(TNewClassForm,'new-class');
 CaptureForm(TNewFunctionForm,'new-function');
 CaptureForm(TNewVarForm,'new-variable');
 CaptureForm(TFunctionSearchForm,'functions');
 CaptureForm(TRemoveUnitForm,'remove-file');
 CaptureForm(TPrintForm,'print');
 WriteLn('UNAVAILABLE icons: legacy Items.ItemData cannot be loaded by Lazarus');
 CaptureForm(TIncrementalForm,'incremental-find');
 CaptureForm(TTipOfTheDayForm,'tips');
 CaptureForm(TAStyleFormatterOptionsForm,'astyle');
 CaptureForm(TClangFormatterOptionsForm,'clang-format');
 CaptureForm(TProcessListForm,'attach-process');
 CaptureForm(TLangForm,'first-run');
 CaptureForm(TAboutForm,'about');
 Timer:=TTimer.Create(nil); Timer.Interval:=100; Timer.OnTimer:=Tick;
 try
  DiscoverWindowsGameConfig('/Applications/Penguin cpp.app/Contents/Resources/',Config); ModalName:='windows-compatibility';
  Timer.Enabled:=True; ConfigureWindowsGame(Config);
  SetupWorking:=False; SetupReady:=False; Timer.Enabled:=True;
  if not EnsureWindowsEnvironment(Config,Work+'environment',True) then raise Exception.Create('Could not prepare the isolated sample environment');
  Timer.Enabled:=False;
  ModalName:='updates'; Timer.Enabled:=True; ShowUpdateCheck;
 finally Timer.Free end;
 MainForm.Close;
 except on E:Exception do WriteLn('FATAL ',E.ClassName,': ',E.Message) end;
 Application.Terminate;
end;
var S:TStringList;
begin
 if (GetEnvironmentVariable('PENGUIN_MANUAL_WORK')='') or (GetEnvironmentVariable('PENGUIN_MANUAL_OUTPUT')='') then begin
  WriteLn('Set PENGUIN_MANUAL_WORK to a disposable directory and PENGUIN_MANUAL_OUTPUT to the screenshot directory.'); Halt(1);
 end;
 Root:=GetCurrentDir; Work:=IncludeTrailingPathDelimiter(ExpandFileName(GetEnvironmentVariable('PENGUIN_MANUAL_WORK')));
 OutDir:=IncludeTrailingPathDelimiter(ExpandFileName(GetEnvironmentVariable('PENGUIN_MANUAL_OUTPUT')));
 ForceDirectories(Work); ForceDirectories(OutDir); Catalog:=TStringList.Create;
 S:=TStringList.Create;
 try
  S.Text:='[Options]'+LineEnding+'First=0'+LineEnding+'Language=English.lng'+LineEnding+'ShowTipsOnStart=0'+LineEnding+
   '[Directories]'+LineEnding+'Lang='+Root+'/Lang/'+LineEnding+'Templates='+Root+'/Templates/'+LineEnding+
   '[Editor.Font]'+LineEnding+'Name=Menlo'+LineEnding+'Size=11'+LineEnding+
   '[FormatterAStyle]'+LineEnding+'AStyleDir=/Applications/Penguin cpp.app/Contents/MacOS/'+LineEnding+'AStyleFile=astyle'+LineEnding+
   '[FormatterClang]'+LineEnding+'ClangDir=/opt/homebrew/bin/'+LineEnding+'ClangFile=clang-format';
  S.SaveToFile(Work+'config.ini');
  S.Text:='#include <iostream>'+LineEnding+LineEnding+'int add(int a, int b) {'+LineEnding+'    return a + b;'+LineEnding+'}'+LineEnding+LineEnding+
   'int main() {'+LineEnding+'    // TODO: try other values'+LineEnding+'    int result = add(2, 3);'+LineEnding+'    std::cout << "Result: " << result << std::endl;'+LineEnding+'    return 0;'+LineEnding+'}';
  S.SaveToFile(Work+'main.cpp');
  S.Text:='[Project]'+LineEnding+'Name=Tutorial'+LineEnding+'FileName=Tutorial.dev'+LineEnding+'Type=1'+LineEnding+'Ver=2'+LineEnding+'IsCpp=1'+LineEnding+'UnitCount=1'+LineEnding+'CompilerSet=0'+LineEnding+
   '[Unit1]'+LineEnding+'FileName=main.cpp'+LineEnding+'CompileCpp=1'+LineEnding+'Compile=1'+LineEnding+'Link=1'+LineEnding+'Priority=1000';
  S.SaveToFile(Work+'Tutorial.dev');
 finally S.Free end;
 devData.INIFileName:=Work+'config.ini'; devData.ReadSelf; CreateOptions;
 RequireDerivedFormResource:=True; Application.Scaled:=True; Application.Initialize; InstallMacViewCompatibility; ApplyApplicationPalette(False); Application.Title:='Penguin cpp'; Application.ShowMainForm:=False;
 Application.CreateForm(TMainForm,MainForm); MainForm.OnShow:=nil;
 Runner:=TCapture.Create; Application.QueueAsyncCall(Runner.Run,0); Application.Run;
 Runner.Free; Catalog.Free;
end.
