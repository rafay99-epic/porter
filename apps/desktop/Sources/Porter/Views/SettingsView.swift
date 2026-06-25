import SwiftUI
import AppKit
import PorterCore

/// The ⌘, settings window. Hardcoded categories for v1 (an editable rules UI is
/// the planned v2 addition); what's tunable here is the where and the how-often.
struct SettingsView: View {
    @Bindable var settings: PorterSettings
    let coordinator: SortCoordinator
    @Bindable var loginItem: LoginItem
    @Bindable var onboarding: OnboardingModel
    @Bindable var updater: Updater
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        TabView {
            general.tabItem { Label("General", systemImage: "gearshape") }
            about.tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460)
        .padding(20)
    }

    private var general: some View {
        Form {
            Section("Startup") {
                Toggle("Launch Porter at login", isOn: launchAtLoginBinding)
                if loginItem.state == .requiresApproval {
                    Text("Approve Porter in System Settings ▸ General ▸ Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Display") {
                Toggle("Show icon in the menu bar", isOn: $settings.menuBarEnabled)
            }

            Section("Folders") {
                folderRow(label: "Watch", path: $settings.sourcePath) {
                    coordinator.reconfigure()
                }
                folderRow(label: "File to", path: $settings.nasMountPath) {
                    coordinator.sortNow()
                }
            }

            Section("Mounting") {
                TextField("SMB URL", text: $settings.smbURL,
                          prompt: Text("smb://user@host/share — optional, for “Mount Now”"))
                    .textFieldStyle(.roundedBorder)
            }

            Section("Timing") {
                VStack(alignment: .leading) {
                    Text("Wait \(Int(settings.settleSeconds))s before moving a new file")
                    Slider(value: $settings.settleSeconds, in: 5...120, step: 5)
                    Text("Protects against grabbing a download that's still being written.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if Channel.current.updatesEnabled {
                Section("Updates") {
                    Toggle("Check for updates automatically", isOn: $settings.autoCheckUpdates)
                    HStack {
                        if let release = updater.available {
                            Text("Update available: \(release.version)").foregroundStyle(.blue)
                            Spacer()
                            Button(updater.isInstalling ? "Installing…" : "Install") { updater.installAvailable() }
                                .disabled(updater.isInstalling)
                        } else {
                            Text(updater.statusMessage ?? "Up to date").foregroundStyle(.secondary)
                            Spacer()
                            Button("Check Now") { Task { await updater.check(userInitiated: true) } }
                                .disabled(updater.isBusy)
                        }
                    }
                }
            }

            Section("Setup") {
                Button("Re-run Onboarding…") {
                    onboarding.restart()
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loginItem.refresh() }
    }

    private var about: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text(Channel.current.displayName).font(.title2).bold()
            Text("Version \(versionString)").font(.caption).foregroundStyle(.secondary)
            if let info = Channel.buildInfo {
                Text(info).font(.caption2).foregroundStyle(.tertiary)
            }
            Text("Syntax Lab Technology · rafay99.com")
                .font(.caption).foregroundStyle(.secondary)
            Text("Licensed under GPL-3.0")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) })
    }

    private func folderRow(label: String, path: Binding<String>, onChange: @escaping () -> Void) -> some View {
        HStack {
            Text(label).frame(width: 56, alignment: .leading)
            TextField("", text: path)
                .textFieldStyle(.roundedBorder)
                .truncationMode(.head)
            Button("Choose…") {
                if let picked = chooseFolderPath(start: path.wrappedValue) {
                    path.wrappedValue = picked
                    onChange()
                }
            }
        }
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
