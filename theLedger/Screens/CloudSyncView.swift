import SwiftUI

struct CloudSyncView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(CloudSyncService.self) private var cloudSync

    @State private var joinCodeInput = ""
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var confirmingPull = false
    @State private var confirmingJoin = false
    @State private var confirmingUnlink = false

    var body: some View {
        PlainScrollScreen {
            if cloudSync.isLinked {
                linkedContent
            } else {
                unlinkedContent
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.serif(13))
                    .foregroundStyle(Theme.clubDarkRed)
                    .padding(.top, 16)
            }
        }
        .confirmationDialog(
            "Pull the latest from the cloud? This replaces everything on this device with what's shared, including anything you haven't pushed yet.",
            isPresented: $confirmingPull, titleVisibility: .visible
        ) {
            Button("Pull and replace", role: .destructive) { pull() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Joining replaces everything on this device with the shared team's data. This device's current data will be lost unless you've already shared it.",
            isPresented: $confirmingJoin, titleVisibility: .visible
        ) {
            Button("Join and replace", role: .destructive) { join() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Stop sharing? This device keeps its own copy of the data, but stops syncing with the others.",
            isPresented: $confirmingUnlink, titleVisibility: .visible
        ) {
            Button("Stop sharing", role: .destructive) { cloudSync.unlink() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Not yet linked

    private var unlinkedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: "Share this team")
                .padding(.top, 14)
            Text("Share the books with a manager or coach: create a shared copy, or join one someone else already started.")
                .font(Theme.serif(14))
                .foregroundStyle(Theme.mutedSoft)
                .lineSpacing(3)
                .padding(.top, 8)
                .padding(.bottom, 24)

            Kicker(text: "Start sharing")
                .padding(.bottom, 8)
            Text("Puts this device's current data in the cloud under a new code, ready for others to join.")
                .font(Theme.serif(13))
                .foregroundStyle(Theme.muted)
                .padding(.bottom, 10)
            primaryButton(isBusy ? "Creating…" : "Create a shared team", disabled: isBusy) { create() }

            Kicker(text: "Join a team")
                .padding(.top, 28)
                .padding(.bottom, 8)
            Text("Enter the code someone shared with you. Replaces this device's data with theirs.")
                .font(Theme.serif(13))
                .foregroundStyle(Theme.muted)
                .padding(.bottom, 10)
            TextField("e.g. AB3D9F2K", text: $joinCodeInput)
                .font(Theme.serif(16))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .frame(height: 46)
                .background(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.sharpCorner).strokeBorder(Theme.divider))
                .clipShape(RoundedRectangle(cornerRadius: Theme.sharpCorner))
            secondaryButton(isBusy ? "Joining…" : "Join", disabled: isBusy || joinCodeInput.trimmingCharacters(in: .whitespaces).isEmpty) {
                confirmingJoin = true
            }
            .padding(.top, 10)
        }
    }

    // MARK: - Linked

    private var linkedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: "This team's code")
                .padding(.top, 14)
            Text(store.team.joinCode)
                .font(Theme.serif(34, weight: .semibold))
                .tracking(2)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .padding(.top, 6)
            Text("Give this to a manager or coach — they enter it under \u{201C}Join a team\u{201D} to see and edit the same data.")
                .font(Theme.serif(14))
                .foregroundStyle(Theme.mutedSoft)
                .lineSpacing(3)
                .padding(.top, 8)

            if let lastSyncedAt = cloudSync.lastSyncedAt {
                Text("Last synced \(Formatting.shortDate(lastSyncedAt)) at \(lastSyncedAt.formatted(date: .omitted, time: .shortened))")
                    .font(Theme.serif(12))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 12)
            }

            primaryButton(isBusy ? "Pushing…" : "Push my changes", disabled: isBusy) { push() }
                .padding(.top, 20)
            Text("Uploads this device's data, overwriting the shared copy.")
                .font(Theme.serif(12))
                .foregroundStyle(Theme.muted)
                .padding(.top, 6)

            secondaryButton(isBusy ? "Pulling…" : "Pull latest", disabled: isBusy) { confirmingPull = true }
                .padding(.top, 16)
            Text("Downloads the shared copy, overwriting this device's data.")
                .font(Theme.serif(12))
                .foregroundStyle(Theme.muted)
                .padding(.top, 6)

            Button("Stop sharing") { confirmingUnlink = true }
                .font(Theme.serif(14))
                .foregroundStyle(Theme.clubDarkRed)
                .padding(.top, 28)
        }
    }

    // MARK: - Actions

    private func create() {
        errorMessage = nil
        isBusy = true
        Task {
            do {
                try await cloudSync.createTeam(joinCode: store.team.joinCode, snapshot: store.exportSnapshot())
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func join() {
        errorMessage = nil
        isBusy = true
        let code = joinCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        Task {
            do {
                let snapshot = try await cloudSync.joinTeam(joinCode: code)
                store.importSnapshot(snapshot)
                joinCodeInput = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func push() {
        errorMessage = nil
        isBusy = true
        Task {
            do {
                try await cloudSync.push(store.exportSnapshot())
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func pull() {
        errorMessage = nil
        isBusy = true
        Task {
            do {
                let snapshot = try await cloudSync.pull()
                store.importSnapshot(snapshot)
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func primaryButton(_ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(PrimaryButtonStyle())
            .disabled(disabled)
            .opacity(disabled ? 0.5 : 1)
    }

    private func secondaryButton(_ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(SecondaryButtonStyle())
            .disabled(disabled)
            .opacity(disabled ? 0.5 : 1)
    }
}
