# Disable All Mods

Surviving Mars Relaunched interface mod that adds a text button immediately to
the right of the `N mods installed` count on the **Installed Mods** page.

- **Disable all mods** stores the exact active mod load order, disables every
  active mod except `Disable All Mods`, and changes the caption to
  **Reenable previous mods**.
- **Reenable previous mods** restores every still-installed remembered mod in
  its original order, keeps this mod active, clears the snapshot, and changes
  the caption back.
- The snapshot uses the game's supported per-mod persistent storage, so it
  survives a restart.

The canonical mod version is `Mod/metadata.lua`.

## Manual verification

1. Enable **Disable All Mods** and at least two other mods.
2. Open **Mod Manager > Installed Mods**.
3. Confirm the button appears directly after the installed-mod count.
4. Press **Disable all mods**, wait for the list to refresh, and close the Mod
   Manager so the game reloads the selected mod set.
5. Confirm only **Disable All Mods** remains enabled.
6. Reopen Installed Mods and confirm the caption is
   **Reenable previous mods**.
7. Press it, close the Mod Manager, and confirm the prior mods return in their
   original load order.
8. Repeat both operations to verify idempotent UI injection and inspect the
   newest game log for `[Disable All Mods]` diagnostics.
