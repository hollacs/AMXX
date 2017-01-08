#include <amxmodx>
#include <fakemeta>

new Float:g_oldAngles[33][3];	

public plugin_init()
{
	register_forward(FM_CmdStart, "OnCmdStart");
}

public OnCmdStart(id, uc)
{
	if (!is_user_alive(id))
		return;
	
	new Float:angles[3];
	get_uc(uc, UC_ViewAngles, angles);
	
	
	
	g_oldAngles[id] = angles;
}