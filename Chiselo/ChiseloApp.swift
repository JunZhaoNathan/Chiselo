import AppKit
import Sparkle
import SwiftUI

@MainActor
final class ChiseloAppDelegate: NSObject, NSApplicationDelegate {
    weak var model: EditorModel?
    private var terminationReplyPending = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationReplyPending else { return .terminateLater }
        guard let model, model.hasOpenDocument else { return .terminateNow }

        terminationReplyPending = true
        model.prepareForApplicationTermination { [weak self, weak sender] shouldTerminate in
            self?.terminationReplyPending = false
            sender?.reply(toApplicationShouldTerminate: shouldTerminate)
        }
        return .terminateLater
    }
}

@main
struct ChiseloApp: App {
    @NSApplicationDelegateAdaptor(ChiseloAppDelegate.self) private var appDelegate
    @StateObject private var model = EditorModel()
    private let updaterController: SPUStandardUpdaterController? = {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }()

    var body: some Scene {
        Window("Chiselo", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1180, minHeight: 760)
                .onAppear {
                    appDelegate.model = model
                }
                .onOpenURL { url in
                    model.openDroppedURLs([url])
                }
        }
        .defaultSize(width: 1280, height: 820)
        Settings {
            PreferencesView()
                .environmentObject(model)
        }
        .commands {
            CommandMenu("Chiselo") {
                Button("检查更新…") {
                    if let updaterController {
                        updaterController.checkForUpdates(nil)
                    } else {
                        showPackagedUpdaterNotice()
                    }
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .newItem) {
                Button("打开 HTML 或项目...") {
                    model.openDeck()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("保存") {
                    model.saveDeck()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!model.hasOpenDocument)

                Button("转为可编辑版") {
                    model.freezeCurrentHTMLLayout()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(!model.hasOpenDocument)

                Button("导出为 HTML...") {
                    model.exportHTML()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!model.hasOpenDocument)

                Button("导出为 PDF...") {
                    model.exportPDF()
                }
                .disabled(!model.hasOpenDocument)

                if model.workspaceMode == .advanced {
                    Button("导出为可编辑 HTML...") {
                        model.exportEditableHTML()
                    }
                    .disabled(!model.hasOpenDocument)

                    Button("导出为 PPTX...") {
                        model.exportPPTX()
                    }
                    .disabled(!model.hasOpenDocument)
                }
            }

            CommandGroup(replacing: .undoRedo) {
                Button("撤销") {
                    model.editorCommand("undo")
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!model.hasOpenDocument || !model.canUndoEdit)
                .help(model.nextUndoLabel.map { "撤销：\($0)" } ?? "没有可撤销的编辑")

                Button("重做") {
                    model.editorCommand("redo")
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!model.hasOpenDocument || !model.canRedoEdit)
                .help(model.nextRedoLabel.map { "重做：\($0)" } ?? "没有可重做的编辑")
            }

            CommandGroup(after: .undoRedo) {
                Button("复制对象") {
                    model.editorCommand("duplicate")
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(!model.hasOpenDocument)

                Button("删除对象") {
                    model.editorCommand("delete")
                }
                .disabled(!model.hasOpenDocument)
            }
        }
    }

    private func showPackagedUpdaterNotice() {
        let alert = NSAlert()
        alert.messageText = "调试运行无法检查更新"
        alert.informativeText = "Sparkle 热更新检查只在打包后的 Chiselo.app 中启用。正式安装包会通过 appcast 自动识别新版本。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
