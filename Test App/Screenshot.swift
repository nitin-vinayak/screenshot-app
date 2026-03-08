//
//  Screenshot.swift
//  Test App
//
//  Created by Nitin Vinayak on 08/03/26.
//

import SwiftData
import SwiftUI

@Model
class Screenshot{
    var id: String
    var imageData: Data
    var category: String
    var extractedText: String
    var savedAt: Date
    
    init(imageData: Data, category: String = "Other", extractedText: String = ""){
        self.id = UUID().uuidString
        self.imageData = imageData
        self.category = category
        self.extractedText = extractedText
        self.savedAt = Date()
    }
    
    var image: UIImage? {
        UIImage(data: imageData)
    }
}
