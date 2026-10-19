{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    Reads the output of gdb's machine interface (gdb --interpreter=mi), one
    line at a time. Dev-C++ read gdb's --annotate=2 output, which gdb no
    longer develops; MI is the stable interface for programs.

    Every line is a record:
      [token]^class,results       the answer to a command (done, running,
                                   connected, error, exit)
      [token]*class,results       the program's state (running, stopped)
      [token]+class,results       progress of a long operation
      [token]=class,results       news (breakpoint-modified, library-loaded...)
      ~"text"  @"text"  &"text"  what gdb prints, the program prints, or
                                   gdb logs
      (gdb)                        gdb waits for the next command
    A result is name=value, and a value is a "C string", a tuple of results
    (in braces) or a list of values or results (in brackets). See "GDB/MI Output Syntax" in
    the gdb manual.

    No LCL here: Tests/GdbMITest checks it without gdb, and the reader
    thread of the debugger uses it without touching the interface.
}

unit GdbMI;

{$MODE DELPHI}

interface

uses
  Classes, SysUtils, Contnrs;

type
  TMIValueKind = (mvConst, mvTuple, mvList);

  // A value: a string (Text), or a tuple/list of values. The values of a
  // tuple, and of a list of results, have a Name.
  TMIValue = class
  private
    fKind: TMIValueKind;
    fName: String;
    fText: String;
    fItems: TObjectList;
    function GetCount: Integer;
    function GetItem(Index: Integer): TMIValue;
  public
    constructor Create(Kind: TMIValueKind; const Name: String = '');
    destructor Destroy; override;
    procedure Add(Value: TMIValue);
    // The item called Name, or nil. A path goes down tuples: 'frame.line'
    function Find(const Path: String): TMIValue;
    // The text at Path, or Default when there is none or it is not a string
    function Get(const Path: String; const Default: String = ''): String;
    function GetInt(const Path: String; Default: Int64 = -1): Int64;
    property Kind: TMIValueKind read fKind;
    property Name: String read fName;
    property Text: String read fText write fText;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TMIValue read GetItem; default;
  end;

  TMIRecordKind = (
    mrResult,  // ^ the answer to a command
    mrExec,    // * the program's state
    mrStatus,  // + progress
    mrNotify,  // = news
    mrConsole, // ~ text from gdb
    mrTarget,  // @ text from the program
    mrLog,     // & gdb's log
    mrPrompt,  // (gdb)
    mrOther);  // anything else (with a remote target, the program's own output)

  TMIRecord = class
  private
    fKind: TMIRecordKind;
    fToken: Int64;
    fClass: String;
    fResults: TMIValue;
    fText: String;
  public
    constructor Create;
    destructor Destroy; override;
    property Kind: TMIRecordKind read fKind;
    // The number written before the command it answers, -1 without one
    property Token: Int64 read fToken;
    // done, running, error, stopped, breakpoint-modified...
    property RecordClass: String read fClass;
    // The results, as a tuple (never nil)
    property Results: TMIValue read fResults;
    // The text of a stream record, unescaped; the whole line for mrOther
    property Text: String read fText;
  end;

// Reads one line of gdb's output (without its line break). Never fails:
// a line it cannot read whole comes back as mrOther with its text, or with
// the results read up to the damage.
function ParseMILine(const Line: String): TMIRecord;

// S as a C string for an MI command: "..." with \ " and control characters
// escaped, so a file name or an expression is always one argument
function MIQuote(const S: String): String;

// A value as gdb prints it, split into its members: '{a = 1, b = {c = 2}}'
// gives 'a = 1' and 'b = {c = 2}'; an array '{1, 2}' gives '1' and '2'.
// False (and nothing added) for a value without members. Commas inside
// strings, characters, braces, brackets, parentheses or <...> (templates,
// <repeats 5 times>) do not split. Members may be nil: just the question.
function SplitGdbValue(const Value: String; Members: TStrings): Boolean;

// 'name = value' into its two parts; Name is '' for an array element
procedure SplitGdbMember(const Member: String; out Name, Value: String);

implementation

{ TMIValue }

constructor TMIValue.Create(Kind: TMIValueKind; const Name: String);
begin
  inherited Create;
  fKind := Kind;
  fName := Name;
  if Kind <> mvConst then
    fItems := TObjectList.Create(True);
end;

destructor TMIValue.Destroy;
begin
  fItems.Free;
  inherited;
end;

function TMIValue.GetCount: Integer;
begin
  if Assigned(fItems) then
    Result := fItems.Count
  else
    Result := 0;
end;

function TMIValue.GetItem(Index: Integer): TMIValue;
begin
  Result := TMIValue(fItems[Index]);
end;

procedure TMIValue.Add(Value: TMIValue);
begin
  fItems.Add(Value);
end;

function TMIValue.Find(const Path: String): TMIValue;
var
  Dot, I: Integer;
  Head, Rest: String;
