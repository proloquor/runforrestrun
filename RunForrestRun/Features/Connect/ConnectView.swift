import SwiftUI

struct ConnectView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var ouraClient: OuraClient
    @EnvironmentObject private var monitor: HeartRateMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var tokenInput = ""
    @State private var isVerifying = false
    @State private var message: String?
    @State private var messageIsError = false

    @State private var ringKeyInput = ""
    @State private var ringKeySaved = Keychain.get(OuraRingHeartRateSource.keychainKey) != nil
    @State private var ringKeyError: String?

    var body: some View {
        NavigationStack {
            Form {
                sourceSection
                ringSection
                ouraSection
                if monitor.sourceKind == .oura {
                    latencyNote
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var ringSection: some View {
        Section {
            if ringKeySaved {
                Label("Ring key saved", systemImage: "key.fill")
                    .foregroundStyle(Theme.good)
                Button("Remove ring key", role: .destructive) {
                    Keychain.delete(OuraRingHeartRateSource.keychainKey)
                    ringKeySaved = false
                    ringKeyInput = ""
                    if monitor.sourceKind == .ouraRing { monitor.reloadSource() }
                }
            } else {
                SecureField("32-hex-character ring auth key", text: $ringKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                Button("Save ring key") { saveRingKey() }
                    .disabled(ringKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let ringKeyError {
                Text(ringKeyError).font(.caption).foregroundStyle(Theme.danger)
            }
            NavigationLink {
                RingDebugView()
            } label: {
                Label("Open ring debug log", systemImage: "waveform.path.ecg.rectangle")
            }
        } header: {
            Text("Oura Ring · direct (experimental)")
        } footer: {
            Text("Reads live HR straight off the ring over Bluetooth — no cloud. This uses the ring's proprietary protocol and needs its 16-byte auth key (a 32-character hex string) that the official Oura app generated when you paired. You must extract that key from the official app's local database and paste it here. ⚠️ This is against Oura's Terms of Service, can break on firmware updates, and is unverified — if it won't connect, use a Bluetooth strap instead.")
        }
    }

    private var sourceSection: some View {
        Section {
            ForEach(HeartRateSourceKind.allCases) { kind in
                Button {
                    monitor.sourceKind = kind
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.displayName).foregroundStyle(.primary)
                            Text(kind.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if monitor.sourceKind == kind {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
        } header: {
            Text("Live heart-rate source")
        } footer: {
            Text("For the 4×4 intervals, a Bluetooth strap gives instant alerts. Oura’s cloud data lags a little and is better suited to the steady Zone 2 run.")
        }
    }

    private var ouraSection: some View {
        Section {
            if ouraClient.isConnected {
                Label("Oura connected", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.good)
                Button("Sync resting HR & age from Oura") {
                    Task { await appModel.syncProfileFromOura() ; message = "Synced from Oura."; messageIsError = false }
                }
                Button("Disconnect Oura", role: .destructive) {
                    ouraClient.disconnect()
                    tokenInput = ""
                }
            } else {
                SecureField("Paste your Oura Personal Access Token", text: $tokenInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    Task { await connect() }
                } label: {
                    HStack {
                        Text("Connect Oura")
                        if isVerifying { ProgressView().padding(.leading, 6) }
                    }
                }
                .disabled(tokenInput.trimmingCharacters(in: .whitespaces).isEmpty || isVerifying)
            }
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(messageIsError ? Theme.danger : Theme.good)
            }
        } header: {
            Text("Oura account")
        } footer: {
            Text("Create a Personal Access Token at cloud.ouraring.com → Personal Access Tokens, then paste it here. It's stored securely in the Keychain and never leaves your device except to call Oura.")
        }
    }

    private var latencyNote: some View {
        Section {
            Label {
                Text("Oura live data can lag by seconds to minutes. Alerts may arrive late during hard intervals.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warning)
            }
            .font(.footnote)
        }
    }

    private func saveRingKey() {
        ringKeyError = nil
        let cleaned = ringKeyInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "0x", with: "")
        guard let data = Data(hexString: cleaned), data.count == 16 else {
            ringKeyError = "That doesn't look like a 16-byte (32 hex character) key."
            return
        }
        Keychain.set(cleaned.lowercased(), for: OuraRingHeartRateSource.keychainKey)
        ringKeySaved = true
        ringKeyInput = ""
        // If the ring is the active source, rebuild it so it picks up the new key;
        // otherwise switch to it now that we can authenticate.
        if monitor.sourceKind == .ouraRing {
            monitor.reloadSource()
        } else {
            monitor.sourceKind = .ouraRing
        }
    }

    private func connect() async {
        isVerifying = true
        message = nil
        ouraClient.saveToken(tokenInput)
        do {
            _ = try await ouraClient.verifyConnection()
            await appModel.syncProfileFromOura()
            message = "Connected! Pulled your latest resting heart rate."
            messageIsError = false
        } catch {
            ouraClient.disconnect()
            message = (error as? LocalizedError)?.errorDescription ?? "Couldn't verify that token."
            messageIsError = true
        }
        isVerifying = false
    }
}

#Preview {
    ConnectView().withPreviewEnvironment()
}
