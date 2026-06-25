import SwiftUI
import PorterCore

/// Visual editor for the ordered sort rules. Reorder (first match wins), enable,
/// edit, delete, add. Editing a rule opens a sheet that covers every match kind.
struct RulesEditor: View {
    @Bindable var settings: PorterSettings
    @State private var editing: SortRule?
    @State private var testName = ""

    /// The rule that would win for the typed test name (nil when the field is empty
    /// or nothing matches). Used both to show the result and to highlight the row.
    private var winningRule: SortRule? {
        let trimmed = testName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return RuleEngine.firstMatch(for: trimmed, using: settings.rules)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rules run top to bottom — the first enabled match wins. End with an “anything else” catch-all.")
                .font(.caption).foregroundStyle(.secondary)

            tester

            ForEach($settings.rules) { $rule in
                RuleRow(rule: $rule,
                        position: position(of: rule.id),
                        count: settings.rules.count,
                        isWinner: !testName.trimmingCharacters(in: .whitespaces).isEmpty && rule.id == winningRule?.id,
                        onEdit: { editing = rule },
                        onDelete: { settings.rules.removeAll { $0.id == rule.id } },
                        onMove: { direction in move(rule.id, by: direction) })
                Divider()
            }

            Button {
                editing = SortRule(match: .extensions([]), destination: "")
            } label: { Label("Add Rule", systemImage: "plus.circle") }
                .buttonStyle(.borderless)
        }
        .sheet(item: $editing) { rule in
            RuleEditorSheet(rule: rule, nasRoot: settings.nasMountPath) { saved in commit(saved) }
        }
    }

    /// Type a filename, see which rule catches it and where it'd land.
    private var tester: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "testtube.2").foregroundStyle(.secondary)
                TextField("Test a filename, e.g. invoice-2026.pdf", text: $testName)
                    .textFieldStyle(.roundedBorder)
                if !testName.isEmpty {
                    Button { testName = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless).foregroundStyle(.tertiary)
                }
            }
            if !testName.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(spacing: 6) {
                    if let rule = winningRule {
                        Image(systemName: FileCategory.symbol(forFolder: rule.destination)).foregroundStyle(.tint)
                        Text("Matches “\(rule.match.summary)” → ").font(.caption) +
                        Text(rule.destination).font(.caption).bold()
                    } else {
                        Image(systemName: "arrow.uturn.down").foregroundStyle(.secondary)
                        Text("No rule matches → files would land in ").font(.caption) +
                        Text("Other").font(.caption).bold()
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 4)
    }

    private func position(of id: UUID) -> Int { settings.rules.firstIndex { $0.id == id } ?? 0 }

    private func move(_ id: UUID, by direction: Int) {
        guard let i = settings.rules.firstIndex(where: { $0.id == id }) else { return }
        let j = i + direction
        guard settings.rules.indices.contains(j) else { return }
        settings.rules.swapAt(i, j)
    }

    private func commit(_ saved: SortRule) {
        if let idx = settings.rules.firstIndex(where: { $0.id == saved.id }) {
            settings.rules[idx] = saved
        } else {
            settings.rules.append(saved)
        }
    }
}

private struct RuleRow: View {
    @Binding var rule: SortRule
    let position: Int
    let count: Int
    var isWinner = false
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMove: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $rule.enabled).labelsHidden()
            Image(systemName: FileCategory.symbol(forFolder: rule.destination))
                .foregroundStyle(isWinner ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.match.summary).font(.callout)
                Text("→ \(rule.destination.isEmpty ? "—" : rule.destination)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if isWinner {
                Text("WINS").font(.caption2).bold().foregroundStyle(.tint)
            }
            Button { onMove(-1) } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.borderless).disabled(position == 0)
            Button { onMove(1) } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.borderless).disabled(position >= count - 1)
            Button(action: onEdit) { Image(systemName: "pencil") }.buttonStyle(.borderless)
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }.buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(isWinner ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 6))
    }
}

