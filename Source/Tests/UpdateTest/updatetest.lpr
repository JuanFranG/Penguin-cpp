program updatetest;
{$mode objfpc}{$H+}
uses SysUtils, Classes, BaseUnix, UpdateCheckCore;
type TCancel = class
  function Yes: Boolean;
end;
function TCancel.Yes: Boolean;
begin Result := True end;
var Failures, C: Integer; V, URL, Script: String; L: TStringList; Cancel: TCancel;
procedure Check(OK: Boolean; const Name: String);
begin
  if OK then WriteLn('[OK] ', Name)
  else begin Inc(Failures); WriteLn('[FAIL] ', Name) end;
end;
procedure FakeCurl(const Body: String);
begin
  L.Text := '#!/bin/sh' + LineEnding + Body;
  L.SaveToFile(Script); FpChmod(Script, &700);
end;
begin
  Check(CompareReleaseVersions('v0.2.10','0.2.9', C) and (C > 0), 'numeric version ordering');
  Check(CompareReleaseVersions('0.2.2','v0.2.2', C) and (C = 0), 'equal versions');
  Check(CompareReleaseVersions('0.1.9','0.2.0', C) and (C < 0), 'older version');
  Check(not CompareReleaseVersions('0.02.2','0.2.2', C), 'reject leading zeros');
  Check(not CompareReleaseVersions('0.2.2-beta','0.2.2', C), 'reject prerelease');
  Check(not CompareReleaseVersions('99999999999999999.2.2','0.2.2', C), 'reject overflow');
  Check(ParseReleaseURL(ReleaseTagPrefix+'v0.3.0', V, URL) and (V='0.3.0'), 'repository release URL');
  Check(not ParseReleaseURL('https://evil.invalid/releases/tag/v0.3.0', V, URL), 'reject other host');
  Check(not ParseReleaseURL(ReleaseTagPrefix+'v0.3.0/../../x', V, URL), 'reject path traversal');
  Script := GetTempFileName(GetTempDir, 'update-test-');
  L := TStringList.Create; Cancel := TCancel.Create;
  try
    FakeCurl('printf "%s" "'+ReleaseTagPrefix+'v0.3.0"');
    Check((FetchLatestRelease(V, URL, nil, Script)=urSuccess) and (V='0.3.0'), 'successful lookup');
    FakeCurl('exit 22');
    Check(FetchLatestRelease(V, URL, nil, Script)=urNetworkError, 'HTTP/network failure');
    FakeCurl('echo https://evil.invalid/v0.3.0');
    Check(FetchLatestRelease(V, URL, nil, Script)=urInvalidReply, 'invalid redirect');
    FakeCurl('exec sleep 10');
    Check(FetchLatestRelease(V, URL, @Cancel.Yes, Script)=urCancelled, 'cancel running lookup');
    Check(FetchLatestRelease(V, URL, nil, Script+'-missing')=urNoCurl, 'missing curl');
  finally Cancel.Free; L.Free; DeleteFile(Script) end;
  if Failures > 0 then Halt(1);
end.
