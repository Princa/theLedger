import SwiftUI

private enum EditTarget: Hashable {
    case player(UUID)
    case staff(UUID)
}

struct TeamSettingsView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(Navigator.self) private var nav
    @Environment(CloudSyncService.self) private var cloudSync
    @State private var editing: EditTarget?

    private struct SettingsRow: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    private var settingsRows: [SettingsRow] {
        [
            SettingsRow(label: "Season", value: store.team.season),
            SettingsRow(label: "Bank", value: store.team.bankMask),
            SettingsRow(label: "Signing authority", value: store.team.signingAuthority),
            SettingsRow(label: "Levy schedule", value: store.team.levySchedule),
            SettingsRow(label: "Visible to", value: store.team.visibleTo),
            SettingsRow(label: "Levy target", value: "\(Formatting.money(store.levyTarget, cents: false)) (\(store.roster.count) × $4,000)"),
        ]
    }

    var body: some View {
        PlainScrollScreen {
            HStack(spacing: 14) {
                Image("RangersCrest")
                    .resizable()
                    .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.team.name).font(Theme.serif(17)).foregroundStyle(Theme.ink)
                    Text(store.team.division).font(Theme.serif(13)).foregroundStyle(Theme.muted)
                    Text(store.team.founded).font(Theme.serif(12)).foregroundStyle(Theme.clubDarkRed).padding(.top, 1)
                }
            }
            .padding(.vertical, 12)

            Text("Expense types follow the ORHC treasurer template.")
                .font(Theme.serif(13))
                .foregroundStyle(Theme.muted)
                .padding(.bottom, 18)

            VStack(spacing: 0) {
                ForEach(settingsRows) { row in
                    HStack {
                        Text(row.label).font(Theme.serif(15)).foregroundStyle(Theme.mutedStrong)
                        Spacer()
                        Text(row.value).font(Theme.serif(15)).foregroundStyle(Theme.ink).multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 13)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
                }
            }

            Button(action: { nav.push(.cloudSync) }) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share this team").font(Theme.serif(15)).foregroundStyle(Theme.ink)
                        Text(cloudSync.isLinked ? "Synced with other devices" : "Not shared yet")
                            .font(Theme.serif(12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text("›").font(Theme.serif(17)).foregroundStyle(Theme.accent)
                }
                .padding(.vertical, 13)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }

            SheetsLinkRow()
                .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }

            HStack(alignment: .firstTextBaseline) {
                Kicker(text: "Bench staff — \(store.staff.count)")
                Spacer()
                Button("+ Add") {
                    let id = store.addStaff()
                    editing = .staff(id)
                }
                .font(Theme.serif(14))
                .foregroundStyle(Theme.accent)
            }
            .padding(.top, 28)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(store.staff) { member in
                    StaffRowView(
                        member: member,
                        isEditing: editing == .staff(member.id),
                        onToggle: { editing = (editing == .staff(member.id)) ? nil : .staff(member.id) }
                    )
                    .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Kicker(text: "Roster — \(store.roster.count) players")
                Spacer()
                Button("+ Add") {
                    let id = store.addPlayer()
                    editing = .player(id)
                }
                .font(Theme.serif(14))
                .foregroundStyle(Theme.accent)
            }
            .padding(.top, 28)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(store.roster) { player in
                    PlayerRowView(
                        player: player,
                        isEditing: editing == .player(player.id),
                        onToggle: { editing = (editing == .player(player.id)) ? nil : .player(player.id) }
                    )
                    .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
                }
            }
        }
    }
}

/// Holds the address of a Google Sheets copy of the books. The app never
/// reads or writes the sheet — the link is a pointer the treasurer keeps
/// current, opened from the Treasurer's report.
private struct SheetsLinkRow: View {
    @Environment(LedgerStore.self) private var store
    @State private var isEditing = false
    @State private var draft = ""

