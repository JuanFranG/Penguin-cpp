program filetransactionstest;
{$mode objfpc}{$H+}
uses Classes, SysUtils, FileTransactions;
var Ini: TAtomicIniFile;
begin
  try
    if ParamStr(1) = 'write' then AtomicWriteFile(ParamStr(2), ParamStr(3))
    else begin
      Ini := TAtomicIniFile.Create(ParamStr(2));
      try
        Ini.WriteString('Project', 'Name', ParamStr(3));
        if ParamStr(1) = 'commit' then Ini.UpdateFile;
      finally Ini.Free end;
    end;
  except on E: Exception do begin WriteLn(StdErr, E.Message); Halt(1) end end;
end.
