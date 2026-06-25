import SwiftUI
import AppKit
import PorterCore

/// Show an `NSOpenPanel` to pick a single folder. Returns its path, or nil if the
/// user cancelled. Shared by onboarding and Settings.
@MainActor
func chooseFolderPath(start: String) -> String? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = URL(fileURLWithPath: start)
    return panel.runModal() == .OK ? panel.url?.path : nil
}

/// Best-effort mount point for an `smb://user@host/share` URL: macOS mounts it at
/// `/Volumes/<share>`. Returns nil when the URL has no share component.
func defaultMountPoint(forSMB url: String) -> String? {
    let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let share = trimmed.split(separator: "/").last, !share.isEmpty,
          trimmed.lowercased().hasPrefix("smb") else { return nil }
    return "/Volumes/\(share)"
}

/// Color for a status — kept in the view layer so `PorterStatus` (in the
/// service layer) stays free of SwiftUI.
func statusColor(_ status: PorterStatus) -> Color {
    switch status {
    case .idle:            return .green
    case .syncing:         return .blue
    case .sorted:          return .green
    case .paused:          return .orange
    case .needsPermission, .error: return .red
    }
}

/// Status icon + title + one-line subtitle. Shared by the menu-bar panel and the
/// main-window dashboard.
struct StatusHeaderView: View {
    let coordinator: SortCoordinator
    var iconSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: coordinator.status.symbolName)
                    .font(.system(size: iconSize))
                    .foregroundStyle(statusColor(coordinator.status))
                    .frame(width: iconSize + 6)
                    .symbolEffect(.pulse, isActive: coordinator.status == .syncing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(coordinator.status.title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if coordinator.status == .syncing {
                progressBar
            }
        }
        .animation(.smooth(duration: 0.25), value: coordinator.status)
    }

    @ViewBuilder private var progressBar: some View {
        if let p = coordinator.progress, p.total > 0 {
            VStack(alignment: .leading, spacing: 3) {
                ProgressView(value: p.fraction)
                Text("Sorting \(p.completed) of \(p.total)…")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        } else {
            // Triaging / no count yet — indeterminate.
            ProgressView().progressViewStyle(.linear)
        }
    }

    private var subtitle: String {
        if let last = coordinator.lastSweepAt {
            let when = last.formatted(date: .omitted, time: .shortened)
            return "\(coordinator.totalMoved) sorted · last at \(when)"
        }
        return "\(coordinator.totalMoved) sorted this session"
    }
}

/// Scrollable list of recent moves/failures, or an empty-state. Shared.
struct ActivityListView: View {
    let entries: [ActivityEntry]
    var maxHeight: CGFloat = 260

    var body: some View {
        if entries.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("No files sorted yet")
                    .font(.callout).foregroundStyle(.secondary)
                Text("Drop a file in your watched folder and it'll appear here.")
                    .font(.caption).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 28)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(entries) { entry in
                        ActivityRow(entry: entry)
                        if entry.id != entries.last?.id { Divider() }
                    }
                }
            }
            .frame(maxHeight: maxHeight)
        }
    }
}

/// One row in the activity log — a moved file (folder it went to) or a failure
/// (reason, in red).
struct ActivityRow: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(entry.isFailure ? .red : .secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.fileName)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(entry.isFailure ? .red : .secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var iconName: String {
        if entry.isFailure { return "exclamationmark.triangle" }
        return entry.destination.map { FileCategory.symbol(forFolder: $0) } ?? "doc"
    }

    private var detail: String {
        switch entry.outcome {
        case .moved(let folder): return "→ \(folder)"
        case .failed(let reason): return reason
        }
    }
}
