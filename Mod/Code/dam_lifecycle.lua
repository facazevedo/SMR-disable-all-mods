-- dam_lifecycle.lua
-- Idempotent high-level apply/restore lifecycle.

DAM_Lifecycle = {}

local applied = false

function DAM_Lifecycle.ApplyModBehavior()
	local ui_applied = DAM_UI.ApplyModBehavior()
	if ui_applied ~= true then
		return false
	end

	local was_applied = applied
	applied = true
	if was_applied ~= true then
		DAM_Debug.Info("Lifecycle", "Applied mod behavior", {
			control_enabled = DAM_Config.ENABLE_MOD_CONTROL,
			ui_enabled = DAM_Config.ENABLE_INSTALLED_MODS_BUTTON,
		}, "DEBUG_LOGS")
	else
		DAM_Debug.Info(
			"Lifecycle",
			"Revalidated mod behavior after game lifecycle event",
			nil,
			"DEBUG_LOGS"
		)
	end
	return true
end

function DAM_Lifecycle.RestoreVanillaBehavior()
	DAM_UI.RestoreVanillaBehavior()
	applied = false
	DAM_Debug.Info("Lifecycle", "Restored vanilla Installed Mods template", nil, "DEBUG_LOGS")
	return true
end

function OnMsg.ModsReloaded()
	DAM_Lifecycle.ApplyModBehavior()
end

function OnMsg.ModUnloadLua(mod_id)
	if mod_id == DAM_Config.MOD_ID then
		DAM_Lifecycle.RestoreVanillaBehavior()
	end
end
