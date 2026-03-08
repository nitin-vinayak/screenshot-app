//
//  CategoryView.swift
//  Test App
//
//  Created by Nitin Vinayak on 08/03/26.
//

import SwiftUI
import SwiftData

struct CategoryView: View {
    let categoryName: String
    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    @Query private var screenshots: [Screenshot]

    init(categoryName: String) {
        self.categoryName = categoryName
        _screenshots = Query(filter: #Predicate<Screenshot> {
            $0.category == categoryName
        })
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(screenshots) { screenshot in
                    if let image = screenshot.image {
                        NavigationLink(destination: DetailView(screenshot: screenshot)) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .aspectRatio(9/16, contentMode: .fit)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
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

#Preview {
    NavigationStack {
        CategoryView(categoryName: "Music")
    }
    .modelContainer(for: Screenshot.self, inMemory: true)
}
