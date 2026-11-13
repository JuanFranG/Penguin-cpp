{ SPDX-License-Identifier: GPL-2.0-or-later }
unit UpdateInstall;
{$mode objfpc}{$H+}
interface
// Starts a visible terminal after the IDE has accepted all save/close prompts.
// The helper waits for this process to exit before replacing its files.
function LaunchUpdateInstaller: Boolean;
implementation
uses Classes, SysUtils, BaseUnix, devPlatform;
function Quote(const S: String): String;
begin Result := '''' + StringReplace(S, '''', '''\''''', [rfReplaceAll]) + '''' end;
function TryLaunchUpdateInstaller: Boolean;
var
  Work, Script, Exe: String;
{$IFDEF DARWIN}
  Bundle, Installer: String;
  Input, Output: TFileStream;
{$ENDIF}
  Lines, Command, Args: TStringList;
  Params: array of String;
  I: Integer;
  ID: TGUID;
begin
  Result := False;
  Work := GetPrivateTempDir;
  if Work = '' then Exit;
  if CreateGUID(ID) <> 0 then Exit;
  Work := IncludeTrailingPathDelimiter(Work) + 'update-' + GUIDToString(ID);
  // mkdir is atomic and starts private; GetTempFileName only reserves a
  // name on Unix and must not be followed by DeleteFile.
  if FpMkdir(Work, &700) <> 0 then Exit;
  Work := IncludeTrailingPathDelimiter(Work);
  Script := Work + 'update.sh';
  Lines := TStringList.Create; Command := TStringList.Create; Args := TStringList.Create;
  try
    Lines.Add('#!/bin/bash'); Lines.Add('set -euo pipefail');
    Lines.Add('trap ' + Quote('rm -rf ' + Quote(ExcludeTrailingPathDelimiter(Work))) + ' EXIT');
    Lines.Add('echo "Penguin cpp: waiting for the IDE to close..."');
    Lines.Add('for i in {1..120}; do');
    Lines.Add('  kill -0 ' + IntToStr(GetProcessID) + ' 2>/dev/null || break');
    Lines.Add('  sleep 1'); Lines.Add('done');
    Lines.Add('if kill -0 ' + IntToStr(GetProcessID) + ' 2>/dev/null; then echo "Close Penguin cpp and try again."; exit 1; fi');
{$IFDEF DARWIN}
    Bundle := ExpandFileName(ParamStr(0));
    for I := 1 to 3 do Bundle := ExtractFileDir(Bundle);
    if ExtractFileExt(Bundle) <> '.app' then Exit;
    Installer := GetDataDir(ExtractFilePath(ParamStr(0))) + 'packaging/install-macos.sh';
    if not FileExists(Installer) then Exit;
    // Copy the installer: its original lives inside the app it will replace.
    Input := TFileStream.Create(Installer, fmOpenRead or fmShareDenyWrite);
    try
      Output := TFileStream.Create(Work + 'install-macos.sh', fmCreate);
      try Output.CopyFrom(Input, 0) finally Output.Free end;
    finally Input.Free end;
    Lines.Add('export INSTALL_DIR=' + Quote(ExtractFileDir(Bundle)));
    Lines.Add('export INSTALL_APP_NAME=' + Quote(ExtractFileName(Bundle)));
    Lines.Add('/bin/bash ' + Quote(Work + 'install-macos.sh'));
    Lines.Add('/usr/bin/open ' + Quote(Bundle));
{$ELSE}
    if not FileExists('/usr/bin/apt-get') then Exit;
    Lines.Add('sudo /usr/bin/apt-get update');
    Lines.Add('sudo /usr/bin/apt-get install --only-upgrade -y penguin-cpp');
    Lines.Add('nohup ' + Quote(ExpandFileName(ParamStr(0))) + ' >/dev/null 2>&1 &');
{$ENDIF}
    Lines.SaveToFile(Script); FpChmod(Script, &700);
    Command.Add('/bin/bash'); Command.Add(Script);
    if not BuildTerminalCommand(Command, True, 'Finished in %s seconds (exit code %d)', 'Press Enter to close', Exe, Args) then Exit;
    SetLength(Params, Args.Count);
    for I := 0 to Args.Count - 1 do Params[I] := Args[I];
    Result := ExecuteFile(Exe, Params, '');
  finally
    Lines.Free; Command.Free; Args.Free;
    if not Result then begin
      DeleteFile(Script); DeleteFile(Work + 'install-macos.sh'); RemoveDir(Work);
    end;
  end;
end;
function LaunchUpdateInstaller: Boolean;
begin
  try Result := TryLaunchUpdateInstaller except Result := False end;
end;
end.
