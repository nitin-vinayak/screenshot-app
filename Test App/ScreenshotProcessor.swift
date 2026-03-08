import Vision
import UIKit
import SwiftData

class ScreenshotProcessor {
    
    static let shared = ScreenshotProcessor()
    
    private let apiKey: String = {
        Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
    }()
    
    func process(image: UIImage, context: ModelContext) {
        let small = resized(image)
        guard let smallCG = small.cgImage else { return }
        let text = extractText(from: smallCG)
        classify(text: text, image: image, context: context)
    }
    
    private func extractText(from cgImage: CGImage) -> String {
        var result = ""
        let semaphore = DispatchSemaphore(value: 0)
        
        let request = VNRecognizeTextRequest { req, _ in
            result = (req.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ") ?? ""
            semaphore.signal()
        }
        request.recognitionLevel = .fast
        try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        semaphore.wait()
        return result
    }
    
    private func resized(_ image: UIImage, maxDimension: CGFloat = 448) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func classify(text: String, image: UIImage, context: ModelContext) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }
        
        let smallImage = resized(image)
        
        guard let imageData = smallImage.jpegData(compressionQuality: 0.6),
              let base64Image = Optional(imageData.base64EncodedString()) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        Look at this screenshot and return a JSON object with exactly two fields:
        - "category": a short category label (1-2 words). Examples: "Jet Engines", "Sneakers", "Italian Food", "Architecture", "Typography".
        - "name": a short descriptive name for this specific screenshot (3-6 words). Examples: "Red Nike Air Max", "Pasta Carbonara Recipe", "Tokyo Street at Night".
        Return only valid JSON, nothing else. No markdown, no backticks.
        Additional text found in screenshot: \(text)
        """
        
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
            "max_tokens": 60,
            "temperature": 0
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                self?.save(image: image, category: "Other", name: nil, text: text, context: context)
                return
            }
            
            let cleaned = content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let contentData = cleaned.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any],
                  let category = parsed["category"] as? String,
                  let name = parsed["name"] as? String else {
                self?.save(image: image, category: "Other", name: nil, text: text, context: context)
                return
            }
            
            self?.save(
                image: image,
                category: category.trimmingCharacters(in: .whitespacesAndNewlines),
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                text: text,
                context: context
            )
        }.resume()
    }
    
    private func save(image: UIImage, category: String, name: String?, text: String, context: ModelContext) {
        DispatchQueue.main.async {
            guard let imageData = image.jpegData(compressionQuality: 0.9) else { return }
            let screenshot = Screenshot(imageData: imageData, category: category, name: name, extractedText: text)
            context.insert(screenshot)
            try? context.save()
        }
    }
}
