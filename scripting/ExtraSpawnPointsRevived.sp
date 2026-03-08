#include <sourcemod>
#include <sdktools>
#include <sdktools_tempents>
#include <sdktools_trace>

#define PL_VERSION "1.3"
#define MAXSPAWNS 256

public Plugin myinfo =
{
	name        = "Extra Spawn Points (Revived)",
	author      = "Christian Deacon (gamemann), moongetsu",
	description = "Enforces a minimum amount of spawns for each team.",
	version     = PL_VERSION,
	url         = "GFLClan.com & AlliedMods.net & github.com/moongetsu"
};

/* ConVars */
ConVar g_cvTSpawns = null;
ConVar g_cvCTSpawns = null;
ConVar g_cvTeams = null;
ConVar g_cvCourse = null;
ConVar g_cvDebug = null;
ConVar g_cvAuto = null;
ConVar g_cvMapStartDelay = null;
ConVar g_cvMoveZAxis = null;
ConVar g_cvReplace = null;
ConVar g_cvEnabled = null;
ConVar g_cvSafetyTrace = null;
ConVar g_cvMaxDist = null;
ConVar g_cvMinInterval = null;
ConVar g_cvDrawDuration = null;

/* Other */
bool g_bMapStart;

int g_iExtraTSpawns[MAXSPAWNS];
int g_iExtraCTSpawns[MAXSPAWNS];
int g_iExtraTSpawnsCount;
int g_iExtraCTSpawnsCount;
int g_iGlowSprite = -1;
float g_fLastAddSpawnsTime = 0.0;

public void OnPluginStart()
{
	// ConVars related to core plugin logic/enable/disable
	g_cvEnabled      = CreateConVar("sm_ESP_enabled", "1", "0 = Disable plugin logic (remove extra spawns), 1 = Enable plugin logic.");

	// ConVars directly controlling spawn count and teams
	g_cvTSpawns      = CreateConVar("sm_ESP_spawns_t", "32", "Amount of spawn points to enforce on the T team.");
	g_cvCTSpawns     = CreateConVar("sm_ESP_spawns_ct", "32", "Amount of spawn points to enforce on the CT team.");
	g_cvTeams        = CreateConVar("sm_ESP_teams", "1", "0 = Disabled, 1 = All Teams, 2 = Terrorist only, 3 = Counter-Terrorist only.");

	// ConVars modifying spawn creation logic
	g_cvReplace      = CreateConVar("sm_ESP_replace", "0", "0 = Only add extra spawns (minimum enforcement). 1 = Enforce exact spawn counts (may remove some map spawns).");
	g_cvCourse       = CreateConVar("sm_ESP_course", "1", "1 = When T or CT spawns are at 0, the opposite team will get double the spawn points.");
	g_cvMaxDist      = CreateConVar("sm_ESP_maxdist", "0.0", "Max distance from team spawn centroid to use when duplicating spawns (0.0 = disabled).");
	g_cvMoveZAxis    = CreateConVar("sm_ESP_zaxis", "16.0", "Increase Z axis by this amount when spawning a spawn point. This may resolve some issues.");
	g_cvSafetyTrace  = CreateConVar("sm_ESP_safetytrace", "1", "1 = Validate new spawn positions with a hull trace to avoid stuck/invalid spots.");

	// ConVars controlling operation timing and automation
	g_cvMinInterval     = CreateConVar("sm_ESP_min_interval", "1.0", "Minimum number of seconds between spawn rebuilds (0.0 = no limit).");
	g_cvMapStartDelay   = CreateConVar("sm_ESP_mapstart_delay", "1.0", "The delay of the timer on map start to add in spawn points.");
	g_cvAuto            = CreateConVar("sm_ESP_auto", "0", "1 = Add the spawn points as soon as a ConVar is changed.");

	// Debugging & visual feedback
	g_cvDebug        = CreateConVar("sm_ESP_debug", "0", "0 = No debug logs, 1 = Normal logs, 2 = Very verbose logs.");
	g_cvDrawDuration = CreateConVar("sm_ESP_draw_duration", "5.0", "Duration (in seconds) of glow markers for sm_esp_drawspawns.");
	/* AlliedMods Release ConVar (required). */
	CreateConVar("sm_ESP_version", PL_VERSION, "Extra Spawn Points version.");

	/* ConVar change hooks (for auto-regeneration). */
	HookConVarChange(g_cvTSpawns, ConVarChanged_ExtraSpawns);
	HookConVarChange(g_cvCTSpawns, ConVarChanged_ExtraSpawns);
	HookConVarChange(g_cvTeams, ConVarChanged_ExtraSpawns);
	HookConVarChange(g_cvCourse, ConVarChanged_ExtraSpawns);
	HookConVarChange(g_cvMoveZAxis, ConVarChanged_ExtraSpawns);
	HookConVarChange(g_cvReplace, ConVarChanged_ExtraSpawns);
	HookConVarChange(g_cvAuto, ConVarChanged_ExtraSpawns);
	
	/* Commands. */
	RegAdminCmd("sm_addspawns", Command_AddSpawns, ADMFLAG_ROOT);
	RegAdminCmd("sm_getspawncount", Command_GetSpawnCount, ADMFLAG_SLAY);
	RegAdminCmd("sm_listspawns", Command_ListSpawns, ADMFLAG_SLAY);
	RegAdminCmd("sm_esp_enable", Command_EnableESP, ADMFLAG_ROOT);
	RegAdminCmd("sm_esp_disable", Command_DisableESP, ADMFLAG_ROOT);
	RegAdminCmd("sm_esp_reload", Command_ReloadESP, ADMFLAG_ROOT);
	RegAdminCmd("sm_esp_drawspawns", Command_DrawSpawns, ADMFLAG_SLAY);
	
	/* Automatically Execute Config. */
	AutoExecConfig(true, "esp/plugin.ESP");
}

