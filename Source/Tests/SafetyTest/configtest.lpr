program configtest;
{$mode objfpc}{$H+}
uses Classes, SysUtils, BaseUnix, CFGData, FileTransactions;
type TSettings=class(TConfigData)
 private FNumber:Integer;
 public procedure SettoDefaults; override;
 published property Number:Integer read FNumber write FNumber;
end;
procedure TSettings.SettoDefaults; begin FNumber:=1 end;
procedure Check(Value:Boolean; const Name:String);
begin if not Value then raise Exception.Create(Name); WriteLn('[OK] ',Name) end;
var S:TSettings; Path,Before:String; L:TStringList; Failed:Boolean;
begin
 Path:=GetTempDir+'penguin-config-'+IntToStr(fpGetPid)+'.ini';
 S:=TSettings.Create; L:=TStringList.Create;
 try
  Failed:=False; try S.SaveSelf except on E:EInOutError do Failed:=True end;
  Check(Failed,'saving without a selected configuration fails explicitly');
  S.INIFileName:=Path; S.Number:=1; S.SaveSelf;
  L.Text := '[Directories]' + LineEnding + 'Lang="%path%\Lang/"' + LineEnding +
    '[Options]' + LineEnding + 'Language="English.lng"';
  L.SaveToFile(Path); S.INIFileName:=Path;
  Check((S.ReadS('Directories','Lang')='%path%\Lang/') and
    (S.ReadS('Options','Language')='English.lng'),'legacy quoted language paths load without quotes');
  L.Text := '[Directories]' + LineEnding + 'Lang="""%path%\Lang/"""' + LineEnding +
    '[Options]' + LineEnding + 'Language="""English.lng"""' + LineEnding +
    'InterfaceFont=""Arial""' + LineEnding + '[Commands]' + LineEnding + 'Text=""keep quotes""';
  L.SaveToFile(Path); S.INIFileName:=Path;
  Check((S.ReadS('Directories','Lang')='%path%\Lang/') and
    (S.ReadS('Options','Language')='English.lng') and
    (S.ReadS('Options','InterfaceFont')='Arial'),'repeatedly saved legacy resource quotes are recovered');
  Check(S.ReadS('Commands','Text')='"keep quotes"','recovery preserves meaningful command quotes');
  S.SaveSelf;
  L.LoadFromFile(Path); Before:=L.Text;
  fpChmod(Path,&400); S.Number:=42; Failed:=False;
  try S.SaveSelf except on E:Exception do Failed:=True end;
  L.LoadFromFile(Path);
  Check(Failed and (L.Text=Before),'read-only settings raise and preserve the previous file');
  Check(S.ReadI('Options','Number')=1,'failed settings commit restores INI state');
  fpChmod(Path,&600);
  S.BeginUpdate; S.Write('Other','Name','unsaved'); S.EndUpdate(False);
  Check(S.ReadS('Other','Name')='','cancelled settings batch rolls back memory');
  S.BeginUpdate; S.SaveSelf; S.Write('Other','Name','saved');
  L.LoadFromFile(Path); Check(L.Text=Before,'nested settings saves wait for the outer commit');
  S.EndUpdate(True); L.LoadFromFile(Path);
  Check((Pos('Number=42',L.Text)>0) and (Pos('Name=saved',L.Text)>0),'one batch commits all sections');
  S.BeginUpdate; S.Ini.WriteString('WindowsGame','Prefix','/private/test-prefix'); S.EndUpdate(True); S.SaveSelf;
  Check(S.ReadS('WindowsGame','Prefix')='/private/test-prefix','saving IDE preferences preserves shared runtime settings');
  L.LoadFromFile(Path); Before:=L.Text; fpChmod(Path,&400); S.BeginUpdate; S.Write('Other','Name','lost'); Failed:=False;
  try S.EndUpdate(True) except on E:Exception do Failed:=True end;
  L.LoadFromFile(Path);
  Check(Failed and (L.Text=Before) and (S.ReadS('Other','Name')='saved'),'failed batch preserves disk and the last INI state');
 finally fpChmod(Path,&600); S.Free; L.Free; DeleteFile(Path) end;
end.
