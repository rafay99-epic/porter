import Foundation
import Observation
import ServiceManagement
import PorterCore

/// Launch-at-login, via `SMAppService.mainApp`. This registers the *app itself* as
/// a login item — NOT a `SMAppService.agent` LaunchAgent. That distinction is the
/// whole point of Porter: a LaunchAgent runs in a bare launchd context that can't
/// write to the Finder-mounted SMB share (the bug we're escaping), whereas the
/// login-item app launches into the full Aqua GUI session where SMB writes work.
@MainActor
@Observable
final class LoginItem {
    enum State: Equatable {
        case enabled
        case disabled
        case requiresApproval   // user must allow it in System Settings ▸ Login Items
        case error(String)
    }

    private(set) var state: State = .disabled
    private let log = AppInfo.logger("login-item")

    private var service: SMAppService { .mainApp }

    func refresh() { state = map(service.status) }

    var isEnabled: Bool { state == .enabled }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            refresh()
            log.info("launch-at-login \(enabled ? "enabled" : "disabled") → \(state)")
            return true
        } catch {
            log.error("SMAppService \(enabled ? "register" : "unregister") failed: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
            return false
        }
    }

    private func map(_ status: SMAppService.Status) -> State {
        switch status {
        case .enabled:          return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered:    return .disabled
        case .notFound:         return .disabled
        @unknown default:       return .disabled
        }
    }
}