begin
  Dot := Pos('.', Path);
  if Dot > 0 then begin
    Head := Copy(Path, 1, Dot - 1);
    Rest := Copy(Path, Dot + 1, MaxInt);
  end else begin
    Head := Path;
    Rest := '';
  end;
  Result := nil;
  for I := 0 to Count - 1 do
    if Items[I].Name = Head then begin
      Result := Items[I];
      Break;
    end;
  if Assigned(Result) and (Rest <> '') then
    Result := Result.Find(Rest);
end;

function TMIValue.Get(const Path, Default: String): String;
var
  V: TMIValue;
begin
  V := Find(Path);
  if Assigned(V) and (V.Kind = mvConst) then
    Result := V.Text
  else
    Result := Default;
end;

function TMIValue.GetInt(const Path: String; Default: Int64): Int64;
begin
  Result := StrToInt64Def(Get(Path), Default);
end;

{ TMIRecord }

constructor TMIRecord.Create;
begin
  inherited;
  fToken := -1;
  fResults := TMIValue.Create(mvTuple);
end;

destructor TMIRecord.Destroy;
begin
  fResults.Free;
  inherited;
end;

{ Parsing }

type
  TMIParser = record
    S: String;
    P: Integer; // next character
    Ok: Boolean;
    function AtEnd: Boolean;
    function Peek: Char;
    function ReadCString: String;
    function ReadName: String;
    function ReadValue(const Name: String): TMIValue;
    procedure ReadResults(Into: TMIValue; Closing: Char);
  end;

function TMIParser.AtEnd: Boolean;
begin
  Result := P > Length(S);
end;

function TMIParser.Peek: Char;
begin
  if AtEnd then
    Result := #0
  else
    Result := S[P];
end;

// "..." with C escapes; P is on the opening quote
function TMIParser.ReadCString: String;
var
  C: Char;
  Code, Digits: Integer;
begin
  Result := '';
  if Peek <> '"' then begin
    Ok := False;
    Exit;
  end;
  Inc(P);
  while not AtEnd do begin
    C := S[P];
    Inc(P);
    if C = '"' then
      Exit;
    if C <> '\' then begin
      Result := Result + C;
      Continue;
    end;
    if AtEnd then
      Break;
    C := S[P];
    Inc(P);
    case C of
      'n': Result := Result + #10;
      't': Result := Result + #9;
      'r': Result := Result + #13;
      'a': Result := Result + #7;
      'b': Result := Result + #8;
      'f': Result := Result + #12;
      'v': Result := Result + #11;
      'e': Result := Result + #27;
      '0'..'7': begin // up to three octal digits: one byte (UTF-8 comes as bytes)
          Code := Ord(C) - Ord('0');
          Digits := 1;
          while (Digits < 3) and not AtEnd and (S[P] in ['0'..'7']) do begin
            Code := Code * 8 + Ord(S[P]) - Ord('0');
            Inc(P);
            Inc(Digits);
          end;
          Result := Result + Chr(Code and $FF);
        end;
    else
      Result := Result + C; // \" \\ \' and anything else: the character itself
    end;
  end;
  Ok := False; // no closing quote
end;

// A variable name: letters, digits, - and _
function TMIParser.ReadName: String;
var
  Start: Integer;
