library MailRuCloud;

{$R *.dres}

uses
	SysUtils,
	DateUtils,
	windows,
	Classes,
	PLUGIN_TYPES,
	PLUGIN_MAIN,
	messages,
	inifiles,
	Vcl.controls,
	CloudMailRu in 'CloudMailRu.pas',
	MRC_Helper in 'MRC_Helper.pas',
	Accounts in 'Accounts.pas' {AccountsForm} ,
	AskPassword in 'AskPassword.pas' {AskPasswordForm};

{$IFDEF WIN64}
{$E wfx64}
{$ENDIF}
{$IFDEF WIN32}
{$E wfx}
{$ENDIF}
{$R *.res}

var
	tmp: pchar;
	IniFilePath: WideString;
	GlobalPath, PluginPath: WideString;
	FileCounter: integer = 0;
	{ Callback data }
	PluginNum: integer;
	CryptoNum: integer;
	MyProgressProc: TProgressProc;
	MyLogProc: TLogProc;
	MyRequestProc: TRequestProc;
	MyCryptProc: TCryptProcW;
	Cloud: TCloudMailRu;
	CurrentListing: TCloudMailRuDirListing;
	CurrentLogon: boolean;

function CloudMailRuDirListingItemToFindData(DirListing: TCloudMailRuDirListingItem): tWIN32FINDDATAW;
begin
	if (DirListing.type_ = TYPE_DIR) then Result.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY
	else Result.dwFileAttributes := 0;
	if (DirListing.size > MAXDWORD) then Result.nFileSizeHigh := DirListing.size div MAXDWORD
	else Result.nFileSizeHigh := 0;
	Result.nFileSizeLow := DirListing.size;
	Result.ftCreationTime := DateTimeToFileTime(UnixToDateTime(DirListing.mtime));
	Result.ftLastWriteTime := DateTimeToFileTime(UnixToDateTime(DirListing.mtime));

	strpcopy(Result.cFileName, DirListing.name);
end;

function FindData_emptyDir(DirName: WideString = '.'): tWIN32FINDDATAW;
begin
	strpcopy(Result.cFileName, DirName);
	Result.ftCreationTime.dwLowDateTime := 0;
	Result.ftCreationTime.dwHighDateTime := 0;
	Result.ftLastWriteTime.dwHighDateTime := 0;
	Result.ftLastWriteTime.dwLowDateTime := 0;
	Result.nFileSizeHigh := 0;
	Result.nFileSizeLow := 0;
	Result.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY;
end;

// �������� ������ �� �����, �� ������������ ��������� ��� ����������� ������ ����
function GetMyPasswordNow(var AccountSettings: TAccountSettings): boolean;
var
	CryptResult: integer;
	AskResult: integer;
	TmpString: WideString;
	buf: PWideChar;
begin
	if AccountSettings.use_tc_password_manager then
	begin // ������ ������ ������� �� TC
		GetMem(buf, 1024);
		CryptResult := MyCryptProc(PluginNum, CryptoNum, FS_CRYPT_LOAD_PASSWORD_NO_UI, PWideChar(AccountSettings.name), buf, 1024); // �������� ����� ������ ��-������
		if CryptResult = FS_FILE_NOTFOUND then
		begin
			MyLogProc(PluginNum, msgtype_details, PWideChar('No master password entered yet'));
			CryptResult := MyCryptProc(PluginNum, CryptoNum, FS_CRYPT_LOAD_PASSWORD, PWideChar(AccountSettings.name), buf, 1024);
		end;
		if CryptResult = FS_FILE_OK then // ������� �������� ������
		begin
			AccountSettings.password := buf;
			Result := true;
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
	end else begin
		// ������ �� ������, ������ ��� ������ ���� � ���������� (���� � �������� ���� �� ��������)
	end;
	if AccountSettings.password = '' then // �� ������ ���, �� � ��������, �� � ������
	begin
		AskResult := TAskPasswordForm.AskPassword(FindTCWindow, AccountSettings.name, AccountSettings.password, AccountSettings.use_tc_password_manager);
		if AskResult <> mrOK then
		begin // �� ������� ������ � �������
			exit(false); // ���������� ������� ������
		end else begin
			if AccountSettings.use_tc_password_manager then
			begin
				case MyCryptProc(PluginNum, CryptoNum, FS_CRYPT_SAVE_PASSWORD, PWideChar(AccountSettings.name), PWideChar(AccountSettings.password), SizeOf(AccountSettings.password)) of
					FS_FILE_OK:
						begin // TC ������ ������, �������� � ������� �������
							MyLogProc(PluginNum, msgtype_details, PWideChar('Password saved in TC password manager'));
							TmpString := AccountSettings.password;
							AccountSettings.password := '';
							SetAccountSettingsToIniFile(IniFilePath, AccountSettings);
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
			exit(true);
		end;

	end // ������ �� �������� ��������
	else exit(true);
