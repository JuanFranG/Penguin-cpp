program manualcapture;
{$mode delphi}
{$modeswitch objectivec1}
uses cthreads, Interfaces, Forms, Classes, SysUtils, Graphics, Controls,
 StdCtrls, ComCtrls, Process, main, devCFG, FileTransactions, MultiLangSupport, Editor,
 Project, AboutFrm, NewProjectFrm, ProjectOptionsFrm, EditorOptFrm, EnviroFrm,
 CompOptionsFrm, FindFrm, GotoLineFrm, FilePropertiesFrm, ParamsFrm, CPUFrm,
 ToolFrm, ToolEditFrm, WindowListFrm, AddToDoFrm, ViewToDoFrm, NewTemplateFrm,
 NewClassFrm, NewFunctionFrm, NewVarFrm, FunctionSearchFrm, RemoveUnitFrm,
 PrintFrm, IconFrm, IncrementalFrm, TipOfTheDayFrm, AStyleFormatterOptionsFrm,
 ClangFormatterOptionsFrm, ProcessListFrm, LangFrm, WindowsGameCore,
 WindowsGameFrm, WindowsSetupFrm, UpdateCheckFrm, ExtCtrls, ProfileAnalysisFrm, MacSupport, CocoaAll, CocoaUtils, PenguinPalette, PenguinTheme, devPlatform;
{$R ../../penguin-cpp.res}
type
 TCapture=class
  Timer:TTimer;
  ModalName:String;
  SetupWorking,SetupReady:Boolean;
  procedure Tick(Sender:TObject);
  procedure Run(Data:PtrInt);
 end;
