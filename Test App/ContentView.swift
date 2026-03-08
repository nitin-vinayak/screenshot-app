import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var screenshots: [Screenshot]
    @State private var showImagePicker = false
    @State private var showSearch = false

    let spacing: CGFloat = 16
    var cardWidth: CGFloat {
        let screenWidth = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.width ?? 390
        return (screenWidth - spacing * 3) / 2
    }
    var columns: [GridItem] {
        [GridItem(.fixed(cardWidth), alignment: .top),
         GridItem(.fixed(cardWidth), alignment: .top)]
    }

    var categories: [(name: String, screenshots: [Screenshot])] {
        Dictionary(grouping: screenshots, by: \.category)
            .map { (name: $0.key, screenshots: $0.value) }
            .sorted { $0.screenshots.count > $1.screenshots.count }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
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
                        LazyVGrid(columns: columns, spacing: spacing) {
                            ForEach(categories, id: \.name) { category in
                                NavigationLink(destination: CategoryView(categoryName: category.name)) {
                                    CategoryCard(name: category.name, screenshots: category.screenshots, width: cardWidth)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(spacing)
                    }
                }

                HStack {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.black)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }

                    Spacer()

                    Button {
                        showImagePicker = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.black)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Your Inspiration")
            .onAppear {
                processInbox()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    processInbox()
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker { image in
                    ScreenshotProcessor.shared.process(image: image, context: modelContext)
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
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
    let width: CGFloat

    var thumbnail: UIImage? {
        screenshots.first?.image
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                }
            }
            .frame(width: width, height: width)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text("\(screenshots.count) item\(screenshots.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
