# CLAUDE.md — Porter

Porter is a native macOS **menu-bar app** (`apps/desktop`, Swift/SwiftUI) that
watches the Downloads folder and files each finished download into the matching
folder on the NAS. Conventions mirror the **Crisp** project. License: **GPL-3.0**.

## Why this app exists (the load-bearing context)

The naïve solution is a `launchd` job that moves files onto a Finder-mounted SMB
share. It does **not** work on modern macOS, for three independent reasons:

1. **SMB writes are scoped to the Aqua GUI session that mounted the share.** A
   `launchd`-spawned process can *read* `/Volumes/<share>` but its *writes* fail.
2. **`launchd` triggers are unreliable** — `WatchPaths` goes silently dead and
   `StartInterval` gets throttled by Sequoia for long stretches.
3. **TCC** silently blocks a background script from reading `~/Downloads`, and the
   grant is bound to `/bin/bash` + the script's mtime, so it breaks on every edit.

Porter fixes all three by being a **real GUI-session app**, not a daemon:

- The folder watcher runs **in-process** via `FSEventStream` (`PorterCore/Watch/
  FolderWatcher.swift`), never as a `SMAppService.agent` LaunchAgent. A LaunchAgent
  would re-introduce bug #1. **Do not move the watcher into a separate agent.**
- Launch-at-login is `SMAppService.mainApp` (`Porter/Services/LoginItem.swift`) — a
  login-item *app* in the full Aqua session, so its SMB writes succeed.
- Full Disk Access attaches to the signed app bundle's stable identity (granted
  once, survives code edits), not to `/bin/bash`.

This is a port of the author's `~/dotfiles/bin/sort-downloads`. The classification
map (`Classifier`) and the move mechanics (`Mover`) mirror that script exactly,
including the **xattr-stripping copy** — see below.

## Workflow rules (explicit — do not violate)

- **No Claude / AI attribution anywhere**: no `Co-Authored-By`, no "Generated with
  Claude" in commits, PR titles/bodies, changelogs, or in-app credits. Credited to
  **Syntax Lab Technology / Abdul Rafay (rafay99.com)**.
- **`nightly` is the integration branch; `main` is the default + protected Stable
  branch.** Feature work branches **from `nightly`** → PR into `nightly`. Never
  hand-commit to `main`. (Mirrors Crisp; set up branch protection when the remote
  exists.)
- **Test on the Dev build, never disturb Stable.** Build + install with `./dev.sh`
  (from `apps/desktop`) — it builds **`Porter Dev.app`** (`…porter.dev`) and runs it
  side by side with a Stable `/Applications/Porter.app`.

## Channels, versioning, releases

- **Stable version = `0.<total commit count on main>`** (`build.sh`; `PORTER_VERSION`
  overrides). Three channels via the `PorterChannel` Info.plist key + the `Channel`
  enum — never hardcoded `isDev` checks:
  - **stable** → `Porter.app`, `com.syntaxlabtechnology.porter`, blue icon.
  - **nightly** → `Porter Nightly.app`, `…porter.nightly`, amber icon, `-nightly`.
  - **dev** → `Porter Dev.app`, `…porter.dev`, purple icon. Local only, no updater.
- Per-channel data home (`~/.porter`, `~/.porter-nightly`, `~/.porter-dev`) so the
  three run side by side. CI: `ci.yml` (push to `main`) — test + lint gate the
  release, then publishes `Porter.dmg`; `nightly.yml` (push to `nightly`) refreshes
  a single rolling `nightly` pre-release whose title carries `build <n>` (the
  updater parses it). PRs upload the DMG as an artifact instead of publishing.
- **Repo is PRIVATE** (`rafay99-epic/porter`). The in-app `Updater` therefore
  authenticates: it pulls a token from `gh auth token` and hits the Releases API +
  downloads assets via the asset API URL with `Accept: application/octet-stream` +
  `Authorization: Bearer`. No `gh`/token → it just can't see releases (surfaced as a
  status message), same shape as Crisp's updater. `Updater.repoSlug` must match the
  repo.

## Architecture

`apps/desktop/Sources/` — SwiftPM, two targets (`swift build` recurses subfolders):

- **`PorterCore`** — all logic, **no SwiftUI**, so the rules are unit-tested:
  - `Common/` — `Channel` (identity from `PorterChannel`), `AppInfo` (logger
    factory), `FileLog` (serial-queue, `O_APPEND`, daily-rotating writer; tees to
    unified logging).
  - `Models/` — `FileCategory` (named to avoid the ObjC-runtime `Category` typedef),
    `ActivityEntry`.
  - `Sorting/` — `Classifier` (name/ext → category), `FileTriage` (junk / partial /
    settle predicates), `Mover` (the move mechanics), `Sorter` (orchestrates a
    sweep, returns a `SweepSummary`).
  - `Watch/FolderWatcher.swift` — the in-process `FSEventStream` wrapper.
  - `NAS/MountCheck.swift` — `getmntinfo`-based mount check (the `mount | grep`
    equivalent), used to gate every sweep.
