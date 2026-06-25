import SwiftUI
import PorterCore

/// First-run wizard shown in the main window until completed. Walks through what
/// Porter does, the file-access grant it needs, NAS connection, and launch-at-login
/// — then hands off to the dashboard. Re-runnable from Settings.
struct OnboardingView: View {
    @Bindable var onboarding: OnboardingModel
    @Bindable var settings: PorterSettings
    @Bindable var loginItem: LoginItem
    let coordinator: SortCoordinator

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                content
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
        }
        .frame(width: 540, height: 520)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: stepIcon)
                .font(.system(size: 36))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .contentTransition(.symbolEffect(.replace))
            Text(onboarding.step.title).font(.title2).bold()
            ProgressView(value: onboarding.progress)
                .frame(maxWidth: 220)
                .tint(.accentColor)
        }
        .padding(.top, 28)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .animation(.smooth, value: onboarding.step)
    }

    private var stepIcon: String {
        switch onboarding.step {
        case .welcome: return "tray.and.arrow.down.fill"
        case .source:  return "folder.fill"
        case .access:  return "lock.shield.fill"
        case .nas:     return "externaldrive.connected.to.line.below.fill"
        case .login:   return "power"
        case .menuBar: return "menubar.rectangle"
        case .done:    return "checkmark.seal.fill"
        }
    }

    @ViewBuilder private var content: some View {
        switch onboarding.step {
        case .welcome: WelcomeStep()
        case .source:  SourceStep(settings: settings, coordinator: coordinator)
        case .access:  AccessStep(settings: settings, coordinator: coordinator)
        case .nas:     NASStep(settings: settings, coordinator: coordinator)
        case .login:   LoginStep(loginItem: loginItem)
        case .menuBar: MenuBarStep(settings: settings)
        case .done:    DoneStep(settings: settings)
        }
    }

    private var footer: some View {
        HStack {
            if !onboarding.isFirstStep {
                Button("Back") { onboarding.back() }
            }
            Spacer()
            if onboarding.isLastStep {
                Button("Start Sorting") { finishFlow() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Continue") { onboarding.next() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
    }

    private func finishFlow() {
        onboarding.finish()
        // Begin watching (first run) and re-point at whatever source the user
        // confirmed. start() is idempotent; reconfigure() handles a re-run where the
        // coordinator is already going.
        coordinator.start()
        coordinator.reconfigure()
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Porter files your downloads onto your NAS — automatically.")
                .font(.title3)
            VStack(alignment: .leading, spacing: 14) {
                row("folder", "Watches a folder you choose")
                row("arrow.right.circle", "Sorts each file by type onto the NAS")
                row("menubar.rectangle", "Lives in the menu bar — always shows its status")
            }
            Label("Takes about 30 seconds to set up.", systemImage: "clock")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func row(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon).font(.callout)
    }
}

private struct AccessStep: View {
    @Bindable var settings: PorterSettings
    let coordinator: SortCoordinator
    @State private var hasAccess = false
    @State private var requested = false

    private var folderName: String { settings.sourceURL.lastPathComponent }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("macOS will ask permission for Porter to read your **\(folderName)** folder. Click Allow when it appears.")
                .foregroundStyle(.secondary)

            statusBadge

            if hasAccess {
                Text("Porter can read this folder. You're good to continue.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Button("Allow Access to \(folderName)") { request() }
                    .buttonStyle(.borderedProminent)
                if requested {
                    Button("Prompt didn't appear? Open Full Disk Access…") {
                        coordinator.openFullDiskAccessSettings()
                    }
                    .buttonStyle(.link)
                    Text("Add Porter with the ＋ button and switch it on. You can also continue and grant this later — Porter will keep a reminder until it's done.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        // Provoke the native per-folder prompt as soon as the step appears, by
        // actually reading the chosen folder.
        .onAppear { hasAccess = Permissions.canRead(settings.sourceURL) }
        .task {
            while !Task.isCancelled {
                hasAccess = Permissions.canRead(settings.sourceURL)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func request() {
        requested = true
        hasAccess = Permissions.canRead(settings.sourceURL)
    }

    private var statusBadge: some View {
        Label(hasAccess ? "Porter can read \(folderName)" : "Waiting for permission…",
              systemImage: hasAccess ? "checkmark.circle.fill" : "hourglass")
            .foregroundStyle(hasAccess ? .green : .orange)
            .font(.callout.bold())
    }
}

private struct SourceStep: View {
    @Bindable var settings: PorterSettings
    let coordinator: SortCoordinator

    private var presets: [(name: String, path: String)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            ("Downloads", home.appendingPathComponent("Downloads").path),
            ("Documents", home.appendingPathComponent("Documents").path),
            ("Desktop", home.appendingPathComponent("Desktop").path)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick the folder Porter should watch. New files that land here get filed onto your NAS. Most people watch Downloads — but it can be any folder: your code projects, Desktop, anything.")
                .foregroundStyle(.secondary)
            ForEach(presets, id: \.path) { preset in
                presetRow(name: preset.name, path: preset.path)
            }
            Divider()
            HStack {
                Text(settings.sourcePath)
                    .font(.callout).lineLimit(1).truncationMode(.head)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Choose Other Folder…") {
                    if let picked = chooseFolderPath(start: settings.sourcePath) {
                        settings.sourcePath = picked
                    }
                }
            }

            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Wait \(Int(settings.settleSeconds))s after a file appears before filing it")
                    .font(.callout)
                Slider(value: $settings.settleSeconds, in: 5...120, step: 5)
                Text("A short wait avoids grabbing a download that's still in progress. You can change this any time in Settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func presetRow(name: String, path: String) -> some View {
        let selected = settings.sourcePath == path
        return Button {
            settings.sourcePath = path
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                Text(name)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct NASStep: View {
    @Bindable var settings: PorterSettings
    let coordinator: SortCoordinator
    @State private var shares: [MountedShare] = []
    @State private var showManual = false
    @State private var attempting = false

    /// Whether the folder Porter will file into is one of the currently-mounted
    /// shares (recomputed as the poll refreshes `shares`).
    private var chosenMounted: Bool {
        !settings.nasMountPath.isEmpty && shares.contains { $0.mountPoint == settings.nasMountPath }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pick the NAS you've connected in Finder — Porter fills in the address and location for you. Not mounted yet? Open Finder (⌘K) to connect it and it'll appear here.")
                .foregroundStyle(.secondary)

            if shares.isEmpty {
                emptyState
            } else {
                shareList
            }

            HStack(spacing: 12) {
                Button("Open in Finder") { coordinator.revealNAS() }
                Button("Rescan") { shares = MountCheck.networkMounts() }
                Spacer()
                statusLabel
            }

            DisclosureGroup("Enter address manually", isExpanded: $showManual) {
                manualEntry
            }
            .font(.callout)
        }
        .task {
            while !Task.isCancelled {
                shares = MountCheck.networkMounts()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private var shareList: some View {
        VStack(spacing: 0) {
            ForEach(shares) { share in
                Button { select(share) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: settings.nasMountPath == share.mountPoint
                              ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(settings.nasMountPath == share.mountPoint ? Color.accentColor : .secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(share.name).font(.body)
                            Text(share.url ?? share.mountPoint)
                                .font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Image(systemName: "externaldrive.fill").foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                if share.id != shares.last?.id { Divider() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No mounted network shares found", systemImage: "externaldrive.badge.questionmark")
                .foregroundStyle(.secondary)
            Text("In Finder, press ⌘K and connect to your NAS — it'll appear here automatically. Or enter its address manually below.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusLabel: some View {
        Label(chosenMounted ? "Ready" : "Not selected",
              systemImage: chosenMounted ? "checkmark.circle.fill" : "circle.dashed")
            .foregroundStyle(chosenMounted ? .green : .secondary)
            .font(.callout.bold())
    }

    private var manualEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("For power users: type the share's address and Porter will mount it.")
                .font(.caption).foregroundStyle(.secondary)
            LabeledContent("NAS address") {
                TextField("smb://user@host/share", text: $settings.smbURL)
                    .textFieldStyle(.roundedBorder).onSubmit(connect)
            }
            LabeledContent("Mount point") {
                TextField("/Volumes/media", text: $settings.nasMountPath)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 12) {
                Button(attempting ? "Connecting…" : "Connect") { connect() }
                    .disabled(settings.smbURL.trimmingCharacters(in: .whitespaces).isEmpty || attempting)
                Button("Point to Folder…") {
                    if let picked = chooseFolderPath(start: "/Volumes") { settings.nasMountPath = picked }
                }
            }
        }
        .padding(.top, 6)
    }

    private func select(_ share: MountedShare) {
        settings.nasMountPath = share.mountPoint
        if let url = share.url { settings.smbURL = url }
    }

    private func connect() {
        if let mp = defaultMountPoint(forSMB: settings.smbURL),
           settings.nasMountPath.isEmpty || settings.nasMountPath == "/Volumes/media" {
            settings.nasMountPath = mp
        }
        attempting = true
        coordinator.mountNow()
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            attempting = false
            shares = MountCheck.networkMounts()
        }
    }
}

private struct LoginStep: View {
    @Bindable var loginItem: LoginItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Keep Porter working without thinking about it — launch it automatically when you log in.")
            Toggle("Launch Porter at login", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }))
                .toggleStyle(.switch)
            if loginItem.state == .requiresApproval {
                Text("Approve Porter in System Settings ▸ General ▸ Login Items.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { loginItem.refresh() }
    }
}

private struct MenuBarStep: View {
    @Bindable var settings: PorterSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Porter can show a status icon in the menu bar for quick access — sort now, see recent activity, mount the NAS. Or keep it Dock-only.")
                .foregroundStyle(.secondary)
            Toggle("Show Porter in the menu bar", isOn: $settings.menuBarEnabled)
                .toggleStyle(.switch)
            Text("You can change this any time in Settings.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct DoneStep: View {
    @Bindable var settings: PorterSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Watching \(settings.sourceURL.lastPathComponent)", systemImage: "eye")
            Label("Filing to \(settings.nasMountPath)", systemImage: "externaldrive")
            Label(settings.menuBarEnabled ? "Menu bar icon on" : "Menu bar icon off",
                  systemImage: settings.menuBarEnabled ? "menubar.rectangle" : "menubar.dock.rectangle")
            Text("Drop a file in the folder you chose and Porter files it onto the NAS within moments. Change anything later in Settings.")
                .foregroundStyle(.secondary)
        }
    }
}
