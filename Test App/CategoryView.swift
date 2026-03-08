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
                        if let image = screenshot.image {
                            NavigationLink(destination: DetailView(screenshot: screenshot)) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(spacing: 12) {
                    ForEach(rightColumn) { screenshot in
                        if let image = screenshot.image {
                            NavigationLink(destination: DetailView(screenshot: screenshot)) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        CategoryView(categoryName: "Music")
    }
    .modelContainer(for: Screenshot.self, inMemory: true)
}
