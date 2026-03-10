import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var screenshots: [Screenshot]
    @State private var showImagePicker = false
    @State private var showSearch = false
    @State private var selectedIDs: Set<String> = []
    @State private var isSelecting = false
    @State private var navigationPath = NavigationPath()

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
            .sorted {
                let aLatest = $0.screenshots.map(\.savedAt).max() ?? .distantPast
                let bLatest = $1.screenshots.map(\.savedAt).max() ?? .distantPast
                return aLatest > bLatest
            }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                                CategoryCard(
                                    name: category.name,
                                    screenshots: category.screenshots,
                                    width: cardWidth,
                                    selectedIDs: $selectedIDs,
                                    isSelecting: isSelecting
                                )
                                .onTapGesture {
                                    if isSelecting {
                                        let allSelected = category.screenshots.allSatisfy { selectedIDs.contains($0.id) }
                                        if allSelected {
                                            for ss in category.screenshots { selectedIDs.remove(ss.id) }
                                        } else {
                                            for ss in category.screenshots { selectedIDs.insert(ss.id) }
                                        }
                                    } else {
                                        navigationPath.append(category.name)
                                    }
                                }
                                .onLongPressGesture {
                                    isSelecting = true
                                    for ss in category.screenshots { selectedIDs.insert(ss.id) }
                                }
                            }
                        }
                        .padding(spacing)
                    }
                }

                HStack {
                    Button {
                        if isSelecting {
                            isSelecting = false
                            selectedIDs.removeAll()
                        } else {
                            showSearch = true
                        }
                    } label: {
                        Image(systemName: isSelecting ? "xmark" : "magnifyingglass")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.black)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }

                    Spacer()

                    if isSelecting {
                        Button {
                            deleteSelected()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(selectedIDs.isEmpty ? .gray : .red)
                                .frame(width: 56, height: 56)
                                .background(Color.black)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .disabled(selectedIDs.isEmpty)
                        .transition(.scale.combined(with: .opacity))
                    } else {
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
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(24)
                .animation(.spring(response: 0.3), value: isSelecting)
            }
            .navigationTitle(isSelecting ? "\(selectedIDs.count) selected" : "Your Screenshots")
            .navigationDestination(for: String.self) { categoryName in
                CategoryView(categoryName: categoryName, navigationPath: $navigationPath)
            }
            .navigationDestination(for: Screenshot.self) { screenshot in
                DetailView(screenshot: screenshot)
            }
            .onAppear { processInbox() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { processInbox() }
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

    private func deleteSelected() {
        let toDelete = screenshots.filter { selectedIDs.contains($0.id) }
        for ss in toDelete {
            modelContext.delete(ss)
        }
        try? modelContext.save()
        withAnimation(.spring(response: 0.3)) {
            selectedIDs.removeAll()
            isSelecting = false
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
    @Binding var selectedIDs: Set<String>
    let isSelecting: Bool

    var thumbnail: UIImage? { screenshots.first?.image }

    var isSelected: Bool {
        !screenshots.isEmpty && screenshots.allSatisfy { selectedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
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
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelecting && isSelected ? Color.red : Color.clear, lineWidth: 3)
                )

                if isSelecting {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.red : Color.white.opacity(0.9))
                            .frame(width: 24, height: 24)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Circle()
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
                                .frame(width: 24, height: 24)
                        }
                    }
                    .padding(8)
                }
            }

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

