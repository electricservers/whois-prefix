#include <sourcemod>
#include <chat-processor>
#include <morecolors>
#include <tf2>
#include <whois>

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
	LoadTranslations("whois-prefix.phrases");
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
	g_DB.Query(SQL_OnNameReceived, query, GetClientUserId(client));
}

public void SQL_OnNameReceived(Database db, DBResultSet results, const char[] error, int userid) {
	if (db == null || results == null) {
		LogError("SQL_OnNameReceived: %s", error);
		delete results;
		return;
	}
	
	if (!results.FetchRow()) {
		return;
	}
	
	int client = GetClientOfUserId(userid);
	
	results.FetchString(0, g_Name[client], sizeof(g_Name[]));
}

public void Whois_OnPermanameModified(int client, int target, const char[] name) {
	strcopy(g_Name[target], sizeof(g_Name[]), name);
}

public Action CP_OnChatMessage(int &author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool &processcolors, bool &removecolors) {
	DataPack pack = new DataPack();
	ArrayList al = view_as<ArrayList>(CloneHandle(recipients));
	pack.WriteCell(author);
	pack.WriteCell(al);
	pack.WriteString(flagstring);
	pack.WriteString(name);
	pack.WriteString(message);
	RequestFrame(Frame_OnMessageSent, pack);
	return Plugin_Stop;
}

public void Frame_OnMessageSent(DataPack pack) {
	pack.Reset();
	int author = pack.ReadCell();
	ArrayList recipients = view_as<ArrayList>(pack.ReadCell());
	char flagstring[32];
	pack.ReadString(flagstring, sizeof(flagstring));
	char name[MAX_NAME_LENGTH];
	pack.ReadString(name, sizeof(name));
	char message[256];
	pack.ReadString(message, sizeof(message));
	delete pack;
	
	for (int i = 0; i < recipients.Length; i++) {
		int rec = GetClientOfUserId(recipients.Get(i));
		if (!IsClientInGame(rec)) {
			continue;
		}
		
		char state[32];
		FormatState(author, flagstring, state, sizeof(state));
		
		if (g_Name[author][0] != '\0' && GetAdminFlag(GetUserAdmin(rec), Admin_Generic)) {
			MC_PrintToChatEx(rec, author, "%t%s%s : %s", "Prefix", g_Name[author], state, name, message);
		}
		else {
			MC_PrintToChatEx(rec, author, "%s%s : %s", state, name, message);
		}
	}
	delete recipients;
} 

void FormatState(int client, const char[] flags, char[] buffer, int max) {
	bool isSpec = GetClientTeam(client) == view_as<int>(TFTeam_Spectator);
	
	if (!IsPlayerAlive(client) && !isSpec) {
		StrCat(buffer, max, "*DEAD* ");
	}
	if (StrContains(flags, "TF_Chat_Team") != -1) {
		StrCat(buffer, max, "(TEAM) ");
	}
	if (isSpec) {
		if (StrEqual(flags, "TF_Chat_Spec")) {
			StrCat(buffer, max, "(Spectator) ");
		}
		else {
			StrCat(buffer, max, "*SPEC* ");
		}
	}
}