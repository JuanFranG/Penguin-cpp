{
    SPDX-License-Identifier: GPL-2.0-or-later
    Copyright (c) 2026 Juan Francisco Gonzalez - Penguin cpp

    This file is part of Penguin cpp, a port of Embarcadero Dev-C++.

    The editor's built-in color schemes. Delphi compiled them from the
    STRINGTABLE of DefaultFiles.rc and read them with LoadStr, which has no
    string resources to read under Free Pascal on Linux, so every color came
    out empty (black). Generated from DefaultFiles.rc; same IDs and values.
}

unit ColorSchemes;

{$MODE DELPHI}

interface

// Color string for ID = scheme index * 1000 + element (see the element list
// at the top of DefaultFiles.rc): "foreground, background[, bold, italic,
// underline]". Returns '' for an unknown ID, as LoadStr did.
function ColorSchemeString(ID: Integer): String;

// Element number (1-14, as in that list) of a C++ highlighter attribute, from
// its stored name; 0 if the scheme has no such element. Delphi's highlighter
// had exactly those 14 attributes, so Dev-C++ used the position in the
// attribute list as the element number. Lazarus' has 10 (no Character, Float,
// Hexadecimal or Octal), and by position every color landed one or more
// elements off: "Space", the background, got the colors of "Number".
function SchemeElement(const StoredName: String): Integer;

// Colors of an attribute in a built-in scheme (0 = Classic), or ''
function SchemeAttrString(Scheme: Integer; const StoredName: String): String;

implementation

uses
  SysUtils;

type
  TSchemeEntry = record
    ID: Integer;
    Value: String;
  end;

