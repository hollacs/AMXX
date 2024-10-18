#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>

const WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)|(1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

const UNIT_SECOND = (1<<12)
const DMG_HEGRENADE = (1<<24)

new g_msgScreenShake

new Float:g_fCrossAngles[33][2], g_fMoveUnit[33], Float:g_fMoveTarget[33][2]
new g_fRecoilUnit[33], Float:g_fRecoilTarget[33]
new g_iStepPath[33], Float:g_fStepDelay[33]
new g_WaveTime[33], Float:g_fSaveTarget[33]
new Float:g_oldorigin[33]
new Float:g_oldangle[33][3]

new Float:g_oldplace[33][2], g_forcemove[33]

new Float:g_player_maxspeed[33], g_set_maxspeed[33], g_is_maxspeed_multi[33]

public plugin_init()
{
	register_plugin("CS Realism Mod", "0.1", "Colgate")
	register_forward(FM_CmdStart, "fwd_CmdStart", 0);
	//register_forward(FM_StartFrame, "fwd_StartFrame");
	register_forward(FM_PlayerPreThink, "fwd_PlayerPreThink", 0);

	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_Item_PreFrame, "player", "fw_PlayerMaxSpeed_Post", 1)

	g_msgScreenShake = get_user_msgid("ScreenShake")
}

public plugin_cfg()
{
	server_cmd("sv_maxspeed 9999")
}

public native_set_player_maxspeed(id, Float:maxspeed, multiplier)
{
	if (maxspeed < 0.0)	return false;
	
	g_set_maxspeed[id] = true
	g_player_maxspeed[id] = maxspeed
	
	if (multiplier)
		g_is_maxspeed_multi[id] = true
	else
		g_is_maxspeed_multi[id] =false
	
	ExecuteHamB(Ham_Item_PreFrame, id)
	return true;
}

public native_reset_player_maxspeed(id)
{
	if (!is_user_connected(id))	return false;

	if (!g_set_maxspeed[id]) return true;
	
	g_set_maxspeed[id] = false
	
	ExecuteHamB(Ham_Item_PreFrame, id)
	return true;
}

public native_move_crossang(id, Float:ca1, Float:ca2, frame)
{
	ViewMoveTo(id, ca1, ca2, frame)
}

public native_set_crossang(id, Float:ca1, Float:ca2)
{
	g_fCrossAngles[id][0] = ca1
	g_fCrossAngles[id][1] = ca2
}

public client_connect(id)
{
	g_oldplace[id][0] = 0.0
	g_oldplace[id][1] = 0.0
	g_forcemove[id] = false
}

public client_disconnected(id)
{
	g_set_maxspeed[id] = false
	//remove fucking slowhack
	//client_cmd(id,"bind shift +speed")
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type)
{
	if (!is_user_connected(attacker))
		return HAM_IGNORED;

	if(damage_type & DMG_HEGRENADE)
	{
		new dmg = floatround(damage)
		message_begin(MSG_ONE_UNRELIABLE, g_msgScreenShake, _, victim)
		write_short(UNIT_SECOND*dmg) // amplitude
		write_short(UNIT_SECOND*dmg) // duration
		write_short(UNIT_SECOND*dmg) // frequency
		message_end()

		new Float:haha[3]
		pev(victim,pev_punchangle,haha)
		haha[0] += damage / 15.0
		haha[1] += damage / 10.0
		haha[2] += damage / 5.0
		set_pev(victim,pev_punchangle,haha)
	}
	return HAM_IGNORED;
}

public fw_PlayerMaxSpeed_Post(id)
{
	if (!is_user_alive(id) || !g_set_maxspeed[id])
		return;
	
	if(g_is_maxspeed_multi[id])
		set_pev(id, pev_maxspeed, pev(id, pev_maxspeed) * g_player_maxspeed[id])
	else
		set_pev(id, pev_maxspeed, g_player_maxspeed[id])
}

