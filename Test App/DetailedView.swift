import SwiftUI
import SwiftData

struct DetailView: View {
    let screenshot: Screenshot
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var editableName: String = ""
    @State private var showingShareSheet = false
    @FocusState private var nameIsFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        if screenshot.name != nil {
                            TextField("Name", text: $editableName, axis: .vertical)
                                .font(.system(.title3, design: .serif).weight(.semibold))
                                .foregroundStyle(Color.appText)
                                .focused($nameIsFocused)
                                .onSubmit { saveName() }
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(spacing: 6) {
                            Text(screenshot.category)
                                .font(.system(size: 13, weight: .medium, design: .serif))
                                .foregroundStyle(Color.forestGreen)

                            Text("·")
                                .foregroundStyle(Color.appMuted)

                            Text(screenshot.savedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 13, weight: .regular, design: .serif))
                                .foregroundStyle(Color.appMuted)
                        }

                        if !screenshot.tags.isEmpty {
                            Text(screenshot.tags.joined(separator: ", "))
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(Color.appMuted)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.bottom, 16)
                    .padding(.horizontal, 4)

                    if let image = screenshot.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }

                    Spacer().frame(height: 100)
                }
                .padding(16)
            }

            HStack {
                if screenshot.image != nil {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.forestGreen)
                            .clipShape(Circle())
                            .shadow(color: Color.forestGreen.opacity(0.35), radius: 12, x: 0, y: 4)
                    }
                }

                Spacer()

                Button {
                    modelContext.delete(screenshot)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 56, height: 56)
                        .background(Color.appSurface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.borderSoft, lineWidth: 1.5))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                }
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let image = screenshot.image {
                ActivityViewController(activityItems: [image])
            }
        }
        .onAppear {
            editableName = screenshot.name ?? ""
        }
        .onChange(of: nameIsFocused) { _, focused in
            if !focused { saveName() }
        }
    }

    private func saveName() {
        let trimmed = editableName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            screenshot.name = trimmed
            try? modelContext.save()
        }
    }
}

// MARK: - Activity View Controller
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = []
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