begin
  Start := P;
  while not AtEnd and (S[P] in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_']) do
    Inc(P);
  Result := Copy(S, Start, P - Start);
end;

function TMIParser.ReadValue(const Name: String): TMIValue;
var
  ItemName: String;
  Save: Integer;
begin
  case Peek of
    '"': begin
        Result := TMIValue.Create(mvConst, Name);
        Result.Text := ReadCString;
      end;
    '{': begin
        Inc(P);
        Result := TMIValue.Create(mvTuple, Name);
        ReadResults(Result, '}');
      end;
    '[': begin
        Inc(P);
        Result := TMIValue.Create(mvList, Name);
        if Peek = ']' then begin
          Inc(P);
          Exit;
        end;
        // a list of values [..] or of results [name=..]
        while Ok and not AtEnd do begin
          Save := P;
          ItemName := ReadName;
          if (ItemName <> '') and (Peek = '=') then
            Inc(P)
          else begin
            P := Save;
            ItemName := '';
          end;
          Result.Add(ReadValue(ItemName));
          if not Ok then
            Exit;
          case Peek of
            ',': Inc(P);
            ']': begin
                Inc(P);
                Exit;
              end;
          else
            Ok := False;
          end;
        end;
        Ok := False; // no closing ]
      end;
  else
    Ok := False;
    Result := TMIValue.Create(mvConst, Name);
  end;
end;

// name=value,name=value up to Closing (#0: the end of the line)
procedure TMIParser.ReadResults(Into: TMIValue; Closing: Char);
var
  Name: String;
begin
  if (Closing <> #0) and (Peek = Closing) then begin
    Inc(P);
    Exit;
  end;
  while Ok and not AtEnd do begin
    Name := ReadName;
    if (Name = '') or (Peek <> '=') then begin
      Ok := False;
      Exit;
    end;
    Inc(P);
    Into.Add(ReadValue(Name));
    if not Ok then
      Exit;
    if Peek = ',' then
      Inc(P)
    else if (Closing <> #0) and (Peek = Closing) then begin
      Inc(P);
      Exit;
    end else begin
      Ok := (Closing = #0) and AtEnd;
      Exit;
    end;
  end;
  if Closing <> #0 then
    Ok := False; // the line ended inside a tuple
end;

function ParseMILine(const Line: String): TMIRecord;
var
  Parser: TMIParser;
  L: String;
  Start: Integer;
begin
  Result := TMIRecord.Create;
  L := Line;
  if (L <> '') and (L[Length(L)] = #13) then
    SetLength(L, Length(L) - 1);
  Result.fText := L;
  Result.fKind := mrOther;

  if Trim(L) = '(gdb)' then begin
    Result.fKind := mrPrompt;
    Exit;
  end;

  Parser.S := L;
  Parser.P := 1;
  Parser.Ok := True;

  // optional token
  Start := Parser.P;
  while not Parser.AtEnd and (Parser.Peek in ['0'..'9']) do
    Inc(Parser.P);
  if Parser.P > Start then
    Result.fToken := StrToInt64Def(Copy(L, Start, Parser.P - Start), -1);

  case Parser.Peek of
    '^': Result.fKind := mrResult;
    '*': Result.fKind := mrExec;
    '+': Result.fKind := mrStatus;
    '=': Result.fKind := mrNotify;
    '~': Result.fKind := mrConsole;
    '@': Result.fKind := mrTarget;
    '&': Result.fKind := mrLog;
  else
    Result.fToken := -1;
    Exit; // mrOther
  end;
  Inc(Parser.P);

  if Result.fKind in [mrConsole, mrTarget, mrLog] then begin
    Result.fText := Parser.ReadCString;
    if not Parser.Ok then begin // not a C string after all
      Result.fKind := mrOther;
      Result.fText := L;
    end;
    Exit;
  end;

  // class, then ,results
  Result.fClass := Parser.ReadName;
  if Result.fClass = '' then begin
    Result.fKind := mrOther;
    Result.fToken := -1;
    Exit;
  end;
  if Parser.Peek = ',' then begin
    Inc(Parser.P);
    Parser.ReadResults(Result.fResults, #0);
  end;
  // A damaged line keeps the results read before the damage
end;

function MIQuote(const S: String): String;
var
  I: Integer;
begin
  Result := '"';
  for I := 1 to Length(S) do
    case S[I] of
      '"', '\': Result := Result + '\' + S[I];
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
      #9: Result := Result + '\t';
      #0..#8, #11, #12, #14..#31: Result := Result + '\' + OctStr(Ord(S[I]), 3);
    else
      Result := Result + S[I];
    end;
  Result := Result + '"';
end;

// Moves through S like gdb's value syntax: Depth counts the brackets of any
// kind, Quote is the open quote (#0 none). True when S[I] is at depth 0 and
// outside quotes.
function OutsideAt(const S: String; var I, Depth: Integer; var Quote: Char): Boolean;
var
  C: Char;
begin
  C := S[I];
  Result := False;
  if Quote <> #0 then begin
    if C = '\' then
      Inc(I) // the escaped character
    else if C = Quote then
      Quote := #0;
    Exit;
  end;
  case C of
    '"', #39: Quote := C;
    '{', '[', '(', '<': Inc(Depth);
    '}', ']', ')', '>':
      if Depth > 0 then
        Dec(Depth);
  else
    Result := Depth = 0;
  end;
end;

function SplitGdbValue(const Value: String; Members: TStrings): Boolean;
var
  S: String;
  I, Depth, Start: Integer;
  Quote: Char;
begin
  S := Trim(Value);
  Result := (Length(S) >= 2) and (S[1] = '{') and (S[Length(S)] = '}');
  if not Result then
    Exit;
  S := Copy(S, 2, Length(S) - 2);
  if Trim(S) = '' then
    Exit(False); // {}: no members
  Depth := 0;
  Quote := #0;
  Start := 1;
  I := 1;
  while I <= Length(S) do begin
    if OutsideAt(S, I, Depth, Quote) and (S[I] = ',') then begin
      if Assigned(Members) then
        Members.Add(Trim(Copy(S, Start, I - Start)));
      Start := I + 1;
    end;
    Inc(I);
  end;
  if Assigned(Members) then
    Members.Add(Trim(Copy(S, Start, MaxInt)));
end;

procedure SplitGdbMember(const Member: String; out Name, Value: String);
var
  I, Depth: Integer;
  Quote: Char;
begin
  Depth := 0;
  Quote := #0;
  I := 1;
  while I <= Length(Member) - 2 do begin
    if OutsideAt(Member, I, Depth, Quote) and (Member[I] = ' ') and (Copy(Member, I, 3) = ' = ') then begin
      Name := Copy(Member, 1, I - 1);
      Value := Copy(Member, I + 3, MaxInt);
      Exit;
    end;
    Inc(I);
  end;
  Name := '';
  Value := Member;
end;

end.
