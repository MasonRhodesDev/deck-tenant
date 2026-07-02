# Maintainer: Mason Rhodes <mrhodesdev@gmail.com>
# Build:   makepkg -f
# Install: pacman --root ~/.local/share/deck-pkgs \
#            --dbpath ~/.local/share/deck-pkgs/var/lib/pacman \
#            -U deck-tenant-*.pkg.tar.zst
pkgname=deck-tenant
pkgver=0.2.0
pkgrel=1
pkgdesc="Per-Steam-account virtual homes for non-Steam apps on Steam Deck"
arch=(any)
url="https://github.com/MasonRhodesDev/deck-tenant"
license=(MIT)
optdepends=(bash python flatpak) # host-provided on SteamOS

package() {
    cd "$startdir"
    install -Dm755 bin/deck-tenant            "$pkgdir/usr/bin/deck-tenant"
    install -Dm755 bin/deck-tenant-guard      "$pkgdir/usr/bin/deck-tenant-guard"
    install -Dm755 bin/deck-tenant-steam-sync "$pkgdir/usr/bin/deck-tenant-steam-sync"
    for u in deck-tenant-login.path deck-tenant-login.service \
             deck-tenant-steamwatch.path deck-tenant-steamwatch.service; do
        install -Dm644 "systemd/$u" "$pkgdir/usr/lib/systemd/user/$u"
    done
    install -Dm644 README.md "$pkgdir/usr/share/doc/deck-tenant/README.md"
}
