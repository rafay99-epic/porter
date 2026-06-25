import SwiftUI
import PorterCore

/// The window that drops down from the menu-bar item (`.menuBarExtraStyle(.window)`).
/// Status first, then any action the current state needs (grant access / mount),
/// then the activity log, then footer controls. Shares its header/list with the
/// main-window dashboard.
struct MenuContent: View {
    @Bindable var coordinator: SortCoordinator
    @Bindable var loginItem: LoginItem
    @Bindable var updater: Updater
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusHeaderView(coordinator: coordinator).padding(12)
            Divider()

            switch coordinator.status {
            case .needsPermission: permissionCallout
            case .paused:          mountCallout
            default:               EmptyView()
            }

            if let release = updater.available {
                updateCallout(release)
            }

            ActivityListView(entries: coordinator.activity)

            Divider()
            footer
        }
        .frame(width: 320)
    }

    private var permissionCallout: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Porter can't read your Downloads folder. Grant it Full Disk Access so it can sort in the background.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Grant Full Disk Access…") { coordinator.openFullDiskAccessSettings() }
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4))
    }

    private func updateCallout(_ release: Updater.Available) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.blue)
            Text("Update available: \(release.version)").font(.caption)
            Spacer()
            Button(updater.isInstalling ? "Installing…" : "Update") { updater.installAvailable() }
                .controlSize(.small)
                .disabled(updater.isInstalling)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.12))
    }

    private var mountCallout: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The NAS isn't mounted, so sorting is paused. Files stay in Downloads until it's back.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Mount Now") { coordinator.mountNow() }
                .buttonStyle(.bordered)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Sort Now") { coordinator.sortNow() }
            Spacer()
            Button("Open Porter") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Menu {
                SettingsLink { Text("Settings…") }
                Button("Reveal Log in Finder") { coordinator.revealLogInFinder() }
                Divider()
                Button("Quit Porter") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(12)
    }
}
