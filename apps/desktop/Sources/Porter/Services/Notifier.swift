import Foundation
import UserNotifications
import PorterCore

/// Posts native macOS notifications for sweep outcomes so the user sees results
/// even with every Porter window closed. Best-effort: if the user hasn't granted
/// permission (or the running build can't post — e.g. an unsigned binary), every
/// call degrades to a silent no-op rather than throwing.
///
/// Lives in the app target (not PorterCore) because it touches UserNotifications
/// and the GUI session — PorterCore stays UI-free and unit-testable.
@MainActor
final class Notifier {
    private let log = AppInfo.logger("notifier")
    private var requested = false

    /// Ask the system for permission once. Safe to call repeatedly — only the
    /// first call prompts. A denied grant simply means later posts are dropped.
    func requestAuthorizationIfNeeded() {
        guard !requested else { return }
        requested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if let error {
                Task { @MainActor in self?.log.error("notification authorization failed: \(error.localizedDescription)") }
            } else {
                Task { @MainActor in self?.log.debug("notification authorization \(granted ? "granted" : "denied")") }
            }
        }
    }

    /// "Sorted N files" confirmation.
    func notifySorted(_ count: Int) {
        guard count > 0 else { return }
        post(title: "Sorted \(count) file\(count == 1 ? "" : "s")",
             body: "Porter filed \(count == 1 ? "it" : "them") onto your NAS.")
    }

    /// Failure toast — distinct so a problem isn't lost behind a closed window.
    func notifyFailures(_ count: Int) {
        guard count > 0 else { return }
        post(title: "\(count) move\(count == 1 ? "" : "s") failed",
             body: "Open Porter to see what went wrong.")
    }

    private func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                Task { @MainActor in self?.log.error("could not post notification: \(error.localizedDescription)") }
            }
        }
    }
}
