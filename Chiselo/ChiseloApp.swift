import SwiftUI

@main
struct ChiseloApp: App {
    @StateObject private var model = EditorModel()

    var body: some Scene {
        Window("Chiselo", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1180, minHeight: 760)
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

                Button("导出为可编辑 HTML...") {
                    model.exportEditableHTML()
                }
                .disabled(!model.hasOpenDocument)

                Button("导出为 PDF...") {
                    model.exportPDF()
                }
                .disabled(!model.hasOpenDocument)

                Button("导出为 PPTX...") {
                    model.exportPPTX()
                }
                .disabled(!model.hasOpenDocument)
            }

            CommandGroup(replacing: .undoRedo) {
                Button("撤销") {
                    model.editorCommand("undo")
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!model.hasOpenDocument)

                Button("重做") {
                    model.editorCommand("redo")
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!model.hasOpenDocument)
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
}
