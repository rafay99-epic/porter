import SwiftUI
import AppKit
import PorterCore

/// The ⌘, settings window. Tabs keep the (now substantial) folder + rule editors
/// from crowding the basics.
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
            folders.tabItem { Label("Folders", systemImage: "folder") }
            rules.tabItem { Label("Rules", systemImage: "list.bullet.rectangle") }
            about.tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 520)
        .padding(20)
    }

    // MARK: - General

    private var general: some View {
        Form {
            Section("Startup") {
                Toggle("Launch Porter at login", isOn: launchAtLoginBinding)
                if loginItem.state == .requiresApproval {
                    Text("Approve Porter in System Settings ▸ General ▸ Login Items.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Display") {
                Toggle("Show icon in the menu bar", isOn: $settings.menuBarEnabled)
                Toggle("Notify me when files are sorted", isOn: $settings.notificationsEnabled)
                    .onChange(of: settings.notificationsEnabled) { _, enabled in
                        if enabled { coordinator.enableNotifications() }
                    }
            }

            Section("NAS") {
                folderRow(label: "File to", path: $settings.nasMountPath) { coordinator.sortNow() }
                TextField("SMB URL", text: $settings.smbURL,
                          prompt: Text("smb://user@host/share — optional, for “Mount Now”"))
                    .textFieldStyle(.roundedBorder)
            }

            Section("Timing") {
                VStack(alignment: .leading) {
                    Text("Wait \(Int(settings.settleSeconds))s before moving a new file")
                    Slider(value: $settings.settleSeconds, in: 5...120, step: 5)
                    Text("Protects against grabbing a download that's still being written.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Quiet Hours") {
                Toggle("Don't sort during a daily window", isOn: $settings.quietHours.enabled)
                if settings.quietHours.enabled {
                    DatePicker("From", selection: quietStartBinding, displayedComponents: .hourAndMinute)
                    DatePicker("Until", selection: quietEndBinding, displayedComponents: .hourAndMinute)
                    Text("Sorting pauses inside this window and resumes automatically after it. Windows that cross midnight are fine.")
                        .font(.caption).foregroundStyle(.secondary)
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

    // MARK: - Folders

    private var folders: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Folders Porter watches. Each can sort by your rules, or send everything to one NAS folder.")
                    .font(.callout).foregroundStyle(.secondary)
                FoldersEditor(settings: settings)
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Re-point the FSEvents watcher whenever the set of folders changes.
        .onChange(of: settings.sources) { coordinator.reconfigure() }
    }

    // MARK: - Rules

    private var rules: some View {
        ScrollView {
            RulesEditor(settings: settings)
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - About

    private var about: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 44)).foregroundStyle(.tint)
            Text(Channel.current.displayName).font(.title2).bold()
            Text("Version \(versionString)").font(.caption).foregroundStyle(.secondary)
            if let info = Channel.buildInfo {
                Text(info).font(.caption2).foregroundStyle(.tertiary)
            }
            Text("Syntax Lab Technology · rafay99.com").font(.caption).foregroundStyle(.secondary)
            Text("Licensed under GPL-3.0").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
    }

    // MARK: - Helpers

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) })
    }

    // Quiet-hours are stored as minutes-since-midnight; the DatePicker works in
    // Dates, so bridge through "today at HH:mm" in both directions.
    private var quietStartBinding: Binding<Date> { minuteBinding(\.startMinute) }
    private var quietEndBinding: Binding<Date> { minuteBinding(\.endMinute) }

    private func minuteBinding(_ keyPath: WritableKeyPath<QuietHours, Int>) -> Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: settings.quietHours[keyPath: keyPath]) },
            set: { settings.quietHours[keyPath: keyPath] = Self.minutes(from: $0) })
    }

    private static func date(fromMinutes minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    private static func minutes(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func folderRow(label: String, path: Binding<String>, onChange: @escaping () -> Void) -> some View {
        HStack {
            Text(label).frame(width: 56, alignment: .leading)
            TextField("", text: path).textFieldStyle(.roundedBorder).truncationMode(.head)
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
