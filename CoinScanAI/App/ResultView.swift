import SwiftUI

struct ResultView: View {
    let scan: ScanResult
    let scanManager: ScanManager

    @EnvironmentObject var collectionManager: CollectionManager
    @AppStorage("cloudEnabled") private var cloudEnabled = false
    @AppStorage("autoContribute") private var autoContribute = false

    @State private var selectedTab: ProcessingType = .original
    @State private var showingAddToCollection = false
    @State private var cloudVerification: VerificationResult?
    @State private var isVerifying = false
    @State private var isBackendOnline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Image Tab View
                VStack(spacing: 0) {
                    Picker("View", selection: $selectedTab) {
                        ForEach(ProcessingType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top)

                    ZStack {
                        if let img = scanManager.image(for: scan, type: selectedTab) {
                            GeometryReader { geo in
                                ZStack {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: geo.size.width, height: geo.size.width)

                                    // Overlay anomaly regions
                                    ForEach(scan.detectedIssues.indices, id: \.self) { idx in
                                        let issue = scan.detectedIssues[idx]
                                        let rect = issue.rect.cgRect
                                        let scaleX = geo.size.width / 224.0
                                        let scaleY = geo.size.width / 224.0

                                        Rectangle()
                                            .stroke(Color.red, lineWidth: 2)
                                            .frame(
                                                width: rect.width * scaleX,
                                                height: rect.height * scaleY
                                            )
                                            .offset(
                                                x: (rect.minX * scaleX) - geo.size.width / 2 + rect.width * scaleX / 2,
                                                y: (rect.minY * scaleY) - geo.size.width / 2 + rect.height * scaleY / 2
                                            )
                                    }
                                }
                            }
                            .frame(height: UIScreen.main.bounds.width)
                        } else {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: UIScreen.main.bounds.width)
                                .overlay(
                                    Text("Image unavailable")
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                }

                // AI Prediction Card
                GroupBox {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Prediction")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(scan.aiPrediction)
                                .font(.title3.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Confidence")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", scan.aiConfidence * 100))
                                .font(.title3.bold())
                                .foregroundColor(confidenceColor(scan.aiConfidence))
                        }
                    }
                }
                .padding(.horizontal)

                // Cloud Verification Card (shown when enabled)
                if cloudEnabled {
                    cloudVerificationCard
                }

                // Anomaly Status Card
                GroupBox {
                    VStack(spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Anomaly Score")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ProgressView(value: Double(scan.anomalyScore))
                                    .tint(anomalyColor(scan.anomalyScore))
                            }
                            Spacer()
                            Text(String(format: "%.0f%%", scan.anomalyScore * 100))
                                .font(.title3.bold())
                                .foregroundColor(anomalyColor(scan.anomalyScore))
                        }

                        // Anomaly type badge (shown when AI detection is available)
                        if let anomalyType = scan.anomalyType, anomalyType != "normal" {
                            Divider()
                            HStack {
                                Image(systemName: anomalyTypeIcon(anomalyType))
                                    .foregroundColor(anomalyTypeColor(anomalyType))
                                Text(anomalyTypeLabel(anomalyType))
                                    .font(.subheadline.bold())
                                    .foregroundColor(anomalyTypeColor(anomalyType))
                                Spacer()
                                if let severity = scan.anomalySeverity {
                                    Text("Severity: \(String(format: "%.0f%%", severity * 100))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Detection method tag
                        if let method = scan.detectionMethod {
                            HStack {
                                Spacer()
                                Text("Detection: \(method.capitalized)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.10))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Condition Grade Card (shown when AI grading is available)
                if let grade = scan.conditionGrade {
                    GroupBox {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Condition Grade")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 6) {
                                    Text(conditionIcon(grade))
                                    Text(grade)
                                        .font(.title3.bold())
                                }
                            }
                            Spacer()
                            if let score = scan.conditionScore {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Score")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.0f / 100", score))
                                        .font(.title3.bold())
                                        .foregroundColor(conditionColor(score))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Detected Issues
                if !scan.detectedIssues.isEmpty {
                    GroupBox("Detected Issues") {
                        ForEach(scan.detectedIssues.indices, id: \.self) { idx in
                            let issue = scan.detectedIssues[idx]
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(issue.type)
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.0f%%", issue.confidence * 100))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.orange)
                            }
                            .padding(.vertical, 2)

                            if idx < scan.detectedIssues.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    GroupBox("Detected Issues") {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("No anomalies detected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }

                // Add to Collection Button
                addToCollectionButton
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("Scan Result")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddToCollection) {
            AddToCollectionSheet(scan: scan)
                .environmentObject(collectionManager)
        }
        .task {
            if cloudEnabled {
                await runCloudVerification()
            }
        }
    }

    // MARK: - Cloud Verification Card

    @ViewBuilder
    private var cloudVerificationCard: some View {
        GroupBox {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "cloud.fill")
                        .foregroundColor(.blue)
                    Text("Cloud Verification")
                        .font(.subheadline.bold())
                    Spacer()
                    if isVerifying {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else if !isBackendOnline {
                        Text("Offline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(6)
                    }
                }

                if let result = cloudVerification {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(verificationStatusLabel(result.status))
                                .font(.subheadline.bold())
                                .foregroundColor(verificationStatusColor(result.status))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Matches")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(result.matchCount)")
                                .font(.subheadline.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Confidence")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.0f%%", result.confidence * 100))
                                .font(.subheadline.bold())
                        }
                    }
                } else if !isVerifying && isBackendOnline {
                    Text("Verification unavailable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Add to Collection Button

    private var addToCollectionButton: some View {
        let alreadyAdded = collectionManager.isInCollection(scanId: scan.id)
        return Button {
            if !alreadyAdded {
                showingAddToCollection = true
            }
        } label: {
            Label(
                alreadyAdded ? "Added to Collection" : "Add to Collection",
                systemImage: alreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill"
            )
            .frame(maxWidth: .infinity)
            .padding()
            .background(alreadyAdded ? Color.green.opacity(0.15) : Color.accentColor)
            .foregroundColor(alreadyAdded ? .green : .white)
            .cornerRadius(12)
        }
        .disabled(alreadyAdded)
    }

    // MARK: - Cloud Verification

    private func runCloudVerification() async {
        isVerifying = true
        let client = BackendClient.shared
        let reachable = await client.isBackendReachable()
        isBackendOnline = reachable

        if reachable {
            let extractor = CloudFeatureExtractor()
            if let img = scanManager.image(for: scan, type: .original) {
                let features = extractor.extractCloudFeatures(from: img)
                let result = await client.verifyCoins(features: features, coinType: scan.aiPrediction)
                cloudVerification = result

                if autoContribute, result != nil {
                    let isVerified = scanManager.isCollectionCandidate(scan)
                    await client.contribute(
                        features: features,
                        coinType: scan.aiPrediction,
                        verified: isVerified
                    )
                }
            }
        }
        isVerifying = false
    }

    // MARK: - Helpers

    private func confidenceColor(_ c: Float) -> Color {
        c > 0.7 ? .green : c > 0.4 ? .orange : .red
    }

    private func anomalyColor(_ s: Float) -> Color {
        s < 0.3 ? .green : s < 0.6 ? .orange : .red
    }

    private func conditionColor(_ score: Float) -> Color {
        score > 70 ? .green : score > 40 ? .orange : .red
    }

    private func anomalyTypeIcon(_ type: String) -> String {
        switch type {
        case "counterfeit":        return "xmark.shield.fill"
        case "manufacturing_error": return "exclamationmark.triangle.fill"
        case "damage":             return "heart.slash.fill"
        case "wear":               return "clock.fill"
        case "alteration":         return "wand.and.stars"
        default:                   return "checkmark.circle.fill"
        }
    }

    private func anomalyTypeColor(_ type: String) -> Color {
        switch type {
        case "counterfeit":         return .red
        case "manufacturing_error": return .orange
        case "damage":              return .pink
        case "wear":                return .secondary
        case "alteration":          return .purple
        default:                    return .green
        }
    }

    private func anomalyTypeLabel(_ type: String) -> String {
        switch type {
        case "counterfeit":         return "🚫 Possible Counterfeit"
        case "manufacturing_error": return "⚠️ Manufacturing Error"
        case "damage":              return "💔 Damage Detected"
        case "wear":                return "🕐 Normal Wear"
        case "alteration":          return "✏️ Possible Alteration"
        default:                    return "✅ Normal"
        }
    }

    private func conditionIcon(_ grade: String) -> String {
        switch grade {
        case "Uncirculated":        return "⭐"
        case "About Uncirculated":  return "✨"
        case "Extremely Fine",
             "Very Fine":           return "💎"
        case "Fine", "Very Good":   return "🟢"
        case "Good", "Fair":        return "🟡"
        default:                    return "🔴"
        }
    }

    private func verificationStatusLabel(_ status: String) -> String {
        switch status {
        case "verified":   return "✅ Verified"
        case "suspicious": return "⚠️ Suspicious"
        default:           return "❓ Unknown"
        }
    }

    private func verificationStatusColor(_ status: String) -> Color {
        switch status {
        case "verified":   return .green
        case "suspicious": return .orange
        default:           return .secondary
        }
    }
}

