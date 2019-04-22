#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike> 
#include <sdktools>
#include <clientprefs>

// Timeleft by Fastmancz, all credits to him ( https://forums.alliedmods.net/showthread.php?t=309700 )
public Plugin myinfo = 
{
	name = "HUDv2",
	author = "xSLOW",
	description = "Server Hud",
	version = "1.1"
};

ConVar MESSAGE1;
ConVar MESSAGE2;
ConVar MESSAGE3;
ConVar slots;
ConVar R_COLOR;
ConVar G_COLOR;
ConVar B_COLOR;

Handle g_HUDv2_Cookie;
bool g_IsHudEnabled[MAXPLAYERS + 1];


public void OnPluginStart()
{
	g_HUDv2_Cookie = RegClientCookie("HudCookie_V2", "HudCookie_V2", CookieAccess_Protected);

	MESSAGE1 = CreateConVar("sm_hud_message1", "MESSAGE 1", "Top-Left first message", FCVAR_NOTIFY);
	MESSAGE2 = CreateConVar("sm_hud_message2", "MESSAGE 2", "Top-Left second message", FCVAR_NOTIFY);
	MESSAGE3 = CreateConVar("sm_hud_message3", "[ MESSAGE 3 ]", "Top-Mid third message", FCVAR_NOTIFY);
	slots = CreateConVar("sm_hud_slots", "32", "Number of server's slots", FCVAR_NOTIFY);
	R_COLOR = CreateConVar("sm_hud_r_color", "97", "First RGB color of the text. You can get more colors from https://www.hexcolortool.com/", FCVAR_NOTIFY);
	G_COLOR = CreateConVar("sm_hud_g_color", "252", "Second RGB color of the text. You can get more colors from https://www.hexcolortool.com/", FCVAR_NOTIFY);
	B_COLOR = CreateConVar("sm_hud_b_color", "0", "Third RGB color of the text. You can get more colors from https://www.hexcolortool.com/", FCVAR_NOTIFY);

	CreateTimer(1.0, TIMER, _, TIMER_REPEAT);
	AutoExecConfig(true, "HUDv2");
	RegConsoleCmd("hud", Command_hud);
}

public void OnClientPutInServer(int client)
{
	g_IsHudEnabled[client] = true;
	char buffer[64];
	GetClientCookie(client, g_HUDv2_Cookie, buffer, sizeof(buffer));
	if(StrEqual(buffer,"0"))
		g_IsHudEnabled[client] = false;
}


public Action Command_hud(int client, int args) 
{
	if(g_IsHudEnabled[client])
	{
		PrintToChat(client, " ★ \x02HUD is now off");
		g_IsHudEnabled[client] = false;
		SetClientCookie(client, g_HUDv2_Cookie, "0");
	}
	else
	{
		PrintToChat(client, " ★ \x04HUD is now on");
		g_IsHudEnabled[client] = true;
		SetClientCookie(client, g_HUDv2_Cookie, "1");
	}
	
}


public Action TIMER(Handle timer, any client)
{
	int clientCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	if (IsClientInGame(i) && !IsFakeClient(i))
	++clientCount;
	char sTime[60];
	int iTimeleft;

	char szTime[30], iMessage1[32], iMessage2[32], iMessage3[32];
	MESSAGE1.GetString(iMessage1, sizeof(iMessage1));
	MESSAGE2.GetString(iMessage2, sizeof(iMessage2));
	MESSAGE3.GetString(iMessage3, sizeof(iMessage3));
	int iR_COLOR = R_COLOR.IntValue;
	int iG_COLOR = G_COLOR.IntValue;
	int iB_COLOR = B_COLOR.IntValue;
	FormatTime(szTime, sizeof(szTime), "%H:%M:%S", GetTime());

	GetMapTimeLeft(iTimeleft);
	if(iTimeleft > 0)
	{
		FormatTime(sTime, sizeof(sTime), "%M:%S", iTimeleft);
		for(int i = 1; i <= MaxClients; i++)
		{
			if(g_IsHudEnabled[i] && IsClientValid(i))
			{
				SetHudTextParams(0.0, 0.0, 2.0, iR_COLOR, iG_COLOR, iB_COLOR, 255, 0, 0.1, 0.0, 0.0);  
				ShowHudText(i, -1, iMessage1);  
	
				SetHudTextParams(0.0, 0.03, 2.0, iR_COLOR, iG_COLOR, iB_COLOR, 255, 0, 0.1, 0.0, 0.0);  
				ShowHudText(i, -1, iMessage2);  
	
				SetHudTextParams(-1.0, 0.075, 2.0, iR_COLOR, iG_COLOR, iB_COLOR, 255, 0, 0.1, 0.0, 0.0);  
				ShowHudText(i, -1, iMessage3);  
	
				char players[60];
				Format(players, sizeof(players), "Players: %d/%d", clientCount, slots.IntValue);
				SetHudTextParams(0.0, 0.06, 1.03, iR_COLOR, iG_COLOR, iB_COLOR, 255, 0, 0.00, 0.0, 0.0);
				ShowHudText(i, -1, players);
	
				char message[60];
				Format(message, sizeof(message), "Timeleft: %s", sTime);
				SetHudTextParams(0.0, 0.09, 1.03, iR_COLOR, iG_COLOR, iB_COLOR, 255, 0, 0.00, 0.0, 0.0);
				ShowHudText(i, -1, message);

				char timp2[60];
				Format(timp2, sizeof(timp2), "Clock: %s", szTime);
				SetHudTextParams(0.0, 0.12, 1.03, iR_COLOR, iG_COLOR, iB_COLOR, 255, 0, 0.00, 0.0, 0.0);
				ShowHudText(i, -1, timp2);
			}
		}
	}
}

stock bool IsClientValid(int client)
{
    if (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
        return true;
    return false;
}
