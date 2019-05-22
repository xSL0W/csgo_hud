#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike> 
#include <sdktools>
#include <clientprefs>

public Plugin myinfo = 
{
	name = "HUDv2",
	author = "xSLOW",
	description = "Server Hud",
	version = "1.4"
};

enum {
	RED = 0,
	GREEN,
	BLUE
}

ConVar g_cvarMessage1;
ConVar g_cvarMessage2;
ConVar g_cvarMessage3;
ConVar g_cvarSlots;
ConVar g_cvarHUDColors;

Handle g_hHUDv2Cookie;
bool g_bIsHudEnabled[MAXPLAYERS + 1];
int g_iHUDColors[3];


public void OnPluginStart()
{
	g_hHUDv2Cookie = RegClientCookie("HudCookie_V2", "HudCookie_V2", CookieAccess_Protected);

	g_cvarMessage1 = CreateConVar("sm_hud_message1", "MESSAGE 1", "Top-Left first message", FCVAR_NOTIFY);
	g_cvarMessage2 = CreateConVar("sm_hud_message2", "MESSAGE 2", "Top-Left second message", FCVAR_NOTIFY);
	g_cvarMessage3 = CreateConVar("sm_hud_message3", "[ MESSAGE 3 ]", "Top-Mid third message", FCVAR_NOTIFY);
	g_cvarSlots = CreateConVar("sm_hud_slots", "32", "Number of server's slots", FCVAR_NOTIFY);
	g_cvarHUDColors = CreateConVar("sm_hud_rgb", "230,57,0", "RGB of the text. You can get more colors from https://www.hexcolortool.com/", FCVAR_NOTIFY);

	AutoExecConfig(true, "HUDv2");

	UpdateHUDColor();
	g_cvarHUDColors.AddChangeHook(cvarChanged_HUDColor);

	CreateTimer(1.0, TIMER, _, TIMER_REPEAT);

	RegConsoleCmd("hud", Command_hud);
}

public void OnClientPutInServer(int client)
{
	g_bIsHudEnabled[client] = true;
	char buffer[64];
	GetClientCookie(client, g_hHUDv2Cookie, buffer, sizeof(buffer));
	if(StrEqual(buffer,"0"))
		g_bIsHudEnabled[client] = false;
}

public void cvarChanged_HUDColor(ConVar convar, const char[] oldValue, const char[] newValue) {
	UpdateHUDColor();
}

public Action Command_hud(int client, int args) 
{
	if(g_bIsHudEnabled[client])
	{
		PrintToChat(client, " ★ \x02HUD is now off");
		g_bIsHudEnabled[client] = false;
		SetClientCookie(client, g_hHUDv2Cookie, "0");
	}
	else
	{
		PrintToChat(client, " ★ \x04HUD is now on");
		g_bIsHudEnabled[client] = true;
		SetClientCookie(client, g_hHUDv2Cookie, "1");
	}
}


public Action TIMER(Handle timer, any client)
{
	int clientCount = 0, iTimeleft;
	char sTime[64], szTime[30], iMessage1[32], iMessage2[32], iMessage3[32], MapTimeLeft[128];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			++clientCount;
	}

	g_cvarMessage1.GetString(iMessage1, sizeof(iMessage1));
	g_cvarMessage2.GetString(iMessage2, sizeof(iMessage2));
	g_cvarMessage3.GetString(iMessage3, sizeof(iMessage3));

	GetMapTimeLeft(iTimeleft);
	FormatTime(szTime, sizeof(szTime), "%H:%M:%S", GetTime());
	FormatTime(sTime, sizeof(sTime), "%M:%S", iTimeleft);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(g_bIsHudEnabled[i] && IsClientValid(i))
		{
			char iBuffer[1024];
			if(!(iTimeleft > 0))
				Format(MapTimeLeft,sizeof(MapTimeLeft), "Last Round");
			else
				Format(MapTimeLeft,sizeof(MapTimeLeft), "%s", sTime);

			Format(iBuffer, sizeof(iBuffer),"%s\n%s\nPlayers: %d/%d\nTimeleft: %s\nClock: %s",iMessage1, iMessage2, clientCount, g_cvarSlots.IntValue, MapTimeLeft, szTime);
			SetHudTextParams(0.0, 0.0, 1.02, g_iHUDColors[RED], g_iHUDColors[GREEN], g_iHUDColors[BLUE], 255, 0, 0.0, 0.0, 0.0);  
			ShowHudText(i, -1, iBuffer);  

			SetHudTextParams(-1.0, 0.075, 1.02, g_iHUDColors[RED], g_iHUDColors[GREEN], g_iHUDColors[BLUE], 255, 0, 0.0, 0.0, 0.0);  
			ShowHudText(i, -1, iMessage3);  
		}
	}
}

bool IsClientValid(int client)
{
    return (0 < client <= MaxClients) && IsClientInGame(client) && !IsFakeClient(client);
}

void UpdateHUDColor() {
	char buffer[16];
	g_cvarHUDColors.GetString(buffer, sizeof(buffer));

	char buffer2[3][4];
	ExplodeString(buffer, ",", buffer2, sizeof(buffer2), sizeof(buffer2[]));
	
	for (int i = 0; i < 3; i++) {
		g_iHUDColors[i] = StringToInt(buffer2[i]);
	}
}