/// Sheet to edit a single rule across all match kinds.
private struct RuleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let id: UUID
    private let enabled: Bool
    private let nasRoot: String
    @State private var kind: Kind
    @State private var text: String
    @State private var extensionsText: String
    @State private var destination: String
    @State private var policy: ConflictPolicy
    let onSave: (SortRule) -> Void

    private enum Kind: String, CaseIterable, Identifiable {
        case extensions = "Extensions"
        case prefix = "Name starts with"
        case suffix = "Name ends with"
        case contains = "Name contains"
        case regex = "Regex"
        case anything = "Anything else"
        var id: String { rawValue }
    }

    init(rule: SortRule, nasRoot: String, onSave: @escaping (SortRule) -> Void) {
        self.id = rule.id
        self.enabled = rule.enabled
        self.nasRoot = nasRoot
        self.onSave = onSave
        switch rule.match {
        case .extensions(let exts): _kind = State(initialValue: .extensions); _extensionsText = State(initialValue: exts.joined(separator: ", ")); _text = State(initialValue: "")
        case .namePrefix(let p):    _kind = State(initialValue: .prefix); _text = State(initialValue: p); _extensionsText = State(initialValue: "")
        case .nameSuffix(let s):    _kind = State(initialValue: .suffix); _text = State(initialValue: s); _extensionsText = State(initialValue: "")
        case .nameContains(let c):  _kind = State(initialValue: .contains); _text = State(initialValue: c); _extensionsText = State(initialValue: "")
        case .regex(let r):         _kind = State(initialValue: .regex); _text = State(initialValue: r); _extensionsText = State(initialValue: "")
        case .anything:             _kind = State(initialValue: .anything); _text = State(initialValue: ""); _extensionsText = State(initialValue: "")
        }
        _destination = State(initialValue: rule.destination)
        _policy = State(initialValue: rule.conflictPolicy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit Rule").font(.headline)
            Picker("Match", selection: $kind) {
                ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
            }
            switch kind {
            case .extensions:
                TextField("Extensions (comma-separated): jpg, png, pdf", text: $extensionsText)
                    .textFieldStyle(.roundedBorder)
            case .prefix, .suffix, .contains, .regex:
                TextField(placeholder, text: $text).textFieldStyle(.roundedBorder)
            case .anything:
                Text("Matches every file that no earlier rule caught.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                TextField("Destination folder on NAS (e.g. Documents/Invoices)", text: $destination)
                    .textFieldStyle(.roundedBorder)
                Button("Choose…") {
                    if let picked = chooseNASFolder(nasRoot: nasRoot) { destination = picked }
                }
            }
            destinationHint
            Picker("If a file already exists", selection: $policy) {
                ForEach(ConflictPolicy.allCases) { Text($0.label).tag($0) }
            }
            Text(policyHelp).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(destination.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    /// Hint about date tokens, with a live expansion of the current destination so
    /// the user sees today's resolved folder as they type.
    @ViewBuilder private var destinationHint: some View {
        if DestinationTemplate.hasTokens(destination) {
            Text("Today this files into ").font(.caption).foregroundStyle(.secondary) +
            Text(DestinationTemplate.expand(destination, date: Date())).font(.caption).bold()
        } else {
            Text("Tip: use date tokens like {yyyy}/{MM} to file into dated subfolders.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var policyHelp: String {
        switch policy {
        case .rename:    return "Keep both — the new file gets a “ (1)” suffix. Nothing is overwritten."
        case .skip:      return "Leave the new file in its watched folder and don't move it."
        case .overwrite: return "Replace the file already on the NAS with the new one."
        case .keepNewer: return "Overwrite only if the new file is more recent, otherwise skip it."
        }
    }

    private var placeholder: String {
        switch kind {
        case .prefix: return "e.g. Screenshot "
        case .suffix: return "e.g. -final.pdf"
        case .contains: return "e.g. invoice"
        case .regex: return #"e.g. ^\d{4}-\d{2}-\d{2}"#
        default: return ""
        }
    }

    private func save() {
        let match: RuleMatch
        switch kind {
        case .extensions:
            let exts = extensionsText
                .split(whereSeparator: { $0 == "," || $0 == " " })
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased() }
                .filter { !$0.isEmpty }
            match = .extensions(exts)
        case .prefix:   match = .namePrefix(text)
        case .suffix:   match = .nameSuffix(text)
        case .contains: match = .nameContains(text)
        case .regex:    match = .regex(text)
        case .anything: match = .anything
        }
        onSave(SortRule(id: id, enabled: enabled, match: match,
                        destination: destination.trimmingCharacters(in: .whitespaces),
                        conflictPolicy: policy))
        dismiss()
    }
}
