import SwiftUI
import AppKit
import UnzippyCore

@main
struct UnzippyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    init() {
        Prefs.registerDefaults()
    }

    var body: some Scene {
        Window("轻解压", id: "main") {
            RootView()
                .environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 720)
        .commands {
            AppCommands(model: model)
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

struct AppCommands: Commands {
    @ObservedObject var model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("打开压缩包…") { model.chooseArchives() }
                .keyboardShortcut("o", modifiers: .command)
            Button("新建压缩包…") { model.chooseCompressionItems() }
                .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu("操作") {
            Button("解压当前压缩包") {
                if let id = model.selectedJobID { model.extract(jobID: id) }
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(model.selectedJobID == nil)

            Button("解压全部") { model.extractAll() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(model.pendingCount == 0)

            Divider()

            Button("取消当前操作") { model.cancelActive() }
                .keyboardShortcut(".", modifiers: .command)

            Button("清空已完成") { model.clearFinished() }
                .disabled(model.jobs.allSatisfy { !$0.isFinished })
        }

        CommandGroup(replacing: .help) {
            Button("轻解压帮助") {
                NSWorkspace.shared.open(URL(fileURLWithPath: Bundle.main.path(forResource: "README", ofType: "md") ?? ""))
            }
            .disabled(Bundle.main.path(forResource: "README", ofType: "md") == nil)
        }
    }
}