var Root,Work,OutDir:String; Catalog:TStringList; Runner:TCapture; CaptureFailed:Boolean=False;
procedure Save(F:TCustomForm; const Name:String);
var P:TPortableNetworkGraphic; Output:String; W:NSWindow; I:Integer;
begin
 if (GetEnvironmentVariable('PENGUIN_MANUAL_VIEWS')<>'') and
  (Pos(','+Name+',',','+GetEnvironmentVariable('PENGUIN_MANUAL_VIEWS')+',')=0) then Exit;
 NSApp.activateIgnoringOtherApps(True); F.BringToFront; Application.ProcessMessages; Application.ProcessMessages;
 for I:=0 to F.ComponentCount-1 do begin
  if F.Components[I] is TCustomEdit then TCustomEdit(F.Components[I]).SelLength:=0;
  if F.Components[I] is TComboBox then TComboBox(F.Components[I]).SelLength:=0;
 end;
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
var F:TForm; Deadline:QWord; I:Integer;
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
  if F is TIncrementalForm then begin
   TIncrementalForm(F).Editor:=MainForm.EditorList.GetEditor.Text;
   TIncrementalForm(F).Edit.Text:='add';
  end;
  if F is TNewProjectForm then with TNewProjectForm(F) do begin
   edProjectName.Text:='Tutorial';
   for I:=0 to ProjView.Items.Count-1 do
    if Pos('Console Application',ProjView.Items[I].Caption)>0 then ProjView.ItemIndex:=I;
  end;
  F.Position:=poScreenCenter;
  F.Show; Application.ProcessMessages;
  if (F is TCPUForm) and MainForm.Debugger.Paused then begin
   Deadline:=GetTickCount64+3000;
   while (TCPUForm(F).RegisterListbox.Items.Count=0) and (GetTickCount64<Deadline) do begin Application.ProcessMessages; Sleep(10) end;
  end;
  Save(F,Name);
  if F is TEditorOptForm then begin
   TEditorOptForm(F).PagesMain.ActivePageIndex:=1;
   Save(F,'editor-fonts');
  end;
  if F is TProjectOptionsFrm then with TProjectOptionsFrm(F) do begin
   PageControl.ActivePage:=tabFiles; Application.ProcessMessages; Save(F,'project-files');
   PageControl.ActivePage:=tabCompiler; Application.ProcessMessages; Save(F,'project-compiler');
   PageControl.ActivePage:=tabCompOpts; Application.ProcessMessages; Save(F,'project-flags');
   PageControl.ActivePage:=tabFilesDir; Application.ProcessMessages; Save(F,'project-directories');
   PageControl.ActivePage:=tabOutputDir; Application.ProcessMessages; Save(F,'project-output');
  end;
  if F is TCompOptForm then with TCompOptForm(F) do begin
   MainPages.ActivePage:=tabCompiler; Application.ProcessMessages; Save(F,'compiler-flags');
   MainPages.ActivePage:=tabCodeGen; Application.ProcessMessages; Save(F,'compiler-settings');
  end;
  F.Hide;
 except on E:Exception do begin CaptureFailed:=True; WriteLn('SKIP ',Name,': ',E.Message) end end;
 if Assigned(F) then begin
  if F is TCPUForm then MainForm.Debugger.CancelHandlers(F);
  F.Free;
 end;
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
var Config:TWindowsGameConfig; Output:String; Deadline:QWord;
begin
 try
 MainForm.SetBounds(0,0,1200,760); MainForm.Show; Save(MainForm,'welcome');
 MainForm.OpenProject(Work+'Tutorial.dev'); MainForm.OpenFile(Work+'main.cpp');
 Application.ProcessMessages; Save(MainForm,'workspace');
 MainForm.Project.OpenUnit(2).Activate; Application.ProcessMessages; Save(MainForm,'header');
 MainForm.Project.OpenUnit(0).Activate;
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
 RunCommand('/usr/bin/xcrun',['clang++','-fprofile-instr-generate',Work+'main.cpp',Work+'calculator.cpp','-o',Work+'Tutorial'],Output);
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
  if GetEnvironmentVariable('PENGUIN_MANUAL_SKIP_SETUP')<>'1' then begin
  SetupWorking:=False; SetupReady:=False; Timer.Enabled:=True;
  if not EnsureWindowsEnvironment(Config,Work+'environment',True) then raise Exception.Create('Could not prepare the isolated sample environment');
  Timer.Enabled:=False;
  end;
  ModalName:='updates'; Timer.Enabled:=True; ShowUpdateCheck;
 finally Timer.Free end;
 if not RunCommand('/usr/bin/xcrun',['clang++','-g','-O0',Work+'main.cpp',Work+'calculator.cpp','-o',MainForm.Project.Executable],Output) then
  raise Exception.Create('Debug example compilation failed: '+Output);
 devCompilerSets.CompilationSet.gdbName:=FindDeveloperTool('lldb-dap');
 MainForm.Project.Options.CompilerOptions:=Copy(devCompilerSets.CompilationSet.INIOptions);
 MainForm.Project.SetCompilerOption('-g3',1); MainForm.Project.SetCompilerOption('-s',0);
 MainForm.Project.OpenUnit(1).Activate;
 MainForm.EditorList.GetEditor.ToggleBreakpoint(5);
 if not MainForm.Project.SaveAll then raise Exception.Create('Could not save the disposable debug project');
 MainForm.actDebugExecute(nil);
 Deadline:=GetTickCount64+15000;
 while not MainForm.Debugger.Paused and (GetTickCount64<Deadline) do begin Application.ProcessMessages; Sleep(10) end;
 if not MainForm.Debugger.Paused then raise Exception.Create('Native debugger did not pause at main');
 MainForm.Debugger.Continue;
 Deadline:=GetTickCount64+10000;
 repeat Application.ProcessMessages; Sleep(10) until (MainForm.Debugger.Paused and (MainForm.Debugger.BreakPointFile=Work+'calculator.cpp')) or (GetTickCount64>Deadline);
 if not MainForm.Debugger.Paused or (Pos('calculator.cpp',MainForm.Debugger.BreakPointFile)=0) then raise Exception.Create('Native debugger did not pause in calculator.cpp');
 MainForm.Debugger.AddWatchVar('left'); MainForm.Debugger.AddWatchVar('right'); MainForm.Debugger.AddWatchVar('total');
 Deadline:=GetTickCount64+1000;
 while GetTickCount64<Deadline do begin Application.ProcessMessages; Sleep(10) end;
 Save(MainForm,'debugger'); CaptureForm(TCPUForm,'cpu-active');
 MainForm.Debugger.Stop;
 MainForm.Close;
 except on E:Exception do begin CaptureFailed:=True; MainForm.Debugger.Stop; WriteLn('FATAL ',E.ClassName,': ',E.Message) end end;
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
  S.LoadFromFile(Root+'/Manual/examples/header-project/main.cpp'); S.SaveToFile(Work+'main.cpp');
  S.LoadFromFile(Root+'/Manual/examples/header-project/calculator.cpp'); S.SaveToFile(Work+'calculator.cpp');
  S.LoadFromFile(Root+'/Manual/examples/header-project/calculator.h'); S.SaveToFile(Work+'calculator.h');
  S.LoadFromFile(Root+'/Manual/examples/header-project/Tutorial.dev'); S.SaveToFile(Work+'Tutorial.dev');
 finally S.Free end;
 devData.INIFileName:=Work+'config.ini'; devData.ReadSelf; CreateOptions;
 RequireDerivedFormResource:=True; Application.Scaled:=True; Application.Initialize; NSApp.setActivationPolicy(NSApplicationActivationPolicyRegular); InstallMacViewCompatibility; ApplyApplicationPalette(False); Application.Title:='Penguin cpp'; Application.ShowMainForm:=False;
 Application.CreateForm(TMainForm,MainForm);
 Runner:=TCapture.Create; Application.QueueAsyncCall(Runner.Run,0); Application.Run;
 Runner.Free; Catalog.Free; if CaptureFailed then Halt(1);
end.
