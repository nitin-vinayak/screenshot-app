import SwiftData
import SwiftUI

@Model
class Screenshot {
    var id: String
    var imageData: Data
    var category: String
    var name: String?
    var extractedText: String
    var savedAt: Date
    
    init(imageData: Data, category: String = "Other", name: String? = nil, extractedText: String = "") {
        self.id = UUID().uuidString
        self.imageData = imageData
        self.category = category
        self.name = name
        self.extractedText = extractedText
        self.savedAt = Date()
    }
    
    var image: UIImage? {
        UIImage(data: imageData)
    }
}
