#include <sourcemod>
#include <chat-processor>
#include <morecolors>
#include <tf2>
#include <whois>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.3"

StringMap g_FlagStrings;
Cookie g_ckTogglePrefixes;
bool g_TogglePrefixes[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "Whois Prefix", 
	author = "ampere", 
	description = "Shows a toggleable chat prefix containing whois' permaname", 
	version = PLUGIN_VERSION, 
	url = "https://electricservers.com.ar"
};

public void OnPluginStart() {
	LoadTranslations("whois-prefix.phrases");
	g_ckTogglePrefixes = new Cookie("whoisprefixes_toggle", "Toggle whois-prefix prefixes.", CookieAccess_Private);
	RegAdminCmd("sm_toggleprefix", CMD_TogglePrefix, ADMFLAG_GENERIC);
	PrepareFlagStrings();
}

public void OnClientCookiesCached(int client) {
	char buffer[2];
	g_ckTogglePrefixes.Get(client, buffer, sizeof(buffer));
	g_TogglePrefixes[client] = buffer[0] == '1';
}

public Action CMD_TogglePrefix(int client, int args) {
	if (!AreClientCookiesCached(client))
	{
		ReplyToCommand(client, "[SM] Your settings have not loaded yet.");
		return Plugin_Handled;
	}
	
	g_TogglePrefixes[client] = !g_TogglePrefixes[client];
	
	char buffer[2];
	IntToString(g_TogglePrefixes[client], buffer, sizeof(buffer));
	g_ckTogglePrefixes.Set(client, buffer);
	
	MC_PrintToChat(client, "[SM] Prefixes %s.", g_TogglePrefixes[client] ? "{green}enabled{default}" : "{red}disabled{default}");
	return Plugin_Handled;
}

void PrepareFlagStrings() {
	if (g_FlagStrings == null) {
		g_FlagStrings = new StringMap();
	}
	g_FlagStrings.SetString("TF_Chat_Team_Loc", "(TEAM) ");
	g_FlagStrings.SetString("TF_Chat_Team", "(TEAM) ");
	g_FlagStrings.SetString("TF_Chat_Team_Dead", "*DEAD*(TEAM) ");
	g_FlagStrings.SetString("TF_Chat_Spec", "(Spectator) ");
	g_FlagStrings.SetString("TF_Chat_All", "");
	g_FlagStrings.SetString("TF_Chat_AllDead", "*DEAD* ");
	g_FlagStrings.SetString("TF_Chat_AllSpec", "*SPEC* ");
	g_FlagStrings.SetString("TF_Chat_Coach", "(Coach) ");
}

public Action CP_OnChatMessage(int &author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool &processcolors, bool &removecolors) {
	DataPack pack = new DataPack();
	ArrayList al = view_as<ArrayList>(CloneHandle(recipients));
	pack.WriteCell(GetClientUserId(author));
	pack.WriteCell(al);
	pack.WriteString(flagstring);
	pack.WriteString(name);
	pack.WriteString(message);
	RequestFrame(Frame_OnMessageSent, pack);
	return Plugin_Stop;
}

public void Frame_OnMessageSent(DataPack pack) {
	pack.Reset();
	int author = GetClientOfUserId(pack.ReadCell());
	ArrayList recipients = pack.ReadCell();
	char flagstring[32];
	pack.ReadString(flagstring, sizeof(flagstring));
	char name[MAX_NAME_LENGTH];
	pack.ReadString(name, sizeof(name));
	char message[256];
	pack.ReadString(message, sizeof(message));
	delete pack;
	
	char state[32];
	g_FlagStrings.GetString(flagstring, state, sizeof(state));
	
	char permaname[128];
	Whois_GetPermaname(author, permaname, sizeof(permaname));
	
	for (int i = 0; i < recipients.Length; i++) {
		int rec = GetClientOfUserId(recipients.Get(i));
		if (!IsClientInGame(rec)) {
			continue;
		}
		if (permaname[0] != '\0' && g_TogglePrefixes[rec] && GetAdminFlag(GetUserAdmin(rec), Admin_Generic)) {
			MC_PrintToChatEx(rec, author, "%t", "Chat_Prefix", permaname, state, name, message);
		}
		else {
			MC_PrintToChatEx(rec, author, "%t", "Chat_NoPrefix", state, name, message);
		}
	}
	delete recipients;
} 