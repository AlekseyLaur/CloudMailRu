unit ConnectionManager;

{ ������������ ���������� �������������� ������������ ��� ������������� ���������� ���������������. ��� ������ ��������� ������ ����������� ��������,
	��� ����������� - �������� ��� ���������. }

interface

uses CloudMailRu, MRC_Helper, windows, controls, PLUGIN_Types,
	AskPassword, PLUGIN_MAIN;

type

	TNamedConnection = record
		Name: WideString;
		Connection: TCloudMailRu;
	end;

	TConnectionManager = class
	private
		Connections: array of TNamedConnection;
		IniFileName: WideString;

		PluginNum: integer;

		MyProgressProc: TProgressProc;
		MyLogProc: TLogProc;

		function ConnectionExists(connectionName: WideString): integer; // ��������� ������������� �����������
		function new(connectionName: WideString): integer; // ��������� ����������� � ���
		function GetMyPasswordNow(var AccountSettings: TAccountSettings): boolean; // �������� ������ �� �����, �� ������������ ��������� ��� ����������� ������ ����

	public
		CryptoNum: integer;
		MyCryptProc: TCryptProcW;
		constructor Create(IniFileName: WideString; PluginNum: integer; MyProgressProc: TProgressProc; MyLogProc: TLogProc);
		destructor Destroy();
		function get(connectionName: WideString): TCloudMailRu; // ���������� ������� ���������� �� �����
		function set_(connectionName: WideString; cloud: TCloudMailRu): boolean;
		function init(connectionName: WideString): cardinal; // �������������� ����������� �� ��� �����, ���������� ��� ���������
		function free(connectionName: WideString): integer; // ����������� ����������� �� ��� �����, ���������� ��� ���������
		function freeAll: integer; // ����������� ��� �����������
		function initialized(connectionName: WideString): boolean; // ���������, ���������������� �� �����������

	end;

implementation

{ TConnectionManager }
constructor TConnectionManager.Create(IniFileName: WideString; PluginNum: integer; MyProgressProc: TProgressProc; MyLogProc: TLogProc);
begin
	SetLength(Connections, 0);
	self.IniFileName := IniFileName;
	self.PluginNum := PluginNum;
	self.MyProgressProc := MyProgressProc;
	self.MyLogProc := MyLogProc;
end;

destructor TConnectionManager.Destroy;
begin
	freeAll();
end;

function TConnectionManager.get(connectionName: WideString): TCloudMailRu;
var
	ConnectionIndex: integer;
	iResult: cardinal;
begin
	ConnectionIndex := ConnectionExists(connectionName);
	if ConnectionIndex <> -1 then exit(Connections[ConnectionIndex].Connection);
	result := Connections[new(connectionName)].Connection;

	if not initialized(connectionName) then iResult := init(connectionName);
	if (iResult = CLOUD_OPERATION_OK) then result := get(connectionName);

end;

function TConnectionManager.set_(connectionName: WideString; cloud: TCloudMailRu): boolean;
var
	ConnectionIndex: integer;
begin
	ConnectionIndex := ConnectionExists(connectionName);
	if ConnectionIndex = -1 then exit(false);
	Connections[ConnectionIndex].Connection := cloud;
	result := true;
end;

function TConnectionManager.init(connectionName: WideString): cardinal;
var
	cloud: TCloudMailRu;
	AccountSettings: TAccountSettings;
begin
	AccountSettings := GetAccountSettingsFromIniFile(IniFileName, connectionName);

	if not GetMyPasswordNow(AccountSettings) then exit(INVALID_HANDLE_VALUE);

	MyLogProc(PluginNum, MSGTYPE_CONNECT, PWideChar('CONNECT ' + AccountSettings.email));

	cloud := TCloudMailRu.Create(AccountSettings.user, AccountSettings.domain, AccountSettings.password, MyProgressProc, PluginNum, MyLogProc);
	if not set_(connectionName, cloud) then exit(INVALID_HANDLE_VALUE);
	result := CLOUD_OPERATION_OK;
	// cloud.destroy;
end;

function TConnectionManager.initialized(connectionName: WideString): boolean;
begin
	result := Assigned(get(connectionName));
end;

function TConnectionManager.new(connectionName: WideString): integer;
begin
	SetLength(Connections, Length(Connections) + 1);
	Connections[Length(Connections) - 1].Name := connectionName;
	result := Length(Connections) - 1;
