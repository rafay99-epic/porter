import SwiftUI
import PorterCore

/// Visual editor for the ordered sort rules. Reorder (first match wins), enable,
/// edit, delete, add. Editing a rule opens a sheet that covers every match kind.
struct RulesEditor: View {
    @Bindable var settings: PorterSettings
    /// Recent moves, used to suggest rules for file types that keep hitting the
    /// catch-all. Defaults empty so the editor still works without history.
    var recentActivity: [ActivityEntry] = []
    @State private var editing: SortRule?
    @State private var testName = ""
    @State private var dismissedSuggestions: Set<String> = []

    private var suggestions: [RuleSuggestion] {
        SuggestionEngine.suggestions(from: recentActivity, rules: settings.rules,
                                     dismissed: dismissedSuggestions)
    }

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

            if !suggestions.isEmpty { suggestionsBanner }

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

    /// Proposed rules for file types that keep hitting the catch-all.
    private var suggestionsBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Suggestions", systemImage: "lightbulb").font(.caption).bold().foregroundStyle(.tint)
            ForEach(suggestions) { suggestion in
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(.tint)
                    Text("\(suggestion.count) “.\(suggestion.ext)” files went to the catch-all").font(.caption)
                    Spacer()
                    Button("Add Rule") { editing = suggestion.rule }
                        .buttonStyle(.borderless).font(.caption)
                    Button { dismissedSuggestions.insert(suggestion.ext) } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless).foregroundStyle(.tertiary)
                    .help("Dismiss")
                }
            }
        }
        .padding(10)
        .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 4)
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
        } else if saved.match != .anything,
                  let catchAll = settings.rules.firstIndex(where: { $0.match == .anything }) {
            // A new specific rule must come *before* the catch-all, or it could
            // never win.
            settings.rules.insert(saved, at: catchAll)
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

/// How multiple conditions combine.
private enum Combinator: String, CaseIterable, Identifiable {
    case all = "Match ALL"
    case any = "Match ANY"
    var id: String { rawValue }
}

/// One editable leaf condition (the UI form of a non-compound `RuleMatch`).
private struct EditableCondition: Identifiable {
    enum Kind: String, CaseIterable, Identifiable {
        case extensions = "Extension"
        case prefix = "Name starts with"
        case suffix = "Name ends with"
        case contains = "Name contains"
        case regex = "Regex"
        case kind = "Kind"
        case largerThan = "Larger than"
        case smallerThan = "Smaller than"
        case olderThan = "Older than"
        case newerThan = "Newer than"
        case anything = "Anything else"
        var id: String { rawValue }
    }

    let id = UUID()
    var kind: Kind = .extensions
    var text = ""
    var extensionsText = ""
    var sizeMB = 100.0
    var days = 30.0
    var fileKind: FileKind = .image

    init() {}

    /// Build from an existing leaf match. Returns nil for compound matches, which
    /// this flat editor doesn't represent.
    init?(_ match: RuleMatch) {
        switch match {
        case .extensions(let e):   kind = .extensions; extensionsText = e.joined(separator: ", ")
        case .namePrefix(let p):   kind = .prefix; text = p
        case .nameSuffix(let s):   kind = .suffix; text = s
        case .nameContains(let c): kind = .contains; text = c
        case .regex(let r):        kind = .regex; text = r
        case .kind(let k):         kind = .kind; fileKind = k
        case .largerThan(let b):   kind = .largerThan; sizeMB = ByteSize.toMegabytes(b)
        case .smallerThan(let b):  kind = .smallerThan; sizeMB = ByteSize.toMegabytes(b)
        case .olderThan(let d):    kind = .olderThan; days = Double(d)
        case .newerThan(let d):    kind = .newerThan; days = Double(d)
        case .anything:            kind = .anything
        case .all, .any:           return nil
        }
    }

    var match: RuleMatch {
        switch kind {
        case .extensions:  return .extensions(parseExtensions(extensionsText))
        case .prefix:      return .namePrefix(text)
        case .suffix:      return .nameSuffix(text)
        case .contains:    return .nameContains(text)
        case .regex:       return .regex(text)
        case .kind:        return .kind(fileKind)
        case .largerThan:  return .largerThan(bytes: ByteSize.megabytes(sizeMB))
        case .smallerThan: return .smallerThan(bytes: ByteSize.megabytes(sizeMB))
        case .olderThan:   return .olderThan(days: Int(days))
        case .newerThan:   return .newerThan(days: Int(days))
        case .anything:    return .anything
        }
    }
}

private func parseExtensions(_ text: String) -> [String] {
    text.split(whereSeparator: { $0 == "," || $0 == " " })
        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased() }
        .filter { !$0.isEmpty }
}

