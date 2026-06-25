import SwiftUI
import PorterCore

/// Add / remove / enable watched folders and choose each folder's routing
/// (sort-by-rules, or send everything to one fixed NAS folder). Shared by the
/// onboarding folder step and Settings.
struct FoldersEditor: View {
    @Bindable var settings: PorterSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if settings.sources.isEmpty {
                Text("No folders yet — add one to start watching.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach($settings.sources) { $source in
                SourceRow(source: $source) { remove(source) }
                Divider()
            }
            Button { addFolder() } label: { Label("Add Folder…", systemImage: "plus.circle") }
                .buttonStyle(.borderless)
        }
    }

    private func addFolder() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard let path = chooseFolderPath(start: home) else { return }
        guard !settings.sources.contains(where: { $0.url.standardizedFileURL.path == URL(fileURLWithPath: path).standardizedFileURL.path }) else { return }
        settings.sources.append(WatchSource(path: path, routing: .classify))
    }

    private func remove(_ source: WatchSource) {
        settings.sources.removeAll { $0.id == source.id }
    }
}

private struct SourceRow: View {
    @Binding var source: WatchSource
    let onRemove: () -> Void

    private enum RoutingKind { case classify, fixed }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Toggle("", isOn: $source.enabled).labelsHidden()
                Image(systemName: "folder.fill").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(source.name).font(.body)
                    Text(source.path).font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 8) {
                Picker("Routing", selection: routingKind) {
                    Text("Sort by rules").tag(RoutingKind.classify)
                    Text("Send all to…").tag(RoutingKind.fixed)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                if routingKind.wrappedValue == .fixed {
                    TextField("NAS folder", text: fixedFolder).textFieldStyle(.roundedBorder)
                }
            }
            .disabled(!source.enabled)
        }
        .padding(.vertical, 2)
    }

    private var routingKind: Binding<RoutingKind> {
        Binding(
            get: { if case .fixed = source.routing { return .fixed }; return .classify },
            set: { kind in
                switch kind {
                case .classify: source.routing = .classify
                case .fixed:
                    if case .fixed = source.routing { } else { source.routing = .fixed(folder: "") }
                }
            })
    }

    private var fixedFolder: Binding<String> {
        Binding(
            get: { if case .fixed(let folder) = source.routing { return folder }; return "" },
            set: { source.routing = .fixed(folder: $0) })
    }
}
