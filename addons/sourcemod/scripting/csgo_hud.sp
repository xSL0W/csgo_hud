#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>

public Plugin myinfo = 
{
	name = "CSGO HUD",
	author = "xSLOW",
	description = "CSGO HUD",
	version = "3.0"
};

enum {
	RED = 0,
	GREEN,
	BLUE
}

ConVar g_cvarMessage1, g_cvarHUDColors, g_cvarAds, \
        g_cvarTimeHeld, g_cvarTimeBetweenAds, g_cvarEffectType, g_cvarEffectDuration, g_cvarFadeInDuration, \
         g_cvarFadeOutDuration, g_cvarHudStyle;

Handle g_hHUDv2Cookie, gh_SyncHUD = null, gh_SyncHUD_Ads = null;
bool g_bIsHudEnabled[MAXPLAYERS + 1], g_bMapHasTimeLimit = false;
int g_iHUDColors[3], g_iMapTimeLimit, g_iAdsAmt, g_iNextMessage;
char g_sAds[1024], g_cCurrentMessage[128], g_cParts[16][128], g_iMessage1[128];
float g_fTimeHeld;

public void OnPluginStart()
{
	g_hHUDv2Cookie = RegClientCookie("csgo_hud", "csgo_hud", CookieAccess_Protected);

	g_cvarMessage1 = CreateConVar("sm_hud_message1", "MESSAGE 1", "Top-Left first message", FCVAR_NOTIFY);
	g_cvarHUDColors = CreateConVar("sm_hud_rgb", "0,102,204", "RGB of the text. You can get more colors from https://www.hexcolortool.com/", FCVAR_NOTIFY);
	g_cvarHudStyle = CreateConVar("sm_hud_style", "1", "1 = Top Left on screen (where the radar is) and 2 = Bottom Mid on screen");

	g_cvarAds = CreateConVar("sm_hud_Ads", "First;Second;Third;Fourth", "Defines all Ads, separated by semicolons.");
	g_cvarTimeHeld = CreateConVar("sm_hud_timeheld", "2.0", "Amount of time in seconds Ads are held.");
	g_cvarTimeBetweenAds = CreateConVar("sm_hud_timebetweenAds", "2.0", "Amount of time in seconds between Ads.");	
	g_cvarEffectType = CreateConVar("sm_hud_effect_type", "1.0", "0 - Fade In; 1 - Fade out; 2 - Flash", _, true, 0.0, true, 2.0);
	g_cvarEffectDuration = CreateConVar("sm_hud_effect_duration", "0.5", "Duration of the selected effect. Not always aplicable");
	g_cvarFadeInDuration = CreateConVar("sm_hud_fadein_duration", "0.5", "Duration of the selected effect.");
	g_cvarFadeOutDuration = CreateConVar("sm_hud_fadeout_duration", "0.5", "Duration of the selected effect.");
	Format(g_sAds, sizeof(g_sAds), "");

	AutoExecConfig(true, "csgo_hud");

	UpdateHUDColor();
	g_cvarHUDColors.AddChangeHook(cvarChanged_HUDColor);

	CreateTimer(3.0, Timer_Hud, _, TIMER_REPEAT);

	RegConsoleCmd("hud", Command_hud);
    
        for(int i = 1; i <= MaxClients; i++)
            EnableHoodini(i);

	gh_SyncHUD = CreateHudSynchronizer();
	gh_SyncHUD_Ads = CreateHudSynchronizer();
}

public void OnMapStart()
{
	g_bMapHasTimeLimit = false;
	GetMapTimeLimit(g_iMapTimeLimit);
	if(g_iMapTimeLimit > 0)
		g_bMapHasTimeLimit = true;

	g_cvarMessage1.GetString(g_iMessage1, sizeof(g_iMessage1));
}

public void OnPluginEnd()
{
	CloseHandle(gh_SyncHUD);
	CloseHandle(gh_SyncHUD_Ads);
}

