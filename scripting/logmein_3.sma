#include <amxmodx>
#include <fakemeta>
#include <regex>
#include <fvault>

#define VERSION "0.1"

#define LOGMEIN_VAULT "logmein"
#define AUTOLOGIN_VAULT "logmein_autologin"
#define SALT "201611280323TheLazyFoxJumpsOverTheQuickBrownDog"
#define TEMP_PLAYER_NAME "zm92ji31Ka9plsjqu32902ias"
enum
{
	MENU_NONE = 0,
	MENU_REGISTER,
	MENU_LOGIN,
	MENU_CHANGE,
};

enum
{
	USER_NOT_SIGNED = 0,
	USER_SIGNED_IN
}

new g_name[33][32];
new g_username[33][32];
new g_password[33][40];
new bool:g_autoLogin[33];
new g_status[33];
new g_wrongs[33];
new Float:g_timer[33] = {-999999.0, ...};

new g_inputData[33][3][32];

new g_registerMenuId;
new g_loginMenuId;
new g_changeMenuId;

new g_loginForward;
new g_logoutForward;
new g_return;

public plugin_init()
{
	register_plugin("LogMeIn", VERSION, "penguinux");
	
	register_clcmd("say /register", "CmdSayRegister");
	register_clcmd("say /reg", "CmdSayRegister");
	register_clcmd("say /login", "CmdSayRegister");
	
	register_clcmd("_ENTER_USERNAME", "CmdEnterUsername");
	register_clcmd("_ENTER_PASSWORD", "CmdEnterPassword");
	register_clcmd("_ENTER_CONFIRM_PASSWORD", "CmdEnterConfirmPassword");
	register_clcmd("_ENTER_OLD_PASSWORD", "CmdEnterOldPassword");
	
	register_logevent("EventEnteredTheGame", 2, "1=entered the game");
	
	register_forward(FM_ClientUserInfoChanged, "OnClientUserInfoChanged");
	
	g_registerMenuId = register_menuid("Register Menu");
	g_loginMenuId = register_menuid("Login Menu");
	g_changeMenuId = register_menuid("Change Menu");
	
	register_menucmd(register_menuid("LogMeIn Menu"), 1023, "HandleLogmeinMenu");
	register_menucmd(g_registerMenuId, 1023, "HandleRegisterMenu");
	register_menucmd(g_loginMenuId, 1023, "HandleLoginMenu");
	register_menucmd(g_changeMenuId, 1023, "HandleChangeMenu");
	
	g_loginForward = CreateMultiForward("Logmein_Login", ET_IGNORE, FP_CELL);
	g_logoutForward = CreateMultiForward("Logmein_Logout", ET_IGNORE, FP_CELL);
}

public plugin_natives()
{
	register_library("logmein");
	
	register_native("logmein_GetUsername", "native_GetUsername");
	register_native("logmein_GetPassword", "native_GetPassword");
	register_native("logmein_GetName", "native_GetName");
	register_native("logmein_GetStatus", "native_GetStatus");
	register_native("logmein_GetAutoLogin", "native_GetAutoLogin");
}

public native_GetUsername()
{
	new id = get_param(1);
	set_string(2, g_username[id], get_param(3));
}

public native_GetPassword()
{
	new id = get_param(1);
	set_string(2, g_password[id], get_param(3));
}

public native_GetName()
{
	new id = get_param(1);
	set_string(2, g_name[id], get_param(3));
}

public native_GetStatus()
{
	new id = get_param(1);
	return g_status[id];
}

public bool:native_GetAutoLogin()
{
	new id = get_param(1);
	return g_autoLogin[id];
}

public CmdSayRegister(id)
{
	ShowLogmeinMenu(id);
	return PLUGIN_HANDLED;
}

