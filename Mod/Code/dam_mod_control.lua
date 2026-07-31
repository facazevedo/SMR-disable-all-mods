-- dam_mod_control.lua
-- Captures, disables, and restores the ordered active-mod set using the
-- Installed Mods UI's own ModUI_Entry:SetEnabledAndSync engine path.

DAM_ModControl = {}

local operation_thread = false

local function copy_list(source)
	local result = {}
	if type(source) == "table" then
		for index = 1, #source do
			if type(source[index]) == "string" then
				result[#result + 1] = source[index]
			end
		end
	end
	return result
end

local function contains(list, value)
	for index = 1, #list do
		if list[index] == value then
			return true
		end
	end
	return false
end

local function validate_runtime()
	local missing = {}
	if type(AccountStorage) ~= "table" then
		missing[#missing + 1] = "AccountStorage"
	elseif type(AccountStorage.LoadMods) ~= "table" then
		missing[#missing + 1] = "AccountStorage.LoadMods"
	end
	if type(Mods) ~= "table" then
		missing[#missing + 1] = "Mods"
	end
	if type(ModUI_Entry) ~= "table" or type(ModUI_Entry.FromModDef) ~= "function" then
		missing[#missing + 1] = "ModUI_Entry:FromModDef"
	end
	if type(CreateRealTimeThread) ~= "function" then
		missing[#missing + 1] = "CreateRealTimeThread"
	end

	local available = #missing == 0
	DAM_Debug.Info("Control", "Runtime API availability checked", {
		available = available,
		missing_count = #missing,
	}, "DEBUG_CONTROL")
	if available ~= true then
		DAM_Debug.Error("Control", "Required runtime API is unavailable", {
			missing = table.concat(missing, ", "),
		}, "DEBUG_CONTROL")
	end
	return available
end

local function replace_load_order(new_order)
	local load_mods = AccountStorage.LoadMods
	for index = #load_mods, 1, -1 do
		load_mods[index] = nil
	end
	for index = 1, #new_order do
		load_mods[index] = new_order[index]
	end
end

local function set_mod_enabled(mod_id, enabled)
	local mod_def = Mods[mod_id]
	if mod_def == nil then
		DAM_Debug.Warn("Control", "Skipped unavailable mod", {
			enabled = enabled,
			mod_id = mod_id,
		}, "DEBUG_CONTROL")
		return false
	end

	local entry = ModUI_Entry:FromModDef(mod_def)
	if entry == nil or type(entry.SetEnabledAndSync) ~= "function" then
		DAM_Debug.Error("Control", "Installed Mods entry cannot synchronize state", {
			enabled = enabled,
			mod_id = mod_id,
		}, "DEBUG_CONTROL")
		return false
	end

	entry:SetEnabledAndSync(enabled, true)
	if type(entry.ObjModified) == "function" then
		entry:ObjModified()
	end
	return true
end

local function save_account_storage()
	if type(SaveAccountStorage) == "function" then
		SaveAccountStorage(1000)
	end
end

local function refresh_installed_mods(host)
	local context = g_ParadoxModsContextObj
	if context and type(context.GetInstalledMods) == "function" then
		context:GetInstalledMods()
		ObjModified(context)
	end
	if DAM_UI and type(DAM_UI.RefreshButton) == "function" then
		DAM_UI.RefreshButton(host)
	end
end

local function disable_all_other_mods(host)
	local previous_load_order = copy_list(AccountStorage.LoadMods)
	if contains(previous_load_order, DAM_Config.MOD_ID) ~= true then
		previous_load_order[#previous_load_order + 1] = DAM_Config.MOD_ID
	end

	local captured, capture_err = DAM_State.CapturePreviousLoadOrder(previous_load_order)
	if captured ~= true then
		return false, capture_err
	end

	local disabled_count = 0
	for index = 1, #previous_load_order do
		local mod_id = previous_load_order[index]
		if mod_id ~= DAM_Config.MOD_ID and set_mod_enabled(mod_id, false) == true then
			disabled_count = disabled_count + 1
		end
	end

	set_mod_enabled(DAM_Config.MOD_ID, true)
	replace_load_order({ DAM_Config.MOD_ID })
	save_account_storage()
	refresh_installed_mods(host)

	DAM_Debug.Info("Control", "Disabled active mods and preserved this mod", {
		disabled_count = disabled_count,
		remembered_count = #previous_load_order,
		self_mod_id = DAM_Config.MOD_ID,
	}, "DEBUG_CONTROL")
	return true
end

local function build_available_restore_order(previous_load_order)
	local restore_order = {}
	local seen = {}
	local missing_count = 0

	for index = 1, #previous_load_order do
		local mod_id = previous_load_order[index]
		if seen[mod_id] ~= true then
			seen[mod_id] = true
			if Mods[mod_id] ~= nil then
				restore_order[#restore_order + 1] = mod_id
			else
				missing_count = missing_count + 1
				DAM_Debug.Warn("Control", "Remembered mod is no longer installed", {
					mod_id = mod_id,
				}, "DEBUG_CONTROL")
			end
		end
	end

	if seen[DAM_Config.MOD_ID] ~= true then
		restore_order[#restore_order + 1] = DAM_Config.MOD_ID
	end
	return restore_order, missing_count
end

local function restore_previous_mods(host)
	local previous_load_order = DAM_State.GetPreviousLoadOrder()
	if #previous_load_order == 0 then
		return false, "no previous active mod load order is available"
	end

	local restore_order, missing_count = build_available_restore_order(previous_load_order)
	local restore_set = {}
	for index = 1, #restore_order do
		restore_set[restore_order[index]] = true
	end

	local current_load_order = copy_list(AccountStorage.LoadMods)
	for index = 1, #current_load_order do
		local mod_id = current_load_order[index]
		if restore_set[mod_id] ~= true and mod_id ~= DAM_Config.MOD_ID then
			set_mod_enabled(mod_id, false)
		end
	end

	local restored_count = 0
	for index = 1, #restore_order do
		local mod_id = restore_order[index]
		if mod_id == DAM_Config.MOD_ID then
			set_mod_enabled(mod_id, true)
		elseif set_mod_enabled(mod_id, true) == true then
			restored_count = restored_count + 1
		end
	end

	replace_load_order(restore_order)
	save_account_storage()

	local cleared, clear_err = DAM_State.ClearPreviousLoadOrder()
	if cleared ~= true then
		refresh_installed_mods(host)
		return false, clear_err
	end

	refresh_installed_mods(host)
	DAM_Debug.Info("Control", "Restored previous active mod load order", {
		missing_count = missing_count,
		restored_count = restored_count,
		target_count = #restore_order,
	}, "DEBUG_CONTROL")
	return true
end

function DAM_ModControl.IsBusy()
	return IsValidThread(operation_thread)
end

function DAM_ModControl.Toggle(host)
	if DAM_Config.ENABLE_MOD_CONTROL ~= true then
		DAM_Debug.Warn("Control", "Toggle ignored because mod control is disabled", nil, "DEBUG_CONTROL")
		return false
	end
	if DAM_ModControl.IsBusy() == true then
		DAM_Debug.Warn("Control", "Toggle ignored because an operation is already running", nil, "DEBUG_CONTROL")
		return false
	end
	if validate_runtime() ~= true then
		return false
	end

	operation_thread = CreateRealTimeThread(function()
		local restoring = DAM_State.HasPreviousLoadOrder() == true
		local ok, result, err = pcall(function()
			if restoring then
				return restore_previous_mods(host)
			end
			return disable_all_other_mods(host)
		end)

		if ok ~= true then
			DAM_Debug.Error("Control", "Toggle operation raised an engine error", {
				error = result,
				operation = restoring and "restore" or "disable",
			}, "DEBUG_CONTROL")
		elseif result ~= true then
			DAM_Debug.Error("Control", "Toggle operation did not complete", {
				error = err,
				operation = restoring and "restore" or "disable",
			}, "DEBUG_CONTROL")
		end

		operation_thread = false
		refresh_installed_mods(host)
	end)

	refresh_installed_mods(host)
	return true
end

function DAM_ModControl.ValidateRuntime()
	return validate_runtime()
end
