import SwiftUI
import AppKit
import PorterCore

/// Keeps Porter alive in the background after its window is closed — the app is a
/// long-running watcher, so closing the window should just hide it (Dock icon +
/// menu bar stay; the folder watcher keeps running). Only ⌘Q / "Quit Porter"
/// actually terminates it. Same approach as the Vitals app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// Porter — files finished downloads onto the NAS. A "full" app: it shows in the
/// Dock (people can see it's live) AND optionally keeps a menu-bar status item
/// (toggled in onboarding/Settings, persisted to the JSON config). The folder
/// watcher runs in-process in this GUI session, which is what lets it write to the
/// SMB share — and it keeps running in the background once the window is closed.
@main
struct PorterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings: PorterSettings
    @State private var coordinator: SortCoordinator
    @State private var loginItem = LoginItem()
    @State private var onboarding = OnboardingModel()
    @State private var updater: Updater

    init() {
        let shared = PorterSettings()
        _settings = State(initialValue: shared)
        _coordinator = State(initialValue: SortCoordinator(settings: shared))
        _updater = State(initialValue: Updater(settings: shared))
    }

    var body: some Scene {
        Window(Channel.current.displayName, id: "main") {
            RootWindowView(onboarding: onboarding, settings: settings,
                           coordinator: coordinator, loginItem: loginItem, updater: updater)
                .task {
                    CrashLogger.install()
                    loginItem.refresh()
                    if onboarding.completed { coordinator.start() }
                    updater.checkOnLaunch()
                }
        }
        .defaultSize(width: 540, height: 580)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    Task { await updater.check(userInitiated: true) }
                }
                .disabled(!Channel.current.updatesEnabled || updater.isBusy)
            }
        }

        // Menu-bar status item — shown only when enabled in config. The label is
        // dynamic so the icon reflects live status.
        MenuBarExtra(isInserted: $settings.menuBarEnabled) {
            MenuContent(coordinator: coordinator, loginItem: loginItem, updater: updater)
        } label: {
            Image(systemName: coordinator.status.symbolName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings, coordinator: coordinator,
                         loginItem: loginItem, onboarding: onboarding, updater: updater)
        }
    }
}

/// Switches the main window between the first-run wizard and the dashboard.
private struct RootWindowView: View {
    @Bindable var onboarding: OnboardingModel
    @Bindable var settings: PorterSettings
    let coordinator: SortCoordinator
    @Bindable var loginItem: LoginItem
    @Bindable var updater: Updater
    @State private var showWhatsNew = false

    var body: some View {
        if onboarding.completed {
            DashboardView(coordinator: coordinator, loginItem: loginItem, updater: updater)
                // Existing users (who won't re-run onboarding) get a one-time tour of
                // the new features after an update.
                .onAppear { showWhatsNew = WhatsNew.shouldShow() }
                .sheet(isPresented: $showWhatsNew, onDismiss: { WhatsNew.markSeen() },
                       content: { WhatsNewView() })
        } else {
            OnboardingView(onboarding: onboarding, settings: settings,
                           loginItem: loginItem, coordinator: coordinator)
        }
    }
}
