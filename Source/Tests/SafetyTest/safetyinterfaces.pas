{ Integration tests use real Cocoa/Qt5 controls and deterministic dialog replies. }
unit SafetyInterfaces;
{$mode objfpc}{$H+}
interface
uses cwstring, InterfaceBase,
 {$IFDEF DARWIN} CocoaWSFactory, CocoaInt, CocoaWSDialogs,
 {$ELSE} QtWSFactory, QtInt, QtWSDialogs, {$ENDIF}
 Forms, Controls, Dialogs, WSLCLClasses;
type TTestWidgetSet=class({$IFDEF DARWIN}TCocoaWidgetSet{$ELSE}TQtWidgetSet{$ENDIF})
 function PromptUser(const Caption,Msg:String; Kind:LongInt; Buttons:PLongInt;
  Count,DefaultIndex,EscapeResult:LongInt):LongInt; override;
 function RequestInput(const Caption,Prompt:String; MaskInput:Boolean; var Value:String):Boolean; override;
end;
TTestFileDialog=class({$IFDEF DARWIN}TCocoaWSFileDialog{$ELSE}TQtWSFileDialog{$ENDIF})
 class procedure ShowModal(const Dialog:TCommonDialog); override;
end;
var InputValue,SaveName:String; InputAccepted:Boolean=True; SaveAccepted:Boolean=False;
LastDialog: String;
DialogReply: LongInt = 2; DialogCount: Integer = 0;
implementation
function TTestWidgetSet.PromptUser(const Caption,Msg:String; Kind:LongInt; Buttons:PLongInt;
 Count,DefaultIndex,EscapeResult:LongInt):LongInt;
begin
 Inc(DialogCount); LastDialog:=Msg; WriteLn('Dialog: ',Msg); Result:=DialogReply;
end;
function TTestWidgetSet.RequestInput(const Caption,Prompt:String; MaskInput:Boolean; var Value:String):Boolean;
begin Value:=InputValue; Result:=InputAccepted end;
class procedure TTestFileDialog.ShowModal(const Dialog:TCommonDialog);
begin
 if SaveAccepted then begin TFileDialog(Dialog).FileName:=SaveName; Dialog.UserChoice:=mrOK end
 else Dialog.UserChoice:=mrCancel;
end;
var SaveDialog:TSaveDialog;
initialization
 CreateWidgetset(TTestWidgetSet);
 SaveDialog:=TSaveDialog.Create(nil); SaveDialog.Free;
 RegisterWSComponent(TSaveDialog,TTestFileDialog);
finalization FreeWidgetSet;
end.
