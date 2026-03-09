import SwiftData
import UIKit

@Model
class Screenshot {
    var id: String
    var imageData: Data
    var category: String
    var name: String?
    var tags: [String] = []
    var savedAt: Date

    var image: UIImage? { UIImage(data: imageData) }

    init(imageData: Data, category: String, name: String?, tags: [String]) {
        self.id = UUID().uuidString
        self.imageData = imageData
        self.category = category
        self.name = name
        self.tags = tags
        self.savedAt = Date()
    }
}
