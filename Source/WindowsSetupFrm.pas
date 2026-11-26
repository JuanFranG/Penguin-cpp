{ SPDX-License-Identifier: GPL-2.0-or-later }
unit WindowsSetupFrm;
{$mode objfpc}{$H+}
interface
uses WindowsGameCore;
function WindowsEnvironmentIsReady(const Config: TWindowsGameConfig;
  const UserDataDirectory: String): Boolean;
function EnsureWindowsEnvironment(const Config: TWindowsGameConfig;
  const UserDataDirectory: String; Force: Boolean = False): Boolean;
implementation
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Process,
  BaseUnix, Unix, SHA1, MultiLangSupport, devPlatform, FileTransactions;
type
  TSetupWorker = class(TThread)
  public
    Config: TWindowsGameConfig;
    Root, Fingerprint, ErrorText: String;
    Step: Integer;
    Success: Boolean;
    procedure Execute; override;
    procedure StopPrefixServer(const Prefix: String);
    function RunCommand(const Command: TStrings; Timeout: QWord; out Output: String): Boolean;
  end;
  TSetupForm = class(TForm)
  private
    Worker: TSetupWorker;
    Timer: TTimer;
    Status: TLabel;
    ErrorDetails: TMemo;
    Bar: TProgressBar;
    CloseButton, RetryButton: TButton;
    Config: TWindowsGameConfig;
    Root, Fingerprint: String;
    ReadyTicks: Integer;
    procedure Start(Sender: TObject);
    procedure Poll(Sender: TObject);
  public
    constructor CreateSetup(const AConfig: TWindowsGameConfig; const ARoot, AKey: String);
    destructor Destroy; override;
  end;
function EnvironmentKey(const Config: TWindowsGameConfig): String;
var C, Cpp, Manifest, Content: String; L: TStringList;
begin
  ResolveWindowsCompilers(Config,C,Cpp);
  Manifest := Config.DataDirectory + 'Compat/windows/environment.json';
  L := TStringList.Create;
  try
    if FileExists(Manifest) then L.LoadFromFile(Manifest);
    Content := L.Text;
    if FileExists(Config.DataDirectory + 'Compat/windows/self-test.cpp') then
      L.LoadFromFile(Config.DataDirectory + 'Compat/windows/self-test.cpp');
    Content := Content + L.Text;
    if FileExists(Config.DataDirectory + 'Compat/windows/console-startup.c') then
      L.LoadFromFile(Config.DataDirectory + 'Compat/windows/console-startup.c');
    Result := SHA1Print(SHA1String(Content + L.Text + IntToStr(Ord(Config.ConsoleProfile)) + Config.Runner + Config.Toolchain +
      IntToStr(FileAge(Cpp)) + IntToStr(FileAge(Config.Runner)) + Config.Prefix));
  finally L.Free end;
end;
function WindowsEnvironmentIsReady(const Config: TWindowsGameConfig;
  const UserDataDirectory: String): Boolean;
var Ready: TStringList; Root, Prefix: String;
begin
  Result := False;
  Root := IncludeTrailingPathDelimiter(UserDataDirectory) + 'Compatibility/windows';
  Prefix := Config.Prefix;
  if Prefix = '' then Prefix := WindowsDefaultPrefix(UserDataDirectory);
  if not WindowsPrefixIsReady(Prefix) or not FileExists(Root + '/ready') then Exit;
  Ready := TStringList.Create;
  try
    try
      Ready.LoadFromFile(Root + '/ready');
      Result := Trim(Ready.Text) = EnvironmentKey(Config);
    except Result := False end;
  finally Ready.Free end;
end;
function TSetupWorker.RunCommand(const Command: TStrings; Timeout: QWord; out Output: String): Boolean;
var Chunk: String; P: TManagedProcess; I, N, Batches: Integer; Buffer: array[0..8191] of Byte; Started: QWord;
begin
  Result := False; Output := ''; P := TManagedProcess.Create(nil);
  try
    P.Executable := Command[0];
    for I := 1 to Command.Count-1 do P.Parameters.Add(Command[I]);
    P.Options := [poUsePipes,poStderrToOutPut]; P.CurrentDirectory := Root;
    P.Execute; Started := GetTickCount64;
    repeat
      Batches := 0;
      while (P.Output.NumBytesAvailable > 0) and (Batches < 16) do begin
        Inc(Batches);
        N := P.Output.Read(Buffer,SizeOf(Buffer));
        if (N > 0) and (Length(Output) < 2*1024*1024) then
          begin SetString(Chunk,PChar(@Buffer[0]),N); Output := Output + Chunk end;
      end;
      if Terminated or (GetTickCount64-Started > Timeout) then begin
        P.StopTree;
        Exit;
      end;
      if not P.Running and (P.Output.NumBytesAvailable = 0) then Break;
      Sleep(20);
    until False;
    P.WaitOnExit;
    Result := P.ExitStatus = 0;
  finally
    if P.Running then P.StopTree;
    P.Free;
  end;
