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

unit AboutFrm;

interface

uses
  LCLIntf, SysUtils, Classes, Version, Graphics, Controls, Forms, Dialogs, StdCtrls, ExtCtrls;

type
  TAboutForm = class(TForm)
    lblVersion, lblCreatorTitle, lblCreator, lblDescription: TLabel;
    lblRepositoryURL, lblLicense, lblDocs: TLabel;
    grpLinks: TGroupBox;
    paBanner: TPanel;
    imgBanner: TImage;
    btnUpdateCheck, btnAuthors, btnOk: TButton;
    procedure URLLabelClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnAuthorsClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnUpdateCheckClick(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
  end;

implementation

uses
  devCFG, Utils, MultiLangSupport, main, UpdateCheckFrm;

{$R *.lfm}

procedure TAboutForm.URLLabelClick(Sender: TObject);
begin
  OpenURL(TLabel(Sender).Hint);
end;

procedure TAboutForm.FormCreate(Sender: TObject);
  procedure StyleLink(Link: TLabel);
  begin
    Link.Font.Color := clBlue;
    Link.Font.Style := [fsUnderline];
    Link.ShowHint := True;
  end;
begin
  Font.Name := devData.InterfaceFont;
  Font.Size := devData.InterfaceFontSize;
  Caption := Lang[80026];
  lblVersion.Caption := 'Version ' + DEVCPP_VERSION;
  lblVersion.Hint := DEVCPP_RELEASE_URL;
  lblVersion.ShowHint := True;
  lblCreatorTitle.Caption := Lang[80019];
  lblCreator.Caption := DEVCPP_CREATOR;
  lblCreator.Font.Assign(Font);
  lblCreator.Font.Style := [fsBold];
  lblDescription.Caption := Lang[80020];
  grpLinks.Caption := Lang[80021];
  lblRepositoryURL.Hint := DEVCPP_REPOSITORY_URL;
  lblLicense.Hint := DEVCPP_REPOSITORY_URL + '/blob/v' + DEVCPP_VERSION + '/COPYING.txt';
  lblDocs.Caption := Lang[80023];
  lblDocs.Hint := MANUAL_URL;
  StyleLink(lblVersion); StyleLink(lblRepositoryURL);
  StyleLink(lblLicense); StyleLink(lblDocs);
  btnAuthors.Caption := Lang[80022];
  btnUpdateCheck.Caption := Lang[80000];
  btnOk.Caption := Lang[80008];
  if FileExists(devData.Splash) then imgBanner.Picture.LoadFromFile(devData.Splash);
end;

procedure TAboutForm.btnAuthorsClick(Sender: TObject);
const
  HistoricalCredits =
    '- Post-5.12 development sponsored by Embarcadero'#13#10 +
    '- 4.9.9.2 to 5.12 development: Johan Mes'#13#10 +
    '- Development: Colin Laplace, Mike Berg, Hongli Lai, Yiannis Mandravellos'#13#10 +
    '- Contributors: Peter Schraut, Marek Januszewski, Anonymous'#13#10 +
    '- MinGW compiler system: Mumit Khan, J.J. van der Heijden, Colin Hendrix and GNU developers'#13#10 +
    '- Splash screen and association icons: Matthijs Crielaard'#13#10 +
    '- New Look theme: Gerard Caulfield'#13#10 +
    '- Gnome icons: Gnome designers'#13#10 +
    '- Blue theme: Thomas Thron';
begin
  MessageDlg('Penguin cpp' + LineEnding + DEVCPP_CREATOR + LineEnding + LineEnding +
    'AI-assisted development: Claude Opus 5.5 (Anthropic), Chat GPT 6.1 Sol (OpenAI).' +
    LineEnding + LineEnding + 'Dev-C++ contributors:' + LineEnding + HistoricalCredits,
    mtInformation, [mbOK], 0);
end;

procedure TAboutForm.btnOkClick(Sender: TObject);
begin
  Close;
end;

procedure TAboutForm.btnUpdateCheckClick(Sender: TObject);
begin
  if ShowUpdateCheck then begin
    ModalResult := mrOK;
    Application.QueueAsyncCall(MainForm.RequestUpdate, 0);
  end;
end;

procedure TAboutForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

end.