end;

procedure FsGetDefRootName(DefRootName: PAnsiChar; maxlen: integer); stdcall; // ��������� ���������� ���� ��� ��� ��������� �������
Begin
	StrLCopy(DefRootName, PAnsiChar('CloudMailRu'), maxlen);
	messagebox(FindTCWindow, PWideChar('Installation succeful'), 'Information', mb_ok + mb_iconinformation);
End;

function FsFindClose(Hdl: thandle): integer; stdcall;
Begin
	// ���������� ��������� ������ ������. Result ������� �� ������������ (������ ����� 0)
	Result := 0;
	FileCounter := 0;
end;

{ ANSI PEASANTS }

function FsInit(PluginNr: integer; pProgressProc: TProgressProc; pLogProc: TLogProc; pRequestProc: TRequestProc): integer; stdcall;
Begin
	PluginNum := PluginNr;
	MyProgressProc := pProgressProc;
	MyLogProc := pLogProc;
	MyRequestProc := pRequestProc;
	// ���� � ������.
	Result := 0;
end;

procedure FsStatusInfo(RemoteDir: PAnsiChar; InfoStartEnd, InfoOperation: integer); stdcall;
begin
	SetLastError(ERROR_NOT_SUPPORTED);
end;

function FsFindFirst(path: PAnsiChar; var FindData: tWIN32FINDDATAA): thandle; stdcall;
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := ERROR_INVALID_HANDLE; // Ansi-��������
end;

function FsFindNext(Hdl: thandle; var FindData: tWIN32FINDDATAA): bool; stdcall;
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := false; // Ansi-��������
end;

function FsExecuteFile(MainWin: thandle; RemoteName, Verb: PAnsiChar): integer; stdcall; // ������ �����
Begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := FS_EXEC_ERROR; // Ansi-��������
End;

function FsGetFile(RemoteName, LocalName: PAnsiChar; CopyFlags: integer; RemoteInfo: pRemoteInfo): integer; stdcall; // ����������� ����� �� �������� ������� �������
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := FS_FILE_NOTSUPPORTED; // Ansi-��������
end;

function FsPutFile(LocalName, RemoteName: PAnsiChar; CopyFlags: integer): integer; stdcall; // ����������� ����� � �������� ������� �������
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := FS_FILE_NOTSUPPORTED; // Ansi-��������
end;

function FsDeleteFile(RemoteName: PAnsiChar): bool; stdcall; // �������� ����� �� �������� �������� �������
Begin
	SetLastError(ERROR_INVALID_FUNCTION); // Ansi-��������
	Result := false;
End;

function FsDisconnect(DisconnectRoot: PAnsiChar): bool; stdcall;
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := false; // ansi-��������
end;

function FsMkDir(path: PAnsiChar): bool; stdcall;
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := false; // ansi-��������
end;

function FsRemoveDir(RemoteName: PAnsiChar): bool; stdcall;
begin
	SetLastError(ERROR_INVALID_FUNCTION);
	Result := false; // ansi-��������
end;

procedure FsSetCryptCallback(PCryptProc: TCryptProcW; CryptoNr: integer; Flags: integer); stdcall;
begin
	SetLastError(ERROR_INVALID_FUNCTION);
end;

{ GLORIOUS UNICODE MASTER RACE }

function FsInitW(PluginNr: integer; pProgressProc: TProgressProc; pLogProc: TLogProc; pRequestProc: TRequestProc): integer; stdcall; // ���� � ������.
Begin
	PluginNum := PluginNr;
	MyProgressProc := pProgressProc;
	MyLogProc := pLogProc;
	MyRequestProc := pRequestProc;
	CurrentLogon := false;
	Result := 0;
end;

