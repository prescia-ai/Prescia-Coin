import SwiftUI

struct ContentView: View {
    @StateObject private var scanManager = ScanManager()
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var showCamera = false
    @State private var selectedScan: ScanResult?
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            scannerTab
                .tabItem {
                    Label("Scanner", systemImage: "camera.fill")
                }
                .tag(0)

            CollectionView()
                .tabItem {
                    Label("My Collection", systemImage: "archivebox.fill")
                }
                .tag(1)

            NavigationView {
                SettingsView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(2)
        }
    }

    // MARK: - Scanner Tab

    private var scannerTab: some View {
        NavigationView {
            List {
                Section {
                    Button(action: { showCamera = true }) {
                        Label("Scan Coin", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Previous Scans") {
                    if scanManager.scans.isEmpty {
                        Text("No scans yet. Tap 'Scan Coin' to get started.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(scanManager.scans) { scan in
                            NavigationLink(
                                destination: ResultView(scan: scan, scanManager: scanManager)
                            ) {
                                ScanRowView(scan: scan)
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { scanManager.deleteScan(scanManager.scans[$0]) }
                        }
                    }
                }
            }
            .navigationTitle("CoinScan AI")
            .toolbar {
                EditButton()
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    showCamera = false
                    guard let image = image else { return }
                    processCapturedImage(image)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func processCapturedImage(_ image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            let detector = CoinDetector()
            let coinImage = detector.detectCoin(in: image) ?? image

            let processor = ImageProcessor()
            let variants = processor.generateAllVariants(image: coinImage)

            let extractor = FeatureExtractor()
            let anomalyDetector = AnomalyDetector()
            let hybridResult = extractor.extractWithAI(from: coinImage, anomalyDetector: anomalyDetector)

            let runner = ModelRunner()
            let enhancedPrediction = runner.classifyEnhanced(image: coinImage)

            DispatchQueue.main.async {
                _ = scanManager.saveScan(
                    original: coinImage,
                    variants: variants,
                    hybridResult: hybridResult,
                    enhancedPrediction: enhancedPrediction,
                    features: hybridResult.traditionalResult,
                    prediction: enhancedPrediction.coinType
                )
            }
        }
    }
}

struct ScanRowView: View {
    let scan: ScanResult

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scan.aiPrediction)
                .font(.headline)
            HStack {
                Text(Self.dateFormatter.string(from: scan.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                AnomalyBadge(score: scan.anomalyScore)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AnomalyBadge: View {
    let score: Float

    private var color: Color {
        switch score {
        case ..<0.3: return .green
        case 0.3..<0.6: return .orange
        default: return .red
        }
    }

    var body: some View {
        Text(String(format: "%.0f%%", score * 100))
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}
