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
  three run side by side. CI (`.github/workflows/ci.yml`): test + lint gate the
  release; `main` push publishes `Porter.dmg`, PRs upload it as an artifact.

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
