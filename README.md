# Porter

A menu-bar app for macOS that watches your **Downloads** folder and quietly files
each finished download into the matching folder on your **NAS** — Pictures, PDFs,
Documents, Installers, Movies, Music, Archives, Screenshots, and everything else.

Porter exists because the obvious approach — a `launchd` job that moves files onto
a Finder-mounted SMB share — **doesn't reliably work** on modern macOS:

- macOS scopes SMB **write** access to the Aqua GUI session that mounted the share.
  A `launchd`-spawned process can read the share but its writes fail.
- `launchd`'s `WatchPaths` goes silently dead, and `StartInterval` gets throttled.
- TCC silently blocks a background script from even reading `~/Downloads`.

Porter sidesteps all three by being a **real menu-bar app that runs in your login
session**:

- The folder watcher runs **in-process** (FSEvents), not as a separate LaunchAgent.
- Launch-at-login uses `SMAppService.mainApp` — a login-item *app* in the full Aqua
  session, **not** a `launchd` agent — so SMB writes succeed.
- Full Disk Access attaches to the signed app's stable identity (granted once,
  survives updates) instead of to `/bin/bash`.
- The menu-bar icon is always-visible status: 🟢 watching · 🔵 sorting · 🟠 NAS not
  mounted · 🔴 needs access / error. **No more silent failures.**

## Build

```sh
cd apps/desktop
swift build          # debug compile
swift test           # unit tests (classification + move mechanics)
swiftlint            # lint
./build.sh           # release build → build/Porter.app  (PORTER_CHANNEL selects channel)
./dev.sh             # build + install "Porter Dev" next to Stable
./make-dmg.sh        # package the channel's DMG
```

Apple Silicon, macOS 14+. The classification map and move rules are a direct port
of the author's `bin/sort-downloads` script.

### Code signing (stable identity)

Builds sign **ad-hoc** by default. Ad-hoc signatures change every build, and macOS
keys TCC grants (Full Disk Access, etc.) and the Gatekeeper identity to the
signature — so an ad-hoc *update* looks like a brand-new app and silently drops
those permissions. To make grants persist across updates, sign with a stable
**self-signed** identity (no Apple account / notarization needed):

```sh
cd apps/desktop
./Scripts/make-signing-cert.sh          # one-time: generates + imports the cert,
                                        # prints the two CI secrets
CODESIGN_IDENTITY="Porter Local Signing" ./build.sh
```

`build.sh` reads `CODESIGN_IDENTITY`; if the name isn't in the keychain it warns and
falls back to ad-hoc. In CI, signing runs **only on the release jobs** (push to
`main` / `nightly`, never a PR), driven by `.github/scripts/setup-signing.sh` and two
repo secrets — `MACOS_SIGN_CERT_P12` (base64 of the `.p12`) and
`MACOS_SIGN_CERT_PASSWORD`. The same cert can be reused across every app in the
family; each distinct bundle id still gets its own designated requirement.

## License

GPL-3.0 — see [LICENSE](LICENSE). © Syntax Lab Technology / Abdul Rafay
([rafay99.com](https://rafay99.com)).
