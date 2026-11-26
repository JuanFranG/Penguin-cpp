program consolecommand;
{$mode objfpc}{$H+}
uses Classes, SysUtils, fpjson, WindowsGameCore;
var Config:TWindowsGameConfig; Args:TStringList; Values:TJSONArray; I:Integer; Error:TWindowsGameError;
begin
 DiscoverWindowsGameConfig('',Config); Config.Runner:=ExpandFileName(ParamStr(1)); Config.Prefix:=ExpandFileName(ParamStr(2));
 Args:=TStringList.Create; Values:=TJSONArray.Create;
 try
  Error:=WindowsGameCommand(Config,ExpandFileName(ParamStr(3)),'','',Args);
  if Error<>wgOK then begin
   WriteLn(StdErr,WindowsGameErrorText(Error)); ExitCode:=1;
  end else begin
  for I:=4 to ParamCount do Args.Add(ParamStr(I));
  WrapWindowsConsoleCommand(Args);
  for I:=0 to Args.Count-1 do Values.Add(Args[I]);
  WriteLn(Values.AsJSON);
  end;
 finally Values.Free; Args.Free end;
end.
