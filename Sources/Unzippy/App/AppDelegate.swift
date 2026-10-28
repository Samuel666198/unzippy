import AppKit
import SwiftUI
import UnzippyCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.registerDefaults()
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        NSApp.activate(ignoringOtherApps: true)
        handleDevelopmentArguments()
    }

    private func handleDevelopmentArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--show-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
                // The SwiftUI Settings command needs the app to be active; if it
                // still did not open (headless test session), show the same view.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if !NSApp.windows.contains(where: { $0.identifier?.rawValue.contains("Settings") == true }) {
                        let tabArgument = ProcessInfo.processInfo.arguments
                            .first { $0.hasPrefix("--settings-tab=") }?
                            .replacingOccurrences(of: "--settings-tab=", with: "")
                        let tab = SettingsTab(rawValue: tabArgument ?? "") ?? .general
                        let controller = NSHostingController(
                            rootView: SettingsView(initialTab: tab).environmentObject(AppModel.shared)
                        )
                        let window = NSWindow(contentViewController: controller)
                        window.title = "设置"
                        window.styleMask = [.titled, .closable]
                        window.setContentSize(NSSize(width: 696, height: 520))
                        window.center()
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            }
        }
        if let index = arguments.firstIndex(of: "--demo-compress"), index + 1 < arguments.count {
            let path = arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                AppModel.shared.openCompressionSheet(items: [URL(fileURLWithPath: path)])
                if arguments.contains("--demo-start-compress") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        AppModel.shared.startCompression()
                    }
                }
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        AppModel.shared.add(urls: urls)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Finder Services

    @objc func extractFromService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let urls = fileURLs(from: pboard), !urls.isEmpty else { return }
        AppModel.shared.add(urls: urls)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func compressFromService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let urls = fileURLs(from: pboard), !urls.isEmpty else { return }
        AppModel.shared.openCompressionSheet(items: urls)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func fileURLs(from pboard: NSPasteboard) -> [URL]? {
        pboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]
    }
}
