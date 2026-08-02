import SwiftUI

struct WorkspaceModePicker: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        Picker("工具模式", selection: modeBinding) {
            ForEach(EditorModel.WorkspaceMode.allCases) { mode in
                Label(mode.title, systemImage: mode.iconName)
                    .tag(mode)
                    .help(mode.detail)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
        .help(model.workspaceMode.detail)
    }

    private var modeBinding: Binding<EditorModel.WorkspaceMode> {
        Binding {
            model.workspaceMode
        } set: { mode in
            model.setWorkspaceMode(mode)
        }
    }
}

struct HTMLViewportPicker: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        Picker("响应式预览", selection: deviceBinding) {
            ForEach(EditorModel.HTMLPreviewDevice.allCases) { device in
                Image(systemName: device.iconName)
                    .tag(device)
                    .help(device.viewportWidth.map { "\(device.title) · \($0)px" } ?? "使用页面原始宽度")
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 126)
        .disabled(!model.hasOpenDocument || model.documentMode != "html")
        .help("按真实 CSS 视口宽度检查桌面、平板和手机布局，不修改 HTML")
    }

    private var deviceBinding: Binding<EditorModel.HTMLPreviewDevice> {
        Binding {
            model.htmlPreviewDevice
        } set: { device in
            model.setHTMLPreviewDevice(device)
        }
    }
}

struct HTMLZoomControls: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        HStack(spacing: 4) {
            Button {
                model.setHTMLZoomPreset("actual")
            } label: {
                Image(systemName: "1.magnifyingglass")
                    .frame(width: 17, height: 17)
                    .accessibilityLabel("100% 显示")
            }
            .help("100% 显示。HTML 不会自动缩放。")

            Button {
                model.setHTMLZoomPreset("fit-width")
            } label: {
                Image(systemName: "arrow.left.and.right")
                    .frame(width: 17, height: 17)
                    .accessibilityLabel("适应宽度")
            }
            .help("仅本次按指令适应编辑区宽度")
        }
        .buttonStyle(MaterialButtonStyle())
        .disabled(!model.hasOpenDocument || model.documentMode != "html")
    }
}

struct AdvancedWorkspaceMenu: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        Menu {
            Section("页面运行") {
                ForEach(EditorModel.HTMLRuntimeMode.allCases) { mode in
                    Button {
                        model.setActiveHTMLRuntimeMode(mode)
                    } label: {
                        Label(
                            mode.title,
                            systemImage: model.activeHTMLRuntimeMode == mode ? "checkmark.circle.fill" : mode.iconName
                        )
                    }
                    .disabled(!model.hasOpenDocument || model.documentMode != "html")
                }
            }

            Section("编辑区背景") {
                ForEach(EditorModel.EditorBackdrop.allCases) { backdrop in
                    Button {
                        model.setEditorBackdrop(backdrop)
                    } label: {
                        Label(
                            backdrop.title,
                            systemImage: model.editorBackdrop == backdrop ? "checkmark.circle.fill" : backdrop.iconName
                        )
                    }
                }
            }

            Divider()

            Button {
                model.revealSafetyFolder()
            } label: {
                Label("打开版本目录", systemImage: "clock.arrow.circlepath")
            }
            .disabled(!model.canRevealSafetyFolder)

            Button {
                model.presentHistoryBrowser()
            } label: {
                Label("恢复历史版本", systemImage: "arrow.counterclockwise.circle")
            }
            .disabled(!model.canRevealSafetyFolder)
        } label: {
            Label("页面选项", systemImage: "slider.horizontal.3")
        }
        .menuStyle(.button)
        .buttonStyle(MaterialButtonStyle())
        .help("运行方式、编辑区背景和版本历史")
    }
}
