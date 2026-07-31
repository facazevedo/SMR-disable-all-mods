-- dam_config.lua
-- Central configuration and explicit feature/debug flags.

DAM_Config = {
	MOD_ID = "DisableAllMods",
	MOD_DISPLAY_NAME = "Disable All Mods",

	ENABLE_MOD_CONTROL = true,
	ENABLE_INSTALLED_MODS_BUTTON = true,

	DEBUG_LOGS = true,
	DEBUG_CONTROL = true,
	DEBUG_STATE = true,
	DEBUG_UI = true,

	BUTTON_ID = "idDisableAllModsPreviousToggle",
	BUTTON_DISABLE_TEXT = "Disable all mods",
	BUTTON_RESTORE_TEXT = "Reenable previous mods",
	HEADER_ACTION_LEFT_MARGIN = 137,
}
