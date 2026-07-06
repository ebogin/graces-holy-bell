import SwiftUI
import UIKit

/// UIActivityViewController wrapper for handing the composed session log to
/// the Notes app (or anywhere else). Apple Notes has no public write API, so
/// the share extension — which supports appending to an existing note via
/// "Choose Note" — is the closest thing to auto-save.
struct ActivityShareSheet: UIViewControllerRepresentable {

    let text: String
    /// Called once when the share sheet closes; `completed` is false on cancel.
    var onComplete: (Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
