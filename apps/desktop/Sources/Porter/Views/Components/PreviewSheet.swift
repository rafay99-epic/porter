import SwiftUI
import PorterCore

/// Dry-run preview: shows exactly what the next sweep would move and where,
/// grouped by destination folder, without touching anything. Reached from the
/// "Preview" button. Pairs with the rules — see a rule's effect before it runs.
struct PreviewSheet: View {
    let coordinator: SortCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var plan: [PlannedMove]?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 460, height: 420)
        .task { await reload() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye").font(.title3).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Preview").font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .help("Re-scan")
        }
        .padding(14)
    }

    private var subtitle: String {
        guard let plan else { return "Scanning your watched folders…" }
        if plan.isEmpty { return "Nothing to move right now" }
        return "\(plan.count) file\(plan.count == 1 ? "" : "s") would move — nothing has been touched"
    }

    @ViewBuilder private var content: some View {
        if let plan {
            if plan.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle").font(.system(size: 30)).foregroundStyle(.tertiary)
                    Text("Everything's already sorted").font(.callout).foregroundStyle(.secondary)
                    Text("New or still-settling files will show up here.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(grouped, id: \.destination) { group in
                            sectionHeader(group.destination, count: group.moves.count)
                            ForEach(group.moves) { move in
                                row(move)
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func sectionHeader(_ destination: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: FileCategory.symbol(forFolder: destination)).foregroundStyle(.secondary)
            Text(destination.isEmpty ? "NAS root" : destination).font(.subheadline).bold()
            Text("\(count)").font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)
    }

    private func row(_ move: PlannedMove) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary).frame(width: 16)
            Text(move.name).font(.callout).lineLimit(1).truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 5)
    }

    private var footer: some View {
        HStack {
            if let plan, !plan.isEmpty {
                Button("Sort These Now") { coordinator.sortNow(); dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
        }
        .padding(14)
    }

    // MARK: - Grouping

    private struct Group { let destination: String; let moves: [PlannedMove] }

    /// Planned moves grouped by destination folder, groups ordered by first
    /// appearance (which mirrors rule order for classify sources).
    private var grouped: [Group] {
        guard let plan else { return [] }
        var order: [String] = []
        var buckets: [String: [PlannedMove]] = [:]
        for move in plan {
            if buckets[move.destination] == nil { order.append(move.destination) }
            buckets[move.destination, default: []].append(move)
        }
        return order.map { Group(destination: $0, moves: buckets[$0] ?? []) }
    }

    private func reload() async {
        plan = nil
        plan = await coordinator.previewPlan()
    }
}
