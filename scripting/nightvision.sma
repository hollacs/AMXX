#include <amxmodx>
#include <fakemeta>

#define NVG_R 0
#define NVG_G 200
#define NVG_B 0
#define NVG_ALPHA 100

#define FFADE_IN 		0x0000 // Just here so we don't pass 0 into the function
#define FFADE_OUT 		0x0001 // Fade out (not in)
#define FFADE_MODULATE 	0x0002 // Modulate (don't blend)
#define FFADE_STAYOUT 	0x0004 // ignores the duration, stays faded out until new ScreenFade message received

new g_lights[32];
new Float:g_nextFadeTime[33];
new Float:g_screenFadeUntil[33];
new bool:g_hasFadeIn[33];

public plugin_init()
{
	register_plugin("New Night Vision", "0.1", "Colgate");
	
	register_event("ScreenFade", "EventScreenFade", "ab");
	
	register_message(get_user_msgid("NVGToggle"), "MsgNVGToggle");
	register_message(SVC_LIGHTSTYLE, "MsgLightStyle");
	
	register_forward(FM_PlayerPreThink, "OnPlayerPreThink");
}

public EventScreenFade(id)
{
	g_hasFadeIn[id] = false;
	
	if (read_data(7) > 0)
	{
		new flags = read_data(3);
		if (flags != FFADE_STAYOUT)
		{
			new Float:fadeTime = read_data(1) / float(1 << 12);
			new Float:holdTime = read_data(2) / float(1 << 12);
			
			if (fadeTime + holdTime > 0.0)
			{
				g_screenFadeUntil[id] = get_gametime() + fadeTime + holdTime;
				
				if (flags == FFADE_IN)
					g_hasFadeIn[id] = true;
			}
		}
		else
		{
			g_screenFadeUntil[id] = get_gametime() + 999999.0;
		}
	}
}

public MsgNVGToggle(msgId, msgDest, id)
{
	// ON
	if (get_msg_arg_int(1))
	{
		sendLightStyle(id, 0, "#");
		g_nextFadeTime[id] = get_gametime();
	}
	// OFF
	else
	{
		sendLightStyle(id, 0, g_lights);
	}
	
	return PLUGIN_HANDLED;
}

public MsgLightStyle(msgId, msgDest, id)
{
	// Catch custom light styles
	if (msgDest == MSG_BROADCAST && get_msg_arg_int(1) == 0)
	{
		get_msg_arg_string(2, g_lights, charsmax(g_lights));
	}
}

public OnPlayerPreThink(id)
{
	if (getPlayerData(id, "m_bNightVisionOn"))
	{
		new Float:currentTime = get_gametime();
		if (currentTime >= g_screenFadeUntil[id])
		{
			if (g_hasFadeIn[id])
			{
				g_hasFadeIn[id] = false;
				sendScreenFade(id, 0.5, 1.0, FFADE_OUT, {NVG_R, NVG_G, NVG_B}, NVG_ALPHA);
				g_nextFadeTime[id] = currentTime + 0.5;
			}
			else if (currentTime >= g_nextFadeTime[id])
			{
				sendScreenFade(id, 1.0, 0.9, FFADE_IN, {NVG_R, NVG_G, NVG_B}, NVG_ALPHA);
				g_nextFadeTime[id] = currentTime + 1.0;
			}
		}
	}
}

public UpdateLightStyle(id)
{
	sendLightStyle(id, 0, g_lights);
}

public client_putinserver(id)
{
	set_task(0.1, "UpdateLightStyle", id);
}

public client_disconnected(id)
{
	remove_task(id);
}

stock setLights(const lights[])
{
	emessage_begin(MSG_BROADCAST, SVC_LIGHTSTYLE);
	ewrite_byte(0);
	ewrite_string(lights);
	emessage_end();
}

stock sendLightStyle(id, style=0, const lights[])
{
	message_begin(MSG_ONE_UNRELIABLE, SVC_LIGHTSTYLE, _, id);
	write_byte(style);
	write_string(lights);
	message_end();
}

stock sendScreenFade(id, Float:duration, Float:holdTime, flags, color[3], alpha, bool:external=false)
{
	static msgScreenFade;
	msgScreenFade || (msgScreenFade = get_user_msgid("ScreenFade"));
	
	if (external)
	{
		emessage_begin(MSG_ONE_UNRELIABLE, msgScreenFade, _, id);
		ewrite_short(fixedUnsigned16(duration, 1<<12));
		ewrite_short(fixedUnsigned16(holdTime, 1<<12));
		ewrite_short(flags);
		ewrite_byte(color[0]);
		ewrite_byte(color[1]);
		ewrite_byte(color[2]);
		ewrite_byte(alpha);
		emessage_end();
	}
	else
	{
		message_begin(MSG_ONE_UNRELIABLE, msgScreenFade, _, id);
		write_short(fixedUnsigned16(duration, 1<<12));
		write_short(fixedUnsigned16(holdTime, 1<<12));
		write_short(flags);
		write_byte(color[0]);
		write_byte(color[1]);
		write_byte(color[2]);
		write_byte(alpha);
		message_end();
	}
}

stock fixedUnsigned16(Float:value, scale)
{
	new output = floatround(value * scale);
	return clamp(output, 0, 0xFFFF);
}

stock getPlayerData(player, const member[], element = 0)
{
	return get_ent_data(player, "CBasePlayer", member, element);
}