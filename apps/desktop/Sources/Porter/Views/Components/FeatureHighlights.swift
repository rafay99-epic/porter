import SwiftUI

/// One headline capability, shown in onboarding and the "What's New" sheet.
struct FeatureHighlight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String

    /// The capabilities added in this release — the single source of truth so
    /// onboarding and the What's New sheet never drift apart.
    static let all: [FeatureHighlight] = [
        .init(icon: "list.bullet.rectangle", title: "Powerful rules",
              detail: "Match by name, extension, size, age, or kind — combine conditions with AND/OR."),
        .init(icon: "eye", title: "Preview before it moves",
              detail: "A dry-run that shows exactly what would go where, without touching a file."),
        .init(icon: "arrow.uturn.backward", title: "Undo any move",
              detail: "One-click “Move Back” for anything Porter filed — your safety net."),
        .init(icon: "bell.badge", title: "Notifications",
              detail: "A toast when files are sorted or a move fails, even with every window closed."),
        .init(icon: "calendar", title: "Dated subfolders",
              detail: "File into Movies/{yyyy}/{MM} using date tokens in a rule's destination."),
        .init(icon: "doc.on.doc", title: "Duplicates & integrity",
              detail: "Skip files already on the NAS, and verify each copy before the original is removed."),
        .init(icon: "chart.bar.xaxis", title: "Statistics",
              detail: "Charts of what you've sorted over time, by category, and the space moved."),
        .init(icon: "moon.zzz", title: "Quiet hours & pause",
              detail: "Don't sort during a daily window, or pause everything with one click."),
        .init(icon: "folder.badge.gearshape", title: "Subfolders & conflicts",
              detail: "Optionally watch subfolders, and pick rename / skip / overwrite / keep-newer per rule."),
        .init(icon: "lightbulb", title: "Smart suggestions",
              detail: "Porter proposes new rules for file types that keep landing in the catch-all.")
    ]
}

/// A scrollable list of feature rows. Reused by the onboarding step and the
/// What's New sheet so the copy stays in one place.
struct FeatureHighlightsList: View {
    var features: [FeatureHighlight] = FeatureHighlight.all

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(features) { feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(.tint)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 26, alignment: .center)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title).font(.callout).fontWeight(.medium)
                        Text(feature.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// One-time "What's New" sheet shown to existing users after an update (new users
/// see the same content as an onboarding step instead). Presentation is gated by
/// `WhatsNew` so it appears once per version.
struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 34)).foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                Text("What's New in Porter").font(.title2).bold()
                Text("Porter just got a lot more capable. Here's what's new.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(.top, 24).padding(.bottom, 16).frame(maxWidth: .infinity)

            Divider()
            ScrollView { FeatureHighlightsList().padding(20) }
            Divider()

            HStack {
                Spacer()
                Button("Got it") { dismiss() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
            .padding(14)
        }
        .frame(width: 460, height: 540)
    }
}

/// Tracks whether the current version's "What's New" has been seen, so it shows
/// once per release. Stored per-channel via the standard defaults suite (the same
/// place onboarding's completion flag lives).
enum WhatsNew {
    private static let key = "lastSeenFeaturesVersion"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// Show when the stored "last seen" version differs from the running one — which
    /// includes existing users upgrading for the first time (no value stored yet).
    static func shouldShow() -> Bool {
        UserDefaults.standard.string(forKey: key) != currentVersion
    }

    static func markSeen() {
        UserDefaults.standard.set(currentVersion, forKey: key)
    }
}