/// Sheet to edit a single rule — one or more conditions combined with AND/OR,
/// plus destination and conflict policy.
private struct RuleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let id: UUID
    private let enabled: Bool
    private let nasRoot: String
    @State private var combinator: Combinator
    @State private var conditions: [EditableCondition]
    @State private var destination: String
    @State private var policy: ConflictPolicy
    let onSave: (SortRule) -> Void

    init(rule: SortRule, nasRoot: String, onSave: @escaping (SortRule) -> Void) {
        self.id = rule.id
        self.enabled = rule.enabled
        self.nasRoot = nasRoot
        self.onSave = onSave
        switch rule.match {
        case .all(let subs):
            _combinator = State(initialValue: .all)
            _conditions = State(initialValue: subs.compactMap(EditableCondition.init))
        case .any(let subs):
            _combinator = State(initialValue: .any)
            _conditions = State(initialValue: subs.compactMap(EditableCondition.init))
        default:
            _combinator = State(initialValue: .all)
            _conditions = State(initialValue: [EditableCondition(rule.match) ?? EditableCondition()])
        }
        _destination = State(initialValue: rule.destination)
        _policy = State(initialValue: rule.conflictPolicy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit Rule").font(.headline)

            if conditions.count > 1 {
                Picker("", selection: $combinator) {
                    ForEach(Combinator.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
            }

            VStack(spacing: 8) {
                ForEach($conditions) { $condition in
                    ConditionRow(condition: $condition, canRemove: conditions.count > 1) {
                        conditions.removeAll { $0.id == condition.id }
                    }
                }
            }
            Button {
                conditions.append(EditableCondition())
            } label: { Label("Add Condition", systemImage: "plus.circle") }
                .buttonStyle(.borderless)

            Divider()

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
                    .disabled(destination.trimmingCharacters(in: .whitespaces).isEmpty || conditions.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
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

    private func save() {
        let leaves = conditions.map(\.match)
        let match: RuleMatch
        if leaves.count == 1 {
            match = leaves[0]
        } else {
            match = combinator == .all ? .all(leaves) : .any(leaves)
        }
        onSave(SortRule(id: id, enabled: enabled, match: match,
                        destination: destination.trimmingCharacters(in: .whitespaces),
                        conflictPolicy: policy))
        dismiss()
    }
}

/// One row in the rule editor: a condition kind picker plus the value input it
/// needs, and a remove button when there's more than one condition.
private struct ConditionRow: View {
    @Binding var condition: EditableCondition
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $condition.kind) {
                ForEach(EditableCondition.Kind.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden().frame(width: 150)
            valueField
            Spacer(minLength: 0)
            if canRemove {
                Button(role: .destructive) { onRemove() } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder private var valueField: some View {
        switch condition.kind {
        case .extensions:
            TextField("jpg, png, pdf", text: $condition.extensionsText).textFieldStyle(.roundedBorder)
        case .prefix, .suffix, .contains, .regex:
            TextField(placeholder, text: $condition.text).textFieldStyle(.roundedBorder)
        case .kind:
            Picker("", selection: $condition.fileKind) {
                ForEach(FileKind.allCases) { Text($0.label).tag($0) }
            }.labelsHidden()
        case .largerThan, .smallerThan:
            HStack(spacing: 4) {
                TextField("100", value: $condition.sizeMB, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 70)
                Text("MB").foregroundStyle(.secondary)
            }
        case .olderThan, .newerThan:
            HStack(spacing: 4) {
                TextField("30", value: $condition.days, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 70)
                Text("days").foregroundStyle(.secondary)
            }
        case .anything:
            Text("Matches everything no earlier rule caught.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var placeholder: String {
        switch condition.kind {
        case .prefix:   return "e.g. Screenshot "
        case .suffix:   return "e.g. -final.pdf"
        case .contains: return "e.g. invoice"
        case .regex:    return #"e.g. ^\d{4}-\d{2}-\d{2}"#
        default:        return ""
        }
    }
}
