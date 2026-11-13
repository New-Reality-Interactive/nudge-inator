import SwiftUI

/// The Apple Account Changed note (ticket 212, the mockup's `accountSheet`): a different Apple
/// Account signed in, so the old account's sharing left this iPhone. It says what went, under
/// Removed from This iPhone, and that the person's own reminders haven't changed. Connection
/// Ended's shape, with no choice to make: one prominent OK, and a swipe down closes it too.
struct AccountChangedSheet: View {
    let note: AccountChangeNote
    /// The person has seen it.
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // The list's own side insets, so the text lines up with the rows, as Connection Ended's.
                    Text("This iPhone is signed in to a different Apple Account now, so sharing stopped for the people you were connected with through the other account.", comment: "The Apple Account Changed sheet: its first line.")
                        .fixedSize(horizontal: false, vertical: true)
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(note.rows, id: \.self, content: row)
                } header: {
                    Text("Removed from This iPhone", comment: "The Apple Account Changed sheet: header of what was removed.")
                } footer: {
                    Text("Your own reminders haven't changed. To share again, invite people from Settings › Connections.", comment: "The Apple Account Changed sheet: under what was removed.")
                }
                Section {
                    Button(action: onDismiss) {
                        Text("OK", comment: "The Apple Account Changed sheet: closes it.")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets()) // the button fills the row on a clear background; no text in the row
            }
            .navigationTitle(Text("Apple Account Changed", comment: "The Apple Account Changed sheet's title: a different Apple Account signed in on the iPhone."))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ row: AccountChangeNote.Row) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s1) {
            title(of: row)
                .foregroundStyle(Color(uiColor: .label))
            detail(of: row)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        .accessibilityElement(children: .combine)
    }

    private func title(of row: AccountChangeNote.Row) -> Text {
        switch row {
        case .received(let count, let senders):
            Text("\(count) reminders from \(senders)", comment: "The Apple Account Changed sheet: the received reminders removed. 1: how many. 2: who sent them, as a list, such as \"Maya Torres and Sam Okafor\".")
        case .connections(let count, _):
            Text("\(count) connections", comment: "The Apple Account Changed sheet: the connections removed, invites among them. The placeholder is how many.")
        case .sent(let count):
            Text("\(count) reminders you sent", comment: "The Apple Account Changed sheet: the reminders this person sent, removed. The placeholder is how many.")
        }
    }

    private func detail(of row: AccountChangeNote.Row) -> Text {
        switch row {
        case .received:
            Text("Their nudges and alarms are canceled.", comment: "The Apple Account Changed sheet: under the received reminders removed.")
        case .connections(_, let names):
            Text("\(names), including invites not yet accepted.", comment: "The Apple Account Changed sheet: under the connections removed. The placeholder is their names, as a list, such as \"Maya Torres, Sam Okafor, and Jordan Lee\".")
        case .sent:
            Text("Your Sent view starts empty.", comment: "The Apple Account Changed sheet: under the reminders this person sent, removed.")
        }
    }
}

extension AccountChangeNote: Identifiable {
    /// The note is its own identity: a different note is a different sheet.
    var id: Self { self }

    /// One line under Removed from This iPhone, with its names as a list in the person's locale.
    enum Row: Hashable {
        case received(count: Int, senders: String)
        case connections(count: Int, names: String)
        case sent(count: Int)
    }

    /// The note's rows, in the mockup's order, a kind with nothing removed left out.
    var rows: [Row] {
        var rows: [Row] = []
        if receivedCount > 0 { rows.append(.received(count: receivedCount, senders: senders.formatted(.list(type: .and)))) }
        if !connections.isEmpty { rows.append(.connections(count: connections.count, names: connections.formatted(.list(type: .and)))) }
        if sentCount > 0 { rows.append(.sent(count: sentCount)) }
        return rows
    }
}

extension View {
    /// The Apple Account Changed note (ticket 212), over whatever screen is showing, as Connection
    /// Ended is: whenever sharing holds a note the person hasn't dismissed, so when they next open
    /// the app. Nothing without a sharing model.
    func accountChanged(sharing: SharingModel?) -> some View {
        modifier(AccountChangedPresenter(sharing: sharing))
    }
}

private struct AccountChangedPresenter: ViewModifier {
    let sharing: SharingModel?

    func body(content: Content) -> some View {
        // The sheet is handed the note, as Connection Ended is handed its connection, so it keeps
        // showing it while it closes after OK has cleared it.
        content.sheet(item: Binding(get: { sharing?.accountChangeNote }, set: { if $0 == nil { dismiss() } })) { note in
            AccountChangedSheet(note: note, onDismiss: dismiss)
        }
    }

    /// A store that can't keep the dismissal leaves the note, which shows again.
    private func dismiss() {
        do {
            try sharing?.dismissAccountChangeNote()
        } catch {
            SharingModel.logger.error("The account change note couldn't be dismissed: \(error, privacy: .public)")
        }
    }
}

#if DEBUG
#Preview("Apple Account Changed") {
    AccountChangedSheet(
        note: AccountChangeNote(receivedCount: 5, senders: ["Maya Torres", "Sam Okafor"], connections: ["Maya Torres", "Sam Okafor", "Jordan Lee", "Priya Shah"], sentCount: 10)
    ) {}
}

#Preview("Apple Account Changed, largest text") {
    AccountChangedSheet(note: AccountChangeNote(receivedCount: 1, senders: ["Maya Torres"], connections: ["Maya Torres"], sentCount: 0)) {}
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