public void OnConfigsExecuted() 
{
	GetConVarString(g_cvarAds, g_sAds, sizeof(g_sAds));
	Format(g_sAds, sizeof(g_sAds), "%s", g_sAds);
	g_iAdsAmt = ExplodeString(g_sAds, ";", g_cParts, sizeof(g_cParts), sizeof(g_cParts[]));
	float timeBetweenAds = GetConVarFloat(g_cvarTimeBetweenAds);
	g_fTimeHeld = GetConVarFloat(g_cvarTimeHeld);
	g_iNextMessage = 0;
	CreateTimer(g_fTimeHeld + timeBetweenAds, Timer_Ads, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void EnableHoodini(int client)
{
	if(AreClientCookiesCached(client) && IsClientValid(client))
	{
    	g_bIsHudEnabled[client] = false;
    	char buffer[64];
    	GetClientCookie(client, g_hHUDv2Cookie, buffer, sizeof(buffer));
    	if(StrEqual(buffer,"1"))
		    g_bIsHudEnabled[client] = true;
	}
}

public void OnClientPostAdminCheck(int client)
{
	EnableHoodini(client);
}

public void OnClientCookiesCached(int client)
{
	EnableHoodini(client);
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


public Action Timer_Hud(Handle timer, any client)
{
	int clientCount = 0, iTimeleft;
	char sTime[64], szTime[30], MapTimeLeft[128], iBuffer[1024];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			++clientCount;
	}

	GetMapTimeLeft(iTimeleft);
	FormatTime(szTime, sizeof(szTime), "%H:%M:%S", GetTime());
	FormatTime(sTime, sizeof(sTime), "%M:%S", iTimeleft);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(g_bIsHudEnabled[i] && IsClientValid(i))
		{
			if(g_cvarHudStyle.IntValue == 1)
			{
				if(g_bMapHasTimeLimit)
				{
					if(!(iTimeleft > 0))
						Format(MapTimeLeft,sizeof(MapTimeLeft), "Last Round");
					else
						Format(MapTimeLeft,sizeof(MapTimeLeft), "%s", sTime);
 
					Format(iBuffer, sizeof(iBuffer),"%s\nPlayers: %d/%d\nTimeleft: %s\nClock: %s",g_iMessage1, clientCount, GetMaxHumanPlayers(), MapTimeLeft, szTime);
					SetHudTextParams(0.0, 0.0, 5.2, g_iHUDColors[RED], g_iHUDColors[GREEN], g_iHUDColors[BLUE], 255, 0, 0.0, 0.0, 0.0);  
					ShowSyncHudText(i, gh_SyncHUD, iBuffer);
				}
				else
				{
					Format(iBuffer, sizeof(iBuffer),"%s\nPlayers: %d/%d\nClock: %s",g_iMessage1, clientCount, GetMaxHumanPlayers(), szTime);
					SetHudTextParams(0.0, 0.0, 5.2, g_iHUDColors[RED], g_iHUDColors[GREEN], g_iHUDColors[BLUE], 255, 0, 0.0, 0.0, 0.0);  
					ShowSyncHudText(i, gh_SyncHUD, iBuffer);
				}
			}
			else if(g_cvarHudStyle.IntValue == 2)
			{
				if(g_bMapHasTimeLimit)
				{
					if(!(iTimeleft > 0))
						Format(MapTimeLeft,sizeof(MapTimeLeft), "Last Round");
					else
						Format(MapTimeLeft,sizeof(MapTimeLeft), "%s", sTime);

					Format(iBuffer, sizeof(iBuffer),"Players: %d/%d\nTimeleft: %s\nClock: %s\n%s", clientCount, GetMaxHumanPlayers(), MapTimeLeft, szTime, g_iMessage1);
					SetHudTextParams(-1.0, 1.0, 5.2, g_iHUDColors[RED], g_iHUDColors[GREEN], g_iHUDColors[BLUE], 255, 0, 0.0, 0.0, 0.0);  
					ShowSyncHudText(i, gh_SyncHUD, iBuffer);
				}
				else
				{
					Format(iBuffer, sizeof(iBuffer),"Players: %d/%d\nClock: %s\n%s", clientCount, GetMaxHumanPlayers(), szTime, g_iMessage1);
					SetHudTextParams(-1.0, 1.0, 5.2, g_iHUDColors[RED], g_iHUDColors[GREEN], g_iHUDColors[BLUE], 255, 0, 0.0, 0.0, 0.0);  
					ShowSyncHudText(i, gh_SyncHUD, iBuffer);
				}
			}
        }
        if(!g_bIsHudEnabled[i] && IsClientValid(i))
        {
            Format(iBuffer, sizeof(iBuffer),"%s", g_iMessage1);
            SetHudTextParams(-1.0, 0.075, 5.2, g_iHUDColors[RED], g_iHUDColors[GREEN], g_iHUDColors[BLUE], 255, 0, 0.0, 0.0, 0.0);
            ShowSyncHudText(i, gh_SyncHUD, iBuffer);
        }
	}
}


public Action Timer_Ads(Handle timer)
{
    Format(g_cCurrentMessage, sizeof(g_cCurrentMessage), g_cParts[g_iNextMessage]);

    int effect = GetConVarInt(g_cvarEffectType);
    float effectDuration = GetConVarFloat(g_cvarEffectDuration);
    float fadeIn = GetConVarFloat(g_cvarFadeInDuration);
    float fadeOut = GetConVarFloat(g_cvarFadeOutDuration);
    int iRED = GetRandomInt(0,255);
    int iGREEN = GetRandomInt(0,255);
    int iBLUE = GetRandomInt(0,255);	

    for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(g_cvarHudStyle.IntValue == 1)
			{
                if(g_bIsHudEnabled[i])
                {
                    SetHudTextParams(-1.0, 0.075, g_fTimeHeld, iRED, iGREEN, iBLUE, 255, effect, effectDuration, fadeIn, fadeOut);
                    ShowSyncHudText(i, gh_SyncHUD_Ads, g_cCurrentMessage);  
                }
                else if(!g_bIsHudEnabled[i])
                {
				    SetHudTextParams(-1.0, 1.0, g_fTimeHeld, iRED, iGREEN, iBLUE, 255, effect, effectDuration, fadeIn, fadeOut);
				    ShowSyncHudText(i, gh_SyncHUD_Ads, g_cCurrentMessage);
                }
			}
			else if(g_cvarHudStyle.IntValue == 2)
			{
                if(g_bIsHudEnabled[i])
                {
                    SetHudTextParams(-1.0, 0.075, g_fTimeHeld, iRED, iGREEN, iBLUE, 255, effect, effectDuration, fadeIn, fadeOut);
                    ShowSyncHudText(i, gh_SyncHUD_Ads, g_cCurrentMessage);  
                }
                else if(!g_bIsHudEnabled[i])
                {
				    SetHudTextParams(-1.0, 1.0, g_fTimeHeld, iRED, iGREEN, iBLUE, 255, effect, effectDuration, fadeIn, fadeOut);
				    ShowSyncHudText(i, gh_SyncHUD_Ads, g_cCurrentMessage);
                }
			}
		}
	}
    if (g_iNextMessage != g_iAdsAmt - 1) {
		g_iNextMessage++;
	}
	else
	{
		g_iNextMessage = 0;
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