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

## Install

Prebuilt packages come from the [`[mason]` pacman
repo](https://github.com/MasonRhodesDev/arch-repo). SteamOS is Arch-based, so
the Arch package is the **only** packaging target — there is deliberately no
RPM spec / COPR for this repo.

### Steam Deck / SteamOS (user-level pacman root, no sudo)

SteamOS's root filesystem is read-only and wiped on updates, so install into
a user-level pacman root (`~/.local/share/deck-pkgs`) — survives SteamOS
updates, and pacman gives real install/upgrade/uninstall with file tracking:

```sh
# one-time: a pacman config pointing at the [mason] repo and the user root
ROOT=~/.local/share/deck-pkgs
mkdir -p $ROOT/var/lib/pacman $ROOT/var/cache/pacman/pkg ~/.config/deck-pkgs
cat > ~/.config/deck-pkgs/pacman.conf <<EOF
[options]
Architecture = auto
CacheDir = $ROOT/var/cache/pacman/pkg

[mason]
SigLevel = Optional TrustAll
Server = https://masonrhodesdev.github.io/arch-repo/x86_64
EOF

# install / upgrade (same command; pacman needs euid 0 → rootless userns)
unshare -r pacman --config ~/.config/deck-pkgs/pacman.conf \
    --root $ROOT --dbpath $ROOT/var/lib/pacman -Sy deck-tenant

# one-time per-user wiring: PATH snippet, guard units linked+enabled, and
# ExecStart drop-in overrides pointing the canonical units at this root
$ROOT/usr/bin/deck-tenant setup

# uninstall
unshare -r pacman --config ~/.config/deck-pkgs/pacman.conf \
    --root $ROOT --dbpath $ROOT/var/lib/pacman -R deck-tenant
```

### Arch Linux (regular system install)

Add the repo to `/etc/pacman.conf`:

```ini
[mason]
SigLevel = Optional TrustAll
Server = https://masonrhodesdev.github.io/arch-repo/x86_64
```

```sh
sudo pacman -Sy deck-tenant
deck-tenant setup   # enables the per-user guard units
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
- **`deck-tenant-guard`** — fully event-driven, no daemon and no polling:
  a systemd path unit on `loginusers.vdf` delivers account changes
  (`handle-login`), and a path unit on `steam.pid` re-arms a watcher that
  blocks on a **pidfd** until Steam exits (`watch-steam` — kernel event, zero
  CPU). Gamescope session end closes all tenant-owned processes; an account
  change closes other tenants' processes and restarts registered apps under
  the new tenant; a desktop-mode Steam exit leaves everything alone.
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
