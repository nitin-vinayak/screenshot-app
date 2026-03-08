import SwiftUI
import SwiftData

struct SearchView: View {
    @Query private var screenshots: [Screenshot]
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    var results: [Screenshot] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        return screenshots.filter {
            ($0.name?.lowercased().contains(q) ?? false) ||
            $0.category.lowercased().contains(q) ||
            $0.extractedText.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if query.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 80)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Search your screenshots")
                            .font(.headline)
                        Text("Search by name, category, or text in the screenshot")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if results.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 80)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No results for \"\(query)\"")
                            .font(.headline)
                    }
                    .padding()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(results) { screenshot in
                            NavigationLink(destination: DetailView(screenshot: screenshot)) {
                                SearchResultRow(screenshot: screenshot)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .searchable(text: $query, prompt: "Search screenshots")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SearchResultRow: View {
    let screenshot: Screenshot

    var body: some View {
        HStack(spacing: 12) {
            if let image = screenshot.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                if let name = screenshot.name {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                Text(screenshot.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(screenshot.savedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
