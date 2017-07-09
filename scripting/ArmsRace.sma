#pragma semicolon 1
#pragma ctrlchar '\'

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <cstrike>
#include <hamsandwich>
#include <reapi>

#define VERSION "0.1"

#define MAX_LEVEL (sizeof(WEAPON_ORDER) - 1)
#define WEAPON_ORDER[%0][$%1] WEAPON_ORDER[%0][WpnOrder_%1]
#define AMMO_DATA[%0][$%1] AMMO_DATA[%0][Ammo_%1]

new const SOUND_DEATHCAM[][] = 
{
	"9up/deathcam_gg_01.wav",
	"9up/deathcam_gg_02.wav",
	"9up/deathcam_gg_03.wav"
};

new const SOUND_LEVELUP[] = "9up/armsrace_level_up.wav";
new const SOUND_DEMOTE[] = "9up/armsrace_demoted.wav";
new const SOUND_LEADER[] = "9up/armsrace_become_leader_match.wav";
new const MUSIC_MVP[] = "sound/9up/roundmvpanthem_01.mp3";

// Objective classname
new const OBJECTIVE_CLASSNAME[][] =
{
	"func_bomb_target",
	"info_bomb_target",
	"info_vip_start",
	"func_vip_safetyzone",
	"func_escapezone",
	"hostage_entity",
	"monster_scientist",
	"func_hostage_rescue",
	"info_hostage_rescue",
	"func_buyzone"
};

// Weapon name
new const WEAPON_NAME[][] =
{
	"",
	"P228",
	"",
	"Scout",
	"HE Grenade",
	"XM1014",
	"C4",
	"MAC10",
	"AUG",
	"Smoke Grenade",
	"Dual Elites",
	"Fiveseven",
	"UMP45",
	"SG550",
	"Galil",
	"Famas",
	"USP",
	"Glock 18",
	"AWP",
	"MP5",
	"M249",
	"M3",
	"M4A1",
	"TMP",
	"G3SG1",
	"Flashbang",
	"Deagle",
	"SG552",
	"AK47",
	"Knife",
	"P90"
};

// Weapon ammo type
new const WEAPON_AMMOTYPE[] =
{
	0,
	9, //p228
	0,
	2, //scout
	12, //hegrenade
	5, //xm1014
	14, //c4
	6, //mac10
	4, //aug
	13, //smoke
	10, //elite
	7, //fiveseven
	6, //ump45
	4, //sg550
	4, //galil
	4, //famas
	6, //usp
	10, //glock
	1, //awp
	10, //mp5
	3, //m249
	5, //m3
	4, //m4a1
	10, //tmp
	2, //g3sg1
	11, //flash
	8, //deagle
	4, //sg552
	2, //ak47
	0,
	7 //p90
};

// Ammo data
enum _:AmmoData
{
	Ammo_Name[16],
	Ammo_Amount,
	Ammo_Max
};

new const AMMO_DATA[][AmmoData] = 
{
	{"", -1, -1},
	{"338magnum", 10, 30},
	{"762nato", 30, 90},
	{"556natobox", 30, 200},
	{"556nato", 30, 90},
	{"buckshot", 8, 32},
	{"45acp", 12, 100},
	{"57mm", 50, 100},
	{"50ae", 7, 35},
	{"357sig", 13, 52},
	{"9mm", 30, 100},
	{"Flashbang", 1, 2},
	{"HEGrenade", 1, 10},
	{"SmokeGrenade", 1, 1},
	{"C4", 1, 1},
};

enum _:WeaponOrder
{
	WpnOrder_Id,
	WpnOrder_Xp
};

