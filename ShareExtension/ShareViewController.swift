import UIKit

class ShareViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleIncomingScreenshot()
    }

    private func handleIncomingScreenshot() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            done()
            return
        }

        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier("public.image") {
                attachment.loadItem(forTypeIdentifier: "public.image", options: nil) { [weak self] data, error in
                    var image: UIImage?
                    
                    if let uiImage = data as? UIImage {
                        image = uiImage
                    } else if let nsData = data as? NSData {
                        image = UIImage(data: nsData as Data)
                    } else if let url = data as? URL {
                        image = UIImage(contentsOfFile: url.path)
                    }
                    
                    if let image = image {
                        self?.save(image: image)
                    }
                    self?.done()
                }
                return
            }
        }
        done()
    }

    private func save(image: UIImage) {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.nitinvinayak.screenshotapp")?
            .appendingPathComponent("Inbox", isDirectory: true) else { return }

        try? FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)

        let maxDimension: CGFloat = 768
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }

        if let data = resized.jpegData(compressionQuality: 0.5) {
            let fileURL = containerURL.appendingPathComponent("\(UUID().uuidString).jpg")
            try? data.write(to: fileURL)
        }
    }

    private func done() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
