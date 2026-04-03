import SwiftUI

// MARK: - Collection View

struct CollectionView: View {
    @EnvironmentObject var collectionManager: CollectionManager

    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .dateAdded
    @State private var filterType: String? = nil
    @State private var showingExportSheet = false
    @State private var exportData: Data?
    @State private var isGridMode = false

    enum SortOrder: String, CaseIterable, Identifiable {
        case dateAdded   = "Date Added"
        case coinType    = "Coin Type"
        case value       = "Value"
        var id: String { rawValue }
    }

    private var allTypes: [String] {
        Array(Set(collectionManager.collection.map { $0.coinType })).sorted()
    }

    private var filteredCollection: [CollectionItem] {
        var items = collectionManager.collection

        if let type = filterType {
            items = items.filter { $0.coinType == type }
        }

        if !searchText.isEmpty {
            items = items.filter {
                $0.coinType.localizedCaseInsensitiveContains(searchText) ||
                $0.notes.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        switch sortOrder {
        case .dateAdded:
            return items.sorted { $0.dateAdded > $1.dateAdded }
        case .coinType:
            return items.sorted { $0.coinType < $1.coinType }
        case .value:
            return items.sorted { ($0.estimatedValue ?? 0) > ($1.estimatedValue ?? 0) }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                statsBar
                filterBar

                if filteredCollection.isEmpty {
                    emptyState
                } else if isGridMode {
                    gridContent
                } else {
                    listContent
                }
            }
            .navigationTitle("My Collection")
            .searchable(text: $searchText, prompt: "Search coins…")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        isGridMode.toggle()
                    } label: {
                        Image(systemName: isGridMode ? "list.bullet" : "square.grid.2x2")
                    }

                    Menu {
                        ForEach(SortOrder.allCases) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                if sortOrder == order {
                                    Label(order.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(order.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }

                    Button {
                        prepareExport()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                if let data = exportData {
                    ShareSheet(items: [data])
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Subviews

    private var statsBar: some View {
        let stats = collectionManager.collectionStatistics()
        return HStack(spacing: 0) {
            StatCell(value: "\(stats.totalCount)", label: "Coins")
            Divider().frame(height: 32)
            StatCell(value: "\(stats.favoriteCount)", label: "Favorites")
            Divider().frame(height: 32)
            StatCell(
                value: stats.estimatedTotalValue > 0
                    ? String(format: "$%.2f", stats.estimatedTotalValue)
                    : "—",
                label: "Est. Value"
            )
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: filterType == nil) {
                    filterType = nil
                }
                ForEach(allTypes, id: \.self) { type in
                    FilterChip(title: type, isSelected: filterType == type) {
                        filterType = (filterType == type) ? nil : type
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "archivebox")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text(collectionManager.collection.isEmpty
                 ? "Your collection is empty"
                 : "No matching coins")
                .font(.headline)
            Text(collectionManager.collection.isEmpty
                 ? "Scan a coin and tap \"Add to Collection\" to get started"
                 : "Try a different search or filter")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var listContent: some View {
        List {
            ForEach(filteredCollection) { item in
                CollectionRowView(item: item)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            collectionManager.removeFromCollection(item)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                ForEach(filteredCollection) { item in
                    CollectionGridCell(item: item) {
                        collectionManager.removeFromCollection(item)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Export

    private func prepareExport() {
        exportData = collectionManager.exportCollection()
        showingExportSheet = exportData != nil
    }
}

// MARK: - Collection Row

struct CollectionRowView: View {
    let item: CollectionItem

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.coinType)
                    .font(.headline)
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                Spacer()
                if let value = item.estimatedValue {
                    Text(String(format: "$%.2f", value))
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                }
            }

            HStack(spacing: 8) {
                if let year = item.year {
                    Text(String(year))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let mintMark = item.mintMark {
                    Text(mintMark)
                        .font(.caption)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                }
                if let condition = item.condition {
                    Text(condition)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(Self.formatter.string(from: item.dateAdded))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if !item.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Collection Grid Cell

struct CollectionGridCell: View {
    let item: CollectionItem
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.coinType)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                Spacer()
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }

            if let year = item.year {
                Text(String(year))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let condition = item.condition {
                Text(condition)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let value = item.estimatedValue {
                Text(String(format: "$%.2f", value))
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Remove from Collection", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add to Collection Sheet

struct AddToCollectionSheet: View {
    let scan: ScanResult
    @EnvironmentObject var collectionManager: CollectionManager
    @Environment(\.dismiss) var dismiss

    @State private var year: String = ""
    @State private var mintMark: String = ""
    @State private var estimatedValue: String = ""
    @State private var notes: String = ""
    @State private var isFavorite: Bool = false
    @State private var tagsText: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Coin Details") {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(scan.aiPrediction)
                            .foregroundColor(.secondary)
                    }
                    if let grade = scan.conditionGrade {
                        HStack {
                            Text("Condition")
                            Spacer()
                            Text(grade)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Additional Info") {
                    HStack {
                        Text("Year")
                        Spacer()
                        TextField("e.g. 1965", text: $year)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Mint Mark")
                        Spacer()
                        TextField("e.g. D, S, P", text: $mintMark)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Est. Value ($)")
                        Spacer()
                        TextField("0.00", text: $estimatedValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Notes") {
                    TextField("Add notes…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Tags (comma-separated)") {
                    TextField("e.g. silver, rare, 1800s", text: $tagsText)
                }

                Section {
                    Toggle("Mark as Favorite", isOn: $isFavorite)
                }
            }
            .navigationTitle("Add to Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addToCollection()
                        dismiss()
                    }
                }
            }
        }
    }

    private func addToCollection() {
        let parsedYear    = Int(year)
        let parsedValue   = Double(estimatedValue)
        let cleanedTags   = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let metadata = CollectionMetadata(
            year: parsedYear,
            mintMark: mintMark.isEmpty ? nil : mintMark,
            condition: scan.conditionGrade,
            estimatedValue: parsedValue,
            notes: notes,
            isFavorite: isFavorite,
            tags: cleanedTags
        )
        collectionManager.addToCollection(from: scan, metadata: metadata)
    }
}

// MARK: - Supporting Views

private struct StatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