// Weapon order
new const WEAPON_ORDER[][WeaponOrder] = 
{
	{CSW_TMP, 3},
	{CSW_MAC10, 3},
	{CSW_UMP45, 3},
	{CSW_MP5NAVY, 3},
	{CSW_P90, 3},
	
	{CSW_GALIL, 3},
	{CSW_FAMAS, 3},
	{CSW_AK47, 3},
	{CSW_M4A1, 3},
	{CSW_SG552, 3},
	{CSW_AUG, 3},

	{CSW_M3, 3},
	{CSW_XM1014, 3},
	
	{CSW_SCOUT, 3},
	{CSW_SG550, 3},
	{CSW_G3SG1, 3},
	{CSW_AWP, 3},
	
	{CSW_M249, 3},

	{CSW_GLOCK18, 3},
	{CSW_USP, 3},
	{CSW_P228, 3},
	{CSW_FIVESEVEN, 3},
	{CSW_ELITE, 3},
	{CSW_DEAGLE, 3},
	
	{CSW_HEGRENADE, 3},
	{CSW_KNIFE, 1}
};

enum (+=50)
{
	TASK_UPDATEHUD = 0,
	TASK_PROTECTION,
	TASK_VOTEMAP
}

new g_fwEntSpawn;

new g_hudSyncObj[3];

new g_level[MAX_PLAYERS + 1];
new g_xp[MAX_PLAYERS + 1];
new bool:g_isLeader[MAX_PLAYERS + 1];
new bool:g_hasProtection[MAX_PLAYERS + 1];

new g_teamLeader[3];
new bool:g_isRoundEnded;
new bool:g_editMode;

enum _:SpawnPointData
{
	Float:SP_Origin[3],
	Float:SP_Angles[3],
	SP_Team
};

new Array:g_spawnPoints;
new g_numSpawns;

public plugin_precache()
{
	for (new i = 0; i < sizeof SOUND_DEATHCAM; i++)
		precache_sound(SOUND_DEATHCAM[i]);
	
	precache_sound(SOUND_LEVELUP);
	precache_sound(SOUND_DEMOTE);
	precache_sound(SOUND_LEADER);
	
	precache_generic(MUSIC_MVP);
	
	g_fwEntSpawn = register_forward(FM_Spawn, "OnEntSpawn");
	
	g_spawnPoints = ArrayCreate(SpawnPointData);
	
	loadMapSpawnPoints();
}

public plugin_init()
{
	register_plugin("Arms Race", VERSION, "Holla");
	
	register_forward(FM_GetGameDescription, "OnGetGameDesc");
	unregister_forward(FM_Spawn, g_fwEntSpawn);
	
	register_event("DeathMsg", "OnEventDeathMsg", "a");
	register_event("TeamInfo", "OnEventTeamInfo", "a");
	
	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Post", 1, true);
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled", 0, true);
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled_Post", 1, true);
	RegisterHam(Ham_TraceAttack, "player", "OnPlayerTraceAttack", 0, true);
	RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage", 0, true);
	RegisterHam(Ham_Touch, "armoury_entity", "OnArmouryTouch");
	
	RegisterHookChain(RG_CSGameRules_GetPlayerSpawnSpot, "OnGetPlayerSpawnSpot", 0);
	
	register_menucmd(register_menuid("Player Info"), 1023, "HandlePlayerInfo");
	
	register_clcmd("drop", "CmdDrop");
	
	register_clcmd("spawn_editor", "CmdSpawnEditor", ADMIN_MAP);
	register_clcmd("spawn_create", "CmdSpawnCreate", ADMIN_MAP);
	register_clcmd("spawn_remove", "CmdSpawnRemove", ADMIN_MAP);
	register_clcmd("spawn_save", "CmdSpawnSave", ADMIN_MAP);
	
	set_task(0.5, "TaskUpdateHud", TASK_UPDATEHUD, _, _, "b");
	
	g_hudSyncObj[0] = CreateHudSyncObj();
	g_hudSyncObj[1] = CreateHudSyncObj();
	g_hudSyncObj[2] = CreateHudSyncObj();
}