end;

function TConnectionManager.ConnectionExists(connectionName: WideString): integer;
var
	I: integer;
begin
	result := -1;

	for I := 0 to Length(Connections) - 1 do
	begin
		if Connections[I].Name = connectionName then exit(I);
	end;
end;

function TConnectionManager.free(connectionName: WideString): integer;
begin
	result := CLOUD_OPERATION_OK;
	get(connectionName).Destroy;
end;

function TConnectionManager.freeAll: integer;
var
	I: integer;
begin
	result := CLOUD_OPERATION_OK;

	for I := 0 to Length(Connections) - 1 do
	begin
		Connections[I].Connection.Destroy;
	end;

end;

function TConnectionManager.GetMyPasswordNow(var AccountSettings: TAccountSettings): boolean;
var
	CryptResult: integer;
	AskResult: integer;
	TmpString: WideString;
	buf: PWideChar;
begin
	if AccountSettings.use_tc_password_manager then
	begin // ������ ������ ������� �� TC
		GetMem(buf, 1024);
		CryptResult := MyCryptProc(PluginNum, CryptoNum, FS_CRYPT_LOAD_PASSWORD_NO_UI, PWideChar(AccountSettings.Name), buf, 1024); // �������� ����� ������ ��-������
		if CryptResult = FS_FILE_NOTFOUND then
		begin
			MyLogProc(PluginNum, msgtype_details, PWideChar('No master password entered yet'));
			CryptResult := MyCryptProc(PluginNum, CryptoNum, FS_CRYPT_LOAD_PASSWORD, PWideChar(AccountSettings.Name), buf, 1024);
		end;
		if CryptResult = FS_FILE_OK then // ������� �������� ������
		begin
			AccountSettings.password := buf;
			// Result := true;
		end;
		if CryptResult = FS_FILE_NOTSUPPORTED then // ������������ ������� ���� �������� ������
		begin
			MyLogProc(PluginNum, msgtype_importanterror, PWideChar('CryptProc returns error: Decrypt failed'));
		end;
		if CryptResult = FS_FILE_READERROR then
		begin
			MyLogProc(PluginNum, msgtype_importanterror, PWideChar('CryptProc returns error: Password not found in password store'));
		end;
		FreeMemory(buf);
	end; // else // ������ �� ������, ������ ��� ������ ���� � ���������� (���� � �������� ���� �� ��������)

	if AccountSettings.password = '' then // �� ������ ���, �� � ��������, �� � ������
	begin
		AskResult := TAskPasswordForm.AskPassword(FindTCWindow, AccountSettings.Name, AccountSettings.password, AccountSettings.use_tc_password_manager);
		if AskResult <> mrOK then
		begin // �� ������� ������ � �������
			exit(false); // ���������� ������� ������
		end else begin
			if AccountSettings.use_tc_password_manager then
			begin
				case MyCryptProc(PluginNum, CryptoNum, FS_CRYPT_SAVE_PASSWORD, PWideChar(AccountSettings.Name), PWideChar(AccountSettings.password), SizeOf(AccountSettings.password)) of
					FS_FILE_OK:
						begin // TC ������ ������, �������� � ������� �������
							MyLogProc(PluginNum, msgtype_details, PWideChar('Password saved in TC password manager'));
							TmpString := AccountSettings.password;
							AccountSettings.password := '';
							SetAccountSettingsToIniFile(IniFileName, AccountSettings);
							AccountSettings.password := TmpString;
						end;
					FS_FILE_NOTSUPPORTED: // ���������� �� ����������
						begin
							MyLogProc(PluginNum, msgtype_importanterror, PWideChar('CryptProc returns error: Encrypt failed'));
						end;
					FS_FILE_WRITEERROR: // ���������� ����� �� ����������
						begin
							MyLogProc(PluginNum, msgtype_importanterror, PWideChar('Password NOT saved: Could not write password to password store'));
						end;
					FS_FILE_NOTFOUND: // �� ������ ������-������
						begin
							MyLogProc(PluginNum, msgtype_importanterror, PWideChar('Password NOT saved: No master password entered yet'));
						end;
					// ������ ����� �� ������, ��� ������ �� �� �������� - �� ����� ���� ����� � �������
				end;
			end;
			result := true;
		end;
	end
	else result := true; // ������ ���� �� �������� ��������
end;

end.
