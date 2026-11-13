{ SPDX-License-Identifier: GPL-2.0-or-later }
unit WindowsGameCore;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, IniFiles;
type
  TCompatibilityMode = (cmAutomatic, cmNative, cmWindows);
  TWindowsGameConfig = record
    Mode: TCompatibilityMode;
    DataDirectory: String;
    Enabled, UsesGPTK: Boolean;
    Toolchain, Runner, Prefix: String;
  end;
  TWindowsGameError = (wgOK, wgToolchainMissing, wgToolchainNotNative,
    wgRunnerMissing, wgRunnerNotNative, wgPrefixInvalid, wgInvalidPE, wgGPTKPlatform);
procedure DiscoverWindowsGameConfig(const DataDirectory: String; out Config: TWindowsGameConfig);
procedure ReadWindowsGameConfig(Ini: TCustomIniFile; var Config: TWindowsGameConfig);
procedure WriteWindowsGameConfig(Ini: TCustomIniFile; const Config: TWindowsGameConfig);
function FileNeedsWindows(const FileName: String; IncludeDirs: TStrings = nil): Boolean;
function WindowsMakeProgram(const Config: TWindowsGameConfig): String;
function WindowsDefaultPrefix(const UserDataDirectory: String): String;
function WindowsRuntimeCommand(const Config: TWindowsGameConfig; const Prefix: String;
  Command: TStrings): TWindowsGameError;
function WindowsGameErrorText(Error: TWindowsGameError): String;
function HasArm64MachO(const FileName: String): Boolean;
function WindowsPEMachine(const FileName: String): Word;
function ResolveWindowsCompilers(const Config: TWindowsGameConfig;
  out CCompiler, CppCompiler: String): TWindowsGameError;
function WindowsGameCommand(const Config: TWindowsGameConfig; const ProgramFile,
  Parameters, DefaultPrefix: String; Command: TStrings): TWindowsGameError;