    private var meta: String {
        store.sheetsLink?.host() ?? "Not set — paste a link to a sheet"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google Sheets copy").font(Theme.serif(15)).foregroundStyle(Theme.ink)
                        Text(meta).font(Theme.serif(12)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    Spacer()
                    Text(isEditing ? "Close" : "Edit").font(Theme.serif(14)).foregroundStyle(Theme.accent)
                }
                .padding(.vertical, 13)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("docs.google.com/spreadsheets/…", text: $draft)
                        .font(Theme.serif(14))
                        .foregroundStyle(Theme.ink)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { saveDraft() }
                        .padding(.horizontal, 10)
                        .frame(height: 40)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.divider))

                    Text("Open the sheet in a browser and paste its address. Anyone opening it from the report needs their own access to the sheet.")
                        .font(Theme.serif(12))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(3)

                    HStack(spacing: 8) {
                        Button("Save") { saveDraft() }
                            .font(Theme.serif(14))
                            .foregroundStyle(Theme.accent700)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.accent700))

                        if !store.team.sheetsURL.isEmpty {
                            Button("Remove") { removeLink() }
                                .font(Theme.serif(14))
                                .foregroundStyle(Theme.clubDarkRed)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.clubDarkRed))
                        }
                    }
                }
                .padding(.bottom, 14)
            }
        }
    }

    private func toggle() {
        if !isEditing { draft = store.team.sheetsURL }
        isEditing.toggle()
    }

    /// Stays open on a rejected address so the bad paste is still there to fix.
    private func saveDraft() {
        if store.setSheetsURL(draft) {
            draft = store.team.sheetsURL
            isEditing = false
        }
    }

    private func removeLink() {
        store.setSheetsURL("")
        draft = ""
        isEditing = false
    }
}

private struct StaffRowView: View {
    @Environment(LedgerStore.self) private var store
    let member: StaffMember
    let isEditing: Bool
    var onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(member.name).font(Theme.serif(15)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(member.role.rawValue).font(Theme.serif(13)).foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 11)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name", text: nameBinding)
                        .font(Theme.serif(15))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 40)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.divider))

                    WrapChips() {
                        ForEach(StaffRole.allCases) { role in
                            Chip(label: role.rawValue, isSelected: member.role == role) { setRole(role) }
                        }
                    }

                    Button("Remove") { store.removeStaff(member.id) }
                        .font(Theme.serif(14))
                        .foregroundStyle(Theme.clubDarkRed)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.clubDarkRed))
                }
                .padding(.bottom, 14)
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { member.name },
            set: { newValue in
                if let i = store.staff.firstIndex(where: { $0.id == member.id }) { store.staff[i].name = newValue }
            }
        )
    }
    private func setRole(_ role: StaffRole) {
        if let i = store.staff.firstIndex(where: { $0.id == member.id }) { store.staff[i].role = role }
    }
}

private struct PlayerRowView: View {
    @Environment(LedgerStore.self) private var store
    let player: Player
    let isEditing: Bool
    var onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(player.jerseyNumber)").font(Theme.serif(14)).monospacedDigit().foregroundStyle(Theme.muted).frame(width: 34, alignment: .leading)
                    Text(player.name).font(Theme.serif(15)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(player.position.rawValue).font(Theme.serif(13)).foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        TextField("##", text: numberBinding)
                            .keyboardType(.numberPad)
                            .font(Theme.serif(15))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                            .padding(.horizontal, 10)
                            .frame(width: 60, height: 40)
                            .background(Theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.divider))

                        TextField("Player name", text: nameBinding)
                            .font(Theme.serif(15))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10)
                            .frame(height: 40)
                            .background(Theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.divider))
                    }

                    WrapChips() {
                        ForEach(Position.allCases) { pos in
                            Chip(label: pos.rawValue, isSelected: player.position == pos) { setPosition(pos) }
                        }
                    }

                    Button("Remove from roster") { store.removePlayer(player.id) }
                        .font(Theme.serif(14))
                        .foregroundStyle(Theme.clubDarkRed)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.clubDarkRed))
                }
                .padding(.bottom, 14)
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { player.name },
            set: { newValue in
                if let i = store.roster.firstIndex(where: { $0.id == player.id }) { store.roster[i].name = newValue }
            }
        )
    }
    private var numberBinding: Binding<String> {
        Binding(
            get: { player.jerseyNumber == 0 ? "" : "\(player.jerseyNumber)" },
            set: { newValue in
                if let i = store.roster.firstIndex(where: { $0.id == player.id }) {
                    store.roster[i].jerseyNumber = Int(newValue.filter(\.isNumber)) ?? 0
                }
            }
        )
    }
    private func setPosition(_ pos: Position) {
        if let i = store.roster.firstIndex(where: { $0.id == player.id }) { store.roster[i].position = pos }
    }
}