procedure FsStatusInfoW(RemoteDir: PWideChar; InfoStartEnd, InfoOperation: integer); stdcall;
begin
	if Assigned(Cloud) then Cloud.CancelCopy := false; // todo: �������� ������
	// ������ � ����� �������� FS
	if (InfoStartEnd = FS_STATUS_START) then
	begin
		case InfoOperation of
			FS_STATUS_OP_LIST:
				begin
				end;
			FS_STATUS_OP_GET_SINGLE:
				begin
				end;
			FS_STATUS_OP_GET_MULTI:
				begin
				end;
			FS_STATUS_OP_PUT_SINGLE:
				begin
				end;
			FS_STATUS_OP_PUT_MULTI:
				begin
				end;
			FS_STATUS_OP_RENMOV_SINGLE:
				begin
				end;
			FS_STATUS_OP_RENMOV_MULTI:
				begin
				end;
			FS_STATUS_OP_DELETE:
				begin
				end;
			FS_STATUS_OP_ATTRIB:
				begin
				end;
			FS_STATUS_OP_MKDIR:
				begin
				end;
			FS_STATUS_OP_EXEC:
				begin
				end;
			FS_STATUS_OP_CALCSIZE:
				begin
				end;
			FS_STATUS_OP_SEARCH:
				begin
				end;
			FS_STATUS_OP_SEARCH_TEXT:
				begin
				end;
		end;
		exit;
	end;
	if (InfoStartEnd = FS_STATUS_END) then
	begin
		case InfoOperation of
			FS_STATUS_OP_LIST:
				begin
				end;
			FS_STATUS_OP_GET_SINGLE:
				begin
				end;
			FS_STATUS_OP_GET_MULTI:
				begin
				end;
			FS_STATUS_OP_PUT_SINGLE:
				begin
				end;
			FS_STATUS_OP_PUT_MULTI:
				begin
				end;
			FS_STATUS_OP_RENMOV_SINGLE:
				begin
				end;
			FS_STATUS_OP_RENMOV_MULTI:
				begin
				end;
			FS_STATUS_OP_DELETE:
				begin
				end;
			FS_STATUS_OP_ATTRIB:
				begin
				end;
			FS_STATUS_OP_MKDIR:
				begin
				end;
			FS_STATUS_OP_EXEC:
				begin
				end;
			FS_STATUS_OP_CALCSIZE:
				begin
				end;
			FS_STATUS_OP_SEARCH:
				begin
				end;
			FS_STATUS_OP_SEARCH_TEXT:
				begin
				end;
		end;
		exit;
	end;
end;

function FsFindFirstW(path: PWideChar; var FindData: tWIN32FINDDATAW): thandle; stdcall;
var
	Sections: TStringList;
	RealPath: TRealPath;
	CryptResult: integer;
	AccountSettings: TAccountSettings;
begin
	// ��������� ������� ����� � �����. Result ������� �� ������������ (����� ������������ ��� ������ �������).
	// setlasterror(ERROR_NO_MORE_FILES);
	GlobalPath := path;
	if GlobalPath = '\' then
	begin // ������ ����������
		if Assigned(Cloud) then FreeAndNil(Cloud);

		Sections := TStringList.Create;
		GetAccountsListFromIniFile(IniFilePath, Sections);

		if (Sections.Count > 0) then
		begin
			FindData := FindData_emptyDir(Sections.Strings[0]);
			FileCounter := 1;
		end else begin
			Result := INVALID_HANDLE_VALUE; // ������ ������������ exit
			SetLastError(ERROR_NO_MORE_FILES);
		end;
	end else begin
		RealPath := ExtractRealPath(GlobalPath);

		if not Assigned(Cloud) then
		begin
			if RealPath.Account = '' then RealPath.Account := ExtractFileName(GlobalPath);

			AccountSettings := GetAccountSettingsFromIniFile(IniFilePath, RealPath.Account);

			if not GetMyPasswordNow(AccountSettings) then
			begin
				SetLastError(ERROR_WRONG_PASSWORD);
				exit(INVALID_HANDLE_VALUE);
			end;

			MyLogProc(PluginNum, MSGTYPE_CONNECT, PWideChar('CONNECT ' + AccountSettings.email));
			Cloud := TCloudMailRu.Create(AccountSettings.user, AccountSettings.domain, AccountSettings.password, MyProgressProc, PluginNum, MyLogProc);
			if Cloud.login() then
			begin
				CurrentLogon := true;
			end else begin
				CurrentLogon := false;
				FreeAndNil(Cloud);
				Result := INVALID_HANDLE_VALUE; // ������ ������������ exit
				SetLastError(ERROR_NO_MORE_FILES);
			end;

		end;

		if CurrentLogon then
		begin
			if not Cloud.getDir(RealPath.path, CurrentListing) then
			begin
				SetLastError(ERROR_PATH_NOT_FOUND);
			end;

			if Length(CurrentListing) = 0 then
			begin
				FindData := FindData_emptyDir(); // ���������� ���� � �������������� ����� � ������ �������, ��. http://www.ghisler.ch/board/viewtopic.php?t=42399
				Result := 0; // ������ ������������ exit
				SetLastError(ERROR_NO_MORE_FILES);
			end else begin
				FindData := CloudMailRuDirListingItemToFindData(CurrentListing[0]);
				FileCounter := 1;
				Result := 1;
			end;
		end else begin
			SetLastError(ERROR_INVALID_HANDLE);
			Result := INVALID_HANDLE_VALUE;
			strpcopy(FindData.cFileName, '������ ����� �� ��������� ������'); // ���� ������� �� ������ �������
		end;
	end;
