program processresulttest;
{$mode objfpc}{$H+}
uses cthreads, Classes, SysUtils, BaseUnix, devPlatform;
type TCallbacks=class
 procedure Line(const Text:String);
 procedure Abort(var Value:Boolean);
end;
var C:TCallbacks; Outcome:TProcessResult; Lines:TStringList; Start:QWord; Output, Dir:String;
procedure Check(Value:Boolean; const Name:String);
begin if not Value then raise Exception.Create(Name); WriteLn('[OK] ',Name) end;
procedure TCallbacks.Line(const Text:String); begin Lines.Add(Text) end;
procedure TCallbacks.Abort(var Value:Boolean); begin Value:=GetTickCount64-Start>100 end;
var Pid:Integer; S:TStringList;
begin
 C:=TCallbacks.Create; Lines:=TStringList.Create; S:=TStringList.Create;
 Dir:=GetTempDir+'penguin-process-'+IntToStr(fpGetPid)+'/'; ForceDirectories(Dir);
 try
  Output:=RunAndGetOutput('/bin/sh -c '+QuotedStr('printf tail; exit 7'),'',@C.Line,nil,False,False,@Outcome);
  Check(Outcome.Started and (Outcome.ExitCode=7),'nonzero exit status');
  Check((Output='tail') and (Lines.Count=1) and (Lines[0]='tail'),'last line without newline');
  Lines.Clear;
  RunAndGetOutput(Dir+'missing','',@C.Line,nil,False,False,@Outcome);
  Check(not Outcome.Started and (Outcome.ExitCode=-1) and (Outcome.ErrorText<>''),'missing executable fails');
  Check(Lines.Count=1,'launch failure reaches output callback');
  RunAndGetOutput('/bin/sh -c '+QuotedStr('kill -TERM $$'),'',nil,nil,False,False,@Outcome);
  Check(Outcome.ExitCode=143,'signal is not success');
  Start:=GetTickCount64;
  RunAndGetOutput('/bin/sh -c '+QuotedStr('sleep 30 & echo $! > '+Dir+'child; wait'),'',nil,@C.Abort,False,False,@Outcome);
  Check(Outcome.Cancelled and (GetTickCount64-Start<3000),'cancel completes promptly');
  S.LoadFromFile(Dir+'child'); Pid:=StrToInt(Trim(S.Text));
  Sleep(100); Check(fpKill(Pid,0)<>0,'cancel stops descendants');
  DeleteFile(Dir+'child'); RemoveDir(Dir);
 finally C.Free; Lines.Free; S.Free end;
end.
