#include <amxmodx>
#include <fakemeta>
#include <regex>
#include <fvault>

#define VERSION "0.1"

#define VAULT_NAME "logmein"
#define AUTOLOGIN_INFO "_logmein"
#define SALT "201611280323TheLazyFoxJumpsOverTheQuickBrownDog"

enum
{
	MENU_NONE = 0,
	MENU_MAIN,
	MENU_REGISTER,
	MENU_LOGIN,
	MENU_CHANGE,
};

enum
{
	USER_UNREGISTERED = 0,
	USER_REGISTERED,
	USER_LOGGED_IN,
};

new g_status[33];
new g_password[33][40];
new bool:g_autoLogin[33];
new Float:g_timer[33] = {-999999.0, ...};
new g_wrong[33];

new g_inputData[33][3][32];

new g_menuMain;
new g_menuRegister;
new g_menuLogin;
new g_menuChange;

new g_hudSyncObj;

public plugin_init()
{
	register_plugin("LogMeIn", VERSION, "penguinux");
	
	register_clcmd("say /register", "CmdSayRegister");
	register_clcmd("say /reg", "CmdSayRegister");
	register_clcmd("say /login", "CmdSayRegister");
	
	register_clcmd("_ENTER_PASSWORD", "CmdEnterPassword");
	register_clcmd("_ENTER_CONFIRM_PASSWORD", "CmdEnterConfirmPassword");
	register_clcmd("_ENTER_OLD_PASSWORD", "CmdEnterOldPassword");
	
	register_clcmd("chooseteam", "CmdChooseTeam");
	register_clcmd("jointeam", "CmdChooseTeam");

	register_message(get_user_msgid("ShowMenu"), "MsgShowMenu");
	register_message(get_user_msgid("VGUIMenu"), "MsgVGUIMenu");
	
	register_forward(FM_ClientUserInfoChanged, "OnClientUserInfoChanged");
	
	g_menuMain     = register_menuid("LogMeIn Menu");
	g_menuRegister = register_menuid("Register Menu");
	g_menuLogin    = register_menuid("Login Menu");
	g_menuChange   = register_menuid("Change Password Menu");

	register_menucmd(g_menuMain,     1023, "HandleLogmeinMenu");
	register_menucmd(g_menuRegister, 1023, "HandleRegisterMenu");
	register_menucmd(g_menuLogin,    1023, "HandleLoginMenu");
	register_menucmd(g_menuChange,   1023, "HandleChangeMenu");
	
	g_hudSyncObj = CreateHudSyncObj();
}

public CmdSayRegister(id)
{
	ShowLogmeinMenu(id);
	return PLUGIN_HANDLED;
}

public CmdEnterPassword(id)
{
	new menu = getMenuType(id);
	if (menu != MENU_NONE)
	{
		if (menu == MENU_MAIN)
		{
			new arg[32];
			read_argv(1, arg, charsmax(arg));
			
			if (!arg[0])
			{
				client_cmd(id, "setinfo ^"%s^" ^"^"", AUTOLOGIN_INFO);
				g_autoLogin[id] = false;
				client_print(id, print_chat, "[LogMeIn] 你關閉了自動登入.");
			}
			else
			{
				client_cmd(id, "setinfo ^"%s^" ^"%s^"", AUTOLOGIN_INFO, arg);
				g_autoLogin[id] = true;
				client_print(id, print_chat, "[LogMeIn] 自動登入已設定.");
			}

			ShowLogmeinMenu(id);
		}
		else
		{
			read_argv(1, g_inputData[id][1], charsmax(g_inputData[][]));
			
			switch (menu)
			{
				case MENU_REGISTER:
					ShowRegisterMenu(id);
				case MENU_LOGIN:
					ShowLoginMenu(id);
				case MENU_CHANGE:
					ShowChangeMenu(id);
			}
		}
	}
	
	return PLUGIN_HANDLED;
}

public CmdEnterConfirmPassword(id)
{
	new type = getMenuType(id);
	if (type == MENU_REGISTER || type == MENU_CHANGE)
	{
		read_argv(1, g_inputData[id][2], charsmax(g_inputData[][]));
		
		if (type == MENU_REGISTER)
			ShowRegisterMenu(id);
		else
			ShowChangeMenu(id);
	}

	return PLUGIN_HANDLED;
}

