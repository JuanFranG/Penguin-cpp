program executortest;
{$mode objfpc}{$H+}
uses cthreads, Forms, main, devCFG, Utils, Classes, SysUtils, BaseUnix, devExec;
type THooks=class
 Calls:Integer;
 procedure Ended(Sender:TObject);
end;
var Hooks:THooks; E:TdevExecutor; Args,S:TStringList; I,Pid:Integer; Dir:String;
procedure Check(Value:Boolean; const Name:String);
begin if not Value then raise Exception.Create(Name); WriteLn('[OK] ',Name) end;
procedure THooks.Ended(Sender:TObject);
begin
 Inc(Calls);
 E.ExecuteAndWatch('/bin/sleep','30','',False,INFINITE,nil);
 CheckSynchronize(1);
end;
procedure Launch(const Name:String);
begin
 Args.Clear; Args.Add('-c'); Args.Add('echo $$ > '+Dir+Name+'; exec sleep 30');
 E.ExecuteAndWatch('/bin/sh',Args,'',nil);
 for I:=1 to 200 do begin if FileExists(Dir+Name) then Exit; Sleep(10) end;
 raise Exception.Create('launch timeout');
end;
var J:Integer;
begin
 Dir:=GetTempDir+'penguin-executor-'+IntToStr(fpGetPid)+'/'; ForceDirectories(Dir);
 Hooks:=THooks.Create; E:=TdevExecutor.Create; Args:=TStringList.Create; S:=TStringList.Create;
 try
  for J:=1 to 10 do begin
   Launch('old'); E.Reset; DeleteFile(Dir+'old');
   Launch('new');
   for I:=1 to 10 do begin CheckSynchronize(10); Sleep(5) end;
   S.LoadFromFile(Dir+'new'); Pid:=StrToInt(Trim(S.Text));
   Check((fpKill(Pid,0)=0) and E.Running,'restart keeps the new execution active');
   E.Reset; Sleep(20);
   Check((fpKill(Pid,0)<>0) and not E.Running,'reset waits and stops the process');
   DeleteFile(Dir+'new');
  end;
  for J:=1 to 50 do begin
   Args.Clear; Args.Add('30'); E.ExecuteAndWatch('/bin/sleep',Args,'',nil); E.Reset;
  end;
  Args.Clear; Args.Add('0'); E.ExecuteAndWatch('/bin/sleep',Args,'',nil);
  for I:=1 to 200 do begin CheckSynchronize(10); if not E.Running then Break; Sleep(5) end;
  Check(not E.Running,'natural completion retires worker');
  CheckSynchronize(100);
  E.ExecuteAndWatch('/bin/sleep','0','',False,INFINITE,@Hooks.Ended);
  for I:=1 to 200 do begin CheckSynchronize(10); if Hooks.Calls>0 then Break; Sleep(5) end;
  Check((Hooks.Calls=1) and E.Running,'completion callback can start a new execution');
  E.Reset; CheckSynchronize(100);
  E.ExecuteAndWatch(Dir+'missing',Args,'',nil);
  for I:=1 to 200 do begin CheckSynchronize(10); if not E.Running then Break; Sleep(5) end;
  Check((not E.Running) and (E.LastError<>''),'executor exposes launch failure');
  CheckSynchronize(100);
 finally E.Free; Hooks.Free; Args.Free; S.Free; RemoveDir(Dir) end;
end.
