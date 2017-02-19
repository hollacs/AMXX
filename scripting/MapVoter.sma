#include <amxmodx>
#include <amxmisc>

#pragma semicolon 1

#define VERSION "0.1"

new Array:g_mapName;
new g_mapCount;

public plugin_init()
{
	register_plugin("Map Voter", VERSION, "penguinux");
	
	register_clcmd("say rtv", "CmdSayRockTheVote");
	register_clcmd("say rockthevote", "CmdSayRockTheVote");

	LoadMaps();
}

LoadMaps()
{
	new filePath[128];
	formatex(filePath, charsmax(filePath), "mapcycle.txt");
	
	static buffer[256], mapName[32];
	new fp = fopen(filePath, "r");
	
	while (!feof(fp))
	{
		fgets(fp, buffer, charsmax(buffer));
		
		if (!buffer[0] || buffer[0] == ';')
			continue;
		
		parse(buffer, mapName, charsmax(mapName));
		
		if (isValidMap(mapName))
		{
			ArrayPushString(g_mapName, mapName);
			g_mapCount++;
		}
	}

	fclose(fp);
	
	return g_mapCount;
}

stock bool:isValidMap(mapName[])
{
	if (is_map_valid(mapName))
		return true;
	
	new len = strlen(mapName) - 4;
	if (len < 0)
		return false;
	
	if (equali(mapName[len], ".bsp"))
	{
		mapName[len] = '^0';
		
		if (is_map_valid(mapName))
			return true;
	}
	
	return false;
}