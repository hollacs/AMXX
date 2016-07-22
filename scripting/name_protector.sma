#include <amxmodx>
#include <regex>
#include <fvault>

#define VERSION "0.1"

#define FFADE_IN 		0x0000 // Just here so we don't pass 0 into the function
#define FFADE_OUT 		0x0001 // Fade out (not in)
#define FFADE_MODULATE 	0x0002 // Modulate (don't blend)
#define FFADE_STAYOUT 	0x0004 // ignores the duration, stays faded out until new ScreenFade message received

#define SALT "0Jo2av8jWm"
#define VAULT "name_protector"

enum
{
	USER_LOGIN = 1,
	USER_REGISTER
}

new g_status[33];
new g_tries[33];
new g_count[33];
new Float:g_nextMsgTime[33] = {-999999.0, ...};

new g_hash[33][41];
new g_lastLogin[33];
new g_registerDate[33];

new bool:g_isFirstJoin[33] = {true, ...};

new g_hudSyncObj;

new cvarTime, cvarMaxTries, cvarMinLen, cvarMaxLen;

public plugin_init()
{
	register_plugin("Name Protector", VERSION, "penguinux");
	
	register_message(get_user_msgid("ShowMenu"), "MsgShowMenu");
	register_message(get_user_msgid("VGUIMenu"), "MsgVguiMenu");
	
	register_clcmd("amx_register", "CmdRegister");
	register_clcmd("amx_login", "CmdLogin");
	register_clcmd("say", "CmdSay");
	
	cvarTime = register_cvar("np_time", "120");
	cvarMaxTries = register_cvar("np_max_tries", "5");
	cvarMinLen = register_cvar("np_min_len", "6");
	cvarMaxLen = register_cvar("np_max_len", "32");
	
	g_hudSyncObj = CreateHudSyncObj();
}

public CmdRegister(id)
{
	new arg[32], arg2[32]
	read_argv(1, arg, charsmax(arg));
	read_argv(2, arg2, charsmax(arg2));
	
	userRegister(id, arg, arg2);
	return PLUGIN_HANDLED
}

public CmdLogin(id)
{
	new arg[32];
	read_argv(1, arg, charsmax(arg));
	
	userLogin(id, arg);
	return PLUGIN_HANDLED
}