end;

function FsFindNextW(Hdl: thandle; var FindData: tWIN32FINDDATAW): bool; stdcall;
var
	Sections: TStringList;
begin
	if GlobalPath = '\' then
	begin
		Sections := TStringList.Create;
		GetAccountsListFromIniFile(IniFilePath, Sections);
		if (Sections.Count > FileCounter) then
		begin
			FindData := FindData_emptyDir(Sections.Strings[FileCounter]);
			inc(FileCounter);
			Result := true;
		end
		else Result := false;
	end else begin
		if not CurrentLogon then
		begin
			Result := false;
		end else begin
			// ��������� ����������� ������ � ����� (���������� �� ��� ���, ���� �� ����� false).
			if (Length(CurrentListing) > FileCounter) then
			begin
				FindData := CloudMailRuDirListingItemToFindData(CurrentListing[FileCounter]);
				Result := true;
				inc(FileCounter);
			end else begin
				FillChar(FindData, SizeOf(WIN32_FIND_DATA), 0);
				FileCounter := 0;
				Result := false;
			end;
		end;
	end;
end;

function FsExecuteFileW(MainWin: thandle; RemoteName, Verb: PWideChar): integer; stdcall; // ������ �����
var
	RealPath: TRealPath;
Begin
	RealPath := ExtractRealPath(RemoteName);

	Result := FS_EXEC_OK;
	if Verb = 'open' then
	begin
		exit(FS_EXEC_YOURSELF);
	end else if Verb = 'properties' then
	begin
		if RealPath.path = '' then
		begin
			TAccountsForm.ShowAccounts(MainWin, IniFilePath, MyCryptProc, PluginNum, CryptoNum, RemoteName);
		end;
		// messagebox(MainWin, PWideChar(RemoteName), PWideChar(Verb), mb_ok + mb_iconinformation);
	end else if copy(Verb, 1, 5) = 'chmod' then
	begin
	end else if copy(Verb, 1, 5) = 'quote' then
	begin
	end;
End;

function FsGetFileW(RemoteName, LocalName: PWideChar; CopyFlags: integer; RemoteInfo: pRemoteInfo): integer; stdcall; // ����������� ����� �� �������� ������� �������
var
	RealPath: TRealPath;
begin
	Result := FS_FILE_NOTSUPPORTED;
	RealPath := ExtractRealPath(RemoteName);

	MyProgressProc(PluginNum, LocalName, RemoteName, 0);

	if CopyFlags = FS_FILE_OK then
	begin
		if FileExists(LocalName) then
		begin
			exit(FS_FILE_EXISTS);
		end else begin
			Result := Cloud.getFile(WideString(RealPath.path), WideString(LocalName));
		end;
	end;

	if CheckFlag(FS_COPYFLAGS_MOVE, CopyFlags) then
	begin
		Result := Cloud.getFile(WideString(RealPath.path), WideString(LocalName));
		if Result = FS_FILE_OK then
		begin
			Cloud.deleteFile(RealPath.path);
		end;

	end;
	if CheckFlag(FS_COPYFLAGS_RESUME, CopyFlags) then
	begin { NEVER CALLED HERE }
		Result := FS_FILE_NOTSUPPORTED;
	end;
	if CheckFlag(FS_COPYFLAGS_OVERWRITE, CopyFlags) then
	begin
		Result := Cloud.getFile(WideString(RealPath.path), WideString(LocalName));
	end;
	if Result = FS_FILE_OK then
	begin
		MyProgressProc(PluginNum, LocalName, RemoteName, 100);
		MyLogProc(PluginNum, MSGTYPE_TRANSFERCOMPLETE, PWideChar(RemoteName + '->' + LocalName));
	end;

end;

function FsPutFileW(LocalName, RemoteName: PWideChar; CopyFlags: integer): integer; stdcall;
var
	RealPath: TRealPath;
