import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Standard appearance (when scrolled — inline title)
        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        if let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline).withDesign(.serif) {
            standard.titleTextAttributes = [.font: UIFont(descriptor: descriptor, size: 17)]
        }

        // Scroll-edge appearance (at top — large title)
        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        if let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle).withDesign(.serif) {
            scrollEdge.largeTitleTextAttributes = [.font: UIFont(descriptor: descriptor, size: 34)]
        }

        UINavigationBar.appearance().standardAppearance = standard
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdge
    }
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
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    if screenshots.isEmpty {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.greenLight)
                                    .frame(width: 80, height: 80)
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.forestGreen)
                            }
                            Text("No screenshots yet")
                                .font(.system(.title3, design: .serif))
                                .foregroundStyle(Color.appText)
                            Text("Share a screenshot to this app to get started")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.appMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(48)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                .foregroundStyle(Color.borderSoft)
                        )
                        .padding()
                        .padding(.top, 40)
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
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(isSelecting ? Color.appMuted : .white)
                            .frame(width: 56, height: 56)
                            .background(isSelecting ? Color.appSurface : Color.forestGreen)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.borderSoft, lineWidth: isSelecting ? 1.5 : 0))
                            .shadow(color: isSelecting ? Color.black.opacity(0.04) : Color.forestGreen.opacity(0.35), radius: 12, x: 0, y: 4)
                    }

                    Spacer()

                    if isSelecting {
                        Button {
                            deleteSelected()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(selectedIDs.isEmpty ? Color.appMuted : .red)
                                .frame(width: 56, height: 56)
                                .background(Color.appSurface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.borderSoft, lineWidth: 1.5))
                                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
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
                                .background(Color.forestGreen)
                                .clipShape(Circle())
                                .shadow(color: Color.forestGreen.opacity(0.35), radius: 12, x: 0, y: 4)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(24)
                .animation(.spring(response: 0.3), value: isSelecting)
            }
            .navigationTitle(isSelecting ? "\(selectedIDs.count) selected" : "Your Screenshots")
            .tint(Color.forestGreen)
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
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.greenLight
                    }
                }
                .frame(width: width, height: width)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelecting && isSelected ? Color.forestGreen : Color.borderSoft,
                                lineWidth: isSelecting && isSelected ? 2 : 1.5)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 2)

                if isSelecting {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.forestGreen : Color.white.opacity(0.92))
                            .frame(width: 26, height: 26)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Circle()
                                .stroke(Color.borderSoft, lineWidth: 1.5)
                                .frame(width: 26, height: 26)
                        }
                    }
                    .padding(10)
                }
            }

            VStack(alignment: .center, spacing: 3) {
                Text(name)
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.appText)
                Text("\(screenshots.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 2)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
