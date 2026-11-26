program consolecommand;
{$mode objfpc}{$H+}
uses Classes, SysUtils, fpjson, WindowsGameCore;
var Config:TWindowsGameConfig; Args:TStringList; Values:TJSONArray; I:Integer;
begin
 DiscoverWindowsGameConfig('',Config); Config.Runner:=ExpandFileName(ParamStr(1)); Config.Prefix:=ExpandFileName(ParamStr(2));
 Args:=TStringList.Create; Values:=TJSONArray.Create;
 try
  if WindowsGameCommand(Config,ExpandFileName(ParamStr(3)),'','',Args)<>wgOK then Halt(1);
  for I:=4 to ParamCount do Args.Add(ParamStr(I));
  WrapWindowsConsoleCommand(Args);
  for I:=0 to Args.Count-1 do Values.Add(Args[I]);
  WriteLn(Values.AsJSON);
 finally Values.Free; Args.Free end;
end.
