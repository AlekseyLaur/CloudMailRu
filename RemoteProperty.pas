unit RemoteProperty;

interface

uses
	Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
	Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, CloudMailRu, Vcl.Menus;

type
	TPropertyForm = class(TForm)
		PublicLinkLabel: TLabel;
		WebLink: TEdit;
		AccessCB: TCheckBox;
		OkButton: TButton;
		class function ShowProperty(parentWindow: HWND; RemoteProperty: TCloudMailRuDirListingItem):integer;
		procedure AccessCBClick(Sender: TObject);
		procedure FormShow(Sender: TObject);
		procedure FormDestroy(Sender: TObject);
	private
		{ Private declarations }
		procedure WMHotKey(var Message: TMessage); message WM_HOTKEY;
	protected
		Props: TCloudMailRuDirListingItem;
	public
		{ Public declarations }

	end;

var
	PropertyForm: TPropertyForm;

implementation

{$R *.dfm}
{ TPropertyForm }

procedure TPropertyForm.AccessCBClick(Sender: TObject);
begin
	WebLink.Enabled := AccessCB.checked;
end;

procedure TPropertyForm.FormDestroy(Sender: TObject);
begin
	UnregisterHotKey((Sender as TPropertyForm).handle, 1)
end;

procedure TPropertyForm.FormShow(Sender: TObject);
begin
	if not(Props.WebLink = '') then
	begin
		WebLink.text := 'https://cloud.mail.ru/public/' + Props.WebLink;
		WebLink.SetFocus;
		WebLink.SelectAll;
	end;
	AccessCB.checked := not(Props.WebLink = '');
	WebLink.Enabled := AccessCB.checked;
end;

class function  TPropertyForm.ShowProperty(parentWindow: HWND; RemoteProperty: TCloudMailRuDirListingItem):integer;
var
	PropertyForm: TPropertyForm;
begin
	try
		PropertyForm := TPropertyForm.Create(nil);
		PropertyForm.parentWindow := parentWindow; { TODO : ���������� ���������������� ������������ ���� TC }
		PropertyForm.Caption := RemoteProperty.name;
		PropertyForm.Props := RemoteProperty;
		RegisterHotKey(PropertyForm.Handle, 1, 0, VK_ESCAPE);
		result:=PropertyForm.Showmodal;

	finally
		FreeAndNil(PropertyForm);
	end;
end;

procedure TPropertyForm.WMHotKey(var Message: TMessage);
begin
	close;
end;

end.
