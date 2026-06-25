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

/// A list of feature rows, shown in the onboarding tour.
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
