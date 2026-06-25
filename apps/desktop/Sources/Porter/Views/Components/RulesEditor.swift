import SwiftUI
import PorterCore

/// Visual editor for the ordered sort rules. Reorder (first match wins), enable,
/// edit, delete, add. Editing a rule opens a sheet that covers every match kind.
struct RulesEditor: View {
    @Bindable var settings: PorterSettings
    @State private var editing: SortRule?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rules run top to bottom — the first enabled match wins. End with an “anything else” catch-all.")
                .font(.caption).foregroundStyle(.secondary)

            ForEach($settings.rules) { $rule in
                RuleRow(rule: $rule,
                        position: position(of: rule.id),
                        count: settings.rules.count,
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
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMove: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $rule.enabled).labelsHidden()
            Image(systemName: FileCategory.symbol(forFolder: rule.destination))
                .foregroundStyle(.secondary).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.match.summary).font(.callout)
                Text("→ \(rule.destination.isEmpty ? "—" : rule.destination)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button { onMove(-1) } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.borderless).disabled(position == 0)
            Button { onMove(1) } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.borderless).disabled(position >= count - 1)
            Button(action: onEdit) { Image(systemName: "pencil") }.buttonStyle(.borderless)
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }.buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
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
                        destination: destination.trimmingCharacters(in: .whitespaces)))
        dismiss()
    }
}
