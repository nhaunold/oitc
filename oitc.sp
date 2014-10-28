//
// Copyright 2013 Nicolas Haunold.
// Thanks to the internet for the server tag stuff.
//

#include <sourcemod>
#include <smlib>

#define CHAMBER_VERSION				"0.1"

public Plugin:myinfo =
{
	name = "One in the Chamber",
	author = "Nicolas Haunold",
	description = "",
	version = CHAMBER_VERSION,
	url = ""
}

new Handle:chamber = INVALID_HANDLE
new Handle:chamber_weapon = INVALID_HANDLE

public OnPluginStart()
{
	chamber = CreateConVar("chamber", "1", "Enable OITC")
	chamber_weapon = CreateConVar("chamber_weapon", "deagle", "OITC weapon")

	HookConVarChange(chamber_weapon, CVar_WeaponChanged)
	HookConVarChange(chamber, CVar_ChamberStatusChanged)
	HookEvent("round_start", Event_RoundStart)
	HookEvent("player_spawn", Event_PlayerSpawn)
	HookEvent("player_hurt", Event_PlayerHurt)

	AutoExecConfig(true, "plugin_oitc")
}

public OnConfigsExecuted()
{
	Fixed_AddServerTag("oitc")
}

public OnMapStart()
{
	// Remove every buy zone from the map.
	decl String:class_name[64];
	for (new i = 0; i <= GetMaxEntities(); i++) {
		if (IsValidEdict(i) && IsValidEntity(i)) {
			GetEdictClassname(i, class_name, sizeof(class_name))
			if (StrEqual("func_buyzone", class_name)) {
				RemoveEdict(i)
			}
		}
	}
}

public OnClientPutInServer(client)
{
	CreateTimer(15.0, Timer_Welcome, client)
}

// Configuration
public IsEnabled()
{
	return GetConVarBool(chamber)
}

// Functions
stock HandlePlayerHurt(attacker, victim, increase_ammo=false)
{
	new weap
	new String:weapon[32]
	new String:engine_weapon[64]
	GetConVarString(chamber_weapon, weapon, sizeof(weapon))
	Format(engine_weapon, sizeof(engine_weapon), "weapon_%s", weapon)
	weap = Client_GetWeapon(attacker, engine_weapon)

	if (IsValidEntity(weap)) {
		SetEntityHealth(victim, 0)
		Client_SetWeaponPlayerAmmo(attacker, engine_weapon, 0)

		if (increase_ammo) {
			SetEntProp(Client_GetWeapon(attacker, engine_weapon), Prop_Send, "m_iClip1", GetEntProp(Client_GetWeapon(attacker, engine_weapon), Prop_Data, "m_iClip1") + 1);
		} else {
			SetEntProp(Client_GetWeapon(attacker, engine_weapon), Prop_Send, "m_iClip1", 1);
		}
	}
}

stock Fixed_AddServerTag(const String:tag[])
{
	new Handle:hTags = INVALID_HANDLE
	hTags = FindConVar("sv_tags")
	if (hTags != INVALID_HANDLE) {
		decl String:tags[256]
		GetConVarString(hTags, tags, sizeof(tags))
		if (StrContains(tags, tag, true) > 0) return
		if (strlen(tags) == 0) {
			Format(tags, sizeof(tags), tag)
		} else {
			Format(tags, sizeof(tags), "%s,%s", tags, tag)
		}

		SetConVarString(hTags, tags, true)
	}
}

stock Fixed_RemoveServerTag(const String:tag[])
{
	new Handle:hTags = INVALID_HANDLE
	hTags = FindConVar("sv_tags")
	if (hTags != INVALID_HANDLE) {
		decl String:tags[50]
		GetConVarString(hTags, tags, sizeof(tags))
		if (StrEqual(tags, tag, true)) {
			Format(tags, sizeof(tags), "")
			SetConVarString(hTags, tags, true)
			return
		}

		new pos = StrContains(tags, tag, true)
		new len = strlen(tags)
		if (len > 0 && pos > -1) {
			new bool:found
			new String:taglist[50][50]
			ExplodeString(tags, ",", taglist, sizeof(taglist[]), sizeof(taglist))
			for (new i; i < sizeof(taglist[]); i++) {
				if (StrEqual(taglist[i], tag, true)) {
					Format(taglist[i], sizeof(taglist), "")
					found = true
					break
				}
			}
			if (!found) return;
			ImplodeStrings(taglist, sizeof(taglist[]), ",", tags, sizeof(tags));
			if (pos == 0) {
				tags[0] = 0x20;
			} else if (pos == len-1) {
				Format(tags[strlen(tags)-1], sizeof(tags), "");
			} else {
				ReplaceString(tags, sizeof(tags), ",,", ",");
			}
			SetConVarString(hTags, tags, true)
		}
	}
}

// Cvar hooks
public CVar_WeaponChanged(Handle:CVar, const String:oldvalue[], const String:newvalue[])
{
	if (!IsEnabled()) return

	PrintToChatAll("\x03[One in the Chamber]\x01 Next up: %s", newvalue)
	Game_EndRound()
}

public CVar_ChamberStatusChanged(Handle:CVar, const String:oldvalue[], const String:newvalue[])
{
	if (IsEnabled()) {
		Fixed_AddServerTag("oitc")
	} else {
		Fixed_RemoveServerTag("oitc")
	}
}

// Event hooks
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!IsEnabled()) return

	// Remove ground weapons & items
	decl String:class_name[64]
	for (new i = 0; i <= GetMaxEntities(); i++) {
		if (IsValidEdict(i) && IsValidEntity(i)) {
			GetEdictClassname(i, class_name, sizeof(class_name))
			if (StrContains(class_name, "weapon_") >= 0 || StrContains(class_name, "item_") >= 0) {
				AcceptEntityInput(i, "Kill")
			}
		}
	}
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!IsEnabled()) return
	new player = GetClientOfUserId(GetEventInt(event, "userid"))

	Client_RemoveAllWeapons(player)
	CreateTimer(0.5, Timer_SetAmmo, player)
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!IsEnabled()) return

	new String:weapon[32]
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"))
	new victim = GetClientOfUserId(GetEventInt(event, "userid"))
	if (attacker == 0) return

	GetEventString(event, "weapon", weapon, sizeof(weapon))
	if (StrEqual("knife", weapon)) {
		HandlePlayerHurt(attacker, victim, true)
	} else {
		HandlePlayerHurt(attacker, victim)
	}
}

// Timer
public Action:Timer_Welcome(Handle:timer, any:client)
{
	PrintToChat(client, "\x03[One in the Chamber]\x01 (version %s)", CHAMBER_VERSION)
}

public Action:Timer_SetAmmo(Handle:timer, any:client)
{
	if (IsClientInGame(client)) {
		new String:weapon[32]
		new String:engine_weapon[64]
		GetConVarString(chamber_weapon, weapon, sizeof(weapon))
		Format(engine_weapon, sizeof(engine_weapon), "weapon_%s", weapon)

		Client_GiveWeapon(client, "weapon_knife", false)
		Client_GiveWeaponAndAmmo(client, engine_weapon, true, 0, 0, 1, 0)
	}
}
