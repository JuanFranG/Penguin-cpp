{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    C++ highlighting with code folding. Lazarus' C++ highlighter (TSynCppSyn)
    has no folding, and folding in Lazarus' SynEdit comes from the
    highlighter. This one keeps TSynCppSyn as it is for the tokens and adds
    what Dev-C++ folded: blocks between braces, and //#region ... //#endregion.
}

unit SynHighlighterCppFold;

{$MODE DELPHI}

interface

uses
  Classes, SysUtils, Graphics, SynEditTypes, SynEditHighlighter, SynEditHighlighterFoldBase,
  SynHighlighterCpp;

type
  TCppFoldBlockType = (
    cfbtCppBrace, // { ... }
    cfbtCppRegion, // //#region ... //#endregion
    cfbtCppNone // the root, not a fold
  );

  TSynCppFoldSyn = class(TSynCustomFoldHighlighter)
  private
    FTokens: TSynCppSyn; // does the tokenizing
    FAsmAttri, FCommentAttri, FDirecAttri, FIdentifierAttri, FInvalidAttri, FKeyAttri, FNumberAttri,
      FSpaceAttri, FStringAttri, FSymbolAttri: TSynHighlighterAttributes;
    function OwnAttribute(TokenAttri: TSynHighlighterAttributes): TSynHighlighterAttributes;
    procedure CheckFold;
  protected
    function GetIdentChars: TSynIdentChars; override;
    function GetFoldConfigCount: Integer; override;
    function GetFoldConfigInternalCount: Integer; override;
    function GetFoldConfigInstance(Index: Integer): TSynCustomFoldConfig; override;
    procedure CreateRootCodeFoldBlock; override;
  public
    class function GetLanguageName: string; override;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetDefaultAttribute(Index: integer): TSynHighlighterAttributes; override;
    function GetEol: Boolean; override;
    function GetRange: Pointer; override;
    procedure SetRange(Value: Pointer); override;
    procedure ResetRange; override;
    procedure SetLine(const NewValue: String; LineNumber: Integer); override;
    procedure Next; override;
    function GetToken: String; override;
    procedure GetTokenEx(out TokenStart: PChar; out TokenLength: integer); override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: integer; override;
    function GetTokenPos: Integer; override;
  published
    // The same attributes as TSynCppSyn, so settings and forms keep working
    property AsmAttri: TSynHighlighterAttributes read FAsmAttri write FAsmAttri;
    property CommentAttri: TSynHighlighterAttributes read FCommentAttri write FCommentAttri;
    property DirecAttri: TSynHighlighterAttributes read FDirecAttri write FDirecAttri;
    property IdentifierAttri: TSynHighlighterAttributes read FIdentifierAttri write FIdentifierAttri;
    property InvalidAttri: TSynHighlighterAttributes read FInvalidAttri write FInvalidAttri;
    property KeyAttri: TSynHighlighterAttributes read FKeyAttri write FKeyAttri;
    property NumberAttri: TSynHighlighterAttributes read FNumberAttri write FNumberAttri;
    property SpaceAttri: TSynHighlighterAttributes read FSpaceAttri write FSpaceAttri;
    property StringAttri: TSynHighlighterAttributes read FStringAttri write FStringAttri;
    property SymbolAttri: TSynHighlighterAttributes read FSymbolAttri write FSymbolAttri;
  end;

implementation

uses
  SynEditStrConst;

constructor TSynCppFoldSyn.Create(AOwner: TComponent);

  function CopyAttri(Source: TSynHighlighterAttributes): TSynHighlighterAttributes;
  begin
    Result := TSynHighlighterAttributes.Create(Source.Name, Source.StoredName);
    Result.Assign(Source);
    AddAttribute(Result);
  end;

begin
  FTokens := TSynCppSyn.Create(nil);
  inherited Create(AOwner);
  // Own attributes with the same names and defaults; the tokenizer's ones are
  // only used to know which kind of token it found
  FAsmAttri := CopyAttri(FTokens.AsmAttri);
  FCommentAttri := CopyAttri(FTokens.CommentAttri);
  FDirecAttri := CopyAttri(FTokens.DirecAttri);
  FIdentifierAttri := CopyAttri(FTokens.IdentifierAttri);
  FInvalidAttri := CopyAttri(FTokens.InvalidAttri);
  FKeyAttri := CopyAttri(FTokens.KeyAttri);
  FNumberAttri := CopyAttri(FTokens.NumberAttri);
  FSpaceAttri := CopyAttri(FTokens.SpaceAttri);
  FStringAttri := CopyAttri(FTokens.StringAttri);
  FSymbolAttri := CopyAttri(FTokens.SymbolAttri);
  SetAttributesOnChange(DefHighlightChange);
  fDefaultFilter := FTokens.DefaultFilter;
end;

destructor TSynCppFoldSyn.Destroy;
begin
  inherited Destroy;
  FTokens.Free;
end;

class function TSynCppFoldSyn.GetLanguageName: string;
begin
  Result := TSynCppSyn.GetLanguageName;
end;

