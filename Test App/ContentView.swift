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
    @State private var searchQuery = ""
    @FocusState private var searchFocused: Bool
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

    var filteredCategories: [(name: String, screenshots: [Screenshot])] {
        guard !searchQuery.isEmpty else { return categories }
        let q = searchQuery.lowercased()
        return categories.filter { category in
            category.name.lowercased().contains(q) ||
            category.screenshots.contains {
                ($0.name?.lowercased().contains(q) ?? false) ||
                $0.tags.contains { $0.lowercased().contains(q) }
            }
        }
    }

    var filteredScreenshots: [Screenshot] {
        guard !searchQuery.isEmpty else { return [] }
        let q = searchQuery.lowercased()
        return screenshots.filter {
            ($0.name?.lowercased().contains(q) ?? false) ||
            $0.category.lowercased().contains(q) ||
            $0.tags.contains { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar — outside ScrollView to avoid gesture conflicts
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.appMuted)
                            .font(.system(size: 15))
                        TextField("Search screenshots…", text: $searchQuery)
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(Color.appText)
                            .focused($searchFocused)
                            .onSubmit { searchFocused = false }
                        if !searchQuery.isEmpty {
                            Button { searchQuery = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.appMuted)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(Color.appSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.borderSoft, lineWidth: 1.5))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, spacing)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

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
                        .padding(.top, 20)
                    } else if searchQuery.isEmpty {
                        // Normal category grid
                        LazyVGrid(columns: columns, spacing: spacing) {
                            ForEach(categories, id: \.name) { category in
                                CategoryCard(
                                    name: category.name,
                                    screenshots: category.screenshots,
                                    width: cardWidth,
                                    selectedIDs: $selectedIDs,
                                    isSelecting: isSelecting
                                )
                                .contentShape(Rectangle())
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
                    } else {
                        // Search results
                        VStack(alignment: .leading, spacing: 24) {

                            // Categories section
                            if !filteredCategories.isEmpty {
                                SearchSectionHeader(title: "Categories")
                                    .padding(.horizontal, spacing)
                                LazyVGrid(columns: columns, spacing: spacing) {
                                    ForEach(filteredCategories, id: \.name) { category in
                                        CategoryCard(
                                            name: category.name,
                                            screenshots: category.screenshots,
                                            width: cardWidth,
                                            selectedIDs: $selectedIDs,
                                            isSelecting: false
                                        )
                                        .onTapGesture {
                                            navigationPath.append(category.name)
                                        }
                                    }
                                }
                                .padding(.horizontal, spacing)
                            }

                            // Screenshots section
                            if !filteredScreenshots.isEmpty {
                                SearchSectionHeader(title: "Screenshots")
                                    .padding(.horizontal, spacing)
                                LazyVGrid(columns: columns, spacing: spacing) {
                                    ForEach(filteredScreenshots) { screenshot in
                                        SearchScreenshotCard(screenshot: screenshot, width: cardWidth)
                                            .onTapGesture {
                                                navigationPath.append(screenshot)
                                            }
                                    }
                                }
                                .padding(.horizontal, spacing)
                            }

                            // No results
                            if filteredCategories.isEmpty && filteredScreenshots.isEmpty {
                                VStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.greenLight)
                                            .frame(width: 72, height: 72)
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 28))
                                            .foregroundStyle(Color.forestGreen)
                                    }
                                    Text("No results for \"\(searchQuery)\"")
                                        .font(.system(.subheadline, design: .serif))
                                        .foregroundStyle(Color.appText)
                                    Text("Try a different name, category, or tag")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.appMuted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            }
                        }
                        .padding(.top, 8)
                    }

                    Spacer().frame(height: 100)
                }
                    .scrollDismissesKeyboard(.immediately)
                } // end VStack

                HStack {
                    if isSelecting {
                        Button {
                            isSelecting = false
                            selectedIDs.removeAll()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.forestGreen)
                                .clipShape(Circle())
                                .shadow(color: Color.forestGreen.opacity(0.35), radius: 12, x: 0, y: 4)
                        }
                        .transition(.scale.combined(with: .opacity))

                        Spacer()

                        Button {
                            deleteSelected()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.forestGreen)
                                .clipShape(Circle())
                                .shadow(color: Color.forestGreen.opacity(0.35), radius: 12, x: 0, y: 4)
                                .opacity(selectedIDs.isEmpty ? 0.4 : 1)
                        }
                        .disabled(selectedIDs.isEmpty)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Spacer()

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

// MARK: - Search Section Header

struct SearchSectionHeader: View {
    let title: String
    var body: some View {
        HStack(spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundStyle(Color.appMuted)
                .kerning(1.5)
            Rectangle()
                .fill(Color.borderSoft)
                .frame(height: 1)
        }
    }
}

// MARK: - Search Screenshot Card

struct SearchScreenshotCard: View {
    let screenshot: Screenshot
    let width: CGFloat

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Group {
                if let img = screenshot.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.greenLight
                }
            }
            .frame(width: width, height: width)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.borderSoft, lineWidth: 1.5))
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 2)

            if let name = screenshot.name {
                Text(name)
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(Color.appMuted)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Category Card

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
