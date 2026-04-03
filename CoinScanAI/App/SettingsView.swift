import SwiftUI

struct SettingsView: View {
    @AppStorage("cloudEnabled") var cloudEnabled = false
    @AppStorage("backendURL") var backendURL = "http://localhost:3000/api"
    @AppStorage("autoContribute") var autoContribute = false

    @State private var isCheckingBackend = false
    @State private var backendStatus: BackendStatus = .unknown

    enum BackendStatus {
        case unknown, reachable, unreachable
        var label: String {
            switch self {
            case .unknown:      return "Not checked"
            case .reachable:    return "Connected ✅"
            case .unreachable:  return "Unreachable ❌"
            }
        }
        var color: Color {
            switch self {
            case .unknown:      return .secondary
            case .reachable:    return .green
            case .unreachable:  return .red
            }
        }
    }

    var body: some View {
        Form {
            Section("Cloud Verification") {
                Toggle("Enable Cloud Verification", isOn: $cloudEnabled)

                if cloudEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Backend URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("http://localhost:3000/api", text: $backendURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    Toggle("Auto-contribute verified scans", isOn: $autoContribute)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Backend status")
                                .font(.subheadline)
                            Text(backendStatus.label)
                                .font(.caption)
                                .foregroundColor(backendStatus.color)
                        }
                        Spacer()
                        Button {
                            checkBackend()
                        } label: {
                            if isCheckingBackend {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Text("Test")
                            }
                        }
                        .disabled(isCheckingBackend)
                    }
                }
            }

            Section("Privacy") {
                Label("Only mathematical features are sent, never full images", systemImage: "eye.slash")
                    .font(.subheadline)
                Label("All contributions are anonymous", systemImage: "person.slash")
                    .font(.subheadline)
                Label("Location data is never collected", systemImage: "location.slash")
                    .font(.subheadline)
            }

            Section("What Gets Uploaded (if enabled)") {
                PrivacyRow(icon: "checkmark.circle.fill", color: .green, text: "Feature vectors (mathematical arrays)")
                PrivacyRow(icon: "checkmark.circle.fill", color: .green, text: "Coin type classification")
                PrivacyRow(icon: "checkmark.circle.fill", color: .green, text: "Anonymous device ID")
            }

            Section("What Is Never Uploaded") {
                PrivacyRow(icon: "xmark.circle.fill", color: .red, text: "Raw images")
                PrivacyRow(icon: "xmark.circle.fill", color: .red, text: "Personal information")
                PrivacyRow(icon: "xmark.circle.fill", color: .red, text: "Location data")
                PrivacyRow(icon: "xmark.circle.fill", color: .red, text: "User identity")
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Backend")
                    Spacer()
                    Text("Self-Hosted")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func checkBackend() {
        isCheckingBackend = true
        backendStatus = .unknown
        Task {
            let reachable = await BackendClient.shared.isBackendReachable()
            await MainActor.run {
                backendStatus = reachable ? .reachable : .unreachable
                isCheckingBackend = false
            }
        }
    }
}

private struct PrivacyRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .labelStyle(ColoredIconLabelStyle(color: color))
    }
}

private struct ColoredIconLabelStyle: LabelStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.foregroundColor(color)
            configuration.title
        }
    }
}
