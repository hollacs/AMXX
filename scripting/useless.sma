#include <amxmodx>
#include <fakemeta>

public plugin_init()
{
	register_plugin("Useless", "0.1", "penguinux");
	
	register_forward(FM_CmdStart, "OnCmdStart");
}

public OnCmdStart(id, uc)
{
	new Float:angles[3];
	get_uc(uc, UC_ViewAngles, angles);
}