public CmdEnterOldPassword(id)
{
	if (getMenuType(id) == MENU_CHANGE)
	{
		read_argv(1, g_inputData[id][0], charsmax(g_inputData[][]));
		ShowChangeMenu(id);
	}
	
	return PLUGIN_HANDLED;
}

public CmdChooseTeam(id)
{
	if (g_status[id] == USER_REGISTERED)
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public MsgShowMenu(msgId, msgDest, id)
{
	if (g_status[id] == USER_REGISTERED)
	{	
		new menuCode[32];
		get_msg_arg_string(4, menuCode, charsmax(menuCode));
		
		if (equal(menuCode, "#Team_Select") || equal(menuCode, "#Team_Select_Spect"))
			return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public MsgVGUIMenu(msgId, msgDest, id)
{
	if (g_status[id] == USER_REGISTERED && get_msg_arg_int(1) == 2)
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public OnClientUserInfoChanged(id)
{
	new oldName[32], newName[32];
	pev(id, pev_netname, oldName, charsmax(oldName));

	if(oldName[0])
	{
		get_user_info(id, "name", newName, charsmax(newName));
		if(!equal(oldName, newName))
		{
			set_user_info(id, "name", oldName);
			client_print(id, print_chat, "* Changing name is not allowed in this server.");
		}
	}
}

public client_putinserver(id)
{
	checkUser(id);
}

public client_disconnected(id)
{
	g_autoLogin[id] = false;
	g_status[id] = USER_UNREGISTERED;
	g_password[id][0] = 0;
	g_wrong[id] = 0
	g_timer[id] = -999999.0;
	
	clearInputData(id);
	
	remove_task(id);
}

public ShowLogmeinMenu(id)
{
	static menu[512], len;
	len = formatex(menu, charsmax(menu), "\yLogMeIn 選單");
	
	new keys = MENU_KEY_9|MENU_KEY_0;
	
	switch (g_status[id])
	{
		case USER_UNREGISTERED:
		{
			len += formatex(menu[len], 511-len, " \y[\r未註冊\y]^n^n");
			len += formatex(menu[len], 511-len, "\y1. \w註冊^n");

			keys |= MENU_KEY_1;
		}
		case USER_REGISTERED:
		{
			len += formatex(menu[len], 511-len, " \y[\r未登入\y]^n^n");
			len += formatex(menu[len], 511-len, "\y1. \w登入^n");

			keys |= MENU_KEY_1;
		}
		case USER_LOGGED_IN:
		{
			len += formatex(menu[len], 511-len, " \y[\w%n\y]^n^n", id);
			len += formatex(menu[len], 511-len, "\y1. \w更改密碼^n");
			len += formatex(menu[len], 511-len, "\y2. \w自動登入: %s^n", g_autoLogin[id] ? "\yOn" : "\dOff");
			keys |= MENU_KEY_1|MENU_KEY_2;
		}
	}
	
	len += formatex(menu[len], 511-len, "^n\y9. \wHelp^n");
	len += formatex(menu[len], 511-len, "^n\y0. \wExit");
	
	show_menu(id, keys, menu, -1, "LogMeIn Menu");
}

public HandleLogmeinMenu(id, key)
{
	switch (key)
	{
		case 0:
		{
			switch (g_status[id])
			{
				case USER_UNREGISTERED:
					ShowRegisterMenu(id);
				case USER_REGISTERED:
					ShowLoginMenu(id);
				case USER_LOGGED_IN:
					ShowChangeMenu(id);
			}
		}
		case 1:
		{
			if (g_status[id] == USER_LOGGED_IN)
			{
				client_cmd(id, "messagemode _ENTER_PASSWORD");
				client_print(id, print_chat, "[LogMeIn] 請輸入你地密碼. (輸入空白關閉自動登入)");
				ShowLogmeinMenu(id);
			}
		}
		case 8:
		{
			client_print(id, print_chat, "呢度無野幫到你.");
		}
	}
}

public ShowRegisterMenu(id)
{
	static menu[512], len;
	
	len = formatex(menu, charsmax(menu), "\y註冊選單 \y[\w%n\y]^n^n", id);
	
	new censored[32], len2;
	len2 = strlen(g_inputData[id][1]);
	for (new i = 0; i < len2; i++)
		censored[i] = '*';
	
	len += formatex(menu[len], 511-len, "\y1. \w密碼: \y%s^n", !censored[0] ? "\d按一下輸入" : censored);
	
	arrayset(censored, 0, sizeof censored);
	len2 = strlen(g_inputData[id][2]);
	for (new i = 0; i < len2; i++)
		censored[i] = '*';
	
	len += formatex(menu[len], 511-len, "\y2. \w確認密碼: \y%s^n", !censored[0] ? "\d按一下輸入" : censored);
	len += formatex(menu[len], 511-len, "\d(所有密碼經過 \wSHA1 \d加密)^n");

	len += formatex(menu[len], 511-len, "^n\y9. \w註冊^n");
	len += formatex(menu[len], 511-len, "^n\y0. \wExit");
	
	new keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_9|MENU_KEY_0;
	
	show_menu(id, keys, menu, -1, "Register Menu");
}

public HandleRegisterMenu(id, key)
{
	if (g_status[id] != USER_UNREGISTERED)
		return;
	
	switch (key)
	{
		case 0:
		{
			client_cmd(id, "messagemode _ENTER_PASSWORD");
			ShowRegisterMenu(id);
		}
		case 1:
		{
			client_cmd(id, "messagemode _ENTER_CONFIRM_PASSWORD");
			ShowRegisterMenu(id);
		}
		case 8:
		{
			if (!registerSubmit(id))
				ShowRegisterMenu(id);
			else
				clearInputData(id);
		}
		default:
		{
			clearInputData(id);
		}
	}
}

public ShowLoginMenu(id)
{
	static menu[512], len;
	
	len = formatex(menu, charsmax(menu), "\y登入選單 \y[\w%n\y]^n^n", id);
	
	new censored[32], len2;
	len2 = strlen(g_inputData[id][1]);
	for (new i = 0; i < len2; i++)
		censored[i] = '*';
	
	len += formatex(menu[len], 511-len, "\y1. \w密碼: \y%s^n", !censored[0] ? "\d按一下輸入" : censored);

	len += formatex(menu[len], 511-len, "^n\y9. \w登入^n");
	
	new keys = MENU_KEY_1|MENU_KEY_9;
	
	show_menu(id, keys, menu, -1, "Login Menu");
}

public HandleLoginMenu(id, key)
{
	if (g_status[id] != USER_REGISTERED)
		return;
	
	switch (key)
	{
		case 0:
		{
			client_cmd(id, "messagemode _ENTER_PASSWORD");
			ShowLoginMenu(id);
		}
		case 8:
		{
			if (!loginSubmit(id))
				ShowLoginMenu(id);
			else
				clearInputData(id);
		}
		default:
		{
			clearInputData(id);
		}
	}
}

public ShowChangeMenu(id)
{
	static menu[512], len;
	
	len = formatex(menu, charsmax(menu), "\y更改你的密碼^n^n");
	
	new censored[32], len2;
	len2 = strlen(g_inputData[id][0]);
	for (new i = 0; i < len2; i++)
		censored[i] = '*';

	len += formatex(menu[len], 511-len, "\y1. \w舊密碼: \y%s^n", !censored[0] ? "\d按一下輸入" : censored);
	
	arrayset(censored, 0, sizeof censored);
	len2 = strlen(g_inputData[id][1]);
	for (new i = 0; i < len2; i++)
		censored[i] = '*';
	
	len += formatex(menu[len], 511-len, "\y2. \w新密碼: \y%s^n", !censored[0] ? "\d按一下輸入" : censored);

	arrayset(censored, 0, sizeof censored);
	len2 = strlen(g_inputData[id][2]);
	for (new i = 0; i < len2; i++)
		censored[i] = '*';
	
	len += formatex(menu[len], 511-len, "\y3. \w確認密碼: \y%s^n", !censored[0] ? "\d按一下輸入" : censored);

	len += formatex(menu[len], 511-len, "^n\y9. \w更改^n");
	len += formatex(menu[len], 511-len, "^n\y0. \wExit");
	
	new keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_9|MENU_KEY_0;
	
	show_menu(id, keys, menu, -1, "Change Password Menu");
}

public HandleChangeMenu(id, key)
{
	if (g_status[id] != USER_LOGGED_IN)
		return;
	
	switch (key)
	{
		case 0:
		{
			client_cmd(id, "messagemode _ENTER_OLD_PASSWORD");
			ShowChangeMenu(id);
		}
		case 1:
		{
			client_cmd(id, "messagemode _ENTER_PASSWORD");
			ShowChangeMenu(id);
		}
		case 2:
		{
			client_cmd(id, "messagemode _ENTER_CONFIRM_PASSWORD");
			ShowChangeMenu(id);
		}
		case 8:
		{
			if (!changeSubmit(id))
				ShowChangeMenu(id);
			else
				clearInputData(id);
		}
		default:
		{
			clearInputData(id);
		}
	}
}

public TaskLogin(id)
{
	new timeLeft = floatround((g_timer[id] + 60.0) - get_gametime());
	if (!timeLeft)
	{
		kickPlayer(id, "You have spent too much time to login.")
		return;
	}
	
	set_hudmessage(0, 200, 0, -1.0, 0.4, 0, 0.0, 1.0, 0.0, 0.5, -1);
	ShowSyncHudMsg(id, g_hudSyncObj, "[%n]^n你有 %d 秒登入.", id, timeLeft);
	
	sendScreenFade(id, 2.0, 1.0, 0x0000, {0, 0, 0}, 150);
	
	ShowLoginMenu(id);
}

stock bool:registerSubmit(id)
{
	if (!isPasswordValid(g_inputData[id][1]))
	{
		client_print(id, print_chat, "[LogMeIn] 密碼至少要有 6 個字及只能包含英文字母及數字 (A-Z 0-9 _).");
		return false;
	}
	
	if (!equal(g_inputData[id][1], g_inputData[id][2]))
	{
		client_print(id, print_chat, "[LogMeIn] 你的密碼與確認密碼不相同.");
		return false;
	}
	
	passwordHash(g_inputData[id][1], SALT, g_password[id], charsmax(g_password[]));
	saveUser(id);
	
	g_status[id] = USER_LOGGED_IN;
	
	client_print(id, print_chat, "[LogMeIn] 你成功註冊及登入.");
	return true;
}

stock bool:loginSubmit(id)
{
	if (g_wrong[id] >= 5)
	{
		kickPlayer(id, "You have tried too many times to login.");
		return false;
	}
	
	if (!passwordVerify(g_inputData[id][1], g_password[id], SALT))
	{
		g_wrong[id]++;
		client_print(id, print_chat, "[LogMeIn] 密碼錯誤. [%d/5]", g_wrong[id]);
		return false;
	}
	
	loginUser(id);
	engclient_cmd(id, "chooseteam");
	return true;
}

stock bool:changeSubmit(id)
{
	if (!passwordVerify(g_inputData[id][0], g_password[id], SALT))
	{
		client_print(id, print_chat, "[LogMeIn] 你的舊密碼錯誤.");
		return false;
	}
	
	if (!isPasswordValid(g_inputData[id][1]))
	{
		client_print(id, print_chat, "[LogMeIn] 密碼至少要有 6 個字及只能包含英文字母及數字 (A-Z 0-9 _).");
		return false;
	}
	
	if (!equal(g_inputData[id][1], g_inputData[id][2]))
	{
		client_print(id, print_chat, "[LogMeIn] 你的密碼與確認密碼不相同.");
		return false;
	}
	
	new hash[40];
	passwordHash(g_inputData[id][1], SALT, hash, charsmax(hash));
	
	if (equal(hash, g_password[id]))
	{
		client_print(id, print_chat, "[LogMeIn] 請輸入一個新的密碼.");
		return false;
	}
	
	g_password[id] = hash;
	updateUser(id);
	
	client_print(id, print_chat, "[LogMeIn] 你的密碼已更新.");
	return true;
}

stock kickPlayer(id, const reason[])
{
	server_cmd("kick #%d ^"%s^"", get_user_userid(id), reason);
}

stock loginUser(id)
{
	g_status[id] = USER_LOGGED_IN;
	g_timer[id] = -999999.0;
	
	remove_task(id);
	
	client_print(id, print_chat, "[LogMeIn] 你成功登入了.");
}

stock checkUser(id)
{
	new name[32];
	get_user_name(id, name, charsmax(name));
	
	new data[256];
	if (fvault_get_data(VAULT_NAME, name, data, charsmax(data)))
	{
		replace_string(data, charsmax(data), "㈱", "^"");
		
		new hash[40];
		parse(data, hash, charsmax(hash));
		
		g_password[id] = hash;
		g_status[id] = USER_REGISTERED;
		
		new info[32];
		get_user_info(id, AUTOLOGIN_INFO, info, charsmax(info));
		
		if (passwordVerify(info, hash, SALT))
		{
			loginUser(id);
			g_autoLogin[id] = true;
		}
		else
		{
			g_timer[id] = get_gametime();
			set_task(1.0, "TaskLogin", id, _, _, "b");
			
			g_autoLogin[id] = false;
		}
	}
	else
	{
		g_status[id] = USER_UNREGISTERED;
	}
}

stock saveUser(id)
{
	new address[16];
	get_user_ip(id, address, charsmax(address), 1);
	
	new authId[40];
	get_user_authid(id, authId, charsmax(authId));
	
	new dateTime[32];
	get_time("%Y/%m/%d %H:%M:%S", dateTime, charsmax(dateTime));
	
	new data[256];
	formatex(data, charsmax(data), "%s %s %s ㈱%s㈱", g_password[id], authId, address, dateTime);

	new name[32];
	get_user_name(id, name, charsmax(name));
	
	fvault_set_data(VAULT_NAME, name, data);
}

stock updateUser(id)
{
	new name[32];
	get_user_name(id, name, charsmax(name));
	
	new data[256];
	fvault_get_data(VAULT_NAME, name, data, charsmax(data));
	replace_string(data, charsmax(data), "㈱", "^"");
	
	new left[2];
	argbreak(data, left, charsmax(left), data, charsmax(data));
	
	new string[256];
	formatex(string, charsmax(string), "%s ", g_password[id]);
	add(string, charsmax(string), data);
	
	fvault_set_data(VAULT_NAME, name, string);
}


stock passwordHash(const password[], const salt[], output[], len)
{
	new string[64];
	copy(string, charsmax(string), password);
	add(string, charsmax(string), salt);
	
	hash_string(string, Hash_Sha1, output, len);
}

stock bool:passwordVerify(const password[], const hash[], const salt[])
{
	new hash2[40];
	passwordHash(password, salt, hash2, charsmax(hash2));
	
	if (equal(hash, hash2))
		return true;
	
	return false;
}

stock bool:isPasswordValid(const password[])
{
	new ret, error[64];
	new Regex:regex = regex_match(password, "^^[a-zA-Z0-9_]{6,}$", ret, error, charsmax(error));
	if (regex > REGEX_NO_MATCH)
		return true;
	
	return false;
}

stock clearInputData(id)
{
	for (new i = 0; i < sizeof g_inputData[]; i++)
		g_inputData[id][i][0] = 0;
}

stock getMenuType(id)
{
	new menuId, keys;
	get_user_menu(id, menuId, keys);
	
	if (menuId == g_menuMain)
		return MENU_MAIN;

	if (menuId == g_menuRegister)
		return MENU_REGISTER;
	
	if (menuId == g_menuLogin)
		return MENU_LOGIN;
	
	if (menuId == g_menuChange)
		return MENU_CHANGE;
	
	return MENU_NONE;
}

stock sendScreenFade(id, Float:duration, Float:holdTime, flags, color[3], alpha)
{
	static msgScreenFade;
	msgScreenFade || (msgScreenFade = get_user_msgid("ScreenFade"));
	
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msgScreenFade, _, id);
	write_short(fixedUnsigned16(duration, (1 << 12)));
	write_short(fixedUnsigned16(holdTime, (1 << 12)));
	write_short(flags);
	write_byte(color[0]);
	write_byte(color[1]);
	write_byte(color[2]);
	write_byte(alpha);
	message_end();
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