public plugin_cfg()
{
	static configsDir[128];
	get_configsdir(configsDir, charsmax(configsDir));
	
	server_cmd("exec %s/armsrace.cfg", configsDir);
	server_exec();
}

public CmdDrop(id)
{
	return PLUGIN_HANDLED;
}

public CmdSpawnEditor(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	
	new arg[5];
	read_argv(1, arg, charsmax(arg));
	
	// enable
	if (str_to_num(arg))
	{
		for (new i = 0; i < g_numSpawns; i++)
		{
			createSpawnPointEntity(i);
		}
		
		g_editMode = true;
		
		client_print(0, print_chat, "* Spawn editor has been ENABLED.");
	}
	else
	{
		remove_entity_name("spawnpoint");
		
		g_editMode = false;
		
		client_print(0, print_chat, "* Spawn editor has been DISABLED.");
	}
	
	return PLUGIN_HANDLED;
}

public CmdSpawnCreate(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	
	if (!g_editMode)
	{
		client_print(id, print_console, "You must enable spawn editor before you can use this command.");
		return PLUGIN_HANDLED;
	}
	
	new arg[5];
	read_argv(1, arg, charsmax(arg));
	
	new team = str_to_num(arg);
	
	static Float:origin[3], Float:angles[3];
	pev(id, pev_origin, origin);
	pev(id, pev_angles, angles);
	
	static data[SpawnPointData];
	data[SP_Origin] = origin;
	data[SP_Angles] = angles;
	data[SP_Team] = team;
	
	ArrayPushArray(g_spawnPoints, data);
	g_numSpawns++;
	
	new index = g_numSpawns - 1;
	createSpawnPointEntity(index);
	
	client_print(0, print_chat, "* Create spawn point #%d", index);
	return PLUGIN_HANDLED;
}

public CmdSpawnRemove(id, level, cid)
{
	if (!cmd_access(id, level, cid, 0))
		return PLUGIN_HANDLED;
	
	if (!g_editMode)
	{
		client_print(id, print_console, "You must enable spawn editor before you can use this command.");
		return PLUGIN_HANDLED;
	}
	
	static classname[32];
	
	static Float:origin[3];
	pev(id, pev_origin, origin);
	
	new ent = FM_NULLENT;
	
	while ((ent = find_ent_in_sphere(ent, origin, 50.0)) != 0)
	{
		if (!pev_valid(ent))
			continue;
		
		pev(ent, pev_classname, classname, charsmax(classname));
		if (equal(classname, "spawnpoint"))
		{
			new index = pev(ent, pev_iuser1);
			remove_entity(ent);
			
			ArrayDeleteItem(g_spawnPoints, index);
			g_numSpawns--;
			
			while ((ent = find_ent_by_class(ent, "spawnpoint")) != 0)
			{
				if (pev(ent, pev_iuser1) >= index)
					set_pev(ent, pev_iuser1, pev(ent, pev_iuser1) - 1);
			}
			
			client_print(0, print_chat, "* Remove spawn point #%d", index);
		}
	}
	
	return PLUGIN_HANDLED;
}

public CmdSpawnSave(id, level, cid)
{
	if (!cmd_access(id, level, cid, 0))
		return PLUGIN_HANDLED;
	
	if (!g_editMode)
	{
		client_print(id, print_console, "You must enable spawn editor before you can use this command.");
		return PLUGIN_HANDLED;
	}
	
	saveMapSpawnPoints();
	client_print(0, print_chat, "* Save %d spawn points.", g_numSpawns);
	
	return PLUGIN_HANDLED;
}