begin
	RealPath := ExtractRealPath(RemoteName);
	if RealPath.Account = '' then exit(FS_FILE_NOTSUPPORTED);
	MyProgressProc(PluginNum, LocalName, PWideChar(RealPath.path), 0);
	if CheckFlag(FS_COPYFLAGS_OVERWRITE, CopyFlags) then
	begin
		if Cloud.deleteFile(RealPath.path) then // ����������, ��� ������������ ���� ���� API, �� �� ����� ��� �������
		begin
			Result := Cloud.putFile(WideString(LocalName), RealPath.path);
			if Result = FS_FILE_OK then
			begin
				MyProgressProc(PluginNum, LocalName, PWideChar(RealPath.path), 100);
				MyLogProc(PluginNum, MSGTYPE_TRANSFERCOMPLETE, PWideChar(LocalName + '->' + RemoteName));
			end;

		end else begin
			Result := FS_FILE_NOTSUPPORTED;

		end;

	end;
	if CheckFlag(FS_COPYFLAGS_RESUME, CopyFlags) then
	begin // NOT SUPPORTED
		exit(FS_FILE_NOTSUPPORTED);
	end;

	if CheckFlag(FS_COPYFLAGS_EXISTS_SAMECASE, CopyFlags) or CheckFlag(FS_COPYFLAGS_EXISTS_DIFFERENTCASE, CopyFlags) then // ������ �� ������������ ������ ��������
	begin
		exit(FS_FILE_EXISTS);
	end;
	if CheckFlag(FS_COPYFLAGS_MOVE, CopyFlags) then
	begin
		Result := Cloud.putFile(WideString(LocalName), RealPath.path);
		if Result = FS_FILE_OK then
		begin
			MyProgressProc(PluginNum, LocalName, PWideChar(RealPath.path), 100);
			MyLogProc(PluginNum, MSGTYPE_TRANSFERCOMPLETE, PWideChar(LocalName + '->' + RemoteName));
		end;
		if not DeleteFileW(LocalName) then
		begin // �� ���������� �������
			exit(FS_FILE_NOTSUPPORTED);
		end;
	end;

	if CopyFlags = 0 then
	begin
		Result := Cloud.putFile(WideString(LocalName), RealPath.path);
		if Result = FS_FILE_OK then
		begin
			MyProgressProc(PluginNum, LocalName, PWideChar(RealPath.path), 100);
			MyLogProc(PluginNum, MSGTYPE_TRANSFERCOMPLETE, PWideChar(LocalName + '->' + RemoteName));
		end;
	end;

end;

function FsDeleteFileW(RemoteName: PWideChar): bool; stdcall; // �������� ����� �� �������� �������� �������
var
	RealPath: TRealPath;
Begin
	RealPath := ExtractRealPath(WideString(RemoteName));
	if RealPath.Account = '' then exit(false);
	Result := Cloud.deleteFile(RealPath.path);
End;

function FsMkDirW(path: PWideChar): bool; stdcall;
var
	RealPath: TRealPath;
Begin
	RealPath := ExtractRealPath(WideString(path));
	if RealPath.Account = '' then exit(false);
	Result := Cloud.createDir(RealPath.path);
end;

function FsRemoveDirW(RemoteName: PWideChar): bool; stdcall;
var
	RealPath: TRealPath;
Begin
	RealPath := ExtractRealPath(WideString(RemoteName));
	Result := Cloud.removeDir(RealPath.path);
end;

function FsDisconnectW(DisconnectRoot: PWideChar): bool; stdcall;
begin
	if Assigned(Cloud) then FreeAndNil(Cloud);
	Result := true;
end;

procedure FsSetCryptCallbackW(PCryptProc: TCryptProcW; CryptoNr: integer; Flags: integer); stdcall;
begin
	MyCryptProc := PCryptProc;
	CryptoNum := CryptoNr;
end;

exports FsGetDefRootName, FsInit, FsInitW, FsFindFirst, FsFindFirstW, FsFindNext, FsFindNextW, FsFindClose, FsGetFile, FsGetFileW,
	FsDisconnect, FsDisconnectW, FsStatusInfo, FsStatusInfoW, FsPutFile, FsPutFileW, FsDeleteFile, FsDeleteFileW, FsMkDir, FsMkDirW,
	FsRemoveDir, FsRemoveDirW, FsSetCryptCallback, FsSetCryptCallbackW, FsExecuteFileW;

(* ,
	FsExecuteFile,
	FsGetFile,
	FsPutFile,
	FsDeleteFile,
	FsStatusInfo,
	; *)
// FsExtractCustomIcon, {� ������� ����������� - ��� ������ ���� ������� ����� ������������� ���� ������ �� ������������ ����}
begin

	GetMem(tmp, max_path);
	GetModuleFilename(hInstance, tmp, max_path);
	PluginPath := tmp;
	freemem(tmp);
	PluginPath := IncludeTrailingbackslash(ExtractFilePath(PluginPath));
	IniFilePath := PluginPath + 'MailRuCloud.ini';
	if not FileExists(IniFilePath) then FileClose(FileCreate(IniFilePath));

end.
