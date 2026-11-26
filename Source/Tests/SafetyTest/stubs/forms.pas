unit Forms; {$mode objfpc} interface
type TFakeApplication=class Terminated:Boolean; end;
var Application:TFakeApplication;
implementation
initialization Application:=TFakeApplication.Create;
finalization Application.Free;
end.
