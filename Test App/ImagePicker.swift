import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    let onSelect: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onSelect: (UIImage) -> Void

        init(onSelect: @escaping (UIImage) -> Void) {
            self.onSelect = onSelect
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onSelect(image)
            }
            picker.dismiss(animated: true)
        }
    }
}
