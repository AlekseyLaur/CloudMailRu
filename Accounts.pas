unit Accounts;

interface

uses
	Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
	Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, IniFiles, MRC_Helper, PLUGIN_Types;

type
	TAccountsForm = class(TForm)
		AccountsGroupBox: TGroupBox;
		AccountsList: TListBox;
		UsernameLabel: TLabel;
		EmailEdit: TEdit;
		AccountNameLabel: TLabel;
		AccountNameEdit: TEdit;
		PasswordEdit: TEdit;
		PasswordLabel: TLabel;
		UseTCPwdMngrCB: TCheckBox;
		ApplyButton: TButton;
		DeleteButton: TButton;
		procedure FormShow(Sender: TObject);
		procedure AccountsListClick(Sender: TObject);
		procedure ApplyButtonClick(Sender: TObject);
		procedure UpdateAccountsList();
		procedure DeleteButtonClick(Sender: TObject);
		procedure AccountsListKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
	private
		{ Private declarations }
	public
		{ Public declarations }
		IniPath: WideString;
		CryptProc: TCryptProc;
		PluginNum: Integer;
		CryptoNum: Integer;

	end;

var
	AccountsForm: TAccountsForm;

implementation

{$R *.dfm}

procedure TAccountsForm.AccountsListClick(Sender: TObject);
var
	CASettings: TAccountSettings;
begin
	if (AccountsList.Items.Count > 0) and (AccountsList.ItemIndex <> -1) then
	begin
		CASettings := GetAccountSettingsFromIniFile(IniPath, AccountsList.Items[AccountsList.ItemIndex]);
		AccountNameEdit.Text := CASettings.name;
		EmailEdit.Text := CASettings.email;
		PasswordEdit.Text := CASettings.password;
		UseTCPwdMngrCB.Checked := CASettings.use_tc_password_manager;

	end;

end;

procedure TAccountsForm.AccountsListKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
	if Key = VK_DELETE then DeleteButtonClick(nil);

end;

procedure TAccountsForm.ApplyButtonClick(Sender: TObject);
var
	CASettings: TAccountSettings;
begin
	CASettings.name := AccountNameEdit.Text;
	CASettings.email := EmailEdit.Text;
	CASettings.password := PasswordEdit.Text;
	CASettings.use_tc_password_manager := UseTCPwdMngrCB.Checked;
	if CASettings.use_tc_password_manager then // ������ TC ��������� ������
	begin
		case self.CryptProc(self.PluginNum, self.CryptoNum, FS_CRYPT_SAVE_PASSWORD, PWideChar(CASettings.name), PWideChar(CASettings.password), SizeOf(CASettings.name)) of
			FS_FILE_OK:
				begin // TC ������ ������
					CASettings.password := '';
				end;
			FS_FILE_NOTSUPPORTED: // ���������� �� ����������
				begin

				end;
			FS_FILE_WRITEERROR: // ���������� ����� �� ����������
				begin

				end;
			FS_FILE_NOTFOUND: // �� ������ ������-������
				begin

				end;
		end;

	end;

	SetAccountSettingsToIniFile(IniPath, CASettings);

	UpdateAccountsList();

end;

procedure TAccountsForm.DeleteButtonClick(Sender: TObject);
begin
	if (AccountsList.Items.Count > 0) and (AccountsList.ItemIndex <> -1) then
	begin
		DeleteAccountFromIniFile(IniPath, AccountsList.Items[AccountsList.ItemIndex]);
		UpdateAccountsList();
	end;
end;

procedure TAccountsForm.FormShow(Sender: TObject);
begin
	AccountsList.SetFocus;
	UpdateAccountsList();
	if AccountsList.Items.Count > 0 then
	begin
		AccountsList.Selected[0] := true;
		AccountsList.OnClick(self);
	end;

end;

procedure TAccountsForm.UpdateAccountsList;
var
	TempList: TStringList;
begin
	TempList := TStringList.Create;
	GetAccountsListFromIniFile(IniPath, TempList);
	AccountsList.Items := TempList;
	TempList.Destroy;
end;

end.
