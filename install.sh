#!/usr/bin/env bash
# deck-tenant installer — idempotent, everything user-level (survives SteamOS updates).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say() { printf '\033[1m[deck-tenant]\033[0m %s\n' "$*"; }

install -Dm755 "$REPO/bin/deck-tenant"            "$HOME/.local/bin/deck-tenant"
install -Dm755 "$REPO/bin/deck-tenant-guard"      "$HOME/.local/bin/deck-tenant-guard"
install -Dm755 "$REPO/bin/deck-tenant-steam-sync" "$HOME/.local/bin/deck-tenant-steam-sync"
say "installed deck-tenant, deck-tenant-guard, deck-tenant-steam-sync to ~/.local/bin"

install -Dm644 "$REPO/systemd/deck-tenant-guard.service" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/deck-tenant-guard.service"
systemctl --user daemon-reload
systemctl --user enable deck-tenant-guard
systemctl --user restart deck-tenant-guard
say "session guard enabled and running"

say "next: deck-tenant register --app-id <flatpak-id> --name <Name>"
say "then: deck-tenant-steam-sync (with Steam closed) for per-profile Steam shortcuts"