const
  Entries: array[0..307] of TSchemeEntry = (
    // Classic
    (ID: 1; Value: 'clBlue, clNone, 0, 0, 0'),
    (ID: 2; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 3; Value: 'clHighlight, clNone, 0, 1, 0'),
    (ID: 4; Value: 'clPurple, clNone, 0, 0, 0'),
    (ID: 5; Value: 'clPurple, clNone, 0, 0, 0'),
    (ID: 6; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 7; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 8; Value: 'clPurple, clNone, 0, 0, 0'),
    (ID: 9; Value: 'clPurple, clNone, 0, 0, 0'),
    (ID: 10; Value: 'clGreen, clNone, 0, 0, 0'),
    (ID: 11; Value: 'clBlack, clNone, 1, 0, 0'),
    (ID: 12; Value: 'clBlack, clWhite, 0, 0, 0'),
    (ID: 13; Value: 'clRed, clNone, 0, 0, 0'),
    (ID: 14; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 15; Value: 'clHighlight, clWhite, 0, 0, 0'),
    (ID: 16; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 17; Value: 'clWhite, clRed'),
    (ID: 18; Value: 'clWhite, clMaroon'),
    (ID: 19; Value: 'clWhite, clBlue'),
    (ID: 20; Value: 'clBlack, clBtnFace'),
    (ID: 21; Value: 'clWhite, clNavy'),
    (ID: 22; Value: 'clBlack, clBtnFace'),
    // Classic Plus
    (ID: 1001; Value: 'clBlue, clNone, 0, 0, 0'),
    (ID: 1002; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 1003; Value: 'clHighlight, clNone, 0, 1, 0'),
    (ID: 1004; Value: 'clPurple, clNone, 0, 0, 0'),
    (ID: 1005; Value: 'clPurple, clNone, 0, 0, 0'),
    (ID: 1006; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 1007; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 1008; Value: 'clPurple, clNone, 0, 0, 0'),
    (ID: 1009; Value: 'clPurple, clNone, 0, 0, 0'),
    (ID: 1010; Value: 'clGreen, clNone, 0, 0, 0'),
    (ID: 1011; Value: 'clBlack, clNone, 1, 0, 0'),
    (ID: 1012; Value: 'clBlack, clWhite, 0, 0, 0'),
    (ID: 1013; Value: 'clBlue, clNone, 1, 0, 0'),
    (ID: 1014; Value: 'clRed, clNone, 1, 0, 0'),
    (ID: 1015; Value: 'clHighlight, clWhite, 0, 0, 0'),
    (ID: 1016; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 1017; Value: 'clWhite, clRed'),
    (ID: 1018; Value: 'clWhite, clMaroon'),
    (ID: 1019; Value: 'clWhite, clBlue'),
    (ID: 1020; Value: 'clBlack, clBtnFace'),
    (ID: 1021; Value: 'clWhite, clNavy'),
    (ID: 1022; Value: 'clBlack, clBtnFace'),
    // Twilight
    (ID: 2001; Value: 'clLime, clNone, 0, 0, 0'),
    (ID: 2002; Value: 'clYellow, clNone, 0, 0, 0'),
    (ID: 2003; Value: 'clSilver, clNone, 0, 1, 0'),
    (ID: 2004; Value: 'clFuchsia, clNone, 0, 0, 0'),
    (ID: 2005; Value: 'clFuchsia, clNone, 0, 0, 0'),
    (ID: 2006; Value: 'clWhite, clNone, 0, 0, 0'),
    (ID: 2007; Value: 'clYellow, clMaroon, 0, 0, 0'),
    (ID: 2008; Value: 'clFuchsia, clNone, 0, 0, 0'),
    (ID: 2009; Value: 'clFuchsia, clNone, 0, 0, 0'),
    (ID: 2010; Value: 'clGreen, clNone, 0, 0, 0'),
    (ID: 2011; Value: 'clAqua, clNone, 0, 0, 0'),
    (ID: 2012; Value: 'clWhite, clBlack, 0, 0, 0'),
    (ID: 2013; Value: 'clYellow, clNone, 0, 0, 0'),
    (ID: 2014; Value: 'clAqua, clNone, 0, 0, 0'),
    (ID: 2015; Value: 'clWhite, clRed, 0, 0, 0'),
    (ID: 2016; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 2017; Value: 'clWhite, clRed'),
    (ID: 2018; Value: 'clWhite, clMaroon'),
    (ID: 2019; Value: 'clWhite, clBlue'),
    (ID: 2020; Value: 'clWhite, clBlack'),
    (ID: 2021; Value: 'clWhite, clNavy'),
    (ID: 2022; Value: 'clWhite, clBtnFace'),
    // Ocean
    (ID: 3001; Value: 'clBlue, clNone, 0, 0, 0'),
    (ID: 3002; Value: 'clPurple, clNone, 0, 0, 0'),
    (ID: 3003; Value: 'clTeal, clNone, 0, 1, 0'),
    (ID: 3004; Value: 'clOlive, clNone, 0, 0, 0'),
    (ID: 3005; Value: 'clOlive, clNone, 0, 0, 0'),
    (ID: 3006; Value: 'clBlue, clNone, 0, 0, 0'),
    (ID: 3007; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 3008; Value: 'clOlive, clNone, 0, 0, 0'),
    (ID: 3009; Value: 'clOlive, clNone, 0, 0, 0'),
    (ID: 3010; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 3011; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 3012; Value: 'clBlue, clAqua, 0, 0, 0'),
    (ID: 3013; Value: 'clPurple, clNone, 0, 0, 0'),
    (ID: 3014; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 3015; Value: 'clWhite, clRed, 0, 0, 0'),
    (ID: 3016; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 3017; Value: 'clWhite, clRed'),
    (ID: 3018; Value: 'clWhite, clMaroon'),
    (ID: 3019; Value: 'clWhite, clBlue'),
    (ID: 3020; Value: 'clBlue, clAqua'),
    (ID: 3021; Value: 'clWhite, clNavy'),
    (ID: 3022; Value: 'clBlue, clBtnFace'),
    // Visual Studio
    (ID: 4001; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 4002; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 4003; Value: 'clGreen, clNone, 0, 0, 0'),
    (ID: 4004; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 4005; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 4006; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 4007; Value: 'clRed, clNone, 0, 0, 0'),
    (ID: 4008; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 4009; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 4010; Value: 'clBlue, clNone, 0, 0, 0'),
    (ID: 4011; Value: 'clBlue, clNone, 0, 0, 0'),
    (ID: 4012; Value: 'clNone, clWhite, 0, 0, 0'),
    (ID: 4013; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 4014; Value: 'clBlack, clNone, 0, 0, 0'),
    (ID: 4015; Value: 'clGreen, clNone, 0, 0, 0'),
    (ID: 4016; Value: 'clRed, clNone, 0, 0, 0'),
    (ID: 4017; Value: 'clWhite, clRed'),
    (ID: 4018; Value: 'clRed, clNone'),
    (ID: 4019; Value: 'clWhite, clBlue'),
    (ID: 4020; Value: 'clNone, clWhite'),
    (ID: 4021; Value: 'clWhite, clNavy'),
    (ID: 4022; Value: 'clNone, clBtnFace'),
    // Borland
    (ID: 5001; Value: 'clLime, clNone, 0, 0, 0'),
    (ID: 5002; Value: 'clYellow, clNone, 0, 0, 0'),
    (ID: 5003; Value: 'clSilver, clNone, 0, 0, 0'),
    (ID: 5004; Value: 'clYellow, clNone, 0, 0, 0'),
    (ID: 5005; Value: 'clYellow, clNone, 0, 0, 0'),
    (ID: 5006; Value: 'clYellow, clNone, 0, 0, 0'),
    (ID: 5007; Value: 'clYellow, clNone, 0, 0, 0'),
    (ID: 5008; Value: 'clYellow, clNone, 0, 0, 0'),
    (ID: 5009; Value: 'clYellow, clNone, 0, 0, 0'),
    (ID: 5010; Value: 'clYellow, clNone, 0, 0, 0'),
    (ID: 5011; Value: 'clWhite, clNone, 0, 0, 0'),
    (ID: 5012; Value: 'clYellow, clNavy, 0, 0, 0'),
    (ID: 5013; Value: 'clYellow, clNone, 0, 0, 0'),
    (ID: 5014; Value: 'clYellow, clNone, 0, 0, 0'),
    (ID: 5015; Value: 'clWhite, clRed, 0, 0, 0'),
    (ID: 5016; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 5017; Value: 'clWhite, clRed'),
    (ID: 5018; Value: 'clWhite, clMaroon'),
    (ID: 5019; Value: 'clBlack, clAqua'),
    (ID: 5020; Value: 'clYellow, clNavy'),
    (ID: 5021; Value: 'clBlack, clSilver'),
    (ID: 5022; Value: 'clYellow, clBtnFace'),
    // Matrix
    (ID: 6001; Value: 'clLime, clNone, 0, 0, 0'),
    (ID: 6002; Value: '$00FF6633, clNone, 0, 0, 0'),
    (ID: 6003; Value: '$00FF6633, clNone, 0, 1, 0'),
    (ID: 6004; Value: 'clFuchsia, clNone, 0, 0, 0'),
    (ID: 6005; Value: 'clFuchsia, clNone, 0, 0, 0'),
    (ID: 6006; Value: 'clLime, clNone, 0, 0, 0'),
    (ID: 6007; Value: 'clRed, clMaroon, 0, 0, 0'),
    (ID: 6008; Value: 'clBlue, clNone, 0, 0, 0'),
    (ID: 6009; Value: 'clFuchsia, clNone, 0, 0, 0'),
    (ID: 6010; Value: '$00CCCC33, clNone, 0, 0, 0'),
    (ID: 6011; Value: 'clGreen, clNone, 0, 0, 0'),
    (ID: 6012; Value: 'clWhite, clBlack, 0, 0, 0'),
    (ID: 6013; Value: '$00C3C3C3, clNone, 0, 0, 0'),
    (ID: 6014; Value: 'clRed, clNone, 0, 0, 0'),
    (ID: 6015; Value: 'clHighlight, clWhite, 0, 0, 0'),
    (ID: 6016; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 6017; Value: 'clWhite, 8421504'),
    (ID: 6018; Value: 'clWhite, 255'),
    (ID: 6019; Value: 'clWhite, 16711680'),
    (ID: 6020; Value: 'clLime, clBlack'),
    (ID: 6021; Value: 'clWhite, clNavy'),
    (ID: 6022; Value: 'clRed, clBtnFace'),
    // Obisidian
    (ID: 7001; Value: '$0063c793, clNone, 0, 0, 0'),
    (ID: 7002; Value: '$000984ff, clNone, 0, 0, 0'),
    (ID: 7003; Value: '$007b7466, clNone, 0, 1, 0'),
    (ID: 7004; Value: '$0022cdff, clNone, 0, 0, 0'),
    (ID: 7005; Value: '$0022cdff, clNone, 0, 0, 0'),
    (ID: 7006; Value: '$00e4e2e0, clNone, 0, 0, 0'),
    (ID: 7007; Value: '$000000fb, clNone, 0, 0, 0'),
    (ID: 7008; Value: '$0022cdff, clNone, 0, 0, 0'),
    (ID: 7009; Value: '$0022cdff, clNone, 0, 0, 0'),
    (ID: 7010; Value: '$00bd82a0, clNone, 0, 0, 0'),
    (ID: 7011; Value: '$00b18c67, clNone, 0, 0, 0'),
    (ID: 7012; Value: 'clNone, $02343129, 0, 0, 0'),
    (ID: 7013; Value: '$000076ec, clNone, 0, 0, 0'),
    (ID: 7014; Value: '$00b7e2e8, clNone, 0, 0, 0'),
    (ID: 7015; Value: 'clHighlight, clWhite, 0, 0, 0'),
    (ID: 7016; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 7017; Value: '16777215, $0000cc99'),
    (ID: 7018; Value: '16777215, $001212d5'),
    (ID: 7019; Value: '16777215, $00ffcc00'),
    (ID: 7020; Value: '$0088806a, $003c382f'),
    (ID: 7021; Value: '16777215, $00514e40'),
    (ID: 7022; Value: '$000000c0, $00514e40'),
    // GSS Hacker
    (ID: 8001; Value: '$00ff9c00, $00171717, 0, 0, 0'),
    (ID: 8002; Value: '$00fb32c7, $00171717, 0, 0, 0'),
    (ID: 8003; Value: '$00577a57, $00171717, 0, 0, 0'),
    (ID: 8004; Value: '$00c9deee, $00171717, 0, 0, 0'),
    (ID: 8005; Value: '$00c9deee, $00171717, 0, 0, 0'),
    (ID: 8006; Value: '$00FFFFFF, $00171717, 0, 0, 0'),
    (ID: 8007; Value: '$00FFFFFF, $00096105, 0, 0, 0'),
    (ID: 8008; Value: '$00c9deee, $00171717, 0, 0, 0'),
    (ID: 8009; Value: '$00c9deee, $00171717, 0, 0, 0'),
    (ID: 8010; Value: '$00ff9c00, $00171717, 0, 0, 0'),
    (ID: 8011; Value: '$0080ffaf, $00171717, 0, 0, 0'),
    (ID: 8012; Value: '$00FFFFFF, $00171717, 0, 0, 0'),
    (ID: 8013; Value: '$00ca6716, $00171717, 0, 0, 0'),
    (ID: 8014; Value: '$00FFFFFF, $00171717, 0, 0, 0'),
    (ID: 8015; Value: 'clHighlight, clWhite, 0, 0, 0'),
    (ID: 8016; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 8017; Value: '$00000000, $0000ad41'),
    (ID: 8018; Value: '$00ffffff, $002620c2'),
    (ID: 8019; Value: '$00FFFFFF, $00998e00'),
    (ID: 8020; Value: '$0002ed06, $00000000'),
    (ID: 8021; Value: '$00FFFFFF, $001c5f4e'),
    (ID: 8022; Value: '$00a5a5a5, $00171717'),
    // Obvilion
    (ID: 9001; Value: '$00FFAB79, $001E1E1E, 0, 0, 0'),
    (ID: 9002; Value: '$005252D2, clNone, 0, 0, 0'),
    (ID: 9003; Value: '$000CDDC7, $001E1E1E, 0, 0, 0'),
    (ID: 9004; Value: '$0047B37F, $001E1E1E, 0, 0, 0'),
    (ID: 9005; Value: '$0047B37F, $001E1E1E, 0, 0, 0'),
    (ID: 9006; Value: '$00FFD6BE, clNone, 0, 0, 0'),
    (ID: 9007; Value: '$000000FB, clNone, 0, 0, 0'),
    (ID: 9008; Value: '$0047B37F, $001E1E1E, 0, 0, 0'),
    (ID: 9009; Value: '$0047B37F, $001E1E1E, 0, 0, 0'),
    (ID: 9010; Value: '$00FFAB79, $001E1E1E, 0, 0, 0'),
    (ID: 9011; Value: 'clWhite, $001E1E1E, 0, 0, 0'),
    (ID: 9012; Value: '$00D8D8D8, $001E1E1E, 0, 0, 0'),
    (ID: 9013; Value: '$0000C6FF, $001E1E1E, 0, 0, 0'),
    (ID: 9014; Value: '$0077E5D9, $001E1E1E, 0, 0, 0'),
    (ID: 9015; Value: 'clHighlight, clWhite, 0, 0, 0'),
    (ID: 9016; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 9017; Value: '16777215, 32896'),
    (ID: 9018; Value: '16777215, 5581567'),
    (ID: 9019; Value: '16777215, 13421619'),
    (ID: 9020; Value: '13684944, 1973790'),
    (ID: 9021; Value: '13684944, 0'),
    (ID: 9022; Value: '39423, 5328448'),
    // PlasticCodeWrap
    (ID: 10001; Value: 'clFuchsia, $021D160B, 0, 0, 0'),
    (ID: 10002; Value: '$0039E455, $001D160B, 0, 0, 0'),
    (ID: 10003; Value: '$00E09A1E, $001D160B, 0, 1, 0'),
    (ID: 10004; Value: '$00833AFF, $021D160B, 0, 0, 0'),
    (ID: 10005; Value: '$00833AFF, $021D160B, 0, 0, 0'),
    (ID: 10006; Value: 'clWhite, $021D160B, 0, 0, 0'),
    (ID: 10007; Value: '$000000FB, $021D160B, 0, 0, 0'),
    (ID: 10008; Value: '$00833AFF, $021D160B, 0, 0, 0'),
    (ID: 10009; Value: '$00833AFF, $021D160B, 0, 0, 0'),
    (ID: 10010; Value: '$0000AAFF, $021D160B, 0, 0, 0'),
    (ID: 10011; Value: '$0080F0F6, $021D160B, 0, 0, 0'),
    (ID: 10012; Value: '$1F1D160B, $021D160B, 0, 0, 0'),
    (ID: 10013; Value: '$0039E455, $021D160B, 0, 0, 0'),
    (ID: 10014; Value: '$0000AAFF, $021D160B, 0, 0, 0'),
    (ID: 10015; Value: 'clHighlight, clWhite, 0, 0, 0'),
    (ID: 10016; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 10017; Value: '16777215, 52377'),
    (ID: 10018; Value: '16777215, 1184469'),
    (ID: 10019; Value: '16777215, 16763904'),
    (ID: 10020; Value: '16777215, 3552302'),
    (ID: 10021; Value: '16776960, 1906187'),
    (ID: 10022; Value: '192, 5328448'),
    // Monokai
    (ID: 11001; Value: '$0099FFFF, clNone, 0, 0, 0'),
    (ID: 11002; Value: '$0099FFFF, clNone, 0, 0, 0'),
    (ID: 11003; Value: '$00787878, clNone, 0, 1, 0'),
    (ID: 11004; Value: '$0099FFFF, clNone, 0, 0, 0'),
    (ID: 11005; Value: '$0099FFFF, clNone, 0, 0, 0'),
    (ID: 11006; Value: 'clWhite, clNone, 0, 0, 0'),
    (ID: 11007; Value: 'clAqua, clNone, 0, 0, 0'),
    (ID: 11008; Value: '$00FF55AA, clNone, 0, 0, 0'),
    (ID: 11009; Value: '$0099FFFF, clNone, 0, 0, 0'),
    (ID: 11010; Value: '$007F2AFF, clNone, 0, 0, 0'),
    (ID: 11011; Value: '$00FFD455, clNone, 0, 0, 0'),
    (ID: 11012; Value: 'clWindowText, $001E1E1E, 0, 0, 0'),
    (ID: 11013; Value: '$0099FFFF, clNone, 0, 0, 0'),
    (ID: 11014; Value: '$007F2AFF, clNone, 0, 0, 0'),
    (ID: 11015; Value: 'clHighlight, clWhite, 0, 0, 0'),
    (ID: 11016; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 11017; Value: '16777215, 13209'),
    (ID: 11018; Value: '1973790, 5581567'),
    (ID: 11019; Value: '16777215, 10040115'),
    (ID: 11020; Value: '7895160, 1973790'),
    (ID: 11021; Value: '16777215, 5921370'),
    (ID: 11022; Value: '39423, 5328448'),
    // Monokai-Fresh
    (ID: 12001; Value: '$0099FFFF, clNone, 0, 0, 0'),
    (ID: 12002; Value: '$0066FFFF, clNone, 0, 0, 0'),
    (ID: 12003; Value: '$00797A62, clNone, 0, 1, 0'),
    (ID: 12004; Value: '$00FF82F0, clNone, 0, 0, 0'),
    (ID: 12005; Value: '$00FF82F0, clNone, 0, 0, 0'),
    (ID: 12006; Value: 'clWhite, clNone, 0, 0, 0'),
    (ID: 12007; Value: 'clAqua, clNone, 0, 0, 0'),
    (ID: 12008; Value: '$00FF82F0, clNone, 0, 0, 0'),
    (ID: 12009; Value: '$00FF82F0, clNone, 0, 0, 0'),
    (ID: 12010; Value: '$005E00FF, clNone, 0, 0, 0'),
    (ID: 12011; Value: '$00FFFF41, clNone, 0, 0, 0'),
    (ID: 12012; Value: 'clWindowText, $00151515, 0, 0, 0'),
    (ID: 12013; Value: '$0066FFFF, clNone, 0, 0, 0'),
    (ID: 12014; Value: '$005E00FF, clNone, 0, 0, 0'),
    (ID: 12015; Value: '$005E00FF, clNone, 0, 0, 0'),
    (ID: 12016; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 12017; Value: '16777215, 6160639'),
    (ID: 12018; Value: '16777215, 6160639'),
    (ID: 12019; Value: '16777215, 10040115'),
    (ID: 12020; Value: '7895160, 1973790'),
    (ID: 12021; Value: '4473924, 15658734'),
    (ID: 12022; Value: '39423, 5328448'),
    // Visual Studio Dark
    (ID: 13001; Value: '$0063C793, clNone, 0, 0, 0'),
    (ID: 13002; Value: '$00007AD5, $001E1E1E, 0, 0, 0'),
    (ID: 13003; Value: '$003E8B60, $001E1E1E, 0, 1, 0'),
    (ID: 13004; Value: '$0022CDFF, $001E1E1E, 0, 0, 0'),
    (ID: 13005; Value: '$0022CDFF, clNone, 0, 0, 0'),
    (ID: 13006; Value: '$00E6D8AD, $001E1E1E, 0, 0, 0'),
    (ID: 13007; Value: '$002930FF, $001E1E1E, 0, 0, 0'),
    (ID: 13008; Value: '$00A8CE9C, $021E1E1E, 0, 0, 0'),
    (ID: 13009; Value: '$0022CDFF, clNone, 0, 0, 0'),
    (ID: 13010; Value: '$009B9B9B, $021E1E1E, 0, 0, 0'),
    (ID: 13011; Value: '$00D68E3D, $001E1E1E, 0, 1, 0'),
    (ID: 13012; Value: 'clNone, $001E1E1E, 0, 0, 0'),
    (ID: 13013; Value: '$00859DD6, $021E1E1E, 0, 0, 0'),
    (ID: 13014; Value: '$00B7E2E8, clNone, 0, 0, 0'),
    (ID: 13015; Value: 'clHighlight, clWhite, 0, 0, 0'),
    (ID: 13016; Value: 'clWhite, clMaroon, 0, 0, 0'),
    (ID: 13017; Value: '16777215, 42107'),
    (ID: 13018; Value: '16777215, 2894966'),
    (ID: 13019; Value: '16777215, 11570432'),
    (ID: 13020; Value: '11505963, 1973790'),
    (ID: 13021; Value: '16777215, 7884582'),
    (ID: 13022; Value: '10197915, 5328448')
  );

function ColorSchemeString(ID: Integer): String;
var
  I: Integer;
begin
  for I := Low(Entries) to High(Entries) do
    if Entries[I].ID = ID then
      Exit(Entries[I].Value);
  Result := '';
end;

const
  ElementNames: array[1..14] of String = (
    'Assembler', 'Character', 'Comment', 'Float', 'Hexadecimal', 'Identifier',
    'Illegal char', 'Number', 'Octal', 'Preprocessor', 'Reserved word', 'Space',
    'String', 'Symbol');

function SchemeElement(const StoredName: String): Integer;
var
  I: Integer;
begin
  for I := Low(ElementNames) to High(ElementNames) do
    if CompareText(ElementNames[I], StoredName) = 0 then
      Exit(I);
  Result := 0;
end;

function SchemeAttrString(Scheme: Integer; const StoredName: String): String;
var
  Element: Integer;
begin
  Element := SchemeElement(StoredName);
  if Element = 0 then
    Result := ''
  else
    Result := ColorSchemeString(Scheme * 1000 + Element);
end;

end.
