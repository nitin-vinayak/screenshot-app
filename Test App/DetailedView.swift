import SwiftUI
import SwiftData

struct DetailView: View {
    let screenshot: Screenshot
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let image = screenshot.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let name = screenshot.name {
                        Text(name)
                            .font(.title3)
                            .fontWeight(.semibold)
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
                .padding(.top, 16)
                .padding(.horizontal, 4)

                Divider()
                    .padding(.vertical, 20)

                Button(role: .destructive) {
                    modelContext.delete(screenshot)
                    dismiss()
                } label: {
                    Text("Delete")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(16)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
