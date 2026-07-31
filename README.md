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
- Disabling the mod itself first restores the remembered still-installed mods,
  removes its Installed Mods action, clears its snapshot, cancels transient
  work, restores the original vanilla function, and unloads its runtime globals.

The canonical mod version is `Mod/metadata.lua`.

The publication build keeps all diagnostic and operation-audit logging disabled.

`Mod/` is the complete ModTools-compatible payload. It contains `metadata.lua`,
`items.lua`, the ordered `ModItemCode` scripts under `Code/`, and the publication
assets under `Images/`. Publish or deploy the contents of `Mod/`.

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
8. Repeat both operations to verify idempotent UI injection and confirm the
   newest game log contains no `[Disable All Mods]` messages.
9. Disable **Disable All Mods** while a snapshot is pending, close the Mod
   Manager, and confirm the remembered remaining mods return while the custom
   action and caption are absent.