public fwd_CmdStart(id, uc_handle)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return

	new Float:moveSpeed;
	get_uc(uc_handle, UC_ForwardMove, moveSpeed)
	if(!moveSpeed)
    {
		get_uc(uc_handle, UC_SideMove, moveSpeed)
	}

	new Float:maxSpeed;
	pev(id, pev_maxspeed, maxSpeed)

	new bool:holdingShiftKey = (0.0 < floatabs(moveSpeed) <= maxSpeed * 0.52)
	if (holdingShiftKey)
	{
		set_pev(id, pev_maxspeed, 800.0)
	}
	else
	{
		ExecuteHamB(Ham_Item_PreFrame, id)
	}

	new Float:speed
	speed = fm_get_walk_speed(id)
	
	if(!(pev(id,pev_flags) & FL_ONGROUND))
	{
		g_fStepDelay[id] = get_gametime() + 0.45
		return
	}


	new button, Float:angle[3], Float:oldbutton, frame = 10, Float:wave, Float:gametime, Float:crossangles[2]
	button = get_uc(uc_handle, UC_Buttons);
	
	crossangles[0] = g_oldplace[id][0]
	crossangles[1] = g_oldplace[id][1]
	crossangles[0] -= speed / 20.0

	if(button & IN_MOVERIGHT)
	{
		if((button & IN_FORWARD) || (button & IN_BACK))
		{
			crossangles[1] += speed / 75.0
			crossangles[0] += speed / 75.0
		}
		else {
			crossangles[1] += speed / 55.0

			//oldbutton += speed / 200.0
		}
	}
	else if(button & IN_MOVELEFT)
	{
		if((button & IN_FORWARD) || (button & IN_BACK))
		{
			crossangles[1] -= speed / 75.0 
			crossangles[0] += speed / 75.0
		}
		else {
			crossangles[1] -= speed / 55.0
 
			//oldbutton -= speed / 200.0
		}
	}

	if(speed < 1.0 && (g_fCrossAngles[id][0] != 0.0 || g_fCrossAngles[id][1] != 0.0))
	{
		crossangles[0] = 0.0
		crossangles[1] = 0.0
		g_WaveTime[id] = 0
	}

	get_uc(uc_handle, UC_ViewAngles, angle)

	crossangles[0] += AngleDiff(g_oldangle[id][0], angle[0])
	crossangles[1] += AngleDiff(g_oldangle[id][1], angle[1])
	g_oldangle[id] = angle

	if(crossangles[0] > 25.0) crossangles[0] = 25.0
	if(crossangles[0] < -25.0) crossangles[0] = -25.0
	if(crossangles[1] > 25.0) crossangles[1] = 25.0
	if(crossangles[1] < -25.0) crossangles[1] = -25.0


	ViewMoveTo(id, crossangles[0], crossangles[1], 20)

	gametime = get_gametime()
	if(g_fStepDelay[id] < gametime)
	{
		new Float:delaytime = (1.0 - speed / 440.0)
		if(delaytime < 0.3) delaytime = 0.3
		else if(delaytime > 0.5) delaytime = 0.5

		g_fStepDelay[id] = gametime + delaytime
		g_iStepPath[id] = g_iStepPath[id] ? false : true
		if(!g_WaveTime[id])  g_fStepDelay[id] = gametime + 0.2
		g_WaveTime[id] ++
		g_fRecoilUnit[id] = 0
		g_fSaveTarget[id] = 0.0
	}
	else 	return

	if(g_iStepPath[id])
	{
		wave =  0.0 - (speed / 110.0)

		crossangles[1] += speed / 240.0
	}
	else
	{
		wave = (speed / 110.0)

		crossangles[1] -= speed / 240.0
	}

	if(g_WaveTime[id] == 2) wave /= 2.0 , frame = 5
	oldbutton += wave
	RecoilMoveTo(id, oldbutton, frame)
	return
}

