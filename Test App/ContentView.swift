import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var screenshots: [Screenshot]
    @State private var showImagePicker = false

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var categories: [(name: String, screenshots: [Screenshot])] {
        Dictionary(grouping: screenshots, by: \.category)
            .map { (name: $0.key, screenshots: $0.value) }
            .sorted { $0.screenshots.count > $1.screenshots.count }
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
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(categories, id: \.name) { category in
                            NavigationLink(destination: CategoryView(categoryName: category.name)) {
                                CategoryCard(name: category.name, screenshots: category.screenshots)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Your Inspiration")
            .onAppear {
                processInbox()
            }
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

    private func processInbox() {
        guard let inboxURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.nitinvinayak.screenshotapp")?
            .appendingPathComponent("Inbox") else { return }

        let files = (try? FileManager.default.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: nil
        )) ?? []

        for fileURL in files {
            if let image = UIImage(contentsOfFile: fileURL.path) {
                ScreenshotProcessor.shared.process(image: image, context: modelContext)
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}

struct CategoryCard: View {
    let name: String
    let screenshots: [Screenshot]

    var thumbs: [UIImage] {
        screenshots.prefix(3).compactMap { $0.image }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if thumbs.count >= 3, let img = thumbs[safe: 2] {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3/4, contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .rotationEffect(.degrees(-6))
                        .offset(x: -8, y: 4)
                        .opacity(0.7)
                }

                if thumbs.count >= 2, let img = thumbs[safe: 1] {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3/4, contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .rotationEffect(.degrees(-3))
                        .offset(x: -4, y: 2)
                        .opacity(0.85)
                }

                if let img = thumbs[safe: 0] {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3/4, contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                        .aspectRatio(3/4, contentMode: .fit)
                }
            }
            .padding(.horizontal, 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text("\(screenshots.count) item\(screenshots.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding(.bottom, 8)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
