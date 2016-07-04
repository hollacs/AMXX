#include <amxmodx>
#include <fun>

public plugin_init()
{
	register_clcmd("test", "CmdTest");
}

public CmdTest(id)
{
	give_item(id, "weapon_ak48");
}