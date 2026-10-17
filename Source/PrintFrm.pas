{
    This file is part of Dev-C++
    Copyright (c) 2004 Bloodshed Software

    Dev-C++ is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Dev-C++ is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Dev-C++; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

unit PrintFrm;

interface

uses
  LCLIntf, LCLType, LMessages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls,
  Buttons, ExtCtrls, MultiLangSupport, Spin, DataFrm;

type
  TPrintForm = class(TForm)
    btnCancel: TBitBtn;
    btnOk: TBitBtn;
    grpParams: TGroupBox;
    cbColors: TCheckBox;
    cbHighlight: TCheckBox;
    rbLN: TRadioButton;
    rbLNMargin: TRadioButton;
    cbWordWrap: TCheckBox;
    grpPages: TGroupBox;
    lblCopies: TLabel;
    seCopies: TSpinEdit;
    cbSelection: TCheckBox;
    rbNoLN: TRadioButton;
    pnlPrinter: TPanel;
    lblPrinter: TLabel;
    cboPrinter: TComboBox;
    pnlButtons: TPanel;
    procedure FormCreate(Sender: TObject);
  private
    procedure LoadPrinters;
  public
    procedure LoadText;
    function SaveAsPDF: Boolean; // the last entry of the printer list
    function PrinterName: String;
  end;

implementation

uses
  devCFG, PdfPrint;

{$R *.lfm}

procedure TPrintForm.LoadText;
begin
	// Set interface font
	Font.Name := devData.InterfaceFont;
	Font.Size := devData.InterfaceFontSize;

  Caption:=                 Lang[ID_PRT];
  grpParams.Caption:=       Lang[ID_PRT_GRP_PARAMS];
  grpPages.Caption:=        Lang[ID_PRT_GRP_PAGES];
  cbColors.Caption:=        Lang[ID_PRT_COLORS];
  cbHighlight.Caption:=     Lang[ID_PRT_HIGHLIGHT];
  cbWordWrap.Caption:=      Lang[ID_PRT_WORDWRAP];
  rbLN.Caption:=            Lang[ID_PRT_PRTLINENUM];
  rbLNMargin.Caption:=      Lang[ID_PRT_PRTLINENUMMAR];
  rbNoLN.Caption:=          Lang[ID_PRT_NOPRTLINENUMMAR];
  lblCopies.Caption:=       Lang[ID_PRT_COPIES];
  lblPrinter.Caption:=      Lang[ID_PRT_PRINTER];
  cbSelection.Caption:=     Lang[ID_PRT_SELONLY];

  btnOk.Caption:=           Lang[ID_BTN_OK];
  btnCancel.Caption:=       Lang[ID_BTN_CANCEL];
end;

// The CUPS printers, the default one selected, and "Save as PDF" last. Without
// printers (or without CUPS) only the PDF is left.
procedure TPrintForm.LoadPrinters;
var
  DefaultPrinter: String;
begin
  GetPrinters(cboPrinter.Items, DefaultPrinter);
  cboPrinter.Items.Add(Lang[ID_PRT_SAVEPDF]);
  cboPrinter.ItemIndex := cboPrinter.Items.IndexOf(DefaultPrinter);
  if cboPrinter.ItemIndex < 0 then
    cboPrinter.ItemIndex := 0;
end;

function TPrintForm.SaveAsPDF: Boolean;
begin
  Result := cboPrinter.ItemIndex = cboPrinter.Items.Count - 1;
end;

function TPrintForm.PrinterName: String;
begin
  Result := cboPrinter.Text;
end;

procedure TPrintForm.FormCreate(Sender: TObject);
begin
  LoadText;
  LoadPrinters;
  cbColors.Checked := devData.PrintColors;
  cbHighlight.Checked := devData.PrintHighlight;
  cbWordWrap.Checked := devData.PrintWordWrap;
  rbLN.Checked := devData.PrintLineNumbers;
  rbNoLN.Checked := not devData.PrintLineNumbers;
  rbLNMargin.Checked := devData.PrintLineNumbersMargins;
end;

end.
