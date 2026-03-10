import Vision
import UIKit
import SwiftData

class ScreenshotProcessor {

    static let shared = ScreenshotProcessor()

    private let apiKey: String = {
        Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
    }()

    func process(image: UIImage, context: ModelContext) {
        let existingScreenshots: [Screenshot]
        do {
            let descriptor = FetchDescriptor<Screenshot>()
            existingScreenshots = try context.fetch(descriptor)
        } catch {
            existingScreenshots = []
        }

        let existingCategories = Array(Set(existingScreenshots.map { $0.category })).sorted()

        Task {
            guard let (category, name, summary) = await classify(image: image, existingCategories: existingCategories) else {
                await MainActor.run { self.save(image: image, category: "Other", name: nil, summary: "", embedding: [], context: context) }
                return
            }

            let embedding = await generateEmbedding(for: summary) ?? []

            let resolvedCategory = embedding.isEmpty
                ? category
                : resolveCategory(suggested: category, embedding: embedding, existingScreenshots: existingScreenshots)

            await MainActor.run { self.save(image: image, category: resolvedCategory, name: name, summary: summary, embedding: embedding, context: context) }
        }
    }

    func generateEmbedding(for text: String) async -> [Float]? {
        guard let url = URL(string: "https://api.openai.com/v1/embeddings") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "text-embedding-3-small",
            "input": text
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let embeddingArray = dataArray.first?["embedding"] as? [Double] else {
            return nil
        }

        return embeddingArray.map { Float($0) }
    }

    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = zip(a, b).map(*).reduce(0, +)
        let magA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }

    static func averageEmbedding(_ embeddings: [[Float]]) -> [Float] {
        guard !embeddings.isEmpty, let first = embeddings.first else { return [] }
        var sum = [Float](repeating: 0, count: first.count)
        for embedding in embeddings {
            for (i, v) in embedding.enumerated() { sum[i] += v }
        }
        let count = Float(embeddings.count)
        return sum.map { $0 / count }
    }

    private func resolveCategory(suggested: String, embedding: [Float], existingScreenshots: [Screenshot]) -> String {
        let byCategory = Dictionary(grouping: existingScreenshots.filter { !$0.embedding.isEmpty }, by: \.category)

        var bestCategory: String? = nil
        var bestSimilarity: Float = 0.60

        for (categoryName, screenshots) in byCategory {
            let avg = ScreenshotProcessor.averageEmbedding(screenshots.map { $0.embedding })
            let similarity = ScreenshotProcessor.cosineSimilarity(embedding, avg)
            if similarity > bestSimilarity {
                bestSimilarity = similarity
                bestCategory = categoryName
            }
        }

        return bestCategory ?? suggested
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

    private func classify(image: UIImage, existingCategories: [String]) async -> (category: String, name: String, summary: String)? {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return nil }

        let smallImage = resized(image)
        guard let imageData = smallImage.jpegData(compressionQuality: 0.6) else { return nil }
        let base64Image = imageData.base64EncodedString()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let existingCategoriesLine = existingCategories.isEmpty ? "" : "Existing categories: [\(existingCategories.joined(separator: ", "))]. Reuse one only if it is an exact match for the primary subject. Otherwise create a new one.\n"

        let prompt = """
        You are a screenshot classification engine for a personal screenshot organizer.

        Classify by what the user most likely saved this screenshot for — their intent and the primary subject they captured. Ask yourself: "what would this person label this screenshot as?"

        Ignore incidental visual elements that aren't the main subject — a sofa in album artwork, a background on a webpage, decorative UI. But if a sofa is being sold on a shopping page, the sofa IS the subject. A conversation screenshot is "Chats" unless the message content is clearly about something more specific.

        \(existingCategoriesLine)Return a JSON object with exactly these fields:
        - "category": a 1-2 word noun for the primary subject
        - "name": a 4-6 word descriptive title of what is shown
        - "summary": two parts separated by a newline. First line: a rich, detailed description of everything in the image — all visible objects, people, text, colors, and setting. For any proper noun (person, brand, landmark, city, country, book, song, product, organisation) name it explicitly with context (e.g. landmark → include city and country). Second line: 10 generic comma-separated lowercase tags covering the key subjects, objects, and themes.

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

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return nil
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
            return nil
        }

        let summary = (parsed["summary"] as? String) ?? ""

        return (
            category: category.trimmingCharacters(in: .whitespacesAndNewlines).capitalized,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).capitalized,
            summary: summary
        )
    }

    private func save(image: UIImage, category: String, name: String?, summary: String, embedding: [Float], context: ModelContext) {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else { return }
        let screenshot = Screenshot(imageData: imageData, category: category, name: name, summary: summary, embedding: embedding)
        context.insert(screenshot)
        try? context.save()
    }
}
