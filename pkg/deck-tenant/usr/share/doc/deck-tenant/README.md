# deck-tenant

Per-Steam-account **virtual homes** for non-Steam apps on Steam Deck / SteamOS.

Every Steam profile on a Deck runs as the one `deck` Linux user, so Discord,
Kodi, browsers, and emulators share a single login and state between family
members. SteamOS isolates only Steam's own per-account data — nothing else.
No existing tool fills this gap (Steam-account *switchers* exist; app-data
tenancy does not).

deck-tenant gives each Steam account a virtual home. Registered flatpak apps
get their **entire `~/.var/app/<id>` symlink-swapped** into the tenant's home
— complete state isolation (config, cache, data) with zero app-internal path
knowledge, while `$HOME` stays real: a full `$HOME` override SIGTRAPs
zypak/Electron flatpaks like Discord, whose portal-spawned children resolve
paths from the real home. Non-flatpak commands run via `deck-tenant run` with
`$HOME` pointed at the virtual home. Session plumbing (D-Bus, Wayland,
PipeWire, portals) lives in `$XDG_RUNTIME_DIR`, independent of all this, so
display, audio, and keyring integration are unaffected. The desktop session
itself is never touched, and Steam is explicitly refused tenancy: it is the
application that *defines* the active tenant (`loginusers.vdf` `MostRecent`),
so its dirs are symlinked into every virtual home and `deck-tenant run steam`
is an error.

## Install (proper packages — no installer scripts)

Built as an Arch package and installed into a user-level pacman root
(`~/.local/share/deck-pkgs`) — no sudo, survives SteamOS updates, and pacman
gives real install/upgrade/uninstall with file tracking:

```sh
# one-time: an Arch container for packaging (SteamOS ships distrobox)
distrobox create --image docker.io/library/archlinux:latest --name packager --yes
distrobox enter packager -- sudo pacman -Sy --noconfirm --needed base-devel

# build
git clone https://github.com/MasonRhodesDev/deck-tenant.git && cd deck-tenant
distrobox enter packager -- makepkg -fd

# install / upgrade (same command; pacman needs euid 0 → rootless userns)
ROOT=~/.local/share/deck-pkgs; mkdir -p $ROOT/var/lib/pacman
unshare -r pacman --root $ROOT --dbpath $ROOT/var/lib/pacman     -U --noconfirm deck-tenant-*.pkg.tar.zst

# one-time environment: PATH + the guard unit
echo 'export PATH="$HOME/.local/share/deck-pkgs/usr/bin:$PATH"' >> ~/.bashrc
systemctl --user link $ROOT/usr/lib/systemd/user/deck-tenant-guard.service
systemctl --user enable --now deck-tenant-guard

# uninstall
unshare -r pacman --root $ROOT --dbpath $ROOT/var/lib/pacman -R deck-tenant
```

## Use

```sh
# make an app multi-tenant: launch wrapper + desktop-entry/URI shadow + guard
deck-tenant register --app-id com.discordapp.Discord --name Discord

# ensure every Steam profile has a shortcut launching the wrapper (Steam closed)
deck-tenant-steam-sync

# ad-hoc: run anything in the active tenant's home (tenant-tagged scope)
deck-tenant run -- flatpak run tv.kodi.Kodi

# what's running, and which tenant owns it
deck-tenant ps
```

## Pieces

- **`deck-tenant`** — tenant detection (`active`), virtual-home provisioning
  (`home`; seeds symlinks to shared theming, media dirs, and Steam),
  `run`, `register`, `list`.
- **Process tracking** — every launch is ownership-tagged: flatpak instances
  are recorded (instance-id → tenant) by `deck-tenant _track`; non-flatpak
  commands run in tenant-named systemd scopes (cgroup-tracked). `deck-tenant
  ps` lists them; the guard kills precisely by owner.
- **`deck-tenant-guard`** (systemd user service) — flatpaks survive Steam and
  session switches in their own scopes, so the guard closes tenant-owned
  processes when a game-mode (gamescope) session ends, restarts registered
  apps under the new tenant when the active Steam account changes, and leaves
  everything alone when Steam merely exits in desktop mode.
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
