# deck-tenant

Per-Steam-account **virtual homes** for non-Steam apps on Steam Deck / SteamOS.

Every Steam profile on a Deck runs as the one `deck` Linux user, so Discord,
Kodi, browsers, and emulators share a single login and state between family
members. SteamOS isolates only Steam's own per-account data — nothing else.
No existing tool fills this gap (Steam-account *switchers* exist; app-data
tenancy does not).

deck-tenant gives each Steam account a virtual home and launches apps inside
it. Flatpak and XDG apps resolve `$HOME` from the environment, so **all** of an
app's state — config, cache, `~/.var/app` — lands in the active tenant's home
with zero per-app path knowledge. Session plumbing (D-Bus, Wayland, PipeWire,
portals) lives in `$XDG_RUNTIME_DIR`, independent of `$HOME`, so display,
audio, and keyring integration are unaffected. The desktop session itself is
never touched, and Steam is explicitly refused tenancy: it is the application
that *defines* the active tenant (`loginusers.vdf` `MostRecent`), so its dirs
are symlinked into every virtual home and `deck-tenant run steam` is an error.

## Install

```sh
git clone https://github.com/MasonRhodesDev/deck-tenant.git
deck-tenant/install.sh
```

## Use

```sh
# make an app multi-tenant: launch wrapper + desktop-entry/URI shadow + guard
deck-tenant register --app-id com.discordapp.Discord --name Discord

# ensure every Steam profile has a shortcut launching the wrapper (Steam closed)
deck-tenant-steam-sync

# ad-hoc: run anything in the active tenant's home
deck-tenant run -- flatpak run tv.kodi.Kodi
```

## Pieces

- **`deck-tenant`** — tenant detection (`active`), virtual-home provisioning
  (`home`; seeds symlinks to shared theming, media dirs, and Steam),
  `run`, `register`, `list`.
- **`deck-tenant-guard`** (systemd user service) — flatpaks survive Steam and
  session switches in their own scopes, so the guard closes registered apps
  when a game-mode (gamescope) session ends, restarts them under the new
  tenant when the active Steam account changes, and leaves them alone when
  Steam merely exits in desktop mode.
- **`deck-tenant-steam-sync`** — byte-exact `shortcuts.vdf` editor: rewires
  direct-launch entries to the tenant wrapper (preserving appids/artwork) and
  creates missing ones so every profile can launch — and first-time
  sign-in to — each registered app.

## Notes

- Tenant homes live in `~/.local/share/deck-tenant/homes/<accountid>`.
  Everything is user-level; SteamOS updates never touch it.
- Registered wrappers kill an instance left by another tenant before
  launching (single-instance apps would otherwise focus the previous
  tenant's session).
- With no Steam login (fresh device), the tenant is `default`.