implementation
uses BaseUnix, Process, StrUtils, Math;
const Section = 'WindowsGame';
function FileNeedsWindows(const FileName: String; IncludeDirs: TStrings): Boolean;
var Seen: TStringList;
  function Scan(const Name: String; Depth: Integer): Boolean;
  var F: TFileStream; Text, Header, Delimiter, FullName, Candidate: String;
    I, J, K, Finish, Dir: Integer; StartOfLine: Boolean; Quote: Char;
  begin
    Result := False; FullName := ExpandFileName(Name);
    if (Depth > 64) or (Seen.IndexOf(FullName) >= 0) or not FileExists(FullName) then Exit;
    Seen.Add(FullName);
    if SameText(ExtractFileExt(Name), '.rc') then Exit(True);
    try
      F := TFileStream.Create(FullName, fmOpenRead or fmShareDenyNone);
      try
        if F.Size > 8 * 1024 * 1024 then Exit;
        SetLength(Text, F.Size); if Text <> '' then F.ReadBuffer(Text[1], Length(Text));
      finally F.Free end;
    except Exit end;
    Text := StringReplace(Text, '\' + #13#10, ' ', [rfReplaceAll]);
    Text := StringReplace(Text, '\' + #10, ' ', [rfReplaceAll]);
    I := 1; StartOfLine := True;
    while I <= Length(Text) do begin
      if Text[I] in [#10,#13] then begin StartOfLine := True; Inc(I); Continue end;
      if Text[I] in [' ',#9] then begin Inc(I); Continue end;
      if Copy(Text,I,2) = '//' then begin
        while (I <= Length(Text)) and not (Text[I] in [#10,#13]) do Inc(I);
        Continue;
      end;
      if Copy(Text,I,2) = '/*' then begin
        Inc(I,2);
        while (I <= Length(Text)) and (Copy(Text,I,2) <> '*/') do begin
          if Text[I] in [#10,#13] then StartOfLine := True; Inc(I);
        end;
        Inc(I,2); Continue;
      end;
      if StartOfLine and (Text[I] = '#') then begin
        J := I + 1; while (J <= Length(Text)) and (Text[J] in [' ',#9]) do Inc(J);
        if Copy(Text,J,7) = 'include' then begin
          Inc(J,7); while (J <= Length(Text)) and (Text[J] in [' ',#9]) do Inc(J);
          if (J <= Length(Text)) and (Text[J] in ['<','"']) then begin
            Quote := Text[J]; Inc(J); K := J;
            while (J <= Length(Text)) and not (Text[J] in ['>', '"',#10,#13]) do Inc(J);
            Header := Copy(Text,K,J-K);
            case LowerCase(Header) of
              'windows.h','conio.h','graphics.h','winbgim.h','winsock.h','winsock2.h',
              'ws2tcpip.h','tchar.h','direct.h','io.h','process.h','dos.h','winuser.h',
              'd3d9.h','d3d11.h','d3d12.h','shellapi.h','mmsystem.h': Exit(True);
            end;
            if Quote = '"' then begin
              Candidate := ExtractFilePath(FullName) + Header;
              if Scan(Candidate,Depth+1) then Exit(True);
            end;
            if Assigned(IncludeDirs) then for Dir := 0 to IncludeDirs.Count-1 do begin
              Candidate := IncludeTrailingPathDelimiter(IncludeDirs[Dir]) + Header;
              if Scan(Candidate,Depth+1) then Exit(True);
            end;
          end;
        end;
      end;
      StartOfLine := False;
      // Raw C++ strings can span lines containing text that looks like a directive.
      if Copy(Text,I,2) = 'R"' then begin
        J := I+2; while (J <= Length(Text)) and (J-I <= 18) and (Text[J] <> '(') do Inc(J);
        if (J <= Length(Text)) and (Text[J] = '(') then begin
          Delimiter := ')' + Copy(Text,I+2,J-I-2) + '"'; Finish := PosEx(Delimiter,Text,J+1);
          if Finish = 0 then Exit;
          I := Finish + Length(Delimiter); Continue;
        end;
      end;
      if Text[I] in ['"',#39] then begin
        Quote := Text[I]; Inc(I);
        while I <= Length(Text) do begin
          if Text[I] = '\' then Inc(I,2)
          else if Text[I] = Quote then begin Inc(I); Break end
          else Inc(I);
        end;
      end else Inc(I);
    end;
  end;
begin
  Seen := TStringList.Create;
  try Seen.Sorted := True; Result := Scan(FileName,0) finally Seen.Free end;
end;
procedure DiscoverWindowsGameConfig(const DataDirectory: String; out Config: TWindowsGameConfig);
var Root: String;
{$IFNDEF DARWIN} C: String; {$ENDIF}
begin
  Config.Mode := cmAutomatic; Config.DataDirectory := IncludeTrailingPathDelimiter(DataDirectory);
  Config.Enabled := False; Config.UsesGPTK := False;
  Config.Toolchain := ''; Config.Runner := ''; Config.Prefix := '';
  Root := IncludeTrailingPathDelimiter(DataDirectory) + 'Compat/windows/';
  if DirectoryExists(Root + 'toolchain') then Config.Toolchain := Root + 'toolchain';
  if FileExists(Root + 'runtime/bin/wine') then Config.Runner := Root + 'runtime/bin/wine';
{$IFNDEF DARWIN}
  if Config.Toolchain = '' then begin
    C := ExeSearch('x86_64-w64-mingw32-g++', GetEnvironmentVariable('PATH'));
    if C <> '' then Config.Toolchain := ExtractFileDir(C);
  end;
  if Config.Runner = '' then Config.Runner := ExeSearch('wine', GetEnvironmentVariable('PATH'));
{$ENDIF}
  // Auto selects a target from source dependencies when compiling.
  Config.Enabled := False;
end;
procedure ReadWindowsGameConfig(Ini: TCustomIniFile; var Config: TWindowsGameConfig);
begin
  if Ini.ValueExists(Section, 'Mode') then
    Config.Mode := TCompatibilityMode(EnsureRange(Ini.ReadInteger(Section, 'Mode', 0), 0, 2))
  else if Ini.ValueExists(Section, 'Enabled') then begin
    if Ini.ReadBool(Section, 'Enabled', False) then Config.Mode := cmWindows
    else Config.Mode := cmNative;
  end;
  Config.Enabled := Config.Mode = cmWindows;
  Config.UsesGPTK := Ini.ReadBool(Section, 'UsesGPTK', Config.UsesGPTK);
  if Ini.ReadString(Section, 'Toolchain', '') <> '' then
    Config.Toolchain := Ini.ReadString(Section, 'Toolchain', Config.Toolchain);
  if Ini.ReadString(Section, 'Runner', '') <> '' then
    Config.Runner := Ini.ReadString(Section, 'Runner', Config.Runner);
  Config.Prefix := Ini.ReadString(Section, 'Prefix', Config.Prefix);
end;
procedure WriteWindowsGameConfig(Ini: TCustomIniFile; const Config: TWindowsGameConfig);
begin
  Ini.WriteInteger(Section, 'Mode', Ord(Config.Mode));
  Ini.DeleteKey(Section, 'Enabled');
  Ini.WriteBool(Section, 'UsesGPTK', Config.UsesGPTK);
  if Config.Toolchain = Config.DataDirectory + 'Compat/windows/toolchain' then
    Ini.DeleteKey(Section, 'Toolchain')
  else Ini.WriteString(Section, 'Toolchain', Config.Toolchain);
  if Config.Runner = Config.DataDirectory + 'Compat/windows/runtime/bin/wine' then
    Ini.DeleteKey(Section, 'Runner')
  else Ini.WriteString(Section, 'Runner', Config.Runner);
  Ini.WriteString(Section, 'Prefix', Config.Prefix);
end;
function WindowsGameErrorText(Error: TWindowsGameError): String;
const Messages: array[TWindowsGameError] of String = (
  '', 'Select an installed LLVM-MinGW or MinGW-w64 toolchain.',
  'The compiler must run natively on ARM64 macOS; Intel-only tools require Rosetta.',
  'Select an installed Windows runtime executable (Wine).',
  'The runtime and wineserver must run natively on ARM64 macOS; Intel-only runtimes require Rosetta.',
  'Select an absolute, dedicated runtime folder: empty, new, or an existing Wine prefix.',
  'The output is not a supported Windows executable (PE).',
  'Apple GPTK is available only on macOS.');
begin Result := Messages[Error] end;
function HasArm64MachO(const FileName: String): Boolean;
var F: TFileStream; B: array[0..4095] of Byte; N, I, Count, Step, Offset: Integer;
  function U32(P: Integer; Big: Boolean): LongWord;
  begin
    if Big then Result := LongWord(B[P]) shl 24 or LongWord(B[P+1]) shl 16 or LongWord(B[P+2]) shl 8 or B[P+3]
    else Result := LongWord(B[P+3]) shl 24 or LongWord(B[P+2]) shl 16 or LongWord(B[P+1]) shl 8 or B[P];
  end;
begin
  Result := False;
  try
    F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try N := F.Read(B, SizeOf(B)) finally F.Free end;
  except Exit end;
  if N < 32 then Exit;
  if U32(0, False) = $FEEDFACF then
    Exit((U32(4, False) = $0100000C) and (U32(12, False) = 2));
  if (U32(0, True) <> $CAFEBABE) and (U32(0, True) <> $CAFEBABF) then Exit;
  Count := U32(4, True); Step := 20;
  if U32(0, True) = $CAFEBABF then Step := 32;
  if (Count < 1) or (Count > 64) or (8 + Count * Step > N) then Exit;
  for I := 0 to Count - 1 do begin
    Offset := 8 + I * Step;
    if U32(Offset, True) = $0100000C then Exit(True);
  end;
end;
function WindowsPEMachine(const FileName: String): Word;
var F: TFileStream; Header: array[0..63] of Byte; PE: array[0..5] of Byte; Offset: LongWord;
begin
  Result := 0;
  try
    F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      if (F.Read(Header, SizeOf(Header)) <> SizeOf(Header)) or (Header[0] <> $4D) or (Header[1] <> $5A) then Exit;
      Offset := LongWord(Header[60]) or LongWord(Header[61]) shl 8 or LongWord(Header[62]) shl 16 or LongWord(Header[63]) shl 24;
      if (Offset < 64) or (Int64(Offset) + 6 > F.Size) then Exit;
      F.Position := Offset;
      if (F.Read(PE, SizeOf(PE)) <> SizeOf(PE)) or (PE[0] <> $50) or (PE[1] <> $45) or (PE[2] <> 0) or (PE[3] <> 0) then Exit;
      Result := Word(PE[4]) or Word(PE[5]) shl 8;
      if (Result <> $014C) and (Result <> $8664) and (Result <> $AA64) then Result := 0;
    finally F.Free end;
  except Result := 0 end;
end;
function Executable(const S: String): Boolean;
begin Result := FileExists(S) and (FpAccess(S, X_OK) = 0) end;
function ResolveWindowsCompilers(const Config: TWindowsGameConfig;
  out CCompiler, CppCompiler: String): TWindowsGameError;
var Bin: String;
begin
  CCompiler := ''; CppCompiler := '';
{$IFNDEF DARWIN}
  if Config.UsesGPTK then Exit(wgGPTKPlatform);
{$ENDIF}
  if Trim(Config.Toolchain) = '' then Exit(wgToolchainMissing);
  Bin := IncludeTrailingPathDelimiter(ExpandFileName(Config.Toolchain));
  if DirectoryExists(Bin + 'bin') then Bin := Bin + 'bin' + PathDelim;
  if Executable(Bin + 'x86_64-w64-mingw32-clang') and Executable(Bin + 'x86_64-w64-mingw32-clang++') then begin
    CCompiler := Bin + 'x86_64-w64-mingw32-clang'; CppCompiler := Bin + 'x86_64-w64-mingw32-clang++';
{$IFDEF DARWIN}
    // LLVM-MinGW's named drivers are scripts; their sibling clang is the host binary.
    if not HasArm64MachO(Bin + 'clang') then Exit(wgToolchainNotNative);
{$ENDIF}
  end else if Executable(Bin + 'x86_64-w64-mingw32-gcc') and Executable(Bin + 'x86_64-w64-mingw32-g++') then begin
    CCompiler := Bin + 'x86_64-w64-mingw32-gcc'; CppCompiler := Bin + 'x86_64-w64-mingw32-g++';
{$IFDEF DARWIN}
    if not HasArm64MachO(CCompiler) or not HasArm64MachO(CppCompiler) then Exit(wgToolchainNotNative);
{$ENDIF}
  end else Exit(wgToolchainMissing);
  Result := wgOK;
end;
function EmptyDirectory(const Dir: String): Boolean;
var R: TSearchRec;
begin
  Result := True;
  if not DirectoryExists(Dir) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, R) = 0 then begin
    repeat
      if (R.Name <> '.') and (R.Name <> '..') then begin Result := False; Break end;
    until FindNext(R) <> 0;
    FindClose(R);
  end;
end;
function WindowsMakeProgram(const Config: TWindowsGameConfig): String;
begin
  Result := Config.DataDirectory + 'Compat/windows/tools/bin/make';
  if not Executable(Result) then Result := '';
{$IFNDEF DARWIN}
  if Result = '' then Result := ExeSearch('make',GetEnvironmentVariable('PATH'));
{$ENDIF}
end;
function WindowsDefaultPrefix(const UserDataDirectory: String): String;
begin Result := IncludeTrailingPathDelimiter(UserDataDirectory) + 'Compatibility/windows/prefix' end;
function WindowsRuntimeCommand(const Config: TWindowsGameConfig; const Prefix: String;
  Command: TStrings): TWindowsGameError;
var P, Root: String;
begin
  Command.Clear;
{$IFNDEF DARWIN}
  if Config.UsesGPTK then Exit(wgGPTKPlatform);
{$ENDIF}
  if not Executable(Config.Runner) then Exit(wgRunnerMissing);
{$IFDEF DARWIN}
  if not HasArm64MachO(Config.Runner) then Exit(wgRunnerNotNative);
  if FileExists(ExtractFilePath(Config.Runner) + 'wineserver') and
    not HasArm64MachO(ExtractFilePath(Config.Runner) + 'wineserver') then Exit(wgRunnerNotNative);
{$ENDIF}
  if Prefix = '' then Exit(wgPrefixInvalid);
  if Prefix[1] <> PathDelim then Exit(wgPrefixInvalid);
  P := ExcludeTrailingPathDelimiter(ExpandFileName(Prefix));
  if (P = '') or (P = PathDelim) or (P = ExcludeTrailingPathDelimiter(GetUserDir)) then Exit(wgPrefixInvalid);
  if not EmptyDirectory(P) and not (FileExists(P + '/system.reg') and DirectoryExists(P + '/drive_c')) then Exit(wgPrefixInvalid);
  Command.Add('/usr/bin/env'); Command.Add('WINEPREFIX=' + P);
  Command.Add('WINEDEBUG=-all'); Command.Add('WINEDLLOVERRIDES=mscoree,mshtml=');
  Root := ExpandFileName(ExtractFilePath(Config.Runner) + '..');
  if DirectoryExists(Root + '/lib/gstreamer-1.0') then begin
    Command.Add('GST_PLUGIN_SYSTEM_PATH_1_0=' + Root + '/lib/gstreamer-1.0');
    Command.Add('GST_PLUGIN_SCANNER_1_0=' + Root + '/libexec/gstreamer-1.0/gst-plugin-scanner');
  end;
  if FileExists(Root + '/share/vulkan/icd.d/MoltenVK_icd.json') then
    Command.Add('VK_DRIVER_FILES=' + Root + '/share/vulkan/icd.d/MoltenVK_icd.json');
  Command.Add(Config.Runner);
  Result := wgOK;
end;
function WindowsGameCommand(const Config: TWindowsGameConfig; const ProgramFile,
  Parameters, DefaultPrefix: String; Command: TStrings): TWindowsGameError;
var Prefix: String;
begin
  Prefix := Config.Prefix;
  if Prefix = '' then Prefix := DefaultPrefix;
  Result := WindowsRuntimeCommand(Config, Prefix, Command);
  if Result <> wgOK then Exit;
  if WindowsPEMachine(ProgramFile) = 0 then begin Command.Clear; Exit(wgInvalidPE) end;
  // No shell: project arguments remain individual strings.
  Command.Add(ExpandFileName(ProgramFile)); CommandToList(Parameters, Command);
end;
end.