public CmdSay(id)
{
	new arg[64];
	read_argv(1, arg, charsmax(arg));
	
	if (g_status[id] == USER_LOGIN)
	{
		userLogin(id, arg);
		return PLUGIN_HANDLED;
	}
	else if (g_status[id] == USER_REGISTER)
	{
		userRegister(id, arg);
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public MsgShowMenu(msgId, msgDest, id)
{
	new menuCode[32];
	if (equal(menuCode, "#Team_Select"))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public MsgVguiMenu(msgId, msgDest, id)
{
	server_print("ha %d", get_msg_arg_int(1));
	return PLUGIN_CONTINUE;
}

public client_putinserver(id)
{
	loadUser(id);
	
	remove_task(id);
	set_task(1.0, "CountDown", id, .flags="b");
}

public client_disconnected(id)
{
	g_status[id] = 0;
	g_tries[id] = 0;
	g_count[id] = 0;
	g_nextMsgTime[id] = -999999.0;
	
	g_hash[id][0] = 0;
	g_lastLogin[id] = 0;
	g_registerDate[id] = 0;
	
	g_isFirstJoin[id] = true;
	
	remove_task(id);
}

public CountDown(id)
{
	g_count[id]++;
	
	new maxCount = get_pcvar_num(cvarTime);
	if (g_count[id] >= maxCount)
	{
		kickPlayer(id, "You didn't login or register in specified time.");
		return;
	}
	
	if (get_gametime() >= g_nextMsgTime[id])
	{
		if (g_status[id] == USER_LOGIN)
		{
			set_hudmessage(0, 100, 255, -1.0, -1.0, 0, 0.0, 0.5, 0.0, 1.0, 4);
			ShowSyncHudMsg(id, g_hudSyncObj, "[登入 %n]^n你的名字已被註冊^n請按 Y 輸入你的密碼 或 在控制台輸入 amx_login ^"你的密碼^"^n剩餘時間 %d 秒", id, maxCount - g_count[id]);
		}
		else
		{
			set_hudmessage(0, 255, 0, -1.0, -1.0, 0, 0.0, 0.5, 0.0, 1.0, 4);
			ShowSyncHudMsg(id, g_hudSyncObj, "[註冊 %n]^n請按 Y 輸入你的密碼 (密碼已使用SHA1加密)^n或在控制台輸入 amx_register ^"你的密碼^" ^"你的密碼^"^n剩餘時間 %d 秒", id, maxCount - g_count[id]);
		}
	}
	
	sendScreenFade(id, 1.0, 2.0, FFADE_IN, {0, 0, 0}, 120);
}

loadUser(id)
{
	new name[32];
	get_user_name(id, name, charsmax(name));
	
	new data[128];
	if (fvault_get_data(VAULT, name, data, charsmax(data)))
	{
		new hash[41], address[32], time[16], date[16];
		parse(data, hash, 40, address, 31, time, 15, date, 15);
		
		g_status[id] = USER_LOGIN;
		g_hash[id] = hash;
		g_lastLogin[id] = str_to_num(time);
		g_registerDate[id] = str_to_num(date);
	}
	else
	{
		g_status[id] = USER_REGISTER;
	}
}

saveUser(id)
{
	new name[32];
	get_user_name(id, name, charsmax(name));
	
	new data[128], address[32];
	if (fvault_get_data(VAULT, name, data, charsmax(data)))
		parse(data, address, 31, address, 31);
	else
		get_user_ip(id, address, charsmax(address), 1);
	
	formatex(data, charsmax(data), "%s %s %d %d", g_hash[id], address, g_lastLogin[id], g_registerDate[id]);
	fvault_set_data(VAULT, name, data);
}

bool:userLogin(id, const password[])
{
	if (g_status[id] != USER_LOGIN)
		return false;
	
	new hash[41];
	encryptPassword(password, hash, charsmax(hash));
	
	if (!equal(hash, g_hash[id]))
	{
		new maxTries = get_pcvar_num(cvarMaxTries);
		
		g_tries[id]++;
		if (g_tries[id] >= maxTries)
		{
			kickPlayer(id, "Your have entered wrong password too many times.")
			return false;
		}
		
		client_print(id, print_console, "* You have entered a wrong password. [%d/%d]", g_tries[id], maxTries);
		sendErrorMessage(id, {255, 0, 0}, 3.0, "你輸入的密碼不正確, 請重試 [%d/%d]", g_tries[id], maxTries);
		return false;
	}
	
	g_status[id] = 0;
	remove_task(id);
	
	new lastLogin[32], registerDate[16];
	format_time(lastLogin, charsmax(lastLogin), "%d/%m/%Y - %H:%M", g_lastLogin[id]);
	format_time(registerDate, charsmax(registerDate), "%d/%m/%Y", g_registerDate[id]);
	g_lastLogin[id] = get_systime();
	
	client_print(id, print_chat, "成功登入 ^"%n^". (註冊日期: %s) (上次登入: %s)", id, registerDate, lastLogin);
	client_print(id, print_console, "* You have been logged in successfully. (Register date: %s) (Last login: %s)", registerDate, lastLogin);
	
	set_hudmessage(0, 255, 0, -1.0, -1.0, 0, 0.0, 5.0, 1.0, 1.0, 2);
	ShowSyncHudMsg(id, g_hudSyncObj, "成功登入 ^"%n^"^n(註冊日期: %s) (上次登入: %s)", id, registerDate, lastLogin);
	
	return true;
}

bool:userRegister(id, const password[], const password2[]="")
{
	if (g_status[id] != USER_REGISTER)
		return false;
	
	new confirmPassword[32];
	copy(confirmPassword, charsmax(confirmPassword), password2);
	if (!confirmPassword[0])
		copy(confirmPassword, charsmax(confirmPassword), g_hash[id]);
	
	if (!confirmPassword[0])
	{
		new rangeLen[2];
		rangeLen[0] = get_pcvar_num(cvarMinLen);
		rangeLen[1] = get_pcvar_num(cvarMaxLen);
		
		new length = strlen(password);
		if (length < rangeLen[0] || length > rangeLen[1])
		{
			client_print(id, print_console, "* Please enter a password between %d and %d characters.", rangeLen[0], rangeLen[1]);
			sendErrorMessage(id, {255, 0, 0}, 3.0, "密碼長度在 %d 至 %d 之間", rangeLen[0], rangeLen[1]);
			return false;
		}
		
		if (!validatePassword(password))
		{
			client_print(id, print_console, "* Your password can only contain alphanumeric characters.");
			sendErrorMessage(id, {255, 0, 0}, 3.0, "密碼只能使用英文字母及數字");
			return false;
		}
		
		copy(g_hash[id], charsmax(g_hash[]), password);
		
		client_print(id, print_console, "* Please enter the password ^"%s^" again. (Enter empty password to reset)", password);
		sendErrorMessage(id, {0, 255, 100}, 5.0, "請再次輸入密碼 ^"%s^" 確認 (輸入空白重設)", password);
		return false;
	}
	else
	{
		if (!password[0])
		{
			client_print(id, print_console, "* Password has been resetted.");
			sendErrorMessage(id, {0, 255, 100}, 5.0, "密碼已重設");
			return false;
		}
		
		if (!equal(password, confirmPassword))
		{
			client_print(id, print_console, "* Password does not match the confirm password. (Enter empty password to reset)");
			sendErrorMessage(id, {255, 0, 0}, 3.0, "兩次輸入的密碼不正確 (輸入空白重設)");
			return false;
		}
	}
	
	g_status[id] = 0;
	remove_task(id);
	
	new time = get_systime();
	g_lastLogin[id] = time;
	g_registerDate[id] = time;
	encryptPassword(password, g_hash[id], charsmax(g_hash[]));
	
	saveUser(id);
	
	new address[32];
	get_user_ip(id, address, charsmax(address), 1);
	
	client_print(id, print_chat, "成功註冊 ^"%n^". (IP: %s)", id, address);
	client_print(id, print_console, "* You have been registered successfully. (IP: %s)", address);
	
	set_hudmessage(0, 255, 0, -1.0, -1.0, 0, 0.0, 5.0, 1.0, 1.0, 2);
	ShowSyncHudMsg(id, g_hudSyncObj, "成功註冊 ^"%n^" (IP: %s)", id, address);
	
	return true;
}

stock bool:validatePassword(const password[])
{
	new ret, error[128];
	new Regex:handle = regex_match(password, "^^[a-zA-Z0-9_]+$", ret, error, charsmax(error));
	
	if (handle >= REGEX_OK)
	{
		regex_free(handle);
		return true;
	}
	
	return false;
}

stock kickPlayer(id, const reason[])
{
	server_cmd("kick #%d ^"%s^"", get_user_userid(id), reason);
}

stock encryptPassword(const password[], output[], len)
{
	new string[41];
	copy(string, charsmax(string), password);
	add(string, charsmax(string), SALT);
	
	hash_string(string, Hash_Sha1, output, len);
}

stock sendErrorMessage(id, color[3]={0, 255, 0}, Float:time, const message[], any:...)
{
	new buffer[192];
	vformat(buffer, charsmax(buffer), message, 5);
	
	client_print(id, print_chat, buffer);
	
	set_hudmessage(color[0], color[1], color[2], -1.0, -1.0, 0, 0.0, time, 0.0, 1.0, 4);
	ShowSyncHudMsg(id, g_hudSyncObj, buffer);
	
	g_nextMsgTime[id] = get_gametime() + time;
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

	if (output < 0)
		output = 0;

	if (output > 0xFFFF)
		output = 0xFFFF;

	return output;
}