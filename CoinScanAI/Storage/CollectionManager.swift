import Foundation

// MARK: - Collection Data Models

struct CollectionItem: Identifiable, Codable {
    let id: String
    let scanId: String
    let coinType: String
    let year: Int?
    let mintMark: String?
    let condition: String?
    let estimatedValue: Double?
    let notes: String
    let dateAdded: Date
    let isFavorite: Bool
    let tags: [String]
}

struct CollectionMetadata {
    var year: Int?
    var mintMark: String?
    var condition: String?
    var estimatedValue: Double?
    var notes: String = ""
    var isFavorite: Bool = false
    var tags: [String] = []
}

struct CollectionStats {
    let totalCount: Int
    let favoriteCount: Int
    let estimatedTotalValue: Double
    let byType: [String: Int]
}

// MARK: - Collection Manager

class CollectionManager: ObservableObject {
    @Published var collection: [CollectionItem] = []

    private let fileManager = FileManager.default

    private var collectionFileURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("collection.json")
    }

    init() {
        loadCollection()
    }

    // MARK: - CRUD

    @discardableResult
    func addToCollection(from scan: ScanResult, metadata: CollectionMetadata) -> CollectionItem {
        let item = CollectionItem(
            id: UUID().uuidString,
            scanId: scan.id,
            coinType: scan.aiPrediction,
            year: metadata.year,
            mintMark: metadata.mintMark,
            condition: metadata.condition ?? scan.conditionGrade,
            estimatedValue: metadata.estimatedValue,
            notes: metadata.notes,
            dateAdded: Date(),
            isFavorite: metadata.isFavorite,
            tags: metadata.tags
        )
        DispatchQueue.main.async {
            self.collection.insert(item, at: 0)
            self.saveCollection()
        }
        return item
    }

    func removeFromCollection(_ item: CollectionItem) {
        collection.removeAll { $0.id == item.id }
        saveCollection()
    }

    func updateItem(_ item: CollectionItem) {
        if let idx = collection.firstIndex(where: { $0.id == item.id }) {
            collection[idx] = item
            saveCollection()
        }
    }

    func isInCollection(scanId: String) -> Bool {
        collection.contains { $0.scanId == scanId }
    }

    // MARK: - Organisation

    func organizeByType() -> [String: [CollectionItem]] {
        Dictionary(grouping: collection, by: { $0.coinType })
    }

    // MARK: - Statistics

    func collectionStatistics() -> CollectionStats {
        let byType = organizeByType().mapValues { $0.count }
        let totalValue = collection.compactMap { $0.estimatedValue }.reduce(0, +)
        return CollectionStats(
            totalCount: collection.count,
            favoriteCount: collection.filter { $0.isFavorite }.count,
            estimatedTotalValue: totalValue,
            byType: byType
        )
    }

    // MARK: - Export / Import

    func exportCollection() -> Data? {
        try? JSONEncoder().encode(collection)
    }

    func importCollection(from data: Data) {
        guard let items = try? JSONDecoder().decode([CollectionItem].self, from: data) else { return }
        // Merge: add items whose IDs aren't already present
        let existingIDs = Set(collection.map { $0.id })
        let newItems = items.filter { !existingIDs.contains($0.id) }
        collection.append(contentsOf: newItems)
        collection.sort { $0.dateAdded > $1.dateAdded }
        saveCollection()
    }

    // MARK: - Persistence

    private func saveCollection() {
        guard let data = try? JSONEncoder().encode(collection) else { return }
        try? data.write(to: collectionFileURL, options: .atomic)
    }

    private func loadCollection() {
        guard let data = try? Data(contentsOf: collectionFileURL),
              let items = try? JSONDecoder().decode([CollectionItem].self, from: data) else { return }
        collection = items
    }
}
