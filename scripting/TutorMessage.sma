#include <amxmodx>

#define VERSION "0.0.1"
#define PLUGIN "TutorText"

#define TASK_OFFSET 1354897

enum TutorSounds {
    DefaultTutor,
    FriendDied,
    EnemyDied,
    TaskComplete,
    TutorNoSound
}

new const g_szTutorSounds[TutorSounds][] = 
{
    "sound/events/tutor_msg.wav", // Yellow, Green
    "sound/events/friend_died.wav", // Red
    "sound/events/enemy_died.wav", // Blue
    "sound/events/task_complete.wav" // Green
}

enum TutorColors ( <<= 1 )
{
    TutorGreen = 1,
    TutorRed,
    TutorBlue,
    TutorYellow
}

new g_iTutorText, g_iTutorClose

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, "ConnorMcLeod")
    g_iTutorText = get_user_msgid("TutorText")
    g_iTutorClose = get_user_msgid("TutorClose")
}

public plugin_natives()
{
    register_library("cztutor")
    register_native("client_tutor", "client_tutor")
}

public plugin_precache()
{
    new szModName[9]
    get_modname(szModName, charsmax(szModName))
    if( !equal(szModName, "czero") )
    {
        set_fail_state("Only works on condition zero")
    }
}

// client_tutor(id, TutorColors:iColor, TutorSounds:iSound, Float:flCloseDelay=8.0, fmt[], any:...)
public client_tutor(iPlugin, iParams)
{
    new id = get_param(1)
    new TutorColors:iColor = TutorColors:get_param(2)
    new TutorSounds:iSound = TutorSounds:get_param(3)
    new Float:flDelay = get_param_f(4)
    new szText[256]
    if( iParams == 5 )
    {
        get_string(5, szText, charsmax(szText))
        Send_TutorText(id, iColor, iSound, flDelay, szText)
    }
    else if( id || iParams == 6 )
    {
        vdformat(szText, charsmax(szText), 5, 6)
        Send_TutorText(id, iColor, iSound, flDelay, szText)
    }
    else // iParams > 6
    {
        new iPlayers[32], iNum
        get_players(iPlayers, iNum, "ch")
        if( !iNum )
        {
            return 0
        }
        new i, j, Array:aStoreML = ArrayCreate(), iMlCount
        for(i=6; i<iParams; i++)
        {
            if( get_param_byref(i) == LANG_PLAYER )
            {
                get_string(i+1, szText, charsmax(szText))
                if( GetLangTransKey(szText) != TransKey_Bad )
                {
                    ArrayPushCell(aStoreML, i++)
                    iMlCount++
                }
            }
        }
        if( !iMlCount )
        {
            vdformat(szText, charsmax(szText), 5, 6)
            Send_TutorText(id, iColor, iSound, flDelay, szText)
        }
        else
        {
            for(i=0; i<iNum; i++)
            {
                id = iPlayers[i]
                for(j=0; j<iMlCount; j++)
                {
                    set_param_byref(ArrayGetCell(aStoreML, j), id)
                }
                vdformat(szText, charsmax(szText), 5, 6)
                Send_TutorText(id, iColor, iSound, flDelay, szText)
            }
        }
        ArrayDestroy(aStoreML)
    }
    return 1
}

Send_TutorText(id, TutorColors:iType, TutorSounds:iSound, Float:flDelay, const szText[])
{
    if( iSound != TutorNoSound )
    {
        client_cmd(id, "spk %s", g_szTutorSounds[iSound])
    }

    message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, g_iTutorText, .player=id)
    write_string(szText)
    write_byte(0)
    write_short(-1) // TutorMessageEventI
    write_short( id && !is_user_alive(id) ) 
    write_short( _:iType )
    message_end()

    id += TASK_OFFSET
    remove_task(id)
    if( flDelay > 0.0 )
    {
        set_task(flDelay, "TutorClose", id)
    }
}

public TutorClose(id)
{
    id -= TASK_OFFSET
    if( id )
    {
        message_begin(MSG_ONE_UNRELIABLE, g_iTutorClose, .player=id)
        message_end()
    }
    else
    {
        new iPlayers[32], iNum
        get_players(iPlayers, iNum, "ch")
        for(new i; i<iNum; i++)
        {
            id = iPlayers[i]
            if( !task_exists(id+TASK_OFFSET) )
            {
                message_begin(MSG_ONE_UNRELIABLE, g_iTutorClose, .player=id)
                message_end()
            }
        }
    }
}  