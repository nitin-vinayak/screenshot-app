import SwiftUI
import SwiftData

struct CategoryView: View {
    let categoryName: String

    @Query private var screenshots: [Screenshot]

    init(categoryName: String) {
        self.categoryName = categoryName
        _screenshots = Query(filter: #Predicate<Screenshot> {
            $0.category == categoryName
        })
    }

    var leftColumn: [Screenshot] {
        screenshots.indices.filter { $0 % 2 == 0 }.map { screenshots[$0] }
    }

    var rightColumn: [Screenshot] {
        screenshots.indices.filter { $0 % 2 != 0 }.map { screenshots[$0] }
    }

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 12) {
                    ForEach(leftColumn) { screenshot in
                        NavigationLink(destination: DetailView(screenshot: screenshot)) {
                            ScreenshotCard(screenshot: screenshot)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(spacing: 12) {
                    ForEach(rightColumn) { screenshot in
                        NavigationLink(destination: DetailView(screenshot: screenshot)) {
                            ScreenshotCard(screenshot: screenshot)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct ScreenshotCard: View {
    let screenshot: Screenshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = screenshot.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if let name = screenshot.name {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryView(categoryName: "Music")
    }
    .modelContainer(for: Screenshot.self, inMemory: true)
}
