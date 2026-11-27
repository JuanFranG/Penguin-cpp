{ SPDX-License-Identifier: GPL-2.0-or-later }
unit FileTransactions;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, IniFiles;

// Replaces a file only after all bytes and metadata have been written.
procedure AtomicWriteFile(const FileName: String; const Data: RawByteString);

// Project state is committed explicitly, never by a destructor on Cancel.
type
  TAtomicIniFile = class(TMemIniFile)
  private
    FDiscarding: Boolean;
  public
    constructor Create(const AFileName: String; AOptions: TIniFileOptions = []); override;
    function ReadString(const Section, Ident, Default: String): String; override;
    destructor Destroy; override;
    procedure UpdateFile; override;
  end;

implementation
uses BaseUnix, Unix, ctypes, InitC;

function ChangeOwner(FD: cint; UID, GID: cuint): cint;
  cdecl; external 'c' name 'fchown';
function ChangeMode(FD: cint; Mode: cuint): cint;
  cdecl; external 'c' name 'fchmod';

{$IFDEF DARWIN}
function CopyMetadata(Src, Dst: cint; State: Pointer; Flags: cuint): cint;
  cdecl; external 'c' name 'fcopyfile';
{$ELSE}
function ListAttributes(FD: cint; Names: Pointer; Size: csize_t): ssize_t;
  cdecl; external 'c' name 'flistxattr';
function GetAttribute(FD: cint; Name: PChar; Value: Pointer; Size: csize_t): ssize_t;
  cdecl; external 'c' name 'fgetxattr';
function SetAttribute(FD: cint; Name: PChar; Value: Pointer; Size: csize_t; Flags: cint): cint;
  cdecl; external 'c' name 'fsetxattr';

procedure CopyAttributes(Src, Dst: cint);
var Names, Name, Value: RawByteString; N, Size, I, J: SizeInt;
begin
  N := ListAttributes(Src, nil, 0);
  if (N < 0) and (fpgetCerrno = ESysEOPNOTSUPP) then Exit;
  if N < 0 then RaiseLastOSError(fpgetCerrno);
  if N = 0 then Exit;
  SetLength(Names, N);
  N := ListAttributes(Src, @Names[1], N);
  if N < 0 then RaiseLastOSError(fpgetCerrno);
  I := 1;
  while I <= N do begin
    J := I;
    while (J <= N) and (Names[J] <> #0) do Inc(J);
    Name := Copy(Names, I, J-I);
    Size := GetAttribute(Src, PChar(Name), nil, 0);
    if Size < 0 then RaiseLastOSError(fpgetCerrno);
    SetLength(Value, Size);
    if GetAttribute(Src, PChar(Name), PChar(Value), Size) <> Size then
      RaiseLastOSError(fpgetCerrno);
    if SetAttribute(Dst, PChar(Name), PChar(Value), Size, 0) <> 0 then
      RaiseLastOSError(fpgetCerrno);
    I := J+1;
  end;
end;
{$ENDIF}

procedure AtomicWriteFile(const FileName: String; const Data: RawByteString);
var Target, Temp, Link: String; Info: Stat; ID: TGUID;
  FD, Src, I: Integer; Done, N: SizeInt; Exists: Boolean;
begin
  Target := ExpandFileName(FileName);
  // Editing through a symbolic link must update its target, not remove the link.
  for I := 0 to 40 do begin
    if (fpLStat(Target, Info) <> 0) or not fpS_ISLNK(Info.st_mode) then Break;
    if I = 40 then raise EInOutError.Create('Too many symbolic links: ' + FileName);
    Link := fpReadLink(Target);
    if Link = '' then RaiseLastOSError;
    if Link[1] <> PathDelim then Link := ExtractFilePath(Target) + Link;
    Target := ExpandFileName(Link);
  end;
  Exists := fpStat(Target, Info) = 0;
  if Exists and (fpAccess(Target, W_OK) <> 0) then RaiseLastOSError;
  if Exists and not fpS_ISREG(Info.st_mode) then
    raise EInOutError.Create('Not a regular file: ' + FileName);
  if Exists and (Info.st_nlink > 1) then
    raise EInOutError.Create('Use Save As for a file with multiple hard links: ' + FileName);
  if CreateGUID(ID) <> 0 then raise EInOutError.Create('Cannot reserve save file');
  Temp := ExtractFilePath(Target) + '.penguin-save-' + GUIDToString(ID);
  FD := fpOpen(Temp, O_WRONLY or O_CREAT or O_EXCL, &600);
  if FD < 0 then RaiseLastOSError;
  Src := -1;
  try
    Done := 0;
    while Done < Length(Data) do begin
      N := fpWrite(FD, Data[Done+1], Length(Data)-Done);
      if (N < 0) and (fpGetErrno = ESysEINTR) then Continue;
      if N <= 0 then RaiseLastOSError;
      Inc(Done, N);
    end;
    if Exists then begin
      Src := fpOpen(Target, O_RDONLY);
      if Src < 0 then RaiseLastOSError;
      if ChangeOwner(FD, Info.st_uid, Info.st_gid) <> 0 then RaiseLastOSError(fpgetCerrno);
      if ChangeMode(FD, Info.st_mode and &7777) <> 0 then RaiseLastOSError(fpgetCerrno);
{$IFDEF DARWIN}
      // COPYFILE_ACL | COPYFILE_XATTR; keep the new modification time.
      if CopyMetadata(Src, FD, nil, 5) <> 0 then RaiseLastOSError(fpgetCerrno);
{$ELSE}
      CopyAttributes(Src, FD);
{$ENDIF}
    end;
    if fpFsync(FD) <> 0 then RaiseLastOSError;
    if fpClose(FD) <> 0 then begin FD := -1; RaiseLastOSError end;
    FD := -1;
    if not RenameFile(Temp, Target) then RaiseLastOSError;
  finally
    if Src >= 0 then fpClose(Src);
    if FD >= 0 then fpClose(FD);
    DeleteFile(Temp);
  end;
end;

constructor TAtomicIniFile.Create(const AFileName: String; AOptions: TIniFileOptions);
begin
  // Match TIniFile when reading quoted settings from older Penguin versions.
  inherited Create(AFileName, AOptions + [ifoStripQuotes]);
end;

destructor TAtomicIniFile.Destroy;
begin
  FDiscarding := True;
  inherited Destroy;
end;

function TAtomicIniFile.ReadString(const Section, Ident, Default: String): String;
begin
  Result := inherited ReadString(Section, Ident, Default);
  // The old reader could re-save already quoted resource paths with another pair.
  if SameText(Section, 'Directories') or
    (SameText(Section, 'Options') and (SameText(Ident, 'Language') or
     SameText(Ident, 'InterfaceFont') or SameText(Ident, 'Theme'))) then
    while (Length(Result) >= 2) and (Result[1] = '"') and
      (Result[Length(Result)] = '"') do
      Result := Copy(Result, 2, Length(Result) - 2);
end;

procedure TAtomicIniFile.UpdateFile;
var Lines: TStringList; BufferStream: TMemoryStream; Data: RawByteString;
begin
  if FDiscarding then Exit;
  Lines := TStringList.Create;
  BufferStream := TMemoryStream.Create;
  try
    GetStrings(Lines);
    Lines.WriteBOM := WriteBOM;
    Lines.SaveToStream(BufferStream, Encoding);
    SetLength(Data, BufferStream.Size);
    if Data <> '' then Move(BufferStream.Memory^, Data[1], Length(Data));
    AtomicWriteFile(FileName, Data);
  finally BufferStream.Free; Lines.Free end;
end;
end.