end;
procedure TSetupWorker.StopPrefixServer(const Prefix: String);
var Command: TStringList; Server, Output: String;
begin
  Server := ExtractFilePath(Config.Runner) + 'wineserver';
  if not FileExists(Server) then raise Exception.Create('Cannot find wineserver to finish the private environment');
{$IFDEF DARWIN}
  if not HasArm64MachO(Server) then raise Exception.Create('Recovery requires a native ARM64 wineserver');
{$ENDIF}
  Command := TStringList.Create;
  try
    Command.Add('/usr/bin/env'); Command.Add('WINEPREFIX=' + Prefix);
    Command.Add('WINEDEBUG=-all'); Command.Add(Server); Command.Add('-k');
    RunCommand(Command,10000,Output); // No running server is also a valid recovery state.
    Command[Command.Count-1] := '-w';
    if not RunCommand(Command,10000,Output) then
      raise Exception.Create('Cannot stop the previous private environment: ' + Output);
  finally Command.Free end;
end;

procedure TSetupWorker.Execute;
var C, Cpp, Prefix, Backup, Output, Log: String; Command, Text: TStringList; Lock: Integer; Started: QWord;
  procedure SaveLog;
  begin
    AtomicWriteFile(Root + '/setup.log', Log);
  end;
begin
  Command := TStringList.Create; Text := TStringList.Create; Lock := -1;
  try
    try
      ForceDirectories(Root); FpChmod(Root,&700);
      Lock := FpOpen(Root + '/setup.lock',O_CREAT or O_RDWR,&600);
      if Lock < 0 then raise Exception.Create('Cannot lock setup folder');
      Started := GetTickCount64;
      while FpFlock(Lock,LOCK_EX or LOCK_NB) <> 0 do begin
        if (fpGetErrno <> ESysEWOULDBLOCK) and (fpGetErrno <> ESysEAGAIN) then RaiseLastOSError;
        if Terminated or (GetTickCount64-Started > 120000) then
          raise Exception.Create('Environment setup is already running');
        Sleep(50);
      end;
      Step := 1;
      if ResolveWindowsCompilers(Config,C,Cpp) <> wgOK then
        raise Exception.Create('Compiler unavailable');
      if WindowsMakeProgram(Config) = '' then raise Exception.Create('Bundled make unavailable');
      Text.LoadFromFile(Config.DataDirectory + 'Compat/windows/self-test.cpp');
      Text.SaveToFile(Root + '/self-test.cpp');
      Command.Add(Cpp); Command.Add('-std=c++17'); Command.Add('-static');
      Command.Add('-I' + Config.DataDirectory + 'Compat/common/include');
      Command.Add(Root + '/self-test.cpp'); Command.Add('-o'); Command.Add(Root + '/self-test.exe');
      Command.Add('-lgdi32'); Command.Add('-luser32');
      if Config.ConsoleProfile <> wcProgram then begin
        Command.Add('-x'); Command.Add('c++');
        Command.Add(Config.DataDirectory + 'Compat/windows/console-startup.c');
        case Config.ConsoleProfile of
          wcOEM437: Command.Add('-DPENGUIN_CONSOLE_CP=437');
          wcANSI1252: Command.Add('-DPENGUIN_CONSOLE_CP=1252');
        else Command.Add('-DPENGUIN_CONSOLE_CP=65001') end;
      end;
      if not RunCommand(Command,60000,Output) then raise Exception.Create('Compile: ' + Output);
      Log := 'Compiler:' + LineEnding + Output + LineEnding; Step := 2;
      Prefix := Config.Prefix;
      if Prefix = '' then Prefix := WindowsDefaultPrefix(ExtractFileDir(ExtractFileDir(Root)));
      // Root is <user data>/Compatibility/windows. Its prefix is private and persists across upgrades.
      if Config.Prefix = '' then begin
        // Stop detached services before moving their prefix; they can still write registry files.
        if WindowsPrefixNeedsRecovery(Prefix) then StopPrefixServer(Prefix);
        Prefix := PrepareManagedWindowsPrefix(ExtractFileDir(ExtractFileDir(Root)), Backup);
        if Backup <> '' then Log := Log + 'Incomplete environment preserved at: ' + Backup + LineEnding;
      end;
      if WindowsGameCommand(Config,Root + '/self-test.exe','',Prefix,Command) <> wgOK then
        raise Exception.Create('Runtime/prefix unavailable');
      if not RunCommand(Command,120000,Output) then raise Exception.Create('Run: ' + Output);
      Log := Log + 'Runtime:' + LineEnding + Output + LineEnding;
      if Pos('PENGUIN_WINDOWS_READY',Output) = 0 then raise Exception.Create('Runtime did not return the expected result: ' + Output);
      // A fresh Wine server can defer registry files until shutdown. Make first-run state durable.
      if not WindowsPrefixIsReady(Prefix) then StopPrefixServer(Prefix);
      if not WindowsPrefixIsReady(Prefix) then raise Exception.Create('Runtime did not complete its private environment');
      SaveLog;
      if Terminated then Exit;
      AtomicWriteFile(Root + '/ready', Fingerprint + LineEnding);
      Success := True; Step := 3;
    except
      on E: Exception do begin
        ErrorText := E.Message; Log := Log + ErrorText;
        try SaveLog except end;
      end;
    end;
  finally
    if Lock >= 0 then FpClose(Lock);
    Text.Free; Command.Free;
  end;
