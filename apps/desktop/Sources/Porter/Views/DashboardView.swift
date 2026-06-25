import SwiftUI
import PorterCore

/// The main-window content after onboarding. A polished home screen: a status
/// "hero", a summary of what's being watched and where it's filed, then the
/// activity log and the primary actions.
struct DashboardView: View {
    @Bindable var coordinator: SortCoordinator
    @Bindable var loginItem: LoginItem
    @Bindable var updater: Updater
    @State private var showingPreview = false

    var body: some View {
        VStack(spacing: 0) {
            if let release = updater.available {
                updateBanner(release)
                Divider()
            }

            hero
                .padding(.top, 24)
                .padding(.bottom, 16)
                .padding(.horizontal, 24)

            watchingCard
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            stateCallout
                .padding(.horizontal, 24)

            Divider()

            HStack {
                Text("Recent Activity").font(.subheadline).bold().foregroundStyle(.secondary)
                Spacer()
                if coordinator.totalMoved > 0 {
                    Text("\(coordinator.totalMoved) total").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 10)

            ActivityListView(entries: coordinator.activity, maxHeight: .infinity,
                             onUndo: { coordinator.undo($0) })

            Divider()
            footer
        }
        .frame(minWidth: 460, minHeight: 560)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(statusColor(coordinator.status).opacity(0.15))
                Image(systemName: coordinator.status.symbolName)
                    .font(.system(size: 30))
                    .foregroundStyle(statusColor(coordinator.status))
                    .symbolEffect(.pulse, isActive: coordinator.status == .syncing)
            }
            .frame(width: 68, height: 68)

            Text(coordinator.status.title).font(.title3).bold()
            Text(heroSubtitle).font(.subheadline).foregroundStyle(.secondary)

            if coordinator.status == .syncing {
                progressBar.frame(maxWidth: 280).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.smooth(duration: 0.25), value: coordinator.status)
    }

    private var heroSubtitle: String {
        if let last = coordinator.lastSweepAt {
            return "Last sorted at \(last.formatted(date: .omitted, time: .shortened))"
        }
        return "Ready when you are"
    }

    @ViewBuilder private var progressBar: some View {
        if let p = coordinator.progress, p.total > 0 {
            VStack(spacing: 3) {
                ProgressView(value: p.fraction)
                Text("Sorting \(p.completed) of \(p.total)…").font(.caption2).foregroundStyle(.secondary)
            }
        } else {
            ProgressView().progressViewStyle(.linear)
        }
    }

    // MARK: - Watching summary

    private var watchingCard: some View {
        VStack(spacing: 0) {
            infoRow(icon: "folder.fill", label: "Watching",
                    value: watchingSummary, trailing: nil)
            Divider().padding(.leading, 40)
            infoRow(icon: "externaldrive.fill", label: "Filing to",
                    value: coordinator.settings.nasMountPath,
                    trailing: mountIndicator)
        }
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }

    private var watchingSummary: String {
        let names = coordinator.settings.sources.filter(\.enabled).map(\.name)
        switch names.count {
        case 0:    return "no folders"
        case 1, 2: return names.joined(separator: ", ")
        default:   return "\(names.count) folders"
        }
    }

    private func infoRow(icon: String, label: String, value: String, trailing: AnyView?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.callout).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if let trailing { trailing }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var mountIndicator: AnyView {
        AnyView(
            HStack(spacing: 5) {
                Circle().fill(coordinator.nasMounted ? .green : .orange).frame(width: 7, height: 7)
                Text(coordinator.nasMounted ? "Mounted" : "Offline")
                    .font(.caption).foregroundStyle(.secondary)
            }
        )
    }

    // MARK: - State callout

    @ViewBuilder private var stateCallout: some View {
        switch coordinator.status {
        case .needsPermission:
            callout(text: "Porter can't read your watched folder. Grant Full Disk Access so it can sort in the background.",
                    button: "Grant Full Disk Access…", prominent: true) { coordinator.openFullDiskAccessSettings() }
        case .paused:
            callout(text: "The NAS isn't mounted, so sorting is paused. Files stay put until it's back.",
                    button: "Mount Now", prominent: false) { coordinator.mountNow() }
        default:
            EmptyView()
        }
    }

    // MARK: - Banner / callout / footer

    private func updateBanner(_ release: Updater.Available) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text("Update available — \(release.version)").font(.callout).bold()
                if let msg = updater.statusMessage {
                    Text(msg).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(updater.isInstalling ? "Installing…" : "Update Now") { updater.installAvailable() }
                .buttonStyle(.borderedProminent)
                .disabled(updater.isInstalling)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.12))
    }

    @ViewBuilder
    private func callout(text: String, button: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(text).font(.callout).foregroundStyle(.secondary)
                if prominent {
                    Button(button, action: action).buttonStyle(.borderedProminent)
                } else {
                    Button(button, action: action).buttonStyle(.bordered)
                }
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Sort Now") { coordinator.sortNow() }
                .buttonStyle(.borderedProminent)
            Button("Preview…") { showingPreview = true }
            Button("Reveal Log") { coordinator.revealLogInFinder() }
            Spacer()
            SettingsLink { Text("Settings…") }
        }
        .padding(16)
        .sheet(isPresented: $showingPreview) { PreviewSheet(coordinator: coordinator) }
    }
}
