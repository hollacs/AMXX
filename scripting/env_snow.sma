#include <amxmodx>
#include <engine>

public plugin_precache()
{
	create_entity("env_snow");
}

public plugin_init()
{
	register_plugin("Snow", "0.1", "penguinux");
}