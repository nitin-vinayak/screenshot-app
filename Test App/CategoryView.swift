import SwiftUI
import SwiftData

struct CategoryView: View {
    let categoryName: String
    @Binding var navigationPath: NavigationPath

    @Environment(\.modelContext) private var modelContext
    @Query private var screenshots: [Screenshot]
    @State private var selectedIDs: Set<String> = []
    @State private var isSelecting = false

    init(categoryName: String, navigationPath: Binding<NavigationPath>) {
        self.categoryName = categoryName
        self._navigationPath = navigationPath
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
        ZStack(alignment: .bottom) {
            ScrollView {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 12) {
                        ForEach(leftColumn) { screenshot in
                            ScreenshotCard(screenshot: screenshot, selectedIDs: $selectedIDs, isSelecting: isSelecting)
                                .onTapGesture {
                                    if isSelecting {
                                        if selectedIDs.contains(screenshot.id) {
                                            selectedIDs.remove(screenshot.id)
                                        } else {
                                            selectedIDs.insert(screenshot.id)
                                        }
                                    } else {
                                        navigationPath.append(screenshot)
                                    }
                                }
                                .onLongPressGesture {
                                    isSelecting = true
                                    selectedIDs.insert(screenshot.id)
                                }
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(rightColumn) { screenshot in
                            ScreenshotCard(screenshot: screenshot, selectedIDs: $selectedIDs, isSelecting: isSelecting)
                                .onTapGesture {
                                    if isSelecting {
                                        if selectedIDs.contains(screenshot.id) {
                                            selectedIDs.remove(screenshot.id)
                                        } else {
                                            selectedIDs.insert(screenshot.id)
                                        }
                                    } else {
                                        navigationPath.append(screenshot)
                                    }
                                }
                                .onLongPressGesture {
                                    isSelecting = true
                                    selectedIDs.insert(screenshot.id)
                                }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 80)
            }

            HStack {
                Button {
                    isSelecting = false
                    selectedIDs.removeAll()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.black)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }

                Spacer()

                Button {
                    deleteSelected()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(selectedIDs.isEmpty ? .gray : .red)
                        .frame(width: 56, height: 56)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .disabled(selectedIDs.isEmpty)
            }
            .padding(24)
            .opacity(isSelecting ? 1 : 0)
            .animation(.spring(response: 0.3), value: isSelecting)
        }
        .navigationTitle(isSelecting ? "\(selectedIDs.count) selected" : categoryName)
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: screenshots.count) { _, count in
            if count == 0 {
                navigationPath = NavigationPath()
            }
        }
    }

    private func deleteSelected() {
        let toDelete = screenshots.filter { selectedIDs.contains($0.id) }
        for ss in toDelete {
            modelContext.delete(ss)
        }
        try? modelContext.save()
        selectedIDs.removeAll()
        isSelecting = false
    }
}

struct ScreenshotCard: View {
    let screenshot: Screenshot
    @Binding var selectedIDs: Set<String>
    let isSelecting: Bool

    var isSelected: Bool { selectedIDs.contains(screenshot.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = screenshot.image {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
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
        CategoryView(categoryName: "Music", navigationPath: .constant(NavigationPath()))
    }
    .modelContainer(for: Screenshot.self, inMemory: true)
}

