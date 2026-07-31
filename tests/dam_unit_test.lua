local source_root = arg[1] or "Mod/Code"

local function load_code(name)
	local chunk, err = loadfile(source_root .. "/" .. name)
	assert(chunk, err)
	return chunk()
end

local function assert_list(actual, expected, label)
	assert(#actual == #expected, string.format(
		"%s length mismatch: expected %d, got %d",
		label,
		#expected,
		#actual
	))
	for index = 1, #expected do
		assert(actual[index] == expected[index], string.format(
			"%s mismatch at %d: expected %s, got %s",
			label,
			index,
			tostring(expected[index]),
			tostring(actual[index])
		))
	end
end

function ModLog()
end

function box(...)
	return { ... }
end

function RGBA(...)
	return { ... }
end

function PlaceObj(class_name, properties, children)
	local result = children or {}
	result.class = class_name
	for index = 1, #(properties or {}), 2 do
		result[properties[index]] = properties[index + 1]
	end
	return result
end

local installed_mode = {
	class = "XTemplateMode",
	mode = "installed",
	{
		class = "XTemplateWindow",
		Id = "idTextInstalled",
	},
	{
		class = "XTemplateWindow",
		Id = "idAllToggleEnabled",
	},
}

XTemplates = {
	ModsUIMainContent = {
		{
			class = "XTemplateWindow",
			installed_mode,
		},
	},
}

XTextButton = {
	OnContextUpdate = function()
	end,
}

CurrentModDef = {
	version = 1,
}

CurrentModStorageTable = {}
local persistent_writes = 0
function WriteModPersistentStorageTable()
	persistent_writes = persistent_writes + 1
end

AccountStorage = {
	LoadMods = {
		"Alpha",
		"DisableAllMods",
		"Beta",
	},
}

Mods = {
	Alpha = { id = "Alpha" },
	DisableAllMods = { id = "DisableAllMods" },
	Beta = { id = "Beta" },
}

local function find_index(list, value)
	for index = 1, #list do
		if list[index] == value then
			return index
		end
	end
end

local entries = {}
ModUI_Entry = {}
function ModUI_Entry:FromModDef(mod_def)
	local entry = entries[mod_def.id]
	if entry then
		return entry
	end

	entry = {}
	function entry:SetEnabledAndSync(enabled)
		local index = find_index(AccountStorage.LoadMods, mod_def.id)
		if enabled and not index then
			AccountStorage.LoadMods[#AccountStorage.LoadMods + 1] = mod_def.id
		elseif not enabled and index then
			table.remove(AccountStorage.LoadMods, index)
		end
	end
	function entry:ObjModified()
	end
	entries[mod_def.id] = entry
	return entry
end

function ObjModified()
end

function SaveAccountStorage()
end

local refresh_count = 0
g_ParadoxModsContextObj = {
	GetInstalledMods = function()
		refresh_count = refresh_count + 1
	end,
}

local thread_serial = 0
function CreateRealTimeThread(callback)
	thread_serial = thread_serial + 1
	local thread = {
		valid = true,
		serial = thread_serial,
	}
	callback()
	thread.valid = false
	return thread
end

function IsValidThread(thread)
	return type(thread) == "table" and thread.valid == true
end

local runtime_button = {
	text = false,
	enabled = false,
	SetText = function(self, text)
		self.text = text
	end,
	SetEnabled = function(self, enabled)
		self.enabled = enabled
	end,
}

local host = {
	ResolveId = function(_, id)
		if id == "idDisableAllModsPreviousToggle" then
			return runtime_button
		end
	end,
}

function GetDialog()
	return host
end

OnMsg = {}

load_code("dam_config.lua")
load_code("dam_debug.lua")
load_code("dam_state.lua")
load_code("dam_mod_control.lua")
load_code("dam_ui.lua")
load_code("dam_lifecycle.lua")
load_code("DisableAllMods.lua")

assert(installed_mode[2].Id == DAM_Config.BUTTON_ID, "button was not inserted after installed count")
assert(installed_mode[3].Id == "idAllToggleEnabled", "button displaced the wrong header control")
assert(DAM_State.HasPreviousLoadOrder() == false, "snapshot should not exist initially")

assert(DAM_ModControl.Toggle(host) == true, "disable operation did not start")
assert_list(AccountStorage.LoadMods, { "DisableAllMods" }, "disabled load order")
assert_list(
	DAM_State.GetPreviousLoadOrder(),
	{ "Alpha", "DisableAllMods", "Beta" },
	"remembered load order"
)
assert(runtime_button.text == DAM_Config.BUTTON_RESTORE_TEXT, "button did not switch to restore text")

assert(DAM_ModControl.Toggle(host) == true, "restore operation did not start")
assert_list(
	AccountStorage.LoadMods,
	{ "Alpha", "DisableAllMods", "Beta" },
	"restored load order"
)
assert(DAM_State.HasPreviousLoadOrder() == false, "snapshot was not cleared after restore")
assert(runtime_button.text == DAM_Config.BUTTON_DISABLE_TEXT, "button did not switch to disable text")

assert(DAM_ModControl.Toggle(host) == true, "second disable operation did not start")
assert_list(AccountStorage.LoadMods, { "DisableAllMods" }, "second disabled load order")
Mods.Beta = nil
assert(DAM_ModControl.Toggle(host) == true, "restore with a deleted mod did not start")
assert_list(
	AccountStorage.LoadMods,
	{ "Alpha", "DisableAllMods" },
	"restored load order after remembered mod deletion"
)
assert(
	DAM_State.HasPreviousLoadOrder() == false,
	"snapshot was not cleared after restoring the remaining mods"
)
assert(
	runtime_button.text == DAM_Config.BUTTON_DISABLE_TEXT,
	"button did not reset after restoring the remaining mods"
)

assert(DAM_Lifecycle.ApplyModBehavior() == true, "idempotent apply failed")
assert(#installed_mode == 3, "idempotent apply duplicated the button")
assert(DAM_Lifecycle.RestoreVanillaBehavior() == true, "restore lifecycle failed")
assert(#installed_mode == 2, "restore lifecycle did not remove the button")
assert(DAM_Lifecycle.ApplyModBehavior() == true, "reapply lifecycle failed")
assert(#installed_mode == 3, "reapply lifecycle did not restore the button")

assert(persistent_writes == 4, "unexpected number of persistent writes")
assert(refresh_count > 0, "Installed Mods context was not refreshed")

print("dam_unit_test: PASS")
