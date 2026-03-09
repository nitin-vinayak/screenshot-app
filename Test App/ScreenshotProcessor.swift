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

        let existingCategories: [String]
        do {
            let descriptor = FetchDescriptor<Screenshot>()
            let all = try context.fetch(descriptor)
            existingCategories = Array(Set(all.map { $0.category })).sorted()
        } catch {
            existingCategories = []
        }

        classify(text: text, image: image, existingCategories: existingCategories, context: context)
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

    private func classify(text: String, image: UIImage, existingCategories: [String], context: ModelContext) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }

        let smallImage = resized(image)

        guard let imageData = smallImage.jpegData(compressionQuality: 0.6) else { return }
        let base64Image = imageData.base64EncodedString()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let existingCategoriesLine = existingCategories.isEmpty ? "" : "Existing categories: [\(existingCategories.joined(separator: ", "))]. Reuse one only if it is an exact match for the primary subject. Otherwise create a new one.\n"

        let prompt = """
        You are an image classification engine. Look at this image and identify the single most visually prominent subject.

        \(existingCategoriesLine)Return a JSON object with exactly these fields:
        - "category": a 1-2 word noun for what the primary subject is. Base this only on what you see, not the setting, background, or any text in the image.
        - "name": a 4-6 word descriptive title of what is shown
        - "tags": 10-20 lowercase strings describing what is visibly present — species, colors, brands, materials, objects, places, people, styles. Only tag what you can see. No assumed context.

        Return only valid JSON, no markdown, no explanation.
        """

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image_url",
                        "image_url": ["url": "data:image/jpeg;base64,\(base64Image)", "detail": "low"]
                    ],
                    [
                        "type": "text",
                        "text": prompt
                    ]
                ]
            ]],
            "max_tokens": 300,
            "temperature": 0
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                self?.save(image: image, category: "Other", name: nil, text: text, tags: [], context: context)
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
                self?.save(image: image, category: "Other", name: nil, text: text, tags: [], context: context)
                return
            }

            let tags = parsed["tags"] as? [String] ?? []

            self?.save(
                image: image,
                category: category.trimmingCharacters(in: .whitespacesAndNewlines).capitalized,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines).capitalized,
                text: text,
                tags: tags,
                context: context
            )
        }.resume()
    }

    private func save(image: UIImage, category: String, name: String?, text: String, tags: [String], context: ModelContext) {
        DispatchQueue.main.async {
            guard let imageData = image.jpegData(compressionQuality: 0.9) else { return }
            let screenshot = Screenshot(imageData: imageData, category: category, name: name, extractedText: text, tags: tags)
            context.insert(screenshot)
            try? context.save()
        }
    }
}