public void OnMapStart()
{
	/* Set Map Start bool. This is executed BEFORE OnConfigsExecuted() via https://sm.alliedmods.net/new-api/sourcemod/OnConfigsExecuted so it should be fine. */
	g_bMapStart = false;
	g_iExtraTSpawnsCount = 0;
	g_iExtraCTSpawnsCount = 0;
	g_iGlowSprite = -1;
	g_fLastAddSpawnsTime = 0.0;
}

public Action Command_AddSpawns(int iClient, int iArgs) 
{
	AddMapSpawns();
	
	if (iClient == 0) 
	{
		PrintToServer("[ESP] Added map spawns!");
	} 
	else 
	{
		PrintToChat(iClient, "\x02[ESP] \x03Added map spawns!");
	}
	
	return Plugin_Handled;
}

public Action Command_GetSpawnCount(int iClient, int iArgs)
{
	int idTSpawns = getTeamCount(2);
	int idCTSpawns = getTeamCount(3);
	
	ReplyToCommand(iClient, "[ESP]There are now %d CT spawns and %d T spawns", idCTSpawns, idTSpawns);
	
	return Plugin_Handled;
}

public Action Command_ListSpawns(int iClient, int iArgs)
{
	float fVec[3];
	float fAng[3];

	int i = 1;
	int iEnt = -1;

	PrintToConsole(iClient, "Listing T spawns...");

	while ((iEnt = FindEntityByClassname(iEnt, "info_player_terrorist")) != -1)
	{
		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fVec);
		GetEntPropVector(iEnt, Prop_Data, "m_angRotation", fAng);

		PrintToConsole(iClient, "T Spawn #%d - Vector => %f, %f, %f. Angle => %f, %f, %f.", i, fVec[0], fVec[1], fVec[2], fAng[0], fAng[1], fAng[2]);

		i++;
	}

	i = 1;
	iEnt = -1;

	PrintToConsole(iClient, "Listing CT spawns...");

	while  ((iEnt = FindEntityByClassname(iEnt, "info_player_counterterrorist")) != -1)
	{
		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fVec);
		GetEntPropVector(iEnt, Prop_Data, "m_angRotation", fAng);

		PrintToConsole(iClient, "CT Spawn #%d - Vector => %f, %f, %f. Angle => %f, %f, %f.", i, fVec[0], fVec[1], fVec[2], fAng[0], fAng[1], fAng[2]);

		i++;
	}

	return Plugin_Handled;
}

