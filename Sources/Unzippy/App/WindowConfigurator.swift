import SwiftUI
import AppKit

/// Applies the small set of NSWindow tweaks that SwiftUI does not expose.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.title = "轻解压"
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)
        window.minSize = NSSize(width: 980, height: 620)
        window.collectionBehavior.insert(.fullScreenPrimary)
    }
}
