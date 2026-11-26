program windowsgametest;
{$mode objfpc}{$H+}
uses Classes, SysUtils, IniFiles, BaseUnix, WindowsGameCore;
var Config, CopyConfig: TWindowsGameConfig; Ini: TMemIniFile; Args: TStringList;
  Temp, PEFile, C, Cpp, Managed, Backup: String; F: TFileStream; B: array[0..127] of Byte;
procedure Check(Condition: Boolean; const Name: String);
begin
  if not Condition then begin WriteLn('FAIL: ', Name); Halt(1) end;
  WriteLn('OK: ', Name);
end;
begin
  Temp := GetTempDir(False) + 'penguin-game-test-' + IntToStr(GetProcessID) + '/';
  ForceDirectories(Temp);
  Ini := TMemIniFile.Create(Temp + 'test.ini'); Args := TStringList.Create;
  try
    DiscoverWindowsGameConfig(Temp, Config);
    Check(not RequiresIncludedWindowsEnvironment(Temp), 'native/source copy does not require a bundled environment');
    with TStringList.Create do try
      Text := 'Complete included Windows environment'; SaveToFile(Temp + 'PKG-CONTENT.txt');
      Check(RequiresIncludedWindowsEnvironment(Temp), 'complete package requires setup even if its manifest is missing');
      Check(not HasIncludedWindowsEnvironment(Temp), 'receipt alone cannot claim installed tools');
      Text := 'Native IDE only; Windows tools are not bundled'; SaveToFile(Temp + 'PKG-CONTENT.txt');
      Check(not RequiresIncludedWindowsEnvironment(Temp), 'explicit native-only package remains native');
      DeleteFile(Temp + 'PKG-CONTENT.txt');
    finally Free end;
    Check(Config.ConsoleProfile=wcUTF8,'new console defaults to UTF-8');
    Config.ConsoleProfile:=wcOEM437;
    Config.Mode := cmWindows; Config.Enabled := True; Config.UsesGPTK := False;
    Config.Toolchain := '/tool chain'; Config.Runner := '/runtime path/wine'; Config.Prefix := '/prefix path';
    WriteWindowsGameConfig(Ini, Config); Ini.UpdateFile;
    DiscoverWindowsGameConfig(Temp, CopyConfig); ReadWindowsGameConfig(Ini, CopyConfig);
    Check(CopyConfig.ConsoleProfile=wcOEM437,'console profile persists');
    Check(CopyConfig.Enabled and (CopyConfig.Toolchain = Config.Toolchain) and
      (CopyConfig.Runner = Config.Runner) and (CopyConfig.Prefix = Config.Prefix), 'configuration persists');
    Ini.WriteString('WindowsGame','Mode','0');
    ReadWindowsGameConfig(Ini, CopyConfig);
    Check(CopyConfig.Mode = cmAutomatic, 'automatic mode persists');
    Ini.DeleteKey('WindowsGame','Mode'); Ini.WriteBool('WindowsGame','Enabled',False);
    ReadWindowsGameConfig(Ini, CopyConfig);
    Check(CopyConfig.Mode = cmNative, 'legacy native setting is preserved');
    Ini.WriteBool('WindowsGame','Enabled',True); ReadWindowsGameConfig(Ini, CopyConfig);
    Check(CopyConfig.Mode = cmWindows, 'legacy Windows setting is preserved');
    with TStringList.Create do try
      Text := '// #include <windows.h>' + #10 +
        'const char *s = "#include <conio.h>";' + #10 +
        'const char *raw = R"end(' + #10 + '#include <windows.h>' + #10 + ')end";' + #10 +
        '#include <math.h>' + #10 + '#include <stdlib.h>';
      SaveToFile(Temp + 'native.cpp');
      Check(not FileNeedsWindows(Temp + 'native.cpp'), 'portable code, comments and strings remain native');
      Text := '#include <windows.h>'; SaveToFile(Temp + 'platform.h');
      Text := '#include "platform.h"'; SaveToFile(Temp + 'windows.cpp');
      Check(FileNeedsWindows(Temp + 'windows.cpp'), 'Windows dependency found through a local header');
      Text := '#include "cycle.h"'; SaveToFile(Temp + 'cycle.h');
      Check(not FileNeedsWindows(Temp + 'cycle.h'), 'cyclic includes terminate');
      Text := '#include <conio.h>'; SaveToFile(Temp + 'conio.c');
      Check(FileNeedsWindows(Temp + 'conio.c'), 'conio selects Windows');
      DeleteFile(Temp + 'native.cpp'); DeleteFile(Temp + 'platform.h'); DeleteFile(Temp + 'windows.cpp');
      DeleteFile(Temp + 'cycle.h'); DeleteFile(Temp + 'conio.c');
    finally Free end;
    Check(ResolveWindowsCompilers(Config, C, Cpp) = wgToolchainMissing, 'missing toolchain rejected');
    Check(not HasArm64MachO(ParamStr(0) + '.missing'), 'missing host rejected');
    Check(WindowsPEMachine(ParamStr(0)) = 0, 'host binary cannot be a Windows executable');
    PEFile := Temp + 'program with spaces.exe';
    FillChar(B, SizeOf(B), 0); B[0] := $4D; B[1] := $5A; B[60] := 64;
    B[64] := $50; B[65] := $45; B[68] := $64; B[69] := $86;
    F := TFileStream.Create(PEFile, fmCreate); try F.WriteBuffer(B, SizeOf(B)) finally F.Free end;
    Check(WindowsPEMachine(PEFile) = $8664, 'Windows x64 header detected');
    Config.Runner := ParamStr(0); Config.Prefix := Temp + 'new prefix';
{$IFDEF DARWIN}
    Check(HasArm64MachO(Config.Runner), 'test host is ARM64');
{$ENDIF}
    Check(WindowsGameCommand(Config, PEFile, '"hello world" "$(touch injected)"', '', Args) = wgOK, 'runtime command assembled');
    Check((Args.Count = 8) and (Args[0] = '/usr/bin/env') and
      (Args[1] = 'WINEPREFIX=' + Config.Prefix) and (Args[4] = ParamStr(0)) and
      (Args[5] = PEFile) and (Args[6] = 'hello world') and (Args[7] = '$(touch injected)'),
      'spaces and shell syntax remain literal arguments');
    Config.Prefix := GetUserDir;
    Check(WindowsGameCommand(Config, PEFile, '', '', Args) = wgPrefixInvalid, 'home is not a runtime prefix');
    Config.Prefix := '/';
    Check(WindowsGameCommand(Config, PEFile, '', '', Args) = wgPrefixInvalid, 'root is not a runtime prefix');
    Config.Prefix := 'relative';
    Check(WindowsGameCommand(Config, PEFile, '', '', Args) = wgPrefixInvalid, 'relative prefix rejected');
    Config.Prefix := Temp;
    Check(WindowsGameCommand(Config, PEFile, '', '', Args) = wgPrefixInvalid, 'nonempty foreign folder rejected');
    Managed:=PrepareManagedWindowsPrefix(Temp, Backup);
    Check((Backup='') and DirectoryExists(Managed),'managed prefix can be prepared from scratch');
    Check(not WindowsPrefixIsReady(Managed),'empty prefix is not ready');
    with TStringList.Create do try
      Text:='preserve user data'; SaveToFile(Managed+'/partial');
      Managed:=PrepareManagedWindowsPrefix(Temp, Backup);
      Check((Backup<>'') and FileExists(Backup+'/partial') and not FileExists(Managed+'/partial'),'partial managed prefix is preserved in a backup');
      DeleteFile(Backup+'/partial'); RemoveDir(Backup);
      Text:='valid'; SaveToFile(Managed+'/system.reg'); ForceDirectories(Managed+'/drive_c');
      PrepareManagedWindowsPrefix(Temp, Backup);
      Check((Backup='') and FileExists(Managed+'/system.reg'),'complete prefix is reused');
      Check(WindowsPrefixIsReady(Managed),'ready requires registry and drive directory');
      DeleteFile(Managed+'/system.reg'); RemoveDir(Managed+'/drive_c'); RemoveDir(Managed);
      fpSymlink(PChar(Temp),PChar(Managed));
      try
        try PrepareManagedWindowsPrefix(Temp, Backup); Check(False,'symlink must be rejected')
        except on E:EInOutError do Check(True,'managed prefix never follows a custom symlink') end;
      finally DeleteFile(Managed) end;
      RemoveDir(ExtractFileDir(Managed)); RemoveDir(ExtractFileDir(ExtractFileDir(Managed)));
    finally Free end;
    Config.Runner := Temp + 'missing';
    Check(WindowsGameCommand(Config, PEFile, '', '', Args) = wgRunnerMissing, 'missing runtime rejected');
  finally
    Args.Free; Ini.Free; DeleteFile(PEFile); DeleteFile(Temp + 'test.ini'); RemoveDir(Temp);
  end;
end.