public Action Command_EnableESP(int iClient, int iArgs)
{
	SetConVarBool(g_cvEnabled, true);
	ReplyToCommand(iClient, "[ESP] Plugin logic enabled.");

	if (g_bMapStart)
	{
		AddMapSpawns();
	}

	return Plugin_Handled;
}

public Action Command_DisableESP(int iClient, int iArgs)
{
	SetConVarBool(g_cvEnabled, false);
	RemoveExtraSpawns();

	ReplyToCommand(iClient, "[ESP] Plugin logic disabled and extra spawns removed.");

	return Plugin_Handled;
}

public Action Command_ReloadESP(int iClient, int iArgs)
{
	if (!g_bMapStart)
	{
		ReplyToCommand(iClient, "[ESP] Map has not fully started yet.");
		return Plugin_Handled;
	}

	AddMapSpawns();
	ReplyToCommand(iClient, "[ESP] Spawn points reloaded.");

	return Plugin_Handled;
}

public Action Command_DrawSpawns(int iClient, int iArgs)
{
	if (iClient <= 0 || !IsClientInGame(iClient))
	{
		ReplyToCommand(iClient, "[ESP] This command can only be used in-game by a player.");
		return Plugin_Handled;
	}

	if (g_iGlowSprite == -1)
	{
		g_iGlowSprite = PrecacheModel("sprites/white.vmt");
	}

	float fVec[3];
	float flDuration = g_cvDrawDuration.FloatValue;

	int iEnt = -1;

	/* Draw T spawns. */
	while ((iEnt = FindEntityByClassname(iEnt, "info_player_terrorist")) != -1)
	{
		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fVec);
		TE_SetupGlowSprite(fVec, g_iGlowSprite, flDuration, 16.0, 255);
		TE_SendToClient(iClient);
	}

	iEnt = -1;

	/* Draw CT spawns. */
	while ((iEnt = FindEntityByClassname(iEnt, "info_player_counterterrorist")) != -1)
	{
		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fVec);
		TE_SetupGlowSprite(fVec, g_iGlowSprite, flDuration, 16.0, 255);
		TE_SendToClient(iClient);
	}

	ReplyToCommand(iClient, "[ESP] Drew glow markers at all T/CT spawn points.");

	return Plugin_Handled;
}

public void OnConfigsExecuted() 
{	
	if (!g_bMapStart) 
	{
		/* Optional per-map overrides: cfg/sourcemod/esp/plugin.ESP_<mapname>.cfg */
		char sMap[64];
		char sCfg[96];
		GetCurrentMap(sMap, sizeof(sMap));
		Format(sCfg, sizeof(sCfg), "esp/plugin.ESP_%s", sMap);
		AutoExecConfig(false, sCfg);

		CreateTimer(g_cvMapStartDelay.FloatValue, timer_DelayAddSpawnPoints);

		g_bMapStart = true;
	}
	
	if (g_cvAuto.BoolValue && g_bMapStart) 
	{
		AddMapSpawns();
	}
}

public Action timer_DelayAddSpawnPoints(Handle hTimer) 
{
	AddMapSpawns();

	return Plugin_Stop;
}

public void ConVarChanged_ExtraSpawns(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	/* Only react once the map has started and auto mode is enabled. */
	if (!g_bMapStart || !g_cvAuto.BoolValue || !g_cvEnabled.BoolValue)
	{
		return;
	}

	AddMapSpawns();
}

stock void RemoveExtraSpawns()
{
	for (int i = 0; i < g_iExtraTSpawnsCount; i++)
	{
		int ent = g_iExtraTSpawns[i];

		if (IsValidEntity(ent))
		{
			AcceptEntityInput(ent, "Kill");
		}
	}

	g_iExtraTSpawnsCount = 0;

	for (int i = 0; i < g_iExtraCTSpawnsCount; i++)
	{
		int ent = g_iExtraCTSpawns[i];

		if (IsValidEntity(ent))
		{
			AcceptEntityInput(ent, "Kill");
		}
	}

	g_iExtraCTSpawnsCount = 0;
}

stock void ESP_Log(int iLevel, const char[] sMsg, any ...)
{
	int debugLevel = g_cvDebug.IntValue;

	if (debugLevel <= 0 || iLevel > debugLevel)
	{
		return;
	}

	char buffer[256];
	VFormat(buffer, sizeof(buffer), sMsg, 3);
	LogMessage("%s", buffer);
}

