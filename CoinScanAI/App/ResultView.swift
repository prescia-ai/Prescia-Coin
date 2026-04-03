import SwiftUI

struct ResultView: View {
    let scan: ScanResult
    let scanManager: ScanManager

    @State private var selectedTab: ProcessingType = .original

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

                // Anomaly Score Card
                GroupBox {
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
                }
                .padding(.horizontal)

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
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("Scan Result")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func confidenceColor(_ c: Float) -> Color {
        c > 0.7 ? .green : c > 0.4 ? .orange : .red
    }

    private func anomalyColor(_ s: Float) -> Color {
        s < 0.3 ? .green : s < 0.6 ? .orange : .red
    }
}