public OnEntSpawn(ent)
{
	if (!pev_valid(ent))
		return FMRES_IGNORED;
	
	static classname[32];
	pev(ent, pev_classname, classname, charsmax(classname));
	
	for (new i = 0; i < sizeof OBJECTIVE_CLASSNAME; i++)
	{
		if (equal(OBJECTIVE_CLASSNAME[i], classname))
		{
			remove_entity(ent);
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED;
}

public OnGetGameDesc()
{
	new desc[32];
	formatex(desc, charsmax(desc), "Arms Race %s", VERSION);
	
	forward_return(FMV_STRING, desc);
	return FMRES_SUPERCEDE;
}

public OnArmouryTouch(armoury, toucher)
{
	if (is_user_alive(toucher))
	{
		new count;
		new weapon = cs_get_armoury_type(armoury, count);
		
		if ((1 << weapon) & CSW_ALL_GUNS)
			return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}

public OnEventDeathMsg()
{
	new killer = read_data(1);
	new victim = read_data(2);
	//new headshot = read_data(3);
	
	static weaponName[32];
	read_data(4, weaponName, charsmax(weaponName));
	
	if (killer == victim || !is_user_connected(killer))
		return;
	
	if (getCurrentWeapon(killer) == CSW_KNIFE && !equal(weaponName, "knife"))
		return;
	
	// Knife
	if (equal(weaponName, "knife"))
	{
		if (getCurrentWeapon(killer) == CSW_KNIFE)
		{
			gainPlayerXp(killer, 1);
		}
		else
		{
			setPlayerLevel(killer, g_level[killer] + 1);
			setPlayerLevel(victim, g_level[victim] - 1);
		}
	}
	// Killed a leader
	else if (g_isLeader[victim] && !g_isLeader[killer])
	{
		setPlayerLevel(killer, g_level[killer] + 1);
	}
	else
	{
		gainPlayerXp(killer, 1);
	}
}

public OnEventTeamInfo()
{
	new id = read_data(1);
	
	new teamName[2], team;
	read_data(2, teamName, charsmax(teamName));
	
	switch (teamName[0])
	{
		case 'U': team = 0;
		case 'T': team = 1;
		case 'C': team = 2;
		case 'S': team = 3;
	}
	
	if (g_isLeader[id])
	{
		// Player is joining spectator or changing team
		if (team == 0 || team == 3 || g_teamLeader[team] != id)
			resetTeamLeader(id);
	}
}

public OnPlayerSpawn_Post(id)
{
	if (!is_user_alive(id))
		return;
	
	rg_remove_all_items(id);
	giveWeaponByOrder(id);
	giveEquipments(id);
	
	spawnProtection(id, 3.0);
}

public OnPlayerKilled(id)
{
	rg_remove_all_items(id);
}

public OnPlayerKilled_Post(id, killer)
{
	// Suicide
	if (id == killer || !is_user_connected(killer))
	{
		setPlayerLevel(id, g_level[id] - 1);
	}
	else
	{
		playSound(id, SOUND_DEATHCAM[random(sizeof SOUND_DEATHCAM)]);
	}
	
	TaskRemoveProtection(id + TASK_PROTECTION);
}

public OnPlayerTraceAttack(id, attacker)
{
	if (is_user_connected(attacker))
	{
		if (g_isRoundEnded || g_hasProtection[id])
			return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}

public OnPlayerTakeDamage(id, inflictor, attacker)
{
	if (is_user_connected(attacker))
	{
		if (g_isRoundEnded || g_hasProtection[id])
			return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}

public OnGetPlayerSpawnSpot(id)
{
	if (g_numSpawns <= 0)
		return HC_CONTINUE;
	
	new team = get_member(id, m_iTeam);
	if (team < 1 || team > 2)
		return HC_CONTINUE;
	
	new numSpawns = 0;
	new Array:spawnPoints = ArrayCreate(SpawnPointData);
	new data[SpawnPointData], Float:origin[3];
	
	for (new i = 0; i < g_numSpawns; i++)
	{
		ArrayGetArray(g_spawnPoints, i, data, sizeof data);
		
		if (data[SP_Team] && data[SP_Team] != team)
			continue;
		
		if (!isSpawnPointValid(i))
			continue;
		
		ArrayPushArray(spawnPoints, data);
		numSpawns++;
	}
	
	if (numSpawns <= 0)
	{
		ArrayDestroy(spawnPoints);
		return HC_CONTINUE;
	}
	
	new index = random_num(0, numSpawns - 1);
	ArrayGetArray(spawnPoints, index, data, sizeof data);
	ArrayDestroy(spawnPoints);
	
	origin[0] = data[SP_Origin][0];
	origin[1] = data[SP_Origin][1];
	origin[2] = data[SP_Origin][2];
	
	set_pev(id, pev_origin, origin);
		
	set_pev(id, pev_v_angle, Float:{0.0, 0.0, 0.0});
	set_pev(id, pev_velocity, Float:{0.0, 0.0, 0.0});
	
	set_pev(id, pev_angles, data[SP_Angles]);
	set_pev(id, pev_punchangle, Float:{0.0, 0.0, 0.0});
	set_pev(id, pev_fixangle, 1);
	
	SetHookChainReturn(ATYPE_INTEGER, find_ent_by_class(-1, "info_player_start"));
	return HC_SUPERCEDE;
}

public client_disconnected(id)
{	
	if (g_isLeader[id])
		resetTeamLeader(id);
	
	g_level[id] = 0;
	g_xp[id] = 0;
	g_hasProtection[id] = false;
	
	remove_task(id + TASK_PROTECTION);
}

public TaskUpdateHud()
{
	new nextWeaponName[32];
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_alive(i))
			continue;
		
		getNextWeaponName(i, nextWeaponName, charsmax(nextWeaponName));
		
		set_hudmessage(0, 255, 0, -1.0, 0.85, 0, 0.0, 1.0, 0.0, 0.0, -1);
		
		ShowSyncHudMsg(i, g_hudSyncObj[2], "Level: %d | Weapon: %s (Next: %s) | XP: %d/%d %s",
			g_level[i], 
			WEAPON_NAME[getCurrentWeapon(i)], 
			nextWeaponName,
			g_xp[i],
			getRequiredXp(i),
			g_isLeader[i] ? "\nLeader" : ""
		);
	}
}

public TaskRemoveProtection(taskid)
{
	new id = taskid - TASK_PROTECTION;
	
	g_hasProtection[id] = false;
	
	if (g_isLeader[id])
	{
		if (get_member(id, m_iTeam) == 1)
			set_rendering(id, kRenderFxGlowShell, 255, 30, 30, kRenderNormal, 16);
		else
			set_rendering(id, kRenderFxGlowShell, 30, 30, 255, kRenderNormal, 16);
	}
	else
		set_rendering(id);
}

public TaskVoteMap()
{
	server_cmd("gal_startvote");
	server_exec();
}

// Trigger round end
triggerRoundEnd(id)
{
	new team = get_member(id, m_iTeam);
	if (team == 1)
	{
		set_dhudmessage(255, 50, 50, -1.0, 0.2, 0, 0.0, 8.0, 1.0, 1.0);
		show_dhudmessage(0, "Terrorists Win!");
		
		client_print(0, print_center, "Terrorists Win!");
		
		sendMsgAudio(0, 0, "%!MRAD_terwin");
	}
	else if (team == 2)
	{
		set_dhudmessage(0, 75, 255, -1.0, 0.2, 0, 0.0, 8.0, 1.0, 1.0);
		show_dhudmessage(0, "Counter-Terrorists Win!");
		
		client_print(0, print_center, "Counter-Terrorists Win!");
		
		sendMsgAudio(0, 0, "%!MRAD_ctwin");
	}
	
	set_dhudmessage(200, 200, 200, -1.0, 0.25, 0, 0.0, 5.0, 1.0, 1.0);
	show_dhudmessage(0, "%n has won the game. (%d Kills)", id, get_user_frags(id));
	
	client_print_color(0, id, "\1* \3%n \1has won the game. \1(\3%d \1Kills)", id, get_user_frags(id));
	
	playMusic(0, MUSIC_MVP);
	
	g_isRoundEnded = true;
	
	set_task(10.0, "TaskVoteMap", TASK_VOTEMAP);
}

// Load map spawn points
loadMapSpawnPoints()
{
	static filePath[128], mapName[32];
	get_configsdir(filePath, charsmax(filePath));
	get_mapname(mapName, charsmax(mapName));
	
	format(filePath, charsmax(filePath), "%s/spawns/%s.cfg", filePath, mapName);
	
	// File doesn't exist
	if (!file_exists(filePath))
		return false;
	
	static i;
	static data[SpawnPointData];
	static buffer[128], string[32];
	
	// File open
	new fp = fopen (filePath, "r");
	
	while (!feof(fp))
	{
		fgets(fp, buffer, charsmax(buffer));
		
		if (!buffer[0])
			continue;
		
		// Read origin
		for (i = 0; i < 3; i++)
		{
			argbreak(buffer, string, charsmax(string), buffer, charsmax(buffer));
			data[SP_Origin][i] = str_to_float(string);
		}
		
		// Read angles
		for (i = 0; i < 3; i++)
		{
			argbreak(buffer, string, charsmax(string), buffer, charsmax(buffer));
			data[SP_Angles][i] = str_to_float(string);
		}
		
		// Read team
		argbreak(buffer, string, charsmax(string), buffer, charsmax(buffer));
		
		if (!string[0])
			continue;
		
		data[SP_Team] = str_to_num(string);
		
		// Add to spawn point
		ArrayPushArray(g_spawnPoints, data);
		g_numSpawns++;
	}
	
	// File close
	fclose(fp);
	
	return true;
}

saveMapSpawnPoints()
{
	static filePath[128], mapName[32];
	get_configsdir(filePath, charsmax(filePath));
	get_mapname(mapName, charsmax(mapName));
	
	format(filePath, charsmax(filePath), "%s/spawns/%s.cfg", filePath, mapName);
	
	new fp = fopen(filePath, "w");
	
	static data[SpawnPointData];
	
	for (new i = 0; i < g_numSpawns; i++)
	{
		ArrayGetArray(g_spawnPoints, i, data, sizeof data);
		
		fprintf(fp, "%f %f %f %f %f %f %d\n",
			data[SP_Origin][0], data[SP_Origin][1], data[SP_Origin][2],
			data[SP_Angles][0], data[SP_Angles][1], data[SP_Angles][2],
			data[SP_Team]);
	}
	
	fclose(fp);
	
	return true;
}

stock createSpawnPointEntity(index)
{
	static data[SpawnPointData];
	ArrayGetArray(g_spawnPoints, index, data, sizeof data);
	
	new ent = create_entity("info_target");
	
	set_pev(ent, pev_classname, "spawnpoint");
	
	if (data[SP_Team] == 1)
		entity_set_model(ent, "models/player/terror/terror.mdl");
	else if (data[SP_Team] == 2)
		entity_set_model(ent, "models/player/urban/urban.mdl");
	else
		entity_set_model(ent, "models/player/vip/vip.mdl");
	
	entity_set_size(ent, Float:{-16.0, -16.0, -36.0}, Float:{16.0, 16.0, 36.0});
	
	static Float:origin[3];
	origin[0] = data[SP_Origin][0];
	origin[1] = data[SP_Origin][1];
	origin[2] = data[SP_Origin][2];
	
	entity_set_origin(ent, origin);
	
	set_pev(ent, pev_iuser1, index);
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	set_pev(ent, pev_sequence, 1);
	set_pev(ent, pev_framerate, 0.0);
	
	set_pev(ent, pev_angles, data[SP_Angles]);
	
	set_rendering(ent, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 150);
	
	return ent;
}

// Spawn protection
stock spawnProtection(id, Float:duration)
{
	g_hasProtection[id] = true;
	
	// Set rendering
	if (g_isLeader[id])
	{
		if (get_member(id, m_iTeam) == 1)
			set_rendering(id, kRenderFxGlowShell, 255, 100, 100, kRenderNormal, 16);
		else
			set_rendering(id, kRenderFxGlowShell, 100, 100, 255, kRenderNormal, 16);
	}
	else
		set_rendering(id, kRenderFxGlowShell, 200, 200, 200, kRenderNormal, 16);
	
	// Set timer
	remove_task(id + TASK_PROTECTION);
	set_task(duration, "TaskRemoveProtection", id + TASK_PROTECTION);
}

stock checkTeamLeaders()
{
	new leader;
	
	for (new i, team = 1; team <= 2; team++)
	{
		leader = g_teamLeader[team];
		
		// Leader is not valid?
		if (!is_user_connected(leader) || !(1 <= get_member(leader, m_iTeam) <= 2))
			leader = 0;
		
		for (i = 1; i <= MaxClients; i++)
		{
			if (!is_user_connected(i))
				continue;
			
			// Same team?
			if (get_member(i, m_iTeam) == team)
			{
				// Set new leader if player has higher level
				if (g_level[i] > g_level[leader])
					leader = i;
			}
		}
		
		// Is new leader?
		if (leader != g_teamLeader[team])
		{
			// Reset old leader
			if (g_teamLeader[team])
				resetTeamLeader(g_teamLeader[team], false);
			
			// Set new leader
			setTeamLeader(leader);
			
			// Some notifications
			if (team == 1)
			{
				set_hudmessage(255, 50, 50, 0.025, 0.30, 0, 0.0, 4.0, 1.0, 1.0, -1);
				ShowSyncHudMsg(0, g_hudSyncObj[0], "%n become a Leader! (%d:%s)", leader, g_level[leader], WEAPON_NAME[getCurrentWeapon(leader)]);
			}
			else
			{
				set_hudmessage(50, 50, 255, 0.025, 0.35, 0, 0.0, 4.0, 1.0, 1.0, -1);
				ShowSyncHudMsg(0, g_hudSyncObj[1], "%n become a Leader! (%d:%s)", leader, g_level[leader], WEAPON_NAME[getCurrentWeapon(leader)]);
			}
			
			client_print_color(0, leader, "\3* %n become a Leader! \1(\3%d:\4%s\1)", leader, g_level[leader], WEAPON_NAME[getCurrentWeapon(leader)]);
			
			playSound(0, SOUND_LEADER);
		}
	}
}

stock resetTeamLeader(id, bool:check=true)
{
	// Reset leader
	for (new team = 1; team <= 2; team++)
	{
		if (g_teamLeader[team] == id)
			g_teamLeader[team] = 0;
	}
	
	g_isLeader[id] = false;
	
	// Reset rendering
	set_rendering(id);
	
	// Check team leaders
	if (check)
		checkTeamLeaders();
}

stock setTeamLeader(id)
{
	new team = get_member(id, m_iTeam);
	
	// Set leader
	g_teamLeader[team] = id;
	g_isLeader[id] = true;
	
	// Set rendering
	if (team == 1)
		set_rendering(id, kRenderFxGlowShell, 255, 30, 30, kRenderNormal, 16);
	else
		set_rendering(id, kRenderFxGlowShell, 30, 30, 255, kRenderNormal, 16);
}

stock gainPlayerXp(id, amount)
{
	g_xp[id] += amount;
	
	if (g_xp[id] < 0)
	{
		setPlayerLevel(id, g_level[id] - 1);
	}
	else if (g_xp[id] >= getRequiredXp(id))
	{
		setPlayerLevel(id, g_level[id] + 1);
	}
}

stock setPlayerLevel(id, level)
{
	new oldLevel = g_level[id];
	g_level[id] = clamp(level, 0, MAX_LEVEL);
	
	if (g_level[id] > oldLevel)
	{
		playSound(id, SOUND_LEVELUP);
	}
	else if (g_level[id] < oldLevel)
	{
		playSound(id, SOUND_DEMOTE);
	}
	
	// Done!
	if (level > MAX_LEVEL && g_level[id] == MAX_LEVEL)
	{
		triggerRoundEnd(id);
		return;
	}
	else
	{
		g_xp[id] = 0;
	}
	
	if (is_user_alive(id))
	{
		rg_remove_all_items(id);
		giveWeaponByOrder(id);
	}
	
	checkTeamLeaders();
}

stock giveWeaponByOrder(id)
{
	new weapon = getCurrentWeapon(id);
	
	static classname[32];
	get_weaponname(weapon, classname, charsmax(classname));
	
	rg_give_item(id, "weapon_knife");
	
	if (weapon != CSW_KNIFE)
	{
		rg_give_item(id, classname);
		giveWeaponFullAmmo(id, weapon);
	}
}

stock giveEquipments(id)
{
	rg_set_user_armor(id, 100, ARMOR_VESTHELM);
	
	if (!random_num(0, 2))
		rg_give_item(id, "weapon_flashbang");
	
	if (!random_num(0, 5))
		rg_give_item(id, "weapon_smokegrenade");
}

stock getNextWeaponName(id, str[], len)
{
	if (g_level[id] == MAX_LEVEL)
		copy(str, len, "--");
	else
		copy(str, len, WEAPON_NAME[WEAPON_ORDER[g_level[id] + 1][WpnOrder_Id]]);
}

stock getRequiredXp(id)
{
	return WEAPON_ORDER[g_level[id]][$Xp];
}

stock getCurrentWeapon(id)
{
	return WEAPON_ORDER[g_level[id]][$Id];
}

stock bool:isSpawnPointValid(index)
{
	new data[SpawnPointData];
	ArrayGetArray(g_spawnPoints, index, data, charsmax(data));
	
	new Float:pos[3], Float:origin[3];
	pos[0] = data[SP_Origin][0];
	pos[1] = data[SP_Origin][1];
	pos[2] = data[SP_Origin][2];
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_alive(i))
			continue;
		
		pev(i, pev_origin, origin);
		
		if (get_distance_f(origin, pos) <= 70)
			return false;
	}
	
	return true;
}

stock getWeaponAmmoType(weapon)
{
	return WEAPON_AMMOTYPE[weapon];
}

stock giveFullAmmo(player, type)
{
	giveAmmo(player, type, AMMO_DATA[type][Ammo_Max], AMMO_DATA[type][Ammo_Max]);
}

stock giveAmmo(player, type, amount=0, max=0)
{
	if (!amount)
		amount = AMMO_DATA[type][Ammo_Amount];
	if (!max)
		max = AMMO_DATA[type][Ammo_Max];
	
	new ammo = get_member(player, m_rgAmmo, type);

	ExecuteHamB(Ham_GiveAmmo, player, amount, AMMO_DATA[type][Ammo_Name], max);
	
	if (ammo >= max)
		return false;
	
	return true;
}

stock giveWeaponAmmo(player, weapon, amount=0, max=0)
{
	new type = getWeaponAmmoType(weapon);
	return giveAmmo(player, type, amount, max);
}

stock giveWeaponFullAmmo(player, weapon)
{
	new type = getWeaponAmmoType(weapon);
	giveFullAmmo(player, type);
}

stock sendMsgAudio(id, sender, const code[], pitch=100)
{
	static msgSendAudio;
	msgSendAudio || (msgSendAudio = get_user_msgid("SendAudio"));
	
	emessage_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msgSendAudio, _, id);
	ewrite_byte(sender);
	ewrite_string(code);
	ewrite_short(pitch);
	emessage_end();
}

stock playSound(id, const sound[])
{
	client_cmd(id, "spk \"%s\"", sound);
}

stock playMusic(id, const music[])
{
	client_cmd(id, "mp3 play \"%s\"", music);
}