function TSynCppFoldSyn.OwnAttribute(TokenAttri: TSynHighlighterAttributes): TSynHighlighterAttributes;
begin
  if TokenAttri = FTokens.AsmAttri then Result := FAsmAttri
  else if TokenAttri = FTokens.CommentAttri then Result := FCommentAttri
  else if TokenAttri = FTokens.DirecAttri then Result := FDirecAttri
  else if TokenAttri = FTokens.IdentifierAttri then Result := FIdentifierAttri
  else if TokenAttri = FTokens.InvalidAttri then Result := FInvalidAttri
  else if TokenAttri = FTokens.KeyAttri then Result := FKeyAttri
  else if TokenAttri = FTokens.NumberAttri then Result := FNumberAttri
  else if TokenAttri = FTokens.SpaceAttri then Result := FSpaceAttri
  else if TokenAttri = FTokens.StringAttri then Result := FStringAttri
  else if TokenAttri = FTokens.SymbolAttri then Result := FSymbolAttri
  else Result := nil;
end;

function TSynCppFoldSyn.GetIdentChars: TSynIdentChars;
begin
  Result := FTokens.IdentChars;
end;

function TSynCppFoldSyn.GetDefaultAttribute(Index: integer): TSynHighlighterAttributes;
begin
  Result := OwnAttribute(FTokens.GetDefaultAttribute(Index));
end;

{ Folds }

function TSynCppFoldSyn.GetFoldConfigCount: Integer;
begin
  Result := Ord(cfbtCppNone); // cfbtCppNone is not configurable
end;

function TSynCppFoldSyn.GetFoldConfigInternalCount: Integer;
begin
  Result := Ord(cfbtCppNone) + 1;
end;

function TSynCppFoldSyn.GetFoldConfigInstance(Index: Integer): TSynCustomFoldConfig;
begin
  Result := inherited GetFoldConfigInstance(Index);
  Result.Enabled := TCppFoldBlockType(Index) in [cfbtCppBrace, cfbtCppRegion];
end;

procedure TSynCppFoldSyn.CreateRootCodeFoldBlock;
begin
  inherited CreateRootCodeFoldBlock;
  RootCodeFoldBlock.InitRootBlockType(Pointer(PtrInt(cfbtCppNone)));
end;

// Opens or closes a fold at the current token. Braces inside strings and
// comments are not symbols, so they don't count.
procedure TSynCppFoldSyn.CheckFold;
var
  Text: String;
  Top: TCppFoldBlockType;
begin
  if FTokens.GetEol then
    Exit;
  Top := TCppFoldBlockType(PtrUInt(TopCodeFoldBlockType));
  case FTokens.GetTokenID of
    SynHighlighterCpp.tkSymbol:
      case FTokens.ExtTokenID of
        xtkBraceOpen:
          StartCodeFoldBlock(Pointer(PtrInt(cfbtCppBrace)));
        xtkBraceClose:
          if Top = cfbtCppBrace then // a stray } closes nothing
            EndCodeFoldBlock;
      end;
    SynHighlighterCpp.tkComment: begin
        Text := LowerCase(Trim(FTokens.GetToken));
        if Copy(Text, 1, 9) = '//#region' then
          StartCodeFoldBlock(Pointer(PtrInt(cfbtCppRegion)))
        else if (Copy(Text, 1, 12) = '//#endregion') and (Top = cfbtCppRegion) then
          EndCodeFoldBlock;
      end;
  end;
end;

{ Ranges: the fold stack, with the tokenizer's state (inside a comment,
  string or directive) stored in it }

function TSynCppFoldSyn.GetRange: Pointer;
begin
  CodeFoldRange.RangeType := FTokens.GetRange;
  Result := inherited GetRange;
end;

procedure TSynCppFoldSyn.SetRange(Value: Pointer);
begin
  inherited SetRange(Value);
  FTokens.SetRange(CodeFoldRange.RangeType);
end;

procedure TSynCppFoldSyn.ResetRange;
begin
  inherited ResetRange;
  FTokens.ResetRange;
end;

{ Tokens }

procedure TSynCppFoldSyn.SetLine(const NewValue: String; LineNumber: Integer);
begin
  inherited SetLine(NewValue, LineNumber);
  FTokens.SetLine(NewValue, LineNumber);
  CheckFold;
end;

procedure TSynCppFoldSyn.Next;
begin
  FTokens.Next;
  CheckFold;
end;

function TSynCppFoldSyn.GetEol: Boolean;
begin
  Result := FTokens.GetEol;
end;

function TSynCppFoldSyn.GetToken: String;
begin
  Result := FTokens.GetToken;
end;

procedure TSynCppFoldSyn.GetTokenEx(out TokenStart: PChar; out TokenLength: integer);
begin
  FTokens.GetTokenEx(TokenStart, TokenLength);
end;

function TSynCppFoldSyn.GetTokenAttribute: TSynHighlighterAttributes;
begin
  Result := OwnAttribute(FTokens.GetTokenAttribute);
end;

function TSynCppFoldSyn.GetTokenKind: integer;
begin
  Result := FTokens.GetTokenKind;
end;

function TSynCppFoldSyn.GetTokenPos: Integer;
begin
  Result := FTokens.GetTokenPos;
end;

end.
