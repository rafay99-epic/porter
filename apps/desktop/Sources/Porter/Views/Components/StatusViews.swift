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

/// Pick a destination folder *inside* the mounted NAS and return it as a path
/// relative to `nasRoot` (what `Mover` expects). The panel is rooted at the NAS
/// mount and can create new folders. Picking the root returns "" (files land at
/// the NAS root); a folder outside the NAS falls back to its own name.
@MainActor
func chooseNASFolder(nasRoot: String) -> String? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Choose"
    panel.message = "Pick a folder on your NAS for these files"
    panel.directoryURL = URL(fileURLWithPath: nasRoot)
    guard panel.runModal() == .OK, let url = panel.url else { return nil }

    let picked = url.standardizedFileURL.path
    let root = URL(fileURLWithPath: nasRoot).standardizedFileURL.path
    if picked == root { return "" }
    if picked.hasPrefix(root + "/") { return String(picked.dropFirst(root.count + 1)) }
    return url.lastPathComponent
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
    case .suspended:       return .gray
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
    /// When set, a moved row shows a "move back" button that calls this.
    var onUndo: ((ActivityEntry) -> Void)?

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
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .padding(.vertical, 16)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(entries) { entry in
                        ActivityRow(entry: entry, onUndo: onUndo)
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
    var onUndo: ((ActivityEntry) -> Void)?
    @State private var hovering = false

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
                    .strikethrough(entry.undone, color: .secondary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(entry.isFailure ? .red : .secondary)
                    .lineLimit(1)
            }
            Spacer()
            if entry.undone {
                Text("Moved back").font(.caption2).foregroundStyle(.tertiary)
            } else if let onUndo, entry.canUndo {
                Button("Move Back") { onUndo(entry) }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                    .opacity(hovering ? 1 : 0)
                    .help("Move this file back to where it came from")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var iconName: String {
        if entry.isFailure { return "exclamationmark.triangle" }
        return entry.destination.map { FileCategory.symbol(forFolder: $0) } ?? "doc"
    }

    private var detail: String {
        switch entry.outcome {
        case .moved(let folder): return entry.undone ? "moved back from \(folder)" : "→ \(folder)"
        case .failed(let reason): return reason
        }
    }
}
