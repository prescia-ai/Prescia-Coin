import Foundation
import UIKit

class ScanManager: ObservableObject {
    @Published var scans: [ScanResult] = []

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.coinscanai.storage", attributes: .concurrent)

    private var coinsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("CoinScans", isDirectory: true)
    }

    init() {
        createBaseDirectoryIfNeeded()
        loadScans()
    }

    // MARK: - Save

    func saveScan(
        original: UIImage,
        variants: [ProcessedImage],
        features: ExtractionResult,
        prediction: ClassificationResult
    ) -> ScanResult {
        let id = UUID().uuidString
        let scanDir = coinsDirectory.appendingPathComponent(id, isDirectory: true)

        try? fileManager.createDirectory(at: scanDir, withIntermediateDirectories: true)

        var imagePaths: [String: String] = [:]

        // Save original
        let originalPath = saveImage(original, named: "original.jpg", in: scanDir)
        if let p = originalPath { imagePaths[ProcessingType.original.rawValue] = p }

        // Save variants
        for variant in variants {
            if variant.type == .original { continue }
            let name = variant.type.rawValue.lowercased() + ".jpg"
            if let p = saveImage(variant.image, named: name, in: scanDir) {
                imagePaths[variant.type.rawValue] = p
            }
        }

        // Build DetectedIssues from anomaly regions
        let issues = features.anomalyRegions.map { region in
            DetectedIssue(
                type: region.type,
                confidence: region.confidence,
                rect: CodableRect(region.rect)
            )
        }

        let result = ScanResult(
            id: id,
            date: Date(),
            anomalyScore: features.anomalyScore,
            detectedIssues: issues,
            aiPrediction: prediction.label,
            aiConfidence: prediction.confidence,
            imagePaths: imagePaths
        )

        // Save metadata
        saveMetadata(result, in: scanDir)

        DispatchQueue.main.async {
            self.scans.insert(result, at: 0)
        }

        return result
    }

    // MARK: - Load

    func loadScans() {
        queue.async { [weak self] in
            guard let self = self else { return }
            var loaded: [ScanResult] = []

            guard let contents = try? self.fileManager.contentsOfDirectory(
                at: self.coinsDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            ) else {
                return
            }

            for url in contents {
                let metaURL = url.appendingPathComponent("metadata.json")
                guard let data = try? Data(contentsOf: metaURL),
                      let scan = try? JSONDecoder().decode(ScanResult.self, from: data) else { continue }
                loaded.append(scan)
            }

            loaded.sort { $0.date > $1.date }

            DispatchQueue.main.async {
                self.scans = loaded
            }
        }
    }

    // MARK: - Delete

    func deleteScan(_ scan: ScanResult) {
        let scanDir = coinsDirectory.appendingPathComponent(scan.id, isDirectory: true)
        try? fileManager.removeItem(at: scanDir)

        DispatchQueue.main.async {
            self.scans.removeAll { $0.id == scan.id }
        }
    }

    // MARK: - Image Retrieval

    func image(for scan: ScanResult, type: ProcessingType) -> UIImage? {
        guard let relativePath = scan.imagePaths[type.rawValue] else {
            // Fall back to original if specific type isn't stored
            if type != .original, let originalPath = scan.imagePaths[ProcessingType.original.rawValue] {
                return UIImage(contentsOfFile: originalPath)
            }
            return nil
        }
        return UIImage(contentsOfFile: relativePath)
    }

    // MARK: - Private Helpers

    private func createBaseDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: coinsDirectory.path) {
            try? fileManager.createDirectory(at: coinsDirectory, withIntermediateDirectories: true)
        }
    }

    @discardableResult
    private func saveImage(_ image: UIImage, named name: String, in directory: URL) -> String? {
        let url = directory.appendingPathComponent(name)
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }

    private func saveMetadata(_ scan: ScanResult, in directory: URL) {
        let url = directory.appendingPathComponent("metadata.json")
        guard let data = try? JSONEncoder().encode(scan) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
