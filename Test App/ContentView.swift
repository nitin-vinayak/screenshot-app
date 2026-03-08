import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var screenshots: [Screenshot]
    @State private var showImagePicker = false

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var categories: [(name: String, count: Int)] {
        Dictionary(grouping: screenshots, by: \.category)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if screenshots.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 80)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No screenshots yet")
                            .font(.headline)
                        Text("Share a screenshot to this app to get started")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(categories, id: \.name) { category in
                            NavigationLink(destination: CategoryView(categoryName: category.name)) {
                                CategoryCard(name: category.name, count: category.count)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Your Inspiration")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Test") {
                        showImagePicker = true
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker { image in
                    ScreenshotProcessor.shared.process(image: image, context: modelContext)
                }
            }
        }
    }
}

struct CategoryCard: View {
    let name: String
    let count: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.secondarySystemBackground))
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    Text(name)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("\(count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