- **`Porter`** — the SwiftUI menu-bar app:
  - `App/PorterApp.swift` — `@main`, `MenuBarExtra(.window)` + `Settings`. `LSUIElement`
    (no Dock icon). `coordinator.start()` is driven from the always-present menu-bar
    label's `.task`.
  - `Services/SortCoordinator.swift` — `@MainActor @Observable` brain: owns the
    watcher, the mount observers (`NSWorkspace.didMount/didUnmount`), a 60s safety
    heartbeat, single-flight debounced sweeps, and the activity log. Its
    `PorterStatus` enum drives the menu-bar icon.
  - `Services/PorterSettings.swift` — `UserDefaults`-backed config (source, NAS
    mount, optional SMB URL, settle seconds).
  - `Services/LoginItem.swift` — `SMAppService.mainApp` wrapper.
  - `Services/Permissions.swift` — FDA probe (try to list the folder) + deep links.
  - `Views/` — `MenuContent` (status-first dropdown + activity log), `SettingsView`.

## The move pattern (do not "simplify" to `FileManager.moveItem`)

`Mover.move` copies with `copyfile(COPYFILE_DATA | COPYFILE_STAT)` — bytes +
mode/mtime, **no xattrs/ACLs** — into a `.partial-<pid>` temp on the destination
volume, then `rename(2)` into place, then `unlink(2)` the source. This is the
native equivalent of `cp -Xp` from the bash script. The reason: a cross-volume
`FileManager.moveItem` falls back to a metadata-preserving copy that carries
`com.apple.provenance` / `com.apple.quarantine` xattrs, which **SMB rejects with
EPERM**, aborting the whole move. Stripping xattrs avoids the trap. If any step
fails the source is left untouched for the next sweep.

Folder names are resolved **case-insensitively** (`Mover.resolveCategoryDirectory`)
so an existing `documents/` on the NAS isn't duplicated as `Documents/`. Collisions
get a Finder-style ` (1)` suffix. Skips (junk / partial / unsettled) are never
logged or counted as moves — matching the bash script's quiet behaviour.

## Commands

```sh
# from apps/desktop:
swift build            # debug compile
swift test             # PorterCore unit tests
swiftlint              # lint (CI: --reporter github-actions-logging)
./build.sh             # release build → build/Porter.app  (PORTER_CHANNEL selects channel)
./dev.sh               # build + install "Porter Dev" next to Stable
./make-dmg.sh          # package the channel's DMG
```

## Code signing (stable self-signed identity)

Builds sign **ad-hoc** by default (`codesign --sign -`). Ad-hoc signatures
re-randomise every build, and macOS keys TCC grants (Full Disk Access, etc.) **and**
the Gatekeeper identity to the signature — so an ad-hoc *update* looks like a new app
and silently drops permissions. The single load-bearing reason for stable signing:
sign every build with one **self-signed** cert so the designated requirement
(`identifier <bundle-id> and certificate leaf = H"…"`) is stable and the grant
survives auto-updates. No Apple account / notarization is involved; **do not**
re-introduce a Developer ID/team.

- **`build.sh`** reads `CODESIGN_IDENTITY` (the env var — reuse it, don't invent a
  new one). Default `-` = ad-hoc. If the name isn't in the keychain it **warns and
  falls back to ad-hoc** (never aborts). With a real identity it re-signs
  `--force --deep`. Porter has **no `.entitlements` file**, so none is passed; if one
  is ever added you MUST add `--entitlements <path>` there too or the `--deep` re-sign
  strips it.
- **`Scripts/make-signing-cert.sh`** — one-time local generator: makes a self-signed
  codeSigning cert, imports it into the login keychain, and prints the two CI secrets.
- **`.github/scripts/setup-signing.sh`** — CI imports the cert into an ephemeral
  keychain and exports `CODESIGN_IDENTITY` via `$GITHUB_ENV`. Wired into the **release
  jobs only** — `ci.yml` (push to `main`) and `nightly.yml` (push to `nightly`), both
  trusted branch pushes. **Never** add it to the PR `package` job: a fork PR could run
  untrusted code and exfiltrate the cert. Missing secrets → it warns and the build
  goes ad-hoc (never fails the release).
- Secrets the human adds once: **`MACOS_SIGN_CERT_P12`** (base64 of the `.p12`) and
  **`MACOS_SIGN_CERT_PASSWORD`**. One cert/.p12 can sign every app in the family;
  each app's distinct bundle id still gets its own designated requirement.
- `make-dmg.sh` only `cp -R`s the already-signed app into a DMG — it does **not**
  re-sign, so it never clobbers the identity. Keep it that way.

## Logging

`AppInfo.logger(_:)` → `PorterLog`, which tees every line to Apple unified logging
**and** `~/.porter*/logs/<yyyy-MM-dd>.log` (serial queue, `O_APPEND`, daily rotation,
30-day prune at launch). The menu's "Reveal Log in Finder" opens today's file.

## Design language

Native, Apple-like. SF Symbols, system materials, standard controls. The menu-bar
icon is the primary status surface — distinct symbol per state so it reads in
monochrome. App icon is a white `tray.and.arrow.down` on a channel-tinted rounded
rect (`Scripts/MakeIcon.swift`).

## License & credit

GPL-3.0 (`LICENSE` at root). Credited to Syntax Lab Technology / Abdul Rafay.
