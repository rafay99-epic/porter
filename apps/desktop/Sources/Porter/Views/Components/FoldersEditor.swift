import SwiftUI
import PorterCore

/// Add / remove / enable watched folders and choose each folder's routing.
/// Each folder is one clean card: a switch, the folder, a one-line routing
/// summary, and a routing menu (which opens the NAS picker on demand) — no
/// segmented controls or inline text fields cluttering the row.
struct FoldersEditor: View {
    @Bindable var settings: PorterSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach($settings.sources) { $source in
                FolderCard(source: $source, nasRoot: settings.nasMountPath) { remove(source) }
            }

            Button { addFolder() } label: {
                Label("Add a Folder", systemImage: "plus.circle.fill")
                    .font(.callout)
            }
            .buttonStyle(.borderless)
            .padding(.top, 2)
        }
    }

    private func addFolder() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard let path = chooseFolderPath(start: home) else { return }
        let std = URL(fileURLWithPath: path).standardizedFileURL.path
        guard !settings.sources.contains(where: { $0.url.standardizedFileURL.path == std }) else { return }
        settings.sources.append(WatchSource(path: path, routing: .classify))
    }

    private func remove(_ source: WatchSource) {
        settings.sources.removeAll { $0.id == source.id }
    }
}

private struct FolderCard: View {
    @Binding var source: WatchSource
    let nasRoot: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $source.enabled)
                .labelsHidden().toggleStyle(.switch).controlSize(.mini)

            Image(systemName: "folder.fill")
                .foregroundStyle(source.enabled ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name).fontWeight(.medium)
                Text(routingSummary)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }

            Spacer()

            Menu {
                Button { source.routing = .classify } label: {
                    Label("Sort by rules", systemImage: isClassify ? "checkmark" : "list.bullet")
                }
                Button { chooseFixedFolder() } label: {
                    Label("Send everything to a NAS folder…",
                          systemImage: isClassify ? "tray.full" : "checkmark")
                }
                Divider()
                Toggle(isOn: $source.recursive) { Label("Include subfolders", systemImage: "folder.badge.gearshape") }
            } label: {
                Label("Routing", systemImage: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        .opacity(source.enabled ? 1 : 0.55)
    }

    private var isClassify: Bool {
        if case .classify = source.routing { return true }
        return false
    }

    /// One-line description of where this folder's files go.
    private var routingSummary: String {
        let suffix = source.recursive ? " · incl. subfolders" : ""
        switch source.routing {
        case .classify:
            return "\(abbreviate(source.path)) · sorted by rules\(suffix)"
        case .fixed(let folder):
            return folder.isEmpty
                ? "\(abbreviate(source.path)) · choose a NAS folder\(suffix)"
                : "\(abbreviate(source.path)) · all files → \(folder)\(suffix)"
        }
    }

    private func chooseFixedFolder() {
        if let picked = chooseNASFolder(nasRoot: nasRoot) {
            source.routing = .fixed(folder: picked)
        } else if isClassify {
            // They opened the picker but cancelled — leave routing as-is.
        }
    }

    /// `/Users/me/Downloads` → `~/Downloads` for a calmer display.
    private func abbreviate(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
