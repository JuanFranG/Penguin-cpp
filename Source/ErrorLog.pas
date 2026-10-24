{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    The error report. Errors the IDE did not handle (an access violation, a
    range check...) are added to penguin-cpp-errores.txt on the user's
    desktop, with the date, the version, the system and the backtrace, so
    that the user finds it and can send it. The file may name the user's own
    files, so only the user can read it (0600).

    The installed program has no symbols: its backtrace is addresses, which
    addr2line turns into files and lines with the same build kept with its
    symbols (the CI keeps it as an artifact). The Debug build writes the
    files and lines itself.
}
unit ErrorLog;

{$MODE DELPHI}

interface

uses
  SysUtils;

// Adds the exception being handled to the report. Call it while handling it
// (an except block, Application.OnException): the backtrace is the current
// one. Never raises.
procedure LogException(E: Exception);

// The report, e.g. ~/Escritorio/penguin-cpp-errores.txt
function ErrorLogFileName: String;

// Errors added to the report since the program started
function ErrorsLogged: Integer;

implementation

uses
  Classes, {$IFDEF UNIX}BaseUnix,{$ENDIF} devPlatform, Version;

const
  LogName = 'penguin-cpp-errores.txt';
  MaxLogSize = 512 * 1024; // past it the report starts again, the old one kept as .old.txt

var
  Count: Integer = 0;

function ErrorLogFileName: String;
begin
  Result := GetDesktopDir + LogName;
end;

function ErrorsLogged: Integer;
begin
  Result := Count;
end;

function SystemName: String;
var
  Lines: TStringList;
begin
  Result := '';
  Lines := TStringList.Create;
  try
    try
      Lines.LoadFromFile('/etc/os-release');
      Result := AnsiDequotedStr(Lines.Values['PRETTY_NAME'], '"');
    except
      Result := '';
    end;
  finally
    Lines.Free;
  end;
  if Result = '' then
    Result := 'unknown system';
end;

function FileSizeOf(const FileName: String): Int64;
var
  Rec: TSearchRec;
begin
  Result := 0;
  if FindFirst(FileName, faAnyFile, Rec) = 0 then begin
    Result := Rec.Size;
    FindClose(Rec);
  end;
end;

procedure LogException(E: Exception);
var
  FileName: String;
  F: TextFile;
  Opened: Boolean;
begin
  Inc(Count);
  Opened := False;
  try
    FileName := ErrorLogFileName;
    if FileSizeOf(FileName) > MaxLogSize then
      RenameFile(FileName, ChangeFileExt(FileName, '.old.txt'));
    AssignFile(F, FileName);
    if FileExists(FileName) then
      Append(F)
    else
      Rewrite(F);
    Opened := True;
{$IFDEF UNIX}
    FpChmod(FileName, &600);
{$ENDIF}
    WriteLn(F, '==== ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), '  Penguin cpp ', DEVCPP_VERSION, '  ',
      SystemName);
    WriteLn(F, E.ClassName, ': ', E.Message);
    DumpExceptionBackTrace(F);
    WriteLn(F);
  except
    // A report that can't be written must not cause another error
  end;
  if Opened then
    try
      CloseFile(F);
    except
    end;
end;

end.
