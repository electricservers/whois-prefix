#include <sourcemod>
#include <scp>
#include <morecolors>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

Database g_DB;
bool g_Late;
char g_Name[MAX_NAME_LENGTH][MAXPLAYERS];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_Late = late;
}

public Plugin myinfo = {
	name = "Whois Prefix", 
	author = "ampere", 
	description = "Shows a toggleable chat prefix containing whois' permaname", 
	version = PLUGIN_VERSION, 
	url = "https://electricservers.com.ar"
};

public void OnPluginStart() {
	Database.Connect(SQL_OnDatabaseConnection, "whois");
}

public void SQL_OnDatabaseConnection(Database db, const char[] error, any data) {
	if (error[0] != '\0') {
		LogError(error);
		return;
	}
	
	g_DB = db;
	
	if (g_Late) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				OnClientPostAdminCheck(i);
			}
		}
	}
}

public void OnClientPostAdminCheck(int client) {
	if (g_DB == null) {
		return;
	}
	
	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	char query[128];
	g_DB.Format(query, sizeof(query), "SELECT name FROM whois_permname WHERE steam_id = '%s'", steamid);
	PrintToServer(query);
	g_DB.Query(SQL_OnNameReceived, query, GetClientUserId(client));
}

public void SQL_OnNameReceived(Database db, DBResultSet results, const char[] error, int userid) {
	if (db == null || results == null) {
		LogError("SQL_OnNameReceived: %s", error);
		delete results;
		return;
	}
	
	if (!results.FetchRow()) {
		PrintToServer("ROWCOUNT 0");
		return;
	}
	
	int client = GetClientOfUserId(userid);
	
	results.FetchString(0, g_Name[client], sizeof(g_Name[]));
	PrintToServer(g_Name[client]);
}

public Action OnChatMessage(int &author, ArrayList recipients, char[] name, char[] message) {
	//DataPack pack = new DataPack();
	//ArrayList al = view_as<ArrayList>(CloneHandle(recipients));
	//pack.WriteCell(author);
	//pack.WriteCell(al);
	//pack.WriteString(name);
	//pack.WriteString(message);
	//RequestFrame(Frame_OnMessageSent, pack);
	//return Plugin_Stop;
}

public void Frame_OnMessageSent(DataPack pack) {
	pack.Reset();
	int author = pack.ReadCell();
	ArrayList recipients = view_as<ArrayList>(pack.ReadCell());
	char name[MAX_NAME_LENGTH];
	pack.ReadString(name, sizeof(name));
	char message[256];
	pack.ReadString(message, sizeof(message));
	delete pack;
	
	for (int i = 0; i < recipients.Length; i++) {
		int rec = recipients.Get(i);
		if (!IsClientInGame(rec)) {
			continue;
		}
		if (g_Name[author][0] != '\0' && GetAdminFlag(GetUserAdmin(rec), Admin_Generic)) {
			MC_PrintToChat(rec, "{darkgreen}[%s]{default} %s : %s", g_Name[author], name, message);
		}
		else {
			MC_PrintToChat(rec, "%s : %s", name, message);
		}
	}
	delete recipients;
} 