public fwd_PlayerPreThink(id)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return

	if(!(pev(id,pev_flags) & FL_ONGROUND))
	{
		new Float:crossangles
		new Float:speed = fm_get_air_speed(id)
		new Float:origin[3]
		pev(id,pev_origin,origin)

		crossangles = g_oldplace[id][0]

		if(origin[2] > g_oldorigin[id])
		{
			crossangles -= speed / 20.0
		}
		else 
		{
			crossangles += speed / 38.0
		}
		g_oldorigin[id] = origin[2]

		if(crossangles > 25.0) crossangles = 25.0
		if(crossangles < -25.0) crossangles = -25.0

		if(speed > 700.0)
		{
			message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenShake"), _, id)
			write_short((1<<4)*floatround(speed)) // amplitude
			write_short((1<<12)*1) // duration
			write_short((1<<12)*1) // frequency
			message_end()
		}

		ViewMoveTo(id, crossangles, g_fCrossAngles[id][1], 5)
	}


	if(cs_get_user_zoom(id) >= CS_SET_FIRST_ZOOM )
	{
		if(g_fCrossAngles[id][0] != 0.0 && g_fCrossAngles[id][1] != 0.0) engfunc( EngFunc_CrosshairAngle, id, 0.0 , 0.0)
		return
	}

	if(g_fMoveUnit[id])
	{
		g_fMoveUnit[id] --
		if(!g_fMoveUnit[id] && g_forcemove[id]) g_forcemove[id] = false

		g_fCrossAngles[id][0] += g_fMoveTarget[id][0]
		g_fCrossAngles[id][1] += g_fMoveTarget[id][1]

		engfunc( EngFunc_CrosshairAngle, id, g_fCrossAngles[id][0] , g_fCrossAngles[id][1])
	}
	if(g_fRecoilUnit[id])
	{
		static Float:theon9[3]
		pev(id,pev_punchangle,theon9)
		g_fRecoilUnit[id] --

		theon9[2] += g_fRecoilTarget[id]
		g_fSaveTarget[id] = theon9[2]
		set_pev(id,pev_punchangle,theon9)
	}
}

stock Float:AngleDiff(Float:angle1, Float:angle2)
{
	new Float:diff = floatmod(angle2 - angle1, 360.0);
	if (diff > 180.0)
		diff -= 360.0;

	return diff;
}

stock ViewMoveTo(id, Float:Pitch, Float:Yaw, frame, force = 0)
{
	if(g_forcemove[id])   return

	if(force) 
	{
		g_forcemove[id] = true
		g_oldplace[id][0] = Pitch
		g_oldplace[id][1] = Yaw
	}

	g_fMoveUnit[id] = frame
	g_fMoveTarget[id][0] = (Pitch - g_fCrossAngles[id][0]) / frame
	g_fMoveTarget[id][1] = (Yaw - g_fCrossAngles[id][1]) / frame
}

stock RecoilMoveTo(id, Float:force, frame)
{
	//new Float:theon9[3]
	//pev(id,pev_punchangle,theon9)
	g_fRecoilUnit[id] = frame
	g_fRecoilTarget[id] = (force - g_fSaveTarget[id]) / frame
}

stock Float:fm_get_walk_speed(id)
{
	if(!pev_valid(id))
	return 0.0;
 
	static Float:vVelocity[3];
	pev(id, pev_velocity, vVelocity);
 
	vVelocity[2] = 0.0;
 
	return vector_length(vVelocity);
}

stock Float:fm_get_air_speed(id)
{
	if(!pev_valid(id))
	return 0.0;
 
	static Float:vVelocity[3];
	pev(id, pev_velocity, vVelocity);
 
	vVelocity[0] = 0.0;
 	vVelocity[1] = 0.0;

	return vector_length(vVelocity);
}

stock Float:floatmod(Float:num, Float:denom)
{
	return num - denom * floatround(num / denom, floatround_floor)
}