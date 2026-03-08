//
//  DetailedView.swift
//  Test App
//
//  Created by Nitin Vinayak on 08/03/26.
//

import SwiftUI
import SwiftData

struct DetailView: View {
    let screenshot: Screenshot
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Full screenshot image
                if let image = screenshot.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Metadata
                VStack(alignment: .leading, spacing: 12) {
                    MetaRow(label: "Category", value: screenshot.category)
                    MetaRow(label: "Saved", value: screenshot.savedAt.formatted(date: .abbreviated, time: .shortened))
                    if !screenshot.extractedText.isEmpty {
                        MetaRow(label: "Text found", value: screenshot.extractedText)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Delete button
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

struct MetaRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
}
