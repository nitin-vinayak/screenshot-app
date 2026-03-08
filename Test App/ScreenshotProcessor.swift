//
//  ScreenshotProcessor.swift
//  Test App
//
//  Created by Nitin Vinayak on 08/03/26.
//
import Vision
import UIKit
import SwiftData

class ScreenshotProcessor {
    
    static let shared = ScreenshotProcessor()
    
    func process(image: UIImage, context: ModelContext) {
        guard let cgImage = image.cgImage else { return }
        
        var extractedText = ""
        let group = DispatchGroup()
        
        // Step 1: OCR
        group.enter()
        let ocrRequest = VNRecognizeTextRequest { request, _ in
            extractedText = (request.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ") ?? ""
            group.leave()
        }
        ocrRequest.recognitionLevel = .accurate
        try? VNImageRequestHandler(cgImage: cgImage).perform([ocrRequest])
        
        // Step 2: Classify
        group.enter()
        let classifyRequest = VNClassifyImageRequest { [weak self] request, _ in
            let observations = request.results as? [VNClassificationObservation] ?? []
            let category = self?.mapToCategory(observations: observations, text: extractedText) ?? "Other"
            
            // Step 3: Save to SwiftData
            DispatchQueue.main.async {
                guard let imageData = image.jpegData(compressionQuality: 0.9) else { return }
                let screenshot = Screenshot(imageData: imageData, category: category, extractedText: extractedText)
                context.insert(screenshot)
                try? context.save()
            }
            group.leave()
        }
        try? VNImageRequestHandler(cgImage: cgImage).perform([classifyRequest])
    }
    
    private func mapToCategory(observations: [VNClassificationObservation], text: String) -> String {
        let textLower = text.lowercased()
        
        if textLower.contains("spotify") || textLower.contains("apple music") || textLower.contains("soundcloud") {
            return "Music"
        }
        if textLower.contains("flight") || textLower.contains("boarding") || textLower.contains("gate") {
            return "Travel"
        }
        if textLower.contains("recipe") || textLower.contains("ingredients") {
            return "Food"
        }
        
        let topLabels = observations.prefix(5).map { $0.identifier.lowercased() }
        
        if topLabels.contains(where: { $0.contains("food") || $0.contains("drink") }) { return "Food" }
        if topLabels.contains(where: { $0.contains("fashion") || $0.contains("clothing") }) { return "Fashion" }
        if topLabels.contains(where: { $0.contains("architecture") || $0.contains("interior") }) { return "Design" }
        if topLabels.contains(where: { $0.contains("map") || $0.contains("travel") }) { return "Travel" }
        
        return "Other"
    }
}