end;
constructor TSetupForm.CreateSetup(const AConfig: TWindowsGameConfig; const ARoot, AKey: String);
begin
  inherited CreateNew(Screen.ActiveCustomForm);
  Config := AConfig; Root := ARoot; Fingerprint := AKey;
  Caption := Lang[80210]; Position := poMainFormCenter; BorderStyle := bsDialog;
  Font.Assign(Screen.SystemFont); ClientWidth := 540; ClientHeight := 200;
  Status := TLabel.Create(Self); Status.Parent := Self; Status.AutoSize := False; Status.WordWrap := True;
  Status.SetBounds(20,20,500,70);
  ErrorDetails := TMemo.Create(Self); ErrorDetails.Parent := Self;
  ErrorDetails.Name := 'SetupErrorDetails'; ErrorDetails.ReadOnly := True;
  ErrorDetails.ScrollBars := ssVertical; ErrorDetails.WordWrap := True;
  ErrorDetails.SetBounds(20,70,500,145); ErrorDetails.Visible := False;
  Bar := TProgressBar.Create(Self); Bar.Parent := Self; Bar.SetBounds(20,105,500,20); Bar.Max := 3;
  CloseButton := TButton.Create(Self); CloseButton.Parent := Self; CloseButton.SetBounds(405,155,115,28);
  CloseButton.Caption := Lang[80110]; CloseButton.ModalResult := mrCancel; CloseButton.Cancel := True;
  RetryButton := TButton.Create(Self); RetryButton.Parent := Self; RetryButton.SetBounds(280,155,115,28);
  RetryButton.Caption := Lang[80006]; RetryButton.Visible := False; RetryButton.OnClick := @Start;
  Timer := TTimer.Create(Self); Timer.Enabled := False; Timer.Interval := 80; Timer.OnTimer := @Poll;
  Start(nil);
end;
procedure TSetupForm.Start(Sender: TObject);
begin
  if Assigned(Worker) then begin Worker.WaitFor; FreeAndNil(Worker) end;
  ReadyTicks := 0; RetryButton.Visible := False;
  ErrorDetails.Visible := False; Status.Height := 70; ClientHeight := 200;
  Bar.Top := 105; CloseButton.Top := 155; RetryButton.Top := 155;
  Status.Caption := Lang[80211]; Bar.Position := 0;
  Worker := TSetupWorker.Create(True); Worker.FreeOnTerminate := False;
  Worker.Config := Config; Worker.Root := Root; Worker.Fingerprint := Fingerprint;
  Worker.Start; Timer.Enabled := True;
end;
procedure TSetupForm.Poll(Sender: TObject);
begin
  if not Assigned(Worker) then Exit;
  Bar.Position := Worker.Step;
  if not Worker.Finished then begin
    if Worker.Step >= 2 then Status.Caption := Lang[80212];
    Exit;
  end;
  Worker.WaitFor;
  if Worker.Success then begin
    Status.Caption := Lang[80213]; Inc(ReadyTicks);
    if ReadyTicks >= 10 then begin Timer.Enabled := False; ModalResult := mrOK end;
  end else begin
    Timer.Enabled := False;
    Status.Caption := Lang[80214]; Status.Height := 40;
    ErrorDetails.Text := Worker.ErrorText;
    if FileExists(Root + '/setup.log') then ErrorDetails.Lines.Add('Log: ' + Root + '/setup.log');
    ErrorDetails.Visible := True; ClientHeight := 320;
    Bar.Top := 230; CloseButton.Top := 270; RetryButton.Top := 270;
    RetryButton.Visible := True;
  end;
end;
destructor TSetupForm.Destroy;
begin
  Timer.Enabled := False;
  if Assigned(Worker) then begin Worker.Terminate; Worker.WaitFor; Worker.Free end;
  inherited Destroy;
end;
function EnsureWindowsEnvironment(const Config: TWindowsGameConfig;
  const UserDataDirectory: String; Force: Boolean): Boolean;
var Root, Key: String; Dialog: TSetupForm;
begin
  if not Force and WindowsEnvironmentIsReady(Config,UserDataDirectory) then Exit(True);
  Root := IncludeTrailingPathDelimiter(UserDataDirectory) + 'Compatibility/windows';
  Key := EnvironmentKey(Config);
  Dialog := TSetupForm.CreateSetup(Config,Root,Key);
  try Result := Dialog.ShowModal = mrOK finally Dialog.Free end;
end;
end.
