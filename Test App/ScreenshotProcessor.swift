import Vision
import UIKit
import SwiftData

class ScreenshotProcessor {
    
    static let shared = ScreenshotProcessor()
    
    private let apiKey: String = {
        Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
    }()
    
    func process(image: UIImage, context: ModelContext) {
        guard let cgImage = image.cgImage else { return }
        
        let ocrRequest = VNRecognizeTextRequest { [weak self] request, _ in
            let text = (request.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ") ?? ""
            
            self?.classify(text: text, image: image, context: context)
        }
        ocrRequest.recognitionLevel = .accurate
        try? VNImageRequestHandler(cgImage: cgImage).perform([ocrRequest])
    }
    
    private func classify(text: String, image: UIImage, context: ModelContext) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        Look at this screenshot and return a single short category label (1-2 words max).
        Be specific but concise. Examples: "Jet Engines", "Sneakers", "Italian Food", "Architecture", "Typography".
        Only return the category label, nothing else.
        Additional text found in screenshot: \(text)
        """
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.5),
              let base64Image = Optional(imageData.base64EncodedString()) else { return }
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image_url",
                        "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
                    ],
                    [
                        "type": "text",
                        "text": prompt
                    ]
                ]
            ]],
            "max_tokens": 10,
            "temperature": 0
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let category = message["content"] as? String else {
                self?.save(image: image, category: "Other", text: text, context: context)
                return
            }
            
            self?.save(image: image, category: category.trimmingCharacters(in: .whitespacesAndNewlines), text: text, context: context)
        }.resume()
    }
    
    private func save(image: UIImage, category: String, text: String, context: ModelContext) {
        DispatchQueue.main.async {
            guard let imageData = image.jpegData(compressionQuality: 0.9) else { return }
            let screenshot = Screenshot(imageData: imageData, category: category, extractedText: text)
            context.insert(screenshot)
            try? context.save()
        }
    }
}
