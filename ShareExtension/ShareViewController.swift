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
                attachment.loadFileRepresentation(forTypeIdentifier: "public.image") { [weak self] url, error in
                    if let url = url, let image = UIImage(contentsOfFile: url.path) {
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
