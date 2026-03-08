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

        if let data = image.jpegData(compressionQuality: 0.9) {
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