stock bool IsSpawnLocationSafe(const float vecPos[3])
{
	if (!g_cvSafetyTrace.BoolValue)
	{
		return true;
	}

	float vecMins[3] = { -16.0, -16.0, 0.0 };
	float vecMaxs[3] = { 16.0, 16.0, 72.0 };

	Handle hTrace = TR_TraceHull(vecPos, vecPos, vecMins, vecMaxs, MASK_PLAYERSOLID);

	bool bHit = TR_DidHit(hTrace);
	CloseHandle(hTrace);

	return !bHit;
}

stock void AddMapSpawns() 
{
	if (!g_cvEnabled.BoolValue)
	{
		RemoveExtraSpawns();
		ESP_Log(1, "[ESP]AddMapSpawns() aborted because plugin is disabled.");
		return;
	}

	float flNow = GetEngineTime();
	float flMinInterval = g_cvMinInterval.FloatValue;

	if (flMinInterval > 0.0 && g_fLastAddSpawnsTime > 0.0 && (flNow - g_fLastAddSpawnsTime) < flMinInterval)
	{
		ESP_Log(2, "[ESP]AddMapSpawns() rate-limited (delta=%.3f, min=%.3f).", flNow - g_fLastAddSpawnsTime, flMinInterval);
		return;
	}

	g_fLastAddSpawnsTime = flNow;

	/* Remove any extra spawns previously created by this plugin. */
	RemoveExtraSpawns();

	int iTSpawns = 0;
	int iCTSpawns = 0;
	
	int iToSpawnT = g_cvTSpawns.IntValue;
	int iToSpawnCT = g_cvCTSpawns.IntValue;
	
	/* Clamp requested spawn counts to our buffer size. */
	if (iToSpawnT > MAXSPAWNS)
	{
		iToSpawnT = MAXSPAWNS;
		
		ESP_Log(1, "[ESP]Clamping requested T spawns to %d (MAXSPAWNS).", MAXSPAWNS);
	}
	
	if (iToSpawnCT > MAXSPAWNS)
	{
		iToSpawnCT = MAXSPAWNS;
		
		ESP_Log(1, "[ESP]Clamping requested CT spawns to %d (MAXSPAWNS).", MAXSPAWNS);
	}
	
	float fVecCT[MAXSPAWNS][3];
	float fVecT[MAXSPAWNS][3];

	float fAngT[MAXSPAWNS][3];
	float fAngCT[MAXSPAWNS][3];

	int iEntTList[MAXSPAWNS];
	int iEntCTList[MAXSPAWNS];

	int iSpawnEnt = -1;

	/* Collect all the current T spawns. */
	while ((iSpawnEnt = FindEntityByClassname(iSpawnEnt, "info_player_terrorist")) != -1)
	{
		if (iTSpawns >= MAXSPAWNS)
		{
			ESP_Log(1, "[ESP]Maximum T spawn buffer (%d) reached; remaining T spawns are ignored.", MAXSPAWNS);
			
			break;
		}

		iEntTList[iTSpawns] = iSpawnEnt;

		GetEntPropVector(iSpawnEnt, Prop_Data, "m_vecOrigin", fVecT[iTSpawns]);
		GetEntPropVector(iSpawnEnt, Prop_Data, "m_angRotation", fAngT[iTSpawns]);

		if (g_cvMoveZAxis.FloatValue > 0.0)
		{
			fVecT[iTSpawns][2] += g_cvMoveZAxis.FloatValue;
		}

		iTSpawns++;
	}	
	
	/* Collect all the current CT spawns. */
	iSpawnEnt = -1;

	while ((iSpawnEnt = FindEntityByClassname(iSpawnEnt, "info_player_counterterrorist")) != -1)
	{
		if (iCTSpawns >= MAXSPAWNS)
		{
			ESP_Log(1, "[ESP]Maximum CT spawn buffer (%d) reached; remaining CT spawns are ignored.", MAXSPAWNS);
			
			break;
		}

		iEntCTList[iCTSpawns] = iSpawnEnt;

		GetEntPropVector(iSpawnEnt, Prop_Data, "m_vecOrigin", fVecCT[iCTSpawns]);
		GetEntPropVector(iSpawnEnt, Prop_Data, "m_angRotation", fAngCT[iCTSpawns]);

		if (g_cvMoveZAxis.FloatValue > 0.0)
		{
			fVecCT[iCTSpawns][2] += g_cvMoveZAxis.FloatValue;
		}

		iCTSpawns++;
	}
	
	/* Double the spawn count if Course Mode is enabled along with the amount of spawn points being above 0. */
	if (g_cvCourse.BoolValue) 
	{
		if (iCTSpawns == 0 && iTSpawns > 0) 
		{
			iToSpawnT *= 2;
		}
		
		if (iTSpawns == 0 && iCTSpawns > 0) 
		{
			iToSpawnCT *= 2;
		}
	}
	
	/* Re-clamp after course adjustments. */
	if (iToSpawnT > MAXSPAWNS)
	{
		iToSpawnT = MAXSPAWNS;
		
		ESP_Log(1, "[ESP]Clamping course-adjusted T spawns to %d (MAXSPAWNS).", MAXSPAWNS);
	}
	
	if (iToSpawnCT > MAXSPAWNS)
	{
		iToSpawnCT = MAXSPAWNS;
		
		ESP_Log(1, "[ESP]Clamping course-adjusted CT spawns to %d (MAXSPAWNS).", MAXSPAWNS);
	}

	ESP_Log(1, "[ESP]There are %d/%d CT points and %d/%d T points before modifications.", iCTSpawns, iToSpawnCT, iTSpawns, iToSpawnT);

	float flMaxDist = g_cvMaxDist.FloatValue;
	float vCenterT[3] = {0.0, 0.0, 0.0};
	float vCenterCT[3] = {0.0, 0.0, 0.0};

	if (iTSpawns > 0)
	{
		for (int i = 0; i < iTSpawns; i++)
		{
			vCenterT[0] += fVecT[i][0];
			vCenterT[1] += fVecT[i][1];
			vCenterT[2] += fVecT[i][2];
		}

		vCenterT[0] /= float(iTSpawns);
		vCenterT[1] /= float(iTSpawns);
		vCenterT[2] /= float(iTSpawns);
	}

	if (iCTSpawns > 0)
	{
		for (int i = 0; i < iCTSpawns; i++)
		{
			vCenterCT[0] += fVecCT[i][0];
			vCenterCT[1] += fVecCT[i][1];
			vCenterCT[2] += fVecCT[i][2];
		}

		vCenterCT[0] /= float(iCTSpawns);
		vCenterCT[1] /= float(iCTSpawns);
		vCenterCT[2] /= float(iCTSpawns);
	}

	bool bReplace = g_cvReplace.BoolValue;
	
	/* Handle CT spawns. */
	if (g_cvTeams.IntValue == 1 || g_cvTeams.IntValue == 3)
	{
		if (!bReplace)
		{
			/* Only add extra CT spawns if below target. */
			if (iCTSpawns > 0 && iCTSpawns < iToSpawnCT) 
			{
				for (int i = iCTSpawns; i < iToSpawnCT; i++)
				{
					int iEnt = CreateEntityByName("info_player_counterterrorist");
					
					if (iEnt != -1 && DispatchSpawn(iEnt))
					{
						float vPos[3];
						float vAng[3];
						bool bFound = false;
						int iAttempts = 0;

						while (iAttempts < 8)
						{
							int iRandSpawn = GetRandomInt(0, iCTSpawns - 1);
							vPos[0] = fVecCT[iRandSpawn][0];
							vPos[1] = fVecCT[iRandSpawn][1];
							vPos[2] = fVecCT[iRandSpawn][2];

							vAng[0] = fAngCT[iRandSpawn][0];
							vAng[1] = fAngCT[iRandSpawn][1];
							vAng[2] = fAngCT[iRandSpawn][2];

							bool bTooFar = (flMaxDist > 0.0 && GetVectorDistance(vPos, vCenterCT) > flMaxDist);
							bool bUnsafe = !IsSpawnLocationSafe(vPos);

							if (!bTooFar && !bUnsafe)
							{
								bFound = true;
								break;
							}

							iAttempts++;
						}

						if (!bFound)
						{
							ESP_Log(2, "[ESP]Unable to find safe CT spawn position for extra spawn.");
							continue;
						}

						TeleportEntity(iEnt, vPos, vAng, NULL_VECTOR);

						if (g_iExtraCTSpawnsCount < MAXSPAWNS)
						{
							g_iExtraCTSpawns[g_iExtraCTSpawnsCount++] = iEnt;
						}
						
						ESP_Log(1, "[ESP]+1 CT spawn added.");
					}
				}
			}
		}
		else
		{
			/* Replace mode enforces an exact CT spawn count. */
			if (iCTSpawns > iToSpawnCT)
			{
				int iToRemove = iCTSpawns - iToSpawnCT;

				while (iToRemove > 0 && iCTSpawns > 0)
				{
					int idx = GetRandomInt(0, iCTSpawns - 1);
					int ent = iEntCTList[idx];

					if (IsValidEntity(ent))
					{
						AcceptEntityInput(ent, "Kill");
					}

					for (int j = idx; j < iCTSpawns - 1; j++)
					{
						iEntCTList[j] = iEntCTList[j + 1];
					}

					iCTSpawns--;
					iToRemove--;
				}
			}
			else if (iCTSpawns < iToSpawnCT && iCTSpawns > 0)
			{
				for (int i = iCTSpawns; i < iToSpawnCT; i++)
				{
					int iEnt = CreateEntityByName("info_player_counterterrorist");
					
					if (iEnt != -1 && DispatchSpawn(iEnt))
					{
						float vPos[3];
						float vAng[3];
						bool bFound = false;
						int iAttempts = 0;

						while (iAttempts < 8)
						{
							int iRandSpawn = GetRandomInt(0, iCTSpawns - 1);
							vPos[0] = fVecCT[iRandSpawn][0];
							vPos[1] = fVecCT[iRandSpawn][1];
							vPos[2] = fVecCT[iRandSpawn][2];

							vAng[0] = fAngCT[iRandSpawn][0];
							vAng[1] = fAngCT[iRandSpawn][1];
							vAng[2] = fAngCT[iRandSpawn][2];

							bool bTooFar = (flMaxDist > 0.0 && GetVectorDistance(vPos, vCenterCT) > flMaxDist);
							bool bUnsafe = !IsSpawnLocationSafe(vPos);

							if (!bTooFar && !bUnsafe)
							{
								bFound = true;
								break;
							}

							iAttempts++;
						}

						if (!bFound)
						{
							ESP_Log(2, "[ESP]Unable to find safe CT spawn position for replace-mode extra spawn.");
							continue;
						}

						TeleportEntity(iEnt, vPos, vAng, NULL_VECTOR);

						if (g_iExtraCTSpawnsCount < MAXSPAWNS)
						{
							g_iExtraCTSpawns[g_iExtraCTSpawnsCount++] = iEnt;
						}
						
						ESP_Log(1, "[ESP]+1 CT spawn added (replace mode).");
					}
				}
			}
		}
	}
	
	/* Handle T spawns. */
	if (g_cvTeams.IntValue == 1 || g_cvTeams.IntValue == 2) 
	{
		if (!bReplace)
		{
			/* Only add extra T spawns if below target. */
			if (iTSpawns > 0 && iTSpawns < iToSpawnT) 
			{
				for (int i = iTSpawns; i < iToSpawnT; i++)
				{
					int iEnt = CreateEntityByName("info_player_terrorist");
					
					if (iEnt != -1 && DispatchSpawn(iEnt))
					{
						float vPos[3];
						float vAng[3];
						bool bFound = false;
						int iAttempts = 0;

						while (iAttempts < 8)
						{
							int iRandSpawn = GetRandomInt(0, iTSpawns - 1);
							vPos[0] = fVecT[iRandSpawn][0];
							vPos[1] = fVecT[iRandSpawn][1];
							vPos[2] = fVecT[iRandSpawn][2];

							vAng[0] = fAngT[iRandSpawn][0];
							vAng[1] = fAngT[iRandSpawn][1];
							vAng[2] = fAngT[iRandSpawn][2];

							bool bTooFar = (flMaxDist > 0.0 && GetVectorDistance(vPos, vCenterT) > flMaxDist);
							bool bUnsafe = !IsSpawnLocationSafe(vPos);

							if (!bTooFar && !bUnsafe)
							{
								bFound = true;
								break;
							}

							iAttempts++;
						}

						if (!bFound)
						{
							ESP_Log(2, "[ESP]Unable to find safe T spawn position for extra spawn.");
							continue;
						}

						TeleportEntity(iEnt, vPos, vAng, NULL_VECTOR);

						if (g_iExtraTSpawnsCount < MAXSPAWNS)
						{
							g_iExtraTSpawns[g_iExtraTSpawnsCount++] = iEnt;
						}
						
						ESP_Log(1, "[ESP]+1 T spawn added.");
					}
				}
			}
		}
		else
		{
			/* Replace mode enforces an exact T spawn count. */
			if (iTSpawns > iToSpawnT)
			{
				int iToRemove = iTSpawns - iToSpawnT;

				while (iToRemove > 0 && iTSpawns > 0)
				{
					int idx = GetRandomInt(0, iTSpawns - 1);
					int ent = iEntTList[idx];

					if (IsValidEntity(ent))
					{
						AcceptEntityInput(ent, "Kill");
					}

					for (int j = idx; j < iTSpawns - 1; j++)
					{
						iEntTList[j] = iEntTList[j + 1];
					}

					iTSpawns--;
					iToRemove--;
				}
			}
			else if (iTSpawns < iToSpawnT && iTSpawns > 0)
			{
				for (int i = iTSpawns; i < iToSpawnT; i++)
				{
					int iEnt = CreateEntityByName("info_player_terrorist");
					
					if (iEnt != -1 && DispatchSpawn(iEnt))
					{
						float vPos[3];
						float vAng[3];
						bool bFound = false;
						int iAttempts = 0;

						while (iAttempts < 8)
						{
							int iRandSpawn = GetRandomInt(0, iTSpawns - 1);
							vPos[0] = fVecT[iRandSpawn][0];
							vPos[1] = fVecT[iRandSpawn][1];
							vPos[2] = fVecT[iRandSpawn][2];

							vAng[0] = fAngT[iRandSpawn][0];
							vAng[1] = fAngT[iRandSpawn][1];
							vAng[2] = fAngT[iRandSpawn][2];

							bool bTooFar = (flMaxDist > 0.0 && GetVectorDistance(vPos, vCenterT) > flMaxDist);
							bool bUnsafe = !IsSpawnLocationSafe(vPos);

							if (!bTooFar && !bUnsafe)
							{
								bFound = true;
								break;
							}

							iAttempts++;
						}

						if (!bFound)
						{
							ESP_Log(2, "[ESP]Unable to find safe T spawn position for replace-mode extra spawn.");
							continue;
						}

						TeleportEntity(iEnt, vPos, vAng, NULL_VECTOR);

						if (g_iExtraTSpawnsCount < MAXSPAWNS)
						{
							g_iExtraTSpawns[g_iExtraTSpawnsCount++] = iEnt;
						}
						
						ESP_Log(1, "[ESP]+1 T spawn added (replace mode).");
					}
				}
			}
		}
	}
	
	/* Finally, enter one last debug message. */
	int idTSpawns = getTeamCount(2);
	int idCTSpawns = getTeamCount(3);
	ESP_Log(1, "[ESP]There are now %d CT spawns and %d T spawns", idCTSpawns, idTSpawns);
}

/* Gets the spawn count for a specific team (e.g. CT and T). */
stock int getTeamCount(int iTeam)
{
	int iAmount = 0;
	int iEnt = -1;
	
	/* Receive all the T Spawns. */
	if (iTeam == 2)
	{
		while ((iEnt = FindEntityByClassname(iEnt, "info_player_terrorist")) != -1)
		{
			iAmount++;
		}
	}
	
	/* Receive all the CT Spawns. */
	if (iTeam == 3)
	{
		while ((iEnt = FindEntityByClassname(iEnt, "info_player_counterterrorist")) != -1)
		{
			iAmount++;
		}
	}
	
	return iAmount;
}