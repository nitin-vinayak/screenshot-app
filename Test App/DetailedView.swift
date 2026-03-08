import SwiftUI
import SwiftData

struct DetailView: View {
    let screenshot: Screenshot
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var editableName: String = ""
    @FocusState private var nameIsFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        if screenshot.name != nil {
                            TextField("Name", text: $editableName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .focused($nameIsFocused)
                                .onSubmit { saveName() }
                        }

                        HStack(spacing: 6) {
                            Text(screenshot.category)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("·")
                                .foregroundStyle(.secondary)

                            Text(screenshot.savedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 16)
                    .padding(.horizontal, 4)

                    if let image = screenshot.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Spacer().frame(height: 100)
                }
                .padding(16)
            }

            HStack {
                Spacer()
                Button {
                    modelContext.delete(screenshot)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 56, height: 56)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
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

