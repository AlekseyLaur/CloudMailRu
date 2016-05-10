unit ConnectionManager;

{ ������������ ���������� �������������� ������������ ��� ������������� ���������� ���������������. ��� ������ ��������� ������ ����������� ��������,
	��� ����������� - �������� ��� ���������. }

interface

uses CloudMailRu;

type

	TNamedConnection = record
		Name: WideString;
		Connection: TCloudMailRu;
	end;

	TConnectionManager = class
	private
		Connections: array of TNamedConnection; // Associative array;

		function ConnectionExists(connectionName: WideString): integer; // ��������� ������������� �����������
		function new(connectionName: WideString): integer; // ��������� ����������� � ���

	public
		constructor Create();
		destructor Destroy();
		function get(connectionName: WideString): TCloudMailRu; // ���������� ������� ���������� �� �����
		function free(connectionName: WideString): integer; // ����������� ����������� �� ��� �����, ���������� ��� ���������
		function freeAll: integer; // ����������� ��� �����������

	end;

implementation

{ TConnectionManager }

constructor TConnectionManager.Create;
begin

end;

destructor TConnectionManager.Destroy;
begin

end;

function TConnectionManager.new(connectionName: WideString): integer;
begin
	SetLength(Connections, Length(Connections) + 1);
	Connections[Length(Connections) - 1].Name := connectionName;
	result := Length(Connections) - 1;
end;

function TConnectionManager.ConnectionExists(connectionName: WideString): integer;
var
	Connection: TNamedConnection;
	I: integer;
begin
	result := 0;
	for I := 0 to Length(Connections) - 1 do
	begin
		if Connections[I].Name = connectionName then exit(I);
	end;
end;

function TConnectionManager.free(connectionName: WideString): integer;
begin

end;

function TConnectionManager.freeAll: integer;
begin


end;

function TConnectionManager.get(connectionName: WideString): TCloudMailRu;
var
	ConnectionIndex: integer;
begin
	ConnectionIndex := ConnectionExists(connectionName);
	if ConnectionIndex <> 0 then exit(Connections[ConnectionIndex].Connection);

	result := Connections[new(connectionName)].Connection;
end;

end.