public CmdEnterUsername(id)
{
	new type = getMenuType(id);
	if (type == MENU_REGISTER || type == MENU_LOGIN)
	{
		read_argv(1, g_inputData[id][0], charsmax(g_inputData[][]));
		
		if (type == MENU_REGISTER)
			ShowRegisterMenu(id);
		else
			ShowLoginMenu(id);	
	}
	
	return PLUGIN_HANDLED;
}

public CmdEnterPassword(id)
{
	new type = getMenuType(id);
	if (type == MENU_REGISTER || type == MENU_LOGIN || type == MENU_CHANGE)
	{
		read_argv(1, g_inputData[id][1], charsmax(g_inputData[][]));
		
		if (type == MENU_REGISTER)
			ShowRegisterMenu(id);
		else if (type == MENU_LOGIN)
			ShowLoginMenu(id);
		else
			ShowChangeMenu(id);
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

public EventEnteredTheGame()
{
	new logUser[80], name[32];
	read_logargv(0, logUser, charsmax(logUser));
	parse_loguser(logUser, name, charsmax(name));
	
	new id = get_user_index(name);
	
	new authId[40];
	get_user_authid(id, authId, charsmax(authId));
	
	if (isAuthIdValid(authId))
	{
		new username[32];
		if (fvault_get_data(AUTOLOGIN_VAULT, authId, username, charsmax(username)))
		{
			if (username[0])
			{
				loginUser(id, username);
			}
		}
	}
}

public OnClientUserInfoChanged(id)
{
	new oldName[32];
	pev(id, pev_netname, oldName, charsmax(oldName));
	
	if (oldName[0])
	{
		new newName[32];
		get_user_info(id, "name", newName, charsmax(newName));
		
		if (!equal(oldName, newName))
		{
			if (equal(newName, g_name[id]) 
			|| (equal(oldName, g_name[id]) && newName[0] == '(' && isdigit(newName[1]) && newName[2] == ')' && equal(newName[3], g_name[id])))
			{
				if (equal(oldName, g_name[id]))
					g_name[id][0] = 0;
				
				set_user_info(id, "name", newName);
				
				static msgSayText;
				msgSayText || (msgSayText = get_user_msgid("SayText"));
				
				message_begin(MSG_BROADCAST, msgSayText);
				write_byte(id);
				write_string("Cstrike_Name_Change");
				write_string(oldName);
				write_string(newName);
				message_end();
				
				return FMRES_SUPERCEDE;
			}
			
			if (g_status[id] == USER_SIGNED_IN)
			{
				if (isNameExists(newName))
				{
					client_print(id, print_chat, "* This name has already been taken.");
					set_user_info(id, "name", oldName);
					return FMRES_SUPERCEDE;
				}
				
				g_name[id] = newName;
				updateUser(id);
			}
		}
	}
	
	return FMRES_IGNORED;
}

public client_disconnected(id)
{
	g_status[id] = USER_NOT_SIGNED;
	
	g_autoLogin[id] = false;
	g_name[id][0] = 0;
	g_username[id][0] = 0;
	g_password[id][0] = 0;
	g_wrongs[id] = 0;
	g_timer[id] = -999999.0;
	
	clearInputData(id);
	remove_task(id);
	
	ExecuteForward(g_logoutForward, g_return, id);
}

public ShowLogmeinMenu(id)
{
	static menu[512], len;

	len = formatex(menu, charsmax(menu), "\yLogMeIn Menu");
	
	new keys = MENU_KEY_9|MENU_KEY_0;
	
	if (g_status[id] == USER_NOT_SIGNED)
	{
		len += formatex(menu[len], 511-len, "^n^n");
		len += formatex(menu[len], 511-len, "\y1. \wRegister^n");
		len += formatex(menu[len], 511-len, "\y2. \wLogin^n");
		keys |= MENU_KEY_1|MENU_KEY_2;
	}
	else
	{
		len += formatex(menu[len], 511-len, " \y[\w%s\y]^n^n", g_username[id]);
		len += formatex(menu[len], 511-len, "\y1. \wChange password^n");
		len += formatex(menu[len], 511-len, "\y2. \wAuto login \d(Steam only)\w: %s^n", g_autoLogin[id] ? "\yOn" : "\dOff");
		len += formatex(menu[len], 511-len, "\y3. \wLogout^n");
		keys |= MENU_KEY_1|MENU_KEY_2|MENU_KEY_3;
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
			if (g_status[id] == USER_NOT_SIGNED)
				ShowRegisterMenu(id);
			else
				ShowChangeMenu(id);
		}
		case 1:
		{
			if (g_status[id] == USER_NOT_SIGNED)
				ShowLoginMenu(id);
			else
				setAutoLogin(id, !g_autoLogin[id]);
		}
		case 2:
		{
			if (g_status[id] == USER_SIGNED_IN)
			{
				logoutUser(id);
			}
		}
		case 8:
		{
			client_print(id, print_chat, "Nothing to help.");
		}
	}
}

public ShowRegisterMenu(id)
{
	static menu[512], len;
	
	len = formatex(menu, charsmax(menu), "\yRegister Menu^n^n");
	
	len += formatex(menu[len], 511-len, "\y1. \wUsername: \y%s^n", !g_inputData[id][0][0] ? "\dPress to enter" : g_inputData[id][0]);
	
	new censored[32], len2;
	len2 = strlen(g_inputData[id][1]);
	for (new i = 0; i < len2; i++)
		censored[i] = '*';
	
	len += formatex(menu[len], 511-len, "\y2. \wPassword: \y%s^n", !censored[0] ? "\dPress to enter" : censored);
	
	arrayset(censored, 0, sizeof censored);
	len2 = strlen(g_inputData[id][2]);
	for (new i = 0; i < len2; i++)
		censored[i] = '*';
	
	len += formatex(menu[len], 511-len, "\y3. \wConfirm Password: \y%s^n", !censored[0] ? "\dPress to enter" : censored);
	len += formatex(menu[len], 511-len, "\d(All passwords are encrypted with \wSHA1\d)^n");

	len += formatex(menu[len], 511-len, "^n\y9. \wRegister^n");
	len += formatex(menu[len], 511-len, "^n\y0. \wExit");
	
	new keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_9|MENU_KEY_0;
	
	show_menu(id, keys, menu, -1, "Register Menu");
}

public HandleRegisterMenu(id, key)
{
	if (g_status[id] == USER_SIGNED_IN)
		return;
	
	switch (key)
	{
		case 0:
		{
			client_cmd(id, "messagemode _ENTER_USERNAME");
			ShowRegisterMenu(id);
		}
		case 1:
		{
			client_cmd(id, "messagemode _ENTER_PASSWORD");
			ShowRegisterMenu(id);
		}
		case 2:
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
	
	len = formatex(menu, charsmax(menu), "\yLogin Menu^n^n");
	
	len += formatex(menu[len], 511-len, "\y1. \wUsername: \y%s^n", !g_inputData[id][0][0] ? "\dPress to enter" : g_inputData[id][0]);
	
	new censored[32], len2;
	len2 = strlen(g_inputData[id][1]);
	for (new i = 0; i < len2; i++)
		censored[i] = '*';
	
	len += formatex(menu[len], 511-len, "\y2. \wPassword: \y%s^n", !censored[0] ? "\dPress to enter" : censored);

	len += formatex(menu[len], 511-len, "^n\y9. \wLogin^n");
	len += formatex(menu[len], 511-len, "^n\y0. \wExit");
	
	new keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_9|MENU_KEY_0;
	
	show_menu(id, keys, menu, -1, "Login Menu");
}

public HandleLoginMenu(id, key)
{
	if (g_status[id] == USER_SIGNED_IN)
		return;
	
	switch (key)
	{
		case 0:
		{
			client_cmd(id, "messagemode _ENTER_USERNAME");
			ShowLoginMenu(id);
		}
		case 1:
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
	
	len = formatex(menu, charsmax(menu), "\yChange Your Password^n^n");
	
	new censored[32], len2;
	len2 = strlen(g_inputData[id][0]);
	for (new i = 0; i < len2; i++)
		censored[i] = '*';

	len += formatex(menu[len], 511-len, "\y1. \wOld Password: \y%s^n", !censored[0] ? "\dPress to enter" : censored);
	
	arrayset(censored, 0, sizeof censored);
	len2 = strlen(g_inputData[id][1]);
	for (new i = 0; i < len2; i++)
		censored[i] = '*';
	
	len += formatex(menu[len], 511-len, "\y2. \wNew Password: \y%s^n", !censored[0] ? "\dPress to enter" : censored);

	arrayset(censored, 0, sizeof censored);
	len2 = strlen(g_inputData[id][2]);
	for (new i = 0; i < len2; i++)
		censored[i] = '*';
	
	len += formatex(menu[len], 511-len, "\y3. \wConfirm Password: \y%s^n", !censored[0] ? "\dPress to enter" : censored);

	len += formatex(menu[len], 511-len, "^n\y9. \wChange^n");
	len += formatex(menu[len], 511-len, "^n\y0. \wExit");
	
	new keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_9|MENU_KEY_0;
	
	show_menu(id, keys, menu, -1, "Change Menu");
}

public HandleChangeMenu(id, key)
{
	if (g_status[id] == USER_NOT_SIGNED)
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

public ChangeName(id)
{
	if (is_user_connected(id))
	{
		set_user_info(id, "name", g_name[id]);
	}
}

stock bool:registerSubmit(id)
{
	if (g_wrongs[id] >= 10 || get_gametime() < g_timer[id] + 60.0)
	{
		if (g_wrongs[id] != 0)
		{
			g_wrongs[id] = 0;
			g_timer[id] = get_gametime();
		}

		client_print(id, print_chat, "[LogMeIn] You have tried to register too many times, please try again later.");
		return false;
	}
	
	if (!isUsernameValid(g_inputData[id][0]))
	{
		g_wrongs[id]++;
		client_print(id, print_chat, "[LogMeIn] A username must have 3-16 characters and it can only contain alphanumeric characters (A-Z 0-9 _).");
		return false;
	}
	
	if (!isPasswordValid(g_inputData[id][1]))
	{
		g_wrongs[id]++;
		client_print(id, print_chat, "[LogMeIn] A password must have at least 6 characters and it can only contain alphanumeric characters (A-Z 0-9 _).");
		return false;
	}
	
	if (!equal(g_inputData[id][1], g_inputData[id][2]))
	{
		g_wrongs[id]++;
		client_print(id, print_chat, "[LogMeIn] Your password doesn't match the confirmation password.");
		return false;
	}
	
	if (isUsernameExists(g_inputData[id][0]))
	{
		g_wrongs[id]++;
		client_print(id, print_chat, "[LogMeIn] Your username already exists.");
		return false;
	}
	
	new name[32];
	get_user_name(id, name, charsmax(name));
	
	if (isNameExists(name))
	{
		g_wrongs[id]++;
		client_print(id, print_chat, "[LogMeIn] Your name has already been taken, please rename and retry.");
		return false;
	}
	
	g_wrongs[id] = 0;

	g_name[id] = name;
	copy(g_username[id], charsmax(g_username[]), g_inputData[id][0]);
	passwordHash(g_inputData[id][1], SALT, g_password[id], charsmax(g_password[]));
	saveUser(id);
	
	g_status[id] = USER_SIGNED_IN;
	
	ExecuteForward(g_loginForward, g_return, id);
	
	client_print(id, print_chat, "[LogMeIn] You have successfully registered and logged in. Thank you for registering.");
	return true;
}

stock bool:loginSubmit(id)
{
	if (g_wrongs[id] >= 3 || get_gametime() < g_timer[id] + 60.0)
	{
		if (g_wrongs[id] != 0)
		{
			g_wrongs[id] = 0;
			g_timer[id] = get_gametime();
		}

		client_print(id, print_chat, "[LogMeIn] You have tried to login too many times, please try again later.");
		return false;
	}
	
	new data[256];
	if (!fvault_get_data(LOGMEIN_VAULT, g_inputData[id][0], data, charsmax(data)))
	{
		client_print(id, print_chat, "[LogMeIn] Username doesn't exists.");
		g_wrongs[id]++;
		return false;
	}
	
	replace_string(data, charsmax(data), "㈱", "^"");
	
	new name[32], hash[40];
	parse(data, name, charsmax(name), hash, charsmax(hash));
	
	if (!passwordVerify(g_inputData[id][1], hash, SALT))
	{
		client_print(id, print_chat, "[LogMeIn] Incorrect password.");
		g_wrongs[id]++;
		return false;
	}
	
	loginUser(id, g_inputData[id][0]);
	return true;
}

stock bool:changeSubmit(id)
{
	if (!passwordVerify(g_inputData[id][0], g_password[id], SALT))
	{
		client_print(id, print_chat, "[LogMeIn] Your old password is incorrect.");
		return false;
	}
	
	if (!isPasswordValid(g_inputData[id][1]))
	{
		client_print(id, print_chat, "[LogMeIn] A password must have at least 6 characters and it can only contain alphanumeric characters (A-Z 0-9 _).");
		return false;
	}
	
	if (!equal(g_inputData[id][1], g_inputData[id][2]))
	{
		client_print(id, print_chat, "[LogMeIn] Your new password doesn't match the confirmation password.");
		return false;
	}
	
	new hash[40];
	passwordHash(g_inputData[id][1], SALT, hash, charsmax(hash));
	
	if (equal(hash, g_password[id]))
	{
		client_print(id, print_chat, "[LogMeIn] Please use a different password.");
		return false;
	}
	
	g_password[id] = hash;
	updateUser(id);
	
	client_print(id, print_chat, "[LogMeIn] Your password has been updated.");
	return true;
}

stock bool:loginUser(id, const username[])
{
	new data[256];
	if (!fvault_get_data(LOGMEIN_VAULT, username, data, charsmax(data)))
		return false;
	
	replace_string(data, charsmax(data), "㈱", "^"");
	
	new name[32], hash[40];
	parse(data, name, charsmax(name), hash, charsmax(hash));
	
	copy(g_username[id], charsmax(g_username[]), username);
	g_password[id] = hash;
	g_name[id] = name;
	
	g_wrongs[id] = 0;
	g_status[id] = USER_SIGNED_IN;
	
	g_autoLogin[id] = false;
	
	new authId[40];
	get_user_authid(id, authId, charsmax(authId));
	
	if (fvault_get_data(AUTOLOGIN_VAULT, authId, data, charsmax(data)))
	{
		if (equal(data, username))
			g_autoLogin[id] = true;
	}
	
	changeName(id, name);
	
	ExecuteForward(g_loginForward, g_return, id);
	
	client_print(id, print_chat, "[LogMeIn] You have successfully logged in.");
	return true;
}

stock logoutUser(id)
{
	g_status[id] = USER_NOT_SIGNED;
	
	g_autoLogin[id] = false;
	g_name[id][0] = 0;
	g_username[id][0] = 0;
	g_password[id][0] = 0;
	g_wrongs[id] = 0;
	g_timer[id] = -999999.0;
	
	clearInputData(id);
	
	ExecuteForward(g_logoutForward, g_return, id);
	
	client_print(id, print_chat, "[LogMeIn] You have logged out.");
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
	formatex(data, charsmax(data), "㈱%n㈱ %s %s %s ㈱%s㈱", id, g_password[id], authId, address, dateTime);

	fvault_set_data(LOGMEIN_VAULT, g_username[id], data);
}

stock updateUser(id)
{
	new data[256];
	fvault_get_data(LOGMEIN_VAULT, g_username[id], data, charsmax(data));
	replace_string(data, charsmax(data), "㈱", "^"");
	
	new left[2];
	for (new i = 0; i < 2; i++)
		argbreak(data, left, charsmax(left), data, charsmax(data));
	
	new string[256];
	formatex(string, charsmax(string), "^"%s^" %s ", g_name[id], g_password[id]);
	add(string, charsmax(string), data);
	
	replace_string(string, charsmax(string), "^"", "㈱");
	
	fvault_set_data(LOGMEIN_VAULT, g_username[id], string);
}

stock setAutoLogin(id, bool:set)
{
	new authId[40];
	get_user_authid(id, authId, charsmax(authId));
	
	if (set)
	{
		if (isAuthIdValid(authId))
		{
			new data[32];
			if (fvault_get_data(AUTOLOGIN_VAULT, authId, data, charsmax(data)))
			{
				client_print(id, print_chat, "[LogMeIn] You have other account (%s) is using this function.", data);
				return;
			}
			else
			{
				fvault_set_data(AUTOLOGIN_VAULT, authId, g_username[id]);
				client_print(id, print_chat, "[LogMeIn] You have enabled auto login.");
			}
		}
		else
		{
			client_print(id, print_chat, "[LogMeIn] This function is for steam user only.");
			return;
		}
	}
	else
	{
		fvault_remove_key(AUTOLOGIN_VAULT, authId);
		client_print(id, print_chat, "[LogMeIn] You have disabled auto login.");
	}
	
	g_autoLogin[id] = set;
}

stock bool:isAuthIdValid(const authId[])
{
	return bool:(equal(authId, "STEAM_", 6) && isdigit(authId[6]))
}

stock clearInputData(id)
{
	for (new i = 0; i < sizeof g_inputData[]; i++)
		g_inputData[id][i][0] = 0;
}

stock changeName(id, const name[])
{
	new player = get_user_index(name);
	if (player)
	{
		if (player != id)
		{
			new newName[32];
			copy(newName, charsmax(newName), name);
			
			new num = 0;
			while (get_user_index(newName))
			{
				num++;
				formatex(newName, charsmax(newName), "(%d)%s", num, name);
			}
			
			copy(g_name[player], charsmax(g_name[]), name);
			set_user_info(player, "name", newName);
			
			remove_task(id);
			set_task(0.1, "ChangeName", id);
		}
	}
	else
	{
		set_user_info(id, "name", name);
	}
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

stock bool:isUsernameValid(const username[])
{
	new ret, error[64];
	new Regex:regex = regex_match(username, "^^[a-zA-Z0-9_]{3,}$", ret, error, charsmax(error));
	if (regex > REGEX_NO_MATCH)
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

stock bool:isUsernameExists(const username[])
{
	new data[2];
	if (fvault_get_data(LOGMEIN_VAULT, username, data, charsmax(data)))
		return true;
	
	return false;
}

stock bool:isNameExists(const name[])
{
	new bool:ret = false;
	new Array:datas = ArrayCreate(256);

	new name2[32], data[256];
	new size = fvault_load(LOGMEIN_VAULT, _, datas);

	for(new i = 0; i < size; i++)
	{
		ArrayGetString(datas, i, data, charsmax(data));
		
		replace_string(data, charsmax(data), "㈱", "^"");
		argbreak(data, name2, charsmax(name2), data, charsmax(data));
		
		if (equal(name, name2))
		{
			ret = true;
			break;
		}
	}
	
	ArrayDestroy(datas);
	return ret;
}

stock getMenuType(id)
{
	new menuId, keys;
	get_user_menu(id, menuId, keys);
	
	if (menuId == g_registerMenuId)
		return MENU_REGISTER;
	
	if (menuId == g_loginMenuId)
		return MENU_LOGIN;
	
	if (menuId == g_changeMenuId)
		return MENU_CHANGE;
	
	return MENU_NONE;
}