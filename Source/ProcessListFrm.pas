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

unit ProcessListFrm;

interface

uses
  LCLIntf, LCLType, LMessages, SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, Buttons, ExtCtrls, MultiLangSupport, DataFrm, devPlatform;

type
  TProcessListForm = class(TForm)
    OKBtn: TBitBtn;
    CancelBtn: TBitBtn;
    ProcessCombo: TComboBox;
    MainLabel: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    procedure LoadText;
    { Private declarations }
  public
    ProcessList : TList;
    { Public declarations }
  end;

var
  ProcessListForm: TProcessListForm;

implementation

uses
  devCFG;

{$R *.lfm}

procedure TProcessListForm.FormCreate(Sender: TObject);
var
  Names: TStringList;
  I: integer;
begin
  LoadText;
  ProcessList := TList.Create;
  Names := TStringList.Create;
  try
    ListProcesses(Names);
    for I := 0 to Names.Count - 1 do begin
      ProcessCombo.Items.Add(Names[I]);
      ProcessList.Add(Pointer(Names.Objects[I])); // the process ID
    end;
  finally
    Names.Free;
  end;
end;

procedure TProcessListForm.FormDestroy(Sender: TObject);
begin
  ProcessList.Free;
end;

procedure TProcessListForm.LoadText;
begin
	// Set interface font
	Font.Name := devData.InterfaceFont;
	Font.Size := devData.InterfaceFontSize;

  Caption := Lang[ID_ITEM_ATTACHPROCESS];
  MainLabel.Caption := Lang[ID_MSG_ATTACH];
  MainLabel.Width := 360;
  OKBtn.Caption := Lang[ID_BTN_OK];
  CancelBtn.Caption := Lang[ID_BTN_CANCEL];
end;

end.
