{ SPDX-License-Identifier: GPL-2.0-or-later }
unit UpdateCheckCore;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils;
const
  LatestReleaseURL = 'https://github.com/JuanFranG/Penguin-cpp/releases/latest';
  ReleaseTagPrefix = 'https://github.com/JuanFranG/Penguin-cpp/releases/tag/';
type
  TUpdateResult = (urSuccess, urNoCurl, urNetworkError, urInvalidReply, urCancelled);
  TCancelUpdate = function: Boolean of object;
function CompareReleaseVersions(const A, B: String; out Comparison: Integer): Boolean;
function ParseReleaseURL(const URL: String; out Version, PageURL: String): Boolean;
function FetchLatestRelease(out Version, PageURL: String; Cancel: TCancelUpdate = nil;
  const CurlExecutable: String = ''): TUpdateResult;
implementation
uses Process, devPlatform;
type TVersionParts = array[0..2] of QWord;
function ParseVersion(S: String; out Parts: TVersionParts): Boolean;
var I, P: Integer; Part: String;
begin
  Result := False;
  if (S <> '') and (S[1] = 'v') then Delete(S, 1, 1);
  for I := 0 to 2 do begin
    P := Pos('.', S);
    if I < 2 then begin
      if P = 0 then Exit;
      Part := Copy(S, 1, P - 1); Delete(S, 1, P);
    end else begin
      if P <> 0 then Exit;
      Part := S;
    end;
    if (Part = '') or ((Length(Part) > 1) and (Part[1] = '0')) then Exit;
    for P := 1 to Length(Part) do if not (Part[P] in ['0'..'9']) then Exit;
    if not TryStrToQWord(Part, Parts[I]) or (Parts[I] > High(LongWord)) then Exit;
  end;
  Result := True;
end;
function CompareReleaseVersions(const A, B: String; out Comparison: Integer): Boolean;
var VA, VB: TVersionParts; I: Integer;
begin
  Comparison := 0;
  Result := ParseVersion(A, VA) and ParseVersion(B, VB);
  if not Result then Exit;
  for I := 0 to 2 do begin
    if VA[I] < VB[I] then begin Comparison := -1; Exit end;
    if VA[I] > VB[I] then begin Comparison := 1; Exit end;
  end;
end;
function ParseReleaseURL(const URL: String; out Version, PageURL: String): Boolean;
var Tag: String; Parts: TVersionParts;
begin
  Version := ''; PageURL := '';
  Result := False;
  if Copy(URL, 1, Length(ReleaseTagPrefix)) <> ReleaseTagPrefix then Exit;
  Tag := Copy(URL, Length(ReleaseTagPrefix) + 1, MaxInt);
  if not ParseVersion(Tag, Parts) then Exit;
  Version := IntToStr(Parts[0]) + '.' + IntToStr(Parts[1]) + '.' + IntToStr(Parts[2]);
  PageURL := ReleaseTagPrefix + Tag;
  Result := True;
end;
function FetchLatestRelease(out Version, PageURL: String; Cancel: TCancelUpdate;
  const CurlExecutable: String): TUpdateResult;
var P: TProcess; Output, Chunk: String; Count: LongInt;
  procedure Drain;
  begin
    while P.Output.NumBytesAvailable > 0 do begin
      Count := P.Output.NumBytesAvailable;
      if Count > 4096 then Count := 4096;
      SetLength(Chunk, Count);
      Count := P.Output.Read(Chunk[1], Count);
      if Length(Output) < 8192 then Output := Output + Copy(Chunk, 1, Count);
    end;
  end;
begin
  Version := ''; PageURL := ''; Output := '';
  Result := urNetworkError;
  P := TProcess.Create(nil);
  try
    if CurlExecutable <> '' then P.Executable := CurlExecutable
    else P.Executable := FindExecutable('curl');
    // Use the system TLS stack through curl on both platforms; never a shell,
    // and never disable certificate validation or allow HTTP redirects.
    P.Parameters.Add('--fail'); P.Parameters.Add('--silent');
    P.Parameters.Add('--show-error'); P.Parameters.Add('--head');
    P.Parameters.Add('--location'); P.Parameters.Add('--max-redirs'); P.Parameters.Add('5');
    P.Parameters.Add('--connect-timeout'); P.Parameters.Add('5');
    P.Parameters.Add('--max-time'); P.Parameters.Add('12');
    P.Parameters.Add('--proto'); P.Parameters.Add('=https');
    P.Parameters.Add('--proto-redir'); P.Parameters.Add('=https');
    P.Parameters.Add('--output'); P.Parameters.Add('/dev/null');
    P.Parameters.Add('--write-out'); P.Parameters.Add('%{url_effective}');
    P.Parameters.Add(LatestReleaseURL);
    P.Options := [poUsePipes, poStderrToOutPut];
    try P.Execute except Exit(urNoCurl) end;
    P.CloseInput;
    while True do begin
      if Assigned(Cancel) and Cancel() then begin
        P.Terminate(1); P.WaitOnExit;
        Exit(urCancelled);
      end;
      Drain;
      if not P.Running then Break;
      Sleep(10);
    end;
    Drain; P.WaitOnExit;
    if P.ExitCode <> 0 then Exit;
    if ParseReleaseURL(Trim(Output), Version, PageURL) then Result := urSuccess
    else Result := urInvalidReply;
  finally
    P.Free;
  end;
end;
end.
