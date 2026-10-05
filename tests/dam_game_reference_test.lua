-- Read-only compatibility regression against an explicitly supplied ModTools source.
local game_source = assert(arg[1], "supply the installed game's ModTools/Src path")
local payload = arg[2] or "Mod/Code"

local function read_reference(path)
	local file = assert(io.open(game_source .. "/" .. path, "rb"))
	local source = file:read("*a"):gsub("\r\n", "\n")
	file:close()
	return source
end

local manager_source = read_reference("CommonLua/UI/ModManager.lua")
local function load_engine_function(signature)
	local start = assert(manager_source:find("function " .. signature, 1, true), signature)
	local finish = assert(manager_source:find("\nend", start, true), signature)
	assert(load(manager_source:sub(start, finish + 3), "@game/" .. signature))()
end

function table.find(list, value)
	for index = 1, #list do
		if list[index] == value then return index end
	end
end
function table.insert_unique(list, value)
	if not table.find(list, value) then list[#list + 1] = value end
end
function table.remove_entry(list, value)
	local index = table.find(list, value)
	if index then table.remove(list, index) end
end

-- These engine functions retain their real access to account state. Mod-owned
-- code below gets a sandbox that cannot access AccountStorage or its save API.
AccountStorage = { LoadMods = { "Alpha", "DisableAllMods", "Beta" } }
load_engine_function("TurnModOn(id)")
load_engine_function("TurnModOff(id)")
local vanilla_turn_mod_off = TurnModOff
ModUI_Entry = {}
load_engine_function("ModUI_Entry:SetEnabledAndSync(enabled, silent)")
function ClearInstalledModsCorruptedStatus() end
function ObjModified() end
g_Pdx = { account = false }

Mods = {
	Alpha = { id = "Alpha" },
	DisableAllMods = { id = "DisableAllMods" },
	Beta = { id = "Beta" },
}
function ModUI_Entry:FromModDef(mod_def)
	return setmetatable({
		mod_def = mod_def,
		Enabled = table.find(AccountStorage.LoadMods, mod_def.id) ~= nil,
	}, { __index = self })
end
function ModUI_Entry:PdxModId() return false end
g_InitialMods = { "Alpha", "DisableAllMods", "Beta" }
ModsLoaded = { Mods.Alpha, Mods.DisableAllMods, Mods.Beta }

function box(...) return { ... } end
function point(...) return { ... } end
function RGBA(...) return { ... } end
function T(id, text) return text or id end
XTemplates = {}
function PlaceObj(class, properties, children)
	local object = children or {}
	if class == "XTemplate" then
		object = properties
		XTemplates[object.id] = object
	else
		for index = 1, #(properties or {}), 2 do
			object[properties[index]] = properties[index + 1]
		end
	end
	object.class = class
	return object
end
assert(load(read_reference("Lua/XTemplates/ModsUIMainContent.lua"), "@game/ModsUIMainContent.lua"))()

local function count_button(root)
	local count = root.Id == "idDisableAllModsPreviousToggle" and 1 or 0
	for index = 1, #root do
		if type(root[index]) == "table" then count = count + count_button(root[index]) end
	end
	return count
end
local function find_anchor_parent(root)
	for index = 1, #root do
		local child = root[index]
		if type(child) == "table" then
			if child.Id == "idTextInstalled" then return root, index end
			local parent, child_index = find_anchor_parent(child)
			if parent then return parent, child_index end
		end
	end
end
local template = assert(XTemplates.ModsUIMainContent)
local anchor_parent, anchor_index = find_anchor_parent(template)
assert(anchor_parent, "current game has no Installed Mods count anchor")
local vanilla_children = #anchor_parent

CurrentModDef = { version = 13 }
CurrentModStorageTable = {}
function WriteModPersistentStorageTable() end
local log_count = 0
function ModLog() log_count = log_count + 1 end
OnMsg = {}
function CreateRealTimeThread(callback)
	callback()
	return false
end
function IsValidThread() return false end
function DeleteThread() end

local sandbox = setmetatable({}, {
	__index = function(_, key)
		if key == "AccountStorage" or key == "SaveAccountStorage" then return nil end
		return _G[key]
	end,
	__newindex = _G,
})
for _, name in ipairs({
	"dam_config", "dam_debug", "dam_state", "dam_mod_control", "dam_ui",
	"dam_disable_guard", "dam_lifecycle", "DisableAllMods",
}) do
	assert(loadfile(payload .. "/" .. name .. ".lua", "t", sandbox))()
end
assert(DAM_ModControl.ValidateRuntime(), "current runtime API validation failed")
assert(anchor_parent[anchor_index + 1].Id == DAM_Config.BUTTON_ID, "button is not after current count")
assert(DAM_Lifecycle.ApplyModBehavior())
assert(count_button(template) == 1, "reapply duplicated the button in the current template")

local function assert_order(expected)
	assert(table.concat(AccountStorage.LoadMods, ",") == expected, "unexpected active mod order")
end
assert(DAM_ModControl.Toggle(false))
assert_order("DisableAllMods")
assert(DAM_State.HasPreviousLoadOrder())
assert(DAM_ModControl.Toggle(false))
assert_order("Alpha,DisableAllMods,Beta")
assert(not DAM_State.HasPreviousLoadOrder())
assert(DAM_ModControl.Toggle(false))
TurnModOff("DisableAllMods")
assert_order("Alpha,Beta")
assert(TurnModOff == vanilla_turn_mod_off, "vanilla function was not restored")
assert(count_button(template) == 0, "current template retained the injected button")
assert(#anchor_parent == vanilla_children, "current header structure was not restored")
assert(next(CurrentModStorageTable) == nil, "self-disable left a pending snapshot")
assert(DAM_Lifecycle.RestoreVanillaBehavior(), "repeated cleanup failed")
assert(log_count == 0, "publication defaults emitted debug output")

print("dam_game_reference_test: PASS (engine services stubbed; no in-game verification)")
