import Foundation
import Observation
import PorterCore

/// Drives the first-run onboarding wizard and remembers whether it's been
/// completed (per-channel, via `UserDefaults`). The main window shows the wizard
/// until `completed`, then the dashboard. Re-runnable from Settings.
@MainActor
@Observable
final class OnboardingModel {
    enum Step: Int, CaseIterable {
        // Order matters: mount the NAS first (so picking "send all to" folders works),
        // then file access, then choose folders, then the run/menu-bar prefs.
        case welcome, nas, access, source, login, menuBar, done

        var title: String {
            switch self {
            case .welcome: return "Welcome to Porter"
            case .nas:     return "Connect Your NAS"
            case .access:  return "Allow File Access"
            case .source:  return "Choose Folders to Watch"
            case .login:   return "Run Automatically"
            case .menuBar: return "Menu Bar"
            case .done:    return "You're All Set"
            }
        }
    }

    private(set) var step: Step = .welcome
    private(set) var completed: Bool

    private let defaults = UserDefaults.standard
    private let key = "hasCompletedOnboarding"
    private let log = AppInfo.logger("onboarding")

    init() { completed = defaults.bool(forKey: key) }

    var isFirstStep: Bool { step == .welcome }
    var isLastStep: Bool { step == .done }
    var progress: Double { Double(step.rawValue + 1) / Double(Step.allCases.count) }

    func next() {
        if let n = Step(rawValue: step.rawValue + 1) {
            step = n
            log.info("onboarding → \(n.title)")
        }
    }

    func back() {
        if let p = Step(rawValue: step.rawValue - 1) {
            step = p
            log.info("onboarding ← \(p.title)")
        }
    }

    func finish() {
        completed = true
        defaults.set(true, forKey: key)
        log.info("onboarding complete")
    }

    /// Re-run the wizard (from Settings).
    func restart() {
        step = .welcome
        completed = false
        defaults.set(false, forKey: key)
        log.info("onboarding restarted")
    }
}
