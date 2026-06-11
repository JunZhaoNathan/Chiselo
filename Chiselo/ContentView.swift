import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                AppToolbar()

                if !model.tabs.isEmpty {
                    BrowserTabBar()
                }

                ZStack {
                    HSplitView {
                        DocumentNavigator()
                            .frame(minWidth: 170, idealWidth: 220, maxWidth: 380)
                            .frame(maxHeight: .infinity)

                        WebEditorView()
                            .frame(minWidth: 560)
                            .frame(maxHeight: .infinity)

                        InspectorPanel()
                            .frame(minWidth: 250, idealWidth: 310, maxWidth: 480)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(maxHeight: .infinity)

                    if !model.hasOpenDocument {
                        WelcomeStartView()
                            .transition(.opacity)
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, MaterialTheme.panelPadding)
                .padding(.bottom, 12)

                StatusBar()
            }
            .background(AppGlassBackground())

            if model.isFileDropTargeted {
                DropOverlay()
                    .padding(28)
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: fileDropTargetBinding) { providers in
            model.openDroppedFiles(from: providers)
        }
        .sheet(isPresented: exportPreflightBinding) {
            ExportPreflightPanel()
                .environmentObject(model)
        }
        .sheet(isPresented: historyBrowserBinding) {
            HistoryBrowserPanel()
                .environmentObject(model)
        }
    }

    private var fileDropTargetBinding: Binding<Bool> {
        Binding {
            model.isFileDropTargeted
        } set: { targeted in
            model.setFileDropTargeted(targeted)
        }
    }

    private var exportPreflightBinding: Binding<Bool> {
        Binding {
            model.isExportPreflightPresented
        } set: { isPresented in
            model.isExportPreflightPresented = isPresented
        }
    }

    private var historyBrowserBinding: Binding<Bool> {
        Binding {
            model.isHistoryBrowserPresented
        } set: { isPresented in
            model.isHistoryBrowserPresented = isPresented
        }
    }
}

private struct AppGlassBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    MaterialTheme.surfaceStrong,
                    MaterialTheme.background,
                    MaterialTheme.canvasChromeEnd.opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.54),
                            Color.white.opacity(0.18),
                            MaterialTheme.glow.opacity(0.42)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
    }
}

private struct BrowserTabBar: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.tabs) { tab in
                        BrowserTab(tab: tab, isActive: tab.id == model.activeTabID)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 7)
                .padding(.bottom, 5)
            }

            Spacer(minLength: 8)

            Label("拖入打开", systemImage: "tray.and.arrow.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MaterialTheme.muted)
                .padding(.trailing, 14)
                .help("可将 HTML 文件拖到窗口任意位置")

            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MaterialTheme.muted.opacity(0.82))
                .padding(.trailing, 14)
                .help("拖动分隔线可调整左右栏")
        }
        .frame(height: 44)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(MaterialTheme.hairline).frame(height: 1), alignment: .top)
        .overlay(Rectangle().fill(MaterialTheme.separator).frame(height: 1), alignment: .bottom)
    }
}

private struct BrowserTab: View {
    @EnvironmentObject private var model: EditorModel

    var tab: EditorModel.EditorTab
    var isActive: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button {
                model.activateTab(tab.id)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: tab.mode == "html" ? "safari" : "rectangle.on.rectangle")
                        .font(.system(size: 12, weight: .bold))
                    Text(tab.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                model.closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .heavy))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("关闭标签页")
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .frame(width: 214, height: 32)
        .foregroundStyle(isActive ? MaterialTheme.ink : MaterialTheme.muted)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(isActive ? MaterialTheme.surface : Color.white.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(isActive ? MaterialTheme.primary.opacity(0.36) : MaterialTheme.hairline, lineWidth: 1)
        )
        .shadow(color: isActive ? MaterialTheme.shadow.opacity(0.20) : .clear, radius: 7, x: 0, y: 2)
    }
}

private struct DropOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(MaterialTheme.primary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(MaterialTheme.primary.opacity(0.58), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            )
            .overlay(
                VStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(MaterialTheme.primary)
                    Text("拖入 HTML 文件，在新标签页打开")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(MaterialTheme.ink)
                    Text("HTML, HTM, XHTML, AISLIDE, JSON")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(MaterialTheme.primaryDark)
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                        .fill(.regularMaterial)
                        .shadow(color: MaterialTheme.shadow.opacity(0.22), radius: 16, x: 0, y: 6)
                )
            )
            .allowsHitTesting(false)
    }
}

private struct WelcomeStartView: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(MaterialTheme.primary)

            VStack(spacing: 7) {
                Text("打开一个项目开始")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(MaterialTheme.ink)

                Text("打开 HTML、Chiselo 项目，或直接把文件拖进窗口。")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .multilineTextAlignment(.center)
            }

            Button {
                model.openDeck()
            } label: {
                Label("打开项目", systemImage: "folder")
            }
            .buttonStyle(MaterialButtonStyle(filled: true))
            .keyboardShortcut("o", modifiers: .command)

            VStack(spacing: 6) {
                Text("支持 HTML / HTM / XHTML / AISLIDE / JSON")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(MaterialTheme.primaryDark)
            }
        }
        .padding(34)
        .frame(maxWidth: 520)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusPanel))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusPanel)
                .stroke(MaterialTheme.hairline, lineWidth: 1)
        )
        .shadow(color: MaterialTheme.shadow.opacity(0.18), radius: 24, x: 0, y: 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(0.22))
        )
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        Form {
            Picker("编辑区背景", selection: backgroundBinding) {
                ForEach(EditorModel.EditorBackdrop.allCases) { backdrop in
                    Label(backdrop.title, systemImage: backdrop.iconName)
                        .tag(backdrop)
                }
            }
            .pickerStyle(.segmented)

            Text("背景只影响编辑工作区，不会写入导出的 HTML、PDF 或 PPTX。")
                .font(.caption)
                .foregroundStyle(MaterialTheme.muted)
        }
        .padding(22)
        .frame(width: 420)
    }

    private var backgroundBinding: Binding<EditorModel.EditorBackdrop> {
        Binding {
            model.editorBackdrop
        } set: { value in
            model.setEditorBackdrop(value)
        }
    }
}

private extension EditorModel {
    var deckAspectRatio: Double {
        guard let canvas = deck?.canvas, canvas.height > 0 else { return 16.0 / 9.0 }
        return canvas.width / canvas.height
    }
}

private struct AppToolbar: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Chiselo")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(MaterialTheme.ink)
                Text("HTML主资产 · Office式编辑")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(MaterialTheme.primary)
            }
            .frame(width: 196, alignment: .leading)

            ToolbarCommandGroup {
                ToolbarActionButton(title: "打开", icon: "folder") {
                    model.openDeck()
                }
                .help("打开 HTML、HTM、XHTML 或 Chiselo 项目文件")

                ToolbarActionButton(title: "保存", icon: "square.and.arrow.down") {
                    model.saveDeck()
                }
                .disabled(!model.hasOpenDocument)
                .help("保存当前文件，并在覆盖前生成版本快照")

                ToolbarActionButton(title: "备份", icon: "clock.arrow.circlepath") {
                    model.revealSafetyFolder()
                }
                .disabled(!model.canRevealSafetyFolder)
                .help("打开当前文件的 Chiselo 版本快照目录")

                ToolbarActionButton(title: "恢复", icon: "arrow.counterclockwise.circle") {
                    model.presentHistoryBrowser()
                }
                .disabled(!model.canRevealSafetyFolder)
                .help("浏览 Chiselo 版本快照并恢复指定版本")
            }

            MaterialDivider()

            ToolbarActionButton(title: "冻结版式", icon: "viewfinder") {
                model.freezeCurrentHTMLLayout()
            }
            .disabled(!model.hasOpenDocument)
            .help("将当前 HTML 渲染结果对象化到新的精准布局标签页")

            MaterialDivider()

            ToolbarCommandGroup {
                ToolbarIconButton(icon: "arrow.uturn.backward", title: "撤销") {
                    model.editorCommand("undo")
                }
                .disabled(!model.hasOpenDocument)
                .help("撤销上一步")

                ToolbarIconButton(icon: "arrow.uturn.forward", title: "重做") {
                    model.editorCommand("redo")
                }
                .disabled(!model.hasOpenDocument)
                .help("重做上一步")
            }

            MaterialDivider()

            ExportMenu()

            BackdropMenu()

            Spacer()

            Text(modeBadgeTitle)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(MaterialTheme.primaryDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                        .fill(MaterialTheme.surfaceTint)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                        .stroke(MaterialTheme.separator, lineWidth: 1)
                )
                .help(model.documentMode == "html" ? "直接编辑当前 HTML 文档" : "对象化编辑当前页面")
        }
        .buttonStyle(MaterialButtonStyle())
        .padding(.horizontal, MaterialTheme.panelPadding)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Rectangle().fill(.regularMaterial)
                Rectangle().fill(Color.white.opacity(0.22))
            }
            .shadow(color: MaterialTheme.shadow.opacity(0.20), radius: 10, x: 0, y: 2)
        )
        .overlay(Rectangle().fill(MaterialTheme.hairline).frame(height: 1), alignment: .top)
        .overlay(Rectangle().fill(MaterialTheme.separator).frame(height: 1), alignment: .bottom)
    }

    private var modeBadgeTitle: String {
        guard model.hasOpenDocument else { return "准备开始" }
        return model.documentMode == "html" ? "HTML模式" : "结构模式"
    }
}

private struct BackdropMenu: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        Menu {
            ForEach(EditorModel.EditorBackdrop.allCases) { backdrop in
                Button {
                    model.setEditorBackdrop(backdrop)
                } label: {
                    Label(backdrop.title, systemImage: model.editorBackdrop == backdrop ? "checkmark.circle.fill" : backdrop.iconName)
                }
            }
        } label: {
            Label("背景", systemImage: "square.grid.3x3")
        }
        .menuStyle(.button)
        .buttonStyle(MaterialButtonStyle())
        .help("切换编辑区背景")
    }
}

private struct ToolbarCommandGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 6) {
            content
        }
    }
}

private struct ToolbarActionButton: View {
    var title: String
    var icon: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
    }
}

private struct ToolbarIconButton: View {
    var icon: String
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 17, height: 17)
                .accessibilityLabel(title)
        }
    }
}

private struct ExportMenu: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        Menu {
            Button {
                model.presentExportPreflight()
            } label: {
                ExportMenuItemLabel(
                    title: "导出预检",
                    subtitle: preflightSubtitle,
                    icon: preflightIcon
                )
            }

            Divider()

            Button {
                model.exportHTML()
            } label: {
                ExportMenuItemLabel(
                    title: "干净 HTML",
                    subtitle: "移除编辑器痕迹，适合发布",
                    icon: "doc.text"
                )
            }

            Button {
                model.exportEditableHTML()
            } label: {
                ExportMenuItemLabel(
                    title: "可编辑 HTML",
                    subtitle: "浏览器内可直接改文字",
                    icon: "pencil.and.outline"
                )
            }

            Divider()

            Button {
                model.exportPDF()
            } label: {
                ExportMenuItemLabel(
                    title: "高保真 PDF",
                    subtitle: "按浏览器渲染结果分页输出",
                    icon: "doc.richtext"
                )
            }

            Button {
                model.exportPPTX()
            } label: {
                ExportMenuItemLabel(
                    title: "可编辑 PPTX",
                    subtitle: "作为可编辑 Office 交付格式",
                    icon: "rectangle.on.rectangle.angled"
                )
            }
        } label: {
            Label("导出", systemImage: "square.and.arrow.up")
        }
        .menuStyle(.button)
        .buttonStyle(MaterialButtonStyle(filled: true))
        .disabled(!model.hasOpenDocument)
        .help("从 HTML 主资产导出 HTML、PDF 或可编辑 PPTX")
    }

    private var preflightSubtitle: String {
        guard model.documentMode == "html" else { return "检查页面、对象和导出格式" }
        return model.htmlDiagnostics.preflightSummary
    }

    private var preflightIcon: String {
        guard model.documentMode == "html" else { return "checklist" }
        return model.htmlDiagnostics.preflightIcon
    }
}

private struct ExportMenuItemLabel: View {
    var title: String
    var subtitle: String
    var icon: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
        }
    }
}

private struct ExportPreflightPanel: View {
    @EnvironmentObject private var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: model.documentMode == "html" ? model.htmlDiagnostics.preflightIcon : "checklist")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(headerColor)
                    .frame(width: 42, height: 42)
                    .background(headerColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text("导出预检")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(headerSubtitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MaterialTheme.muted)
                }

                Spacer()

                Button {
                    model.refreshHTMLDiagnostics()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(MaterialButtonStyle())
                .disabled(model.documentMode != "html")
            }
            .padding(20)
            .background(MaterialTheme.surfaceStrong)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.documentMode == "html" {
                        htmlPreflightContent
                    } else {
                        deckPreflightContent
                    }
                }
                .padding(20)
            }

            Divider()

            HStack(spacing: 10) {
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(MaterialButtonStyle())

                Spacer()

                Button {
                    closeThen { model.exportHTML() }
                } label: {
                    Label("导出 HTML", systemImage: "doc.text")
                }
                .buttonStyle(MaterialButtonStyle())

                Button {
                    closeThen { model.exportPDF() }
                } label: {
                    Label("导出 PDF", systemImage: "doc.richtext")
                }
                .buttonStyle(MaterialButtonStyle())

                Button {
                    closeThen { model.exportPPTX() }
                } label: {
                    Label("导出 PPTX", systemImage: "rectangle.on.rectangle.angled")
                }
                .buttonStyle(MaterialButtonStyle(filled: true))
            }
            .padding(16)
            .background(MaterialTheme.surfaceStrong)
        }
        .frame(width: 720, height: 680)
    }

    private var htmlPreflightContent: some View {
        let diagnostics = model.htmlDiagnostics

        return VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ExportTargetScoreCard(
                    title: "HTML",
                    subtitle: diagnostics.cleanExport ? "干净导出" : "需清理",
                    score: diagnostics.htmlReadinessScore,
                    icon: "doc.text",
                    detail: diagnostics.cleanExport ? "无编辑器临时标记，适合交付或继续二次编辑。" : "导出内容仍含临时标记，需要先处理。",
                    color: scoreColor(diagnostics.htmlReadinessScore)
                )

                ExportTargetScoreCard(
                    title: "PDF",
                    subtitle: "高保真渲染",
                    score: diagnostics.pdfFidelityScore,
                    icon: "doc.richtext",
                    detail: "PDF 以浏览器渲染为准，重点复查断链、越界和文字溢出。",
                    color: scoreColor(diagnostics.pdfFidelityScore)
                )

                ExportTargetScoreCard(
                    title: "PPTX",
                    subtitle: "可编辑性 \(diagnostics.pptxEditabilityScore)%",
                    score: diagnostics.pptxEditabilityScore,
                    icon: "rectangle.on.rectangle.angled",
                    detail: diagnostics.pptxRiskSummary,
                    color: scoreColor(diagnostics.pptxEditabilityScore)
                )
            }

            PreflightRecommendationCard(diagnostics: diagnostics)

            VStack(alignment: .leading, spacing: 10) {
                Text("问题定位")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)

                if let issues = diagnostics.issues, !issues.isEmpty {
                    ForEach(issues.prefix(10)) { issue in
                        DeliveryIssueRow(issue: issue) {
                            if let elementId = issue.elementId {
                                dismiss()
                                model.selectHTMLNode(id: elementId)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(successColor)
                        Text("没有发现阻碍交付的问题。")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MaterialTheme.muted)
                    }
                    .padding(12)
                    .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("PPTX 复核提示")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)

                PreflightNoteRow(icon: "tablecells", title: "表格", detail: diagnostics.spanTableCount > 0 ? "合并单元格会降低 PPTX 对象映射稳定性。" : "普通表格仍建议导出后抽查行列和文字框。")
                PreflightNoteRow(icon: "scribble.variable", title: "矢量/SVG", detail: diagnostics.svgCount > 0 ? "SVG 或复杂矢量可能会转成形状或图片，需要复核可编辑程度。" : "未检测到明显 SVG 风险。")
                PreflightNoteRow(icon: "square.stack.3d.up", title: "层叠", detail: (diagnostics.overlapCount ?? 0) > 0 ? "重叠对象导出 PPTX 后要检查层级顺序。" : "未检测到明显重叠风险。")
            }
        }
    }

    private var deckPreflightContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ExportTargetScoreCard(
                    title: "HTML",
                    subtitle: "结构页导出",
                    score: 96,
                    icon: "doc.text",
                    detail: "当前内容已经是对象化页面，HTML 导出风险较低。",
                    color: scoreColor(96)
                )
                ExportTargetScoreCard(
                    title: "PDF",
                    subtitle: "页面渲染",
                    score: 96,
                    icon: "doc.richtext",
                    detail: "PDF 会按页面尺寸渲染，适合高保真交付。",
                    color: scoreColor(96)
                )
                ExportTargetScoreCard(
                    title: "PPTX",
                    subtitle: "对象可编辑",
                    score: 90,
                    icon: "rectangle.on.rectangle.angled",
                    detail: "文本、图片和形状会尽量保留为可编辑对象。",
                    color: scoreColor(90)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("当前页面结构")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                PreflightNoteRow(icon: "rectangle.on.rectangle", title: "页面", detail: "\(model.documentStats.pageCount ?? 0) 页")
                PreflightNoteRow(icon: "square.grid.2x2", title: "对象", detail: "\(model.documentStats.objectCount ?? 0) 个对象")
                PreflightNoteRow(icon: "photo", title: "图片", detail: "\(model.documentStats.imageCount ?? 0) 张图片")
            }
        }
    }

    private var headerSubtitle: String {
        if model.documentMode == "html" {
            return model.htmlDiagnostics.preflightSummary
        }
        return "对象化页面可导出 HTML、PDF 和 PPTX"
    }

    private var headerColor: Color {
        if model.documentMode == "html" {
            return scoreColor(model.htmlDiagnostics.overallExportScore)
        }
        return successColor
    }

    private var successColor: Color {
        Color(red: 0.06, green: 0.52, blue: 0.26)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return successColor }
        if score >= 65 { return Color(red: 0.78, green: 0.47, blue: 0.06) }
        return MaterialTheme.accentDanger
    }

    private func closeThen(_ action: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.async {
            action()
        }
    }
}

private struct ExportTargetScoreCard: View {
    var title: String
    var subtitle: String
    var score: Int
    var icon: String
    var detail: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
                    .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                }
            }

            Text("\(score)%")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(color)

            Text(detail)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct PreflightRecommendationCard: View {
    var diagnostics: HTMLDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("导出建议")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(MaterialTheme.ink)

            ForEach(Array(recommendations.enumerated()), id: \.offset) { _, recommendation in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: recommendation.icon)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(recommendation.color)
                        .frame(width: 18, height: 18)
                    Text(recommendation.text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
    }

    private var recommendations: [(icon: String, text: String, color: Color)] {
        var items: [(String, String, Color)] = []
        if diagnostics.blockingExportRiskCount > 0 {
            items.append(("exclamationmark.triangle.fill", "先处理红色问题，再导出正式版本。断链、文字溢出和越界会直接影响交付质量。", MaterialTheme.accentDanger))
        } else {
            items.append(("checkmark.seal.fill", "HTML 和 PDF 可直接进入导出复核。重要文件仍建议打开导出结果抽查一遍。", Color(red: 0.06, green: 0.52, blue: 0.26)))
        }

        if diagnostics.pptxReviewRiskCount > 0 {
            items.append(("rectangle.on.rectangle.angled", "PPTX 属于可编辑映射，表格、SVG、重叠对象和合并单元格导出后需要重点复核。", Color(red: 0.78, green: 0.47, blue: 0.06)))
        } else {
            items.append(("rectangle.on.rectangle.angled", "PPTX 可编辑性风险较低，可导出后检查文本框、图片和对象层级。", Color(red: 0.06, green: 0.52, blue: 0.26)))
        }
        return items
    }
}

private struct PreflightNoteRow: View {
    var icon: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(MaterialTheme.primary)
                .frame(width: 18, height: 18)
                .background(MaterialTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Text(detail)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }
}

private extension HTMLDiagnostics {
    var preflightSummary: String {
        if blockingExportRiskCount > 0 {
            return "\(blockingExportRiskCount) 项需先处理"
        }
        if pptxReviewRiskCount > 0 {
            return "\(pptxReviewRiskCount) 项导出后需复核"
        }
        return "HTML、PDF、PPTX 可进入导出复核"
    }

    var preflightIcon: String {
        if blockingExportRiskCount > 0 { return "exclamationmark.triangle.fill" }
        if pptxReviewRiskCount > 0 { return "checklist" }
        return "checkmark.seal.fill"
    }

    var blockingExportRiskCount: Int {
        var count = 0
        count += brokenImages
        count += brokenMedia
        if !cleanExport { count += 1 }
        count += textOverflowCount ?? 0
        count += outOfBoundsCount ?? 0
        return count
    }

    var pptxReviewRiskCount: Int {
        var count = 0
        if tableCount > 0 { count += 1 }
        if spanTableCount > 0 { count += 1 }
        if svgCount > 0 { count += 1 }
        if (overlapCount ?? 0) > 0 { count += 1 }
        return count
    }

    var htmlReadinessScore: Int {
        boundedScore(
            100
            - (brokenImages + brokenMedia) * 18
            - (cleanExport ? 0 : 30)
            - (textOverflowCount ?? 0) * 10
            - (outOfBoundsCount ?? 0) * 10
            - min(18, (overlapCount ?? 0) * 3)
        )
    }

    var pdfFidelityScore: Int {
        boundedScore(
            100
            - (brokenImages + brokenMedia) * 22
            - (textOverflowCount ?? 0) * 12
            - (outOfBoundsCount ?? 0) * 12
            - min(20, (overlapCount ?? 0) * 4)
        )
    }

    var pptxEditabilityScore: Int {
        boundedScore(
            100
            - (brokenImages + brokenMedia) * 16
            - (textOverflowCount ?? 0) * 8
            - (outOfBoundsCount ?? 0) * 8
            - min(18, (overlapCount ?? 0) * 5)
            - min(16, tableCount * 4)
            - (spanTableCount > 0 ? 18 : 0)
            - min(20, svgCount * 6)
        )
    }

    var overallExportScore: Int {
        min(htmlReadinessScore, pdfFidelityScore, pptxEditabilityScore)
    }

    var pptxRiskSummary: String {
        if pptxEditabilityScore >= 85 {
            return "PPTX 可编辑性较好，导出后抽查文本框和图片即可。"
        }
        if pptxEditabilityScore >= 65 {
            return "PPTX 可编辑性中等，导出后重点检查表格、SVG 和层级。"
        }
        return "PPTX 可编辑性风险较高，建议先处理红色问题并复核复杂对象。"
    }

    private func boundedScore(_ value: Int) -> Int {
        min(100, max(0, value))
    }
}

private struct HistoryBrowserPanel: View {
    @EnvironmentObject private var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(MaterialTheme.primary)
                    .frame(width: 42, height: 42)
                    .background(MaterialTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text("版本历史")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(headerSubtitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MaterialTheme.muted)
                }

                Spacer()

                Button {
                    model.refreshHistorySnapshots()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(MaterialButtonStyle())
            }
            .padding(20)
            .background(MaterialTheme.surfaceStrong)

            if model.historySnapshots.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(model.historySnapshots.enumerated()), id: \.element.id) { index, snapshot in
                            HistorySnapshotRow(
                                snapshot: snapshot,
                                isLatest: index == 0,
                                isSelected: snapshot.id == model.selectedHistorySnapshotID
                            ) {
                                model.selectedHistorySnapshotID = snapshot.id
                            }
                        }
                    }
                    .padding(20)
                }
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    model.revealSafetyFolder()
                } label: {
                    Label("打开目录", systemImage: "folder")
                }
                .buttonStyle(MaterialButtonStyle())

                Spacer()

                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(MaterialButtonStyle())

                Button {
                    model.restoreSelectedHistorySnapshot()
                } label: {
                    Label("恢复所选", systemImage: "arrow.counterclockwise.circle")
                }
                .buttonStyle(MaterialButtonStyle(filled: true))
                .disabled(model.selectedHistorySnapshotID == nil)
            }
            .padding(16)
            .background(MaterialTheme.surfaceStrong)
        }
        .frame(width: 620, height: 560)
        .onAppear {
            model.refreshHistorySnapshots()
        }
    }

    private var headerSubtitle: String {
        if model.historySnapshots.isEmpty {
            return "当前文件还没有可恢复的保存快照"
        }
        return "\(model.historySnapshots.count) 个可恢复版本，最新版本在最上方"
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(MaterialTheme.primary)
            Text("还没有保存快照")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(MaterialTheme.ink)
            Text("覆盖保存 HTML 或 slides 文件后，Chiselo 会自动把旧版本放进 `.chiselo-history`，之后就能在这里复查和恢复。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct HistorySnapshotRow: View {
    var snapshot: SafeFileHistory.VersionSnapshot
    var isLatest: Bool
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "clock")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(isSelected ? Color.white : MaterialTheme.primary)
                    .frame(width: 26, height: 26)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(formatDate(snapshot.createdAt))
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(isSelected ? Color.white : MaterialTheme.ink)
                        if isLatest {
                            Text("最新")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(isSelected ? Color.white : MaterialTheme.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(latestBadgeBackground, in: RoundedRectangle(cornerRadius: 5))
                        }
                    }

                    Text(snapshot.filename)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.86) : MaterialTheme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                Text(formatBytes(snapshot.byteCount))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.86) : MaterialTheme.muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(isSelected ? Color.clear : MaterialTheme.hairline, lineWidth: 1)
        )
    }

    private var rowBackground: Color {
        isSelected ? MaterialTheme.primary : MaterialTheme.surfaceTint
    }

    private var iconBackground: Color {
        isSelected ? Color.white.opacity(0.18) : MaterialTheme.primary.opacity(0.10)
    }

    private var latestBadgeBackground: Color {
        isSelected ? Color.white.opacity(0.18) : MaterialTheme.primary.opacity(0.10)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "未知时间" }
        return Self.dateFormatter.string(from: date)
    }

    private func formatBytes(_ byteCount: Int64) -> String {
        Self.byteFormatter.string(fromByteCount: byteCount)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}

private struct DocumentNavigator: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MaterialPanelHeader(title: navigatorTitle, subtitle: navigatorSubtitle)
                .padding(.horizontal, MaterialTheme.panelPadding)
                .padding(.top, MaterialTheme.panelPadding)

            NavigatorMetricsBar(
                pageCount: model.documentStats.pageCount,
                objectCount: model.documentStats.objectCount,
                imageCount: model.documentStats.imageCount,
                htmlNodeCount: model.documentStats.htmlNodeCount
            )
            .padding(.horizontal, MaterialTheme.panelPadding)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if model.deck == nil {
                        HTMLDocumentCard()
                        HTMLDeliveryCheckCard(diagnostics: model.htmlDiagnostics)

                        if !model.htmlTree.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("对象结构")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 2)

                                HTMLTreeList(nodes: model.htmlTree)
                            }
                        }
                    }

                    ForEach(Array((model.deck?.slides ?? []).enumerated()), id: \.element.id) { index, slide in
                        Button {
                            model.selectSlide(index: index)
                        } label: {
                            SlideThumbnailView(
                                slide: slide,
                                canvas: model.deck?.canvas,
                                index: index,
                                isSelected: index == model.selectedSlideIndex
                            )
                            .equatable()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
        .background(MaterialSidebarBackground())
    }

    private var navigatorTitle: String {
        model.documentMode == "html" ? "文档" : "页面"
    }

    private var navigatorSubtitle: String {
        model.documentMode == "html" ? "页面对象" : "版面与对象"
    }

}

private struct NavigatorMetricsBar: View {
    var pageCount: Int?
    var objectCount: Int?
    var imageCount: Int?
    var htmlNodeCount: Int?

    var body: some View {
        HStack(spacing: 6) {
            if let pageCount {
                MetricPill(value: "\(pageCount)", label: "页", icon: "rectangle.on.rectangle")
            }

            if let objectCount {
                MetricPill(value: "\(objectCount)", label: "对象", icon: "square.3.layers.3d")
            }

            if let imageCount, imageCount > 0 {
                MetricPill(value: "\(imageCount)", label: "图", icon: "photo")
            }

            if let htmlNodeCount, htmlNodeCount > 0 {
                MetricPill(value: "\(htmlNodeCount)", label: "对象", icon: "square.3.layers.3d")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricPill: View {
    var value: String
    var label: String
    var icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
            Text(value)
                .font(.system(size: 10, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(MaterialTheme.primaryDark)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(MaterialTheme.hairline, lineWidth: 1)
        )
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

private struct CSSPaintView: View {
    var value: String?
    var fallback: Color

    var body: some View {
        if let gradient = cssLinearGradient(value) {
            LinearGradient(
                gradient: Gradient(stops: gradient.stops),
                startPoint: gradient.startPoint,
                endPoint: gradient.endPoint
            )
        } else {
            cssColor(value, fallback: fallback)
        }
    }
}

private struct CSSLinearGradient {
    var startPoint: UnitPoint
    var endPoint: UnitPoint
    var stops: [Gradient.Stop]
}

private struct HTMLDocumentCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
            .fill(MaterialTheme.surface)
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay(
                VStack(alignment: .leading, spacing: 6) {
                    Text("HTML")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(1.2)
                        .foregroundStyle(MaterialTheme.primary)
                    Text("HTML 页面")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(MaterialTheme.ink)
                    Spacer()
                    Text("点击正文或结构")
                        .font(.caption2)
                        .foregroundStyle(MaterialTheme.muted)
                }
                .padding(8),
                alignment: .topLeading
            )
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                    .stroke(MaterialTheme.primary.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: MaterialTheme.shadow.opacity(0.18), radius: 8, x: 0, y: 3)
    }
}

private struct HTMLDeliveryCheckCard: View {
    @EnvironmentObject private var model: EditorModel

    var diagnostics: HTMLDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: headerIcon)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(headerColor)
                    .frame(width: 22, height: 22)
                    .background(headerColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("交付检查")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(headerSubtitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(headerColor)
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 7) {
                DeliveryCheckRow(
                    icon: resourceIcon,
                    title: "资源",
                    detail: resourceDetail,
                    color: resourceColor,
                    isClickable: diagnostics.resourceElementId != nil
                ) {
                    if let elementId = diagnostics.resourceElementId {
                        model.selectHTMLNode(id: elementId)
                    }
                }

                DeliveryCheckRow(
                    icon: diagnostics.cleanExport ? "checkmark.seal" : "exclamationmark.triangle",
                    title: "干净 HTML",
                    detail: diagnostics.cleanExport ? "无编辑器临时标记" : "导出仍含临时标记",
                    color: diagnostics.cleanExport ? successColor : MaterialTheme.accentDanger,
                    isClickable: false
                )

                if diagnostics.tableCount > 0 {
                    DeliveryCheckRow(
                        icon: diagnostics.spanTableCount > 0 ? "tablecells.badge.ellipsis" : "tablecells",
                        title: "表格",
                        detail: diagnostics.spanTableCount > 0 ? "\(diagnostics.tableCount) 个表格，\(diagnostics.spanTableCount) 个含合并单元格" : "\(diagnostics.tableCount) 个表格",
                        color: diagnostics.spanTableCount > 0 ? warningColor : successColor,
                        isClickable: diagnostics.tableElementId != nil
                    ) {
                        if let elementId = diagnostics.tableElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if diagnostics.svgCount > 0 {
                    DeliveryCheckRow(
                        icon: "scribble.variable",
                        title: "SVG",
                        detail: "\(diagnostics.svgCount) 个 SVG/矢量图形",
                        color: warningColor,
                        isClickable: diagnostics.svgElementId != nil
                    ) {
                        if let elementId = diagnostics.svgElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if (diagnostics.textOverflowCount ?? 0) > 0 {
                    DeliveryCheckRow(
                        icon: "text.badge.exclamationmark",
                        title: "文字",
                        detail: "\(diagnostics.textOverflowCount ?? 0) 处文字溢出",
                        color: MaterialTheme.accentDanger,
                        isClickable: diagnostics.textOverflowElementId != nil
                    ) {
                        if let elementId = diagnostics.textOverflowElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if (diagnostics.outOfBoundsCount ?? 0) > 0 {
                    DeliveryCheckRow(
                        icon: "arrow.up.left.and.arrow.down.right",
                        title: "边界",
                        detail: "\(diagnostics.outOfBoundsCount ?? 0) 个元素超出页面",
                        color: MaterialTheme.accentDanger,
                        isClickable: diagnostics.outOfBoundsElementId != nil
                    ) {
                        if let elementId = diagnostics.outOfBoundsElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if (diagnostics.overlapCount ?? 0) > 0 {
                    DeliveryCheckRow(
                        icon: "square.stack.3d.up",
                        title: "重叠",
                        detail: "\(diagnostics.overlapCount ?? 0) 处明显重叠",
                        color: warningColor,
                        isClickable: diagnostics.overlapElementId != nil
                    ) {
                        if let elementId = diagnostics.overlapElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }
            }

            if !visibleIssues.isEmpty {
                Divider()
                    .overlay(MaterialTheme.hairline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("问题定位")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(MaterialTheme.muted)

                    ForEach(visibleIssues) { issue in
                        DeliveryIssueRow(issue: issue) {
                            if let elementId = issue.elementId {
                                model.selectHTMLNode(id: elementId)
                            }
                        }
                    }

                    if hiddenIssueCount > 0 {
                        Text("还有 \(hiddenIssueCount) 项，处理后会继续显示")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(MaterialTheme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
        .padding(12)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(MaterialTheme.hairline, lineWidth: 1)
        )
        .shadow(color: MaterialTheme.shadow.opacity(0.10), radius: 8, x: 0, y: 3)
    }

    private var headerIcon: String {
        diagnostics.issueCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
    }

    private var headerSubtitle: String {
        if diagnostics.issueCount > 0 { return "\(diagnostics.issueCount) 项风险" }
        if diagnostics.warningCount > 0 { return "\(diagnostics.warningCount) 项提示" }
        return "可交付"
    }

    private var headerColor: Color {
        if diagnostics.issueCount > 0 { return MaterialTheme.accentDanger }
        if diagnostics.warningCount > 0 { return warningColor }
        return successColor
    }

    private var resourceIcon: String {
        diagnostics.brokenImages + diagnostics.brokenMedia > 0 ? "photo.badge.exclamationmark" : "photo.on.rectangle"
    }

    private var resourceDetail: String {
        let broken = diagnostics.brokenImages + diagnostics.brokenMedia
        if broken > 0 {
            return "\(diagnostics.brokenImages) 张断链图，\(diagnostics.brokenMedia) 个断链媒体"
        }

        let embedded = diagnostics.embeddedImages ?? 0
        if diagnostics.imageCount == 0 && diagnostics.mediaCount == 0 { return "无外部图片/媒体" }
        if embedded > 0 { return "\(diagnostics.imageCount) 张图，\(embedded) 张已嵌入" }
        return "\(diagnostics.imageCount) 张图，\(diagnostics.mediaCount) 个媒体"
    }

    private var resourceColor: Color {
        diagnostics.brokenImages + diagnostics.brokenMedia > 0 ? MaterialTheme.accentDanger : successColor
    }

    private var successColor: Color {
        Color(red: 0.06, green: 0.52, blue: 0.26)
    }

    private var warningColor: Color {
        Color(red: 0.78, green: 0.47, blue: 0.06)
    }

    private var visibleIssues: [HTMLDiagnosticIssue] {
        Array((diagnostics.issues ?? []).prefix(5))
    }

    private var hiddenIssueCount: Int {
        max(0, (diagnostics.issues ?? []).count - visibleIssues.count)
    }
}

private struct DeliveryCheckRow: View {
    var icon: String
    var title: String
    var detail: String
    var color: Color
    var isClickable: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(color)
                    .frame(width: 18, height: 18)
                    .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(detail)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                if isClickable {
                    Image(systemName: "scope")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(MaterialTheme.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isClickable)
        .opacity(isClickable ? 1 : 0.88)
    }
}

private struct DeliveryIssueRow: View {
    var issue: HTMLDiagnosticIssue
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(color)
                    .frame(width: 18, height: 18)
                    .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(issue.title)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                        .lineLimit(1)
                    Text(issue.detail)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                if issue.elementId != nil {
                    Image(systemName: "scope")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(MaterialTheme.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(issue.elementId == nil)
        .opacity(issue.elementId == nil ? 0.72 : 1)
    }

    private var icon: String {
        switch issue.kind {
        case "broken-image", "broken-media":
            return "photo.badge.exclamationmark"
        case "text-overflow":
            return "text.badge.exclamationmark"
        case "out-of-bounds":
            return "arrow.up.left.and.arrow.down.right"
        case "overlap":
            return "square.stack.3d.up"
        case "span-table":
            return "tablecells.badge.ellipsis"
        default:
            return issue.severity == "error" ? "exclamationmark.triangle" : "info.circle"
        }
    }

    private var color: Color {
        issue.severity == "error" ? MaterialTheme.accentDanger : Color(red: 0.78, green: 0.47, blue: 0.06)
    }
}

private struct SlideThumbnailView: View, Equatable {
    private static let maxPreviewElements = 90

    var slide: EditorSlide
    var canvas: EditorCanvas?
    var index: Int
    var isSelected: Bool

    private var canvasWidth: Double {
        max(1, canvas?.width ?? 1280)
    }

    private var canvasHeight: Double {
        max(1, canvas?.height ?? 720)
    }

    private var aspectRatio: Double {
        canvasWidth / canvasHeight
    }

    private var previewElements: [EditorElement] {
        let sorted = slide.elements.sorted { left, right in
            if left.z == right.z { return left.id < right.id }
            return left.z < right.z
        }
        guard sorted.count > Self.maxPreviewElements else { return sorted }

        var elements = Array(sorted.prefix(24))
        elements.append(contentsOf: sorted.suffix(Self.maxPreviewElements - elements.count))
        return elements
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topLeading) {
                CSSPaintView(value: canvas?.background, fallback: Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))

                GeometryReader { proxy in
                    let scaleX = proxy.size.width / canvasWidth
                    let scaleY = proxy.size.height / canvasHeight

                    ZStack(alignment: .topLeading) {
                        ForEach(previewElements) { element in
                            ThumbnailElementView(
                                element: element,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                renderImages: isSelected
                            )
                            .equatable()
                        }
                    }
                    .clipped()
                }
                .padding(7)

                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(MaterialTheme.primary, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall - 2))
                    .padding(7)
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                    .stroke(MaterialTheme.primary.opacity(isSelected ? 0.82 : 0.18), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: MaterialTheme.shadow.opacity(isSelected ? 0.22 : 0.12), radius: 9, x: 0, y: 3)

            HStack(spacing: 6) {
                Text(slide.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(MaterialTheme.ink)
                Spacer(minLength: 0)
                SlideObjectSummary(elements: slide.elements)
            }
            .padding(.horizontal, 2)
        }
    }

}

private struct SlideObjectSummary: View, Equatable {
    let totalCount: Int
    let imageCount: Int
    let textCount: Int
    let shapeCount: Int

    init(elements: [EditorElement]) {
        totalCount = elements.count
        var images = 0
        var texts = 0

        for element in elements {
            if element.type == "image" {
                images += 1
            } else if element.type == "text" {
                texts += 1
            }
        }

        imageCount = images
        textCount = texts
        shapeCount = elements.count - images - texts
    }

    var body: some View {
        HStack(spacing: 4) {
            if imageCount > 0 {
                Label("\(imageCount)", systemImage: "photo")
            }
            if textCount > 0 {
                Label("\(textCount)", systemImage: "textformat")
            }
            if shapeCount > 0 {
                Label("\(shapeCount)", systemImage: "square")
            }
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(MaterialTheme.muted)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .accessibilityLabel("\(totalCount) 个对象")
    }
}

private struct ThumbnailElementView: View, Equatable {
    var element: EditorElement
    var scaleX: Double
    var scaleY: Double
    var renderImages: Bool

    var body: some View {
        Group {
            if element.type == "text" {
                Text(element.text ?? "")
                    .font(.system(size: thumbnailFontSize, weight: thumbnailFontWeight))
                    .lineLimit(2)
                    .multilineTextAlignment(textAlignment)
                    .foregroundStyle(cssColor(element.style?.color, fallback: MaterialTheme.ink))
                    .frame(width: scaledWidth, height: scaledHeight, alignment: alignment)
                    .clipped()
            } else if element.type == "image" {
                imagePreview
                    .frame(width: scaledWidth, height: scaledHeight)
                    .clipShape(RoundedRectangle(cornerRadius: scaledRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: scaledRadius)
                            .stroke(cssColor(element.style?.stroke, fallback: Color.clear), lineWidth: scaledStrokeWidth)
                    )
            } else {
                CSSPaintView(value: element.style?.fill, fallback: Color.clear)
                    .frame(width: scaledWidth, height: scaledHeight)
                    .clipShape(RoundedRectangle(cornerRadius: scaledRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: scaledRadius)
                            .stroke(cssColor(element.style?.stroke, fallback: Color.clear), lineWidth: scaledStrokeWidth)
                    )
            }
        }
        .position(x: scaledX + scaledWidth / 2, y: scaledY + scaledHeight / 2)
        .rotationEffect(.degrees(element.rotation))
    }

    @ViewBuilder
    private var imagePreview: some View {
        if renderImages {
            thumbnailImage
        } else {
            imagePlaceholder
        }
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let nsImage = nsImageFromDataURL(element.imageSource) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else if let source = element.imageSource,
                  let url = URL(string: source),
                  ["http", "https", "file"].contains(url.scheme?.lowercased() ?? "") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    imagePlaceholder
                }
            }
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: scaledRadius)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.88, green: 0.93, blue: 0.99),
                        Color(red: 0.98, green: 0.98, blue: 0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Image(systemName: "photo")
                .font(.system(size: max(8, min(scaledWidth, scaledHeight) * 0.24), weight: .bold))
                .foregroundStyle(MaterialTheme.primary.opacity(0.68))
        }
    }

    private var scaledX: Double { element.x * scaleX }
    private var scaledY: Double { element.y * scaleY }
    private var scaledWidth: Double { max(1, element.w * scaleX) }
    private var scaledHeight: Double { max(1, element.h * scaleY) }
    private var scaledRadius: Double { max(0, (element.style?.radius ?? 0) * min(scaleX, scaleY)) }
    private var scaledStrokeWidth: Double { max(0.4, (element.style?.strokeWidth ?? 0) * min(scaleX, scaleY)) }
    private var thumbnailFontSize: CGFloat { max(5, CGFloat((element.style?.fontSize ?? 16) * min(scaleX, scaleY))) }

    private var thumbnailFontWeight: Font.Weight {
        let weight = element.style?.fontWeight ?? 400
        if weight >= 750 { return .heavy }
        if weight >= 650 { return .bold }
        if weight >= 550 { return .semibold }
        return .regular
    }

    private var textAlignment: TextAlignment {
        switch element.style?.textAlign {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    private var alignment: Alignment {
        switch element.style?.textAlign {
        case "center": return .top
        case "right": return .topTrailing
        default: return .topLeading
        }
    }
}

private struct HTMLTreeList: View {
    @EnvironmentObject private var model: EditorModel
    var nodes: [HTMLTreeNode]

    var body: some View {
        let selectedID = model.selectedElement?.id

        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(nodes) { node in
                HTMLTreeRow(node: node, depth: 0, selectedID: selectedID)
                    .equatable()
            }
        }
    }
}

private struct HTMLTreeRow: View, Equatable {
    @EnvironmentObject private var model: EditorModel
    var node: HTMLTreeNode
    var depth: Int
    var selectedID: String?

    static func == (lhs: HTMLTreeRow, rhs: HTMLTreeRow) -> Bool {
        lhs.node == rhs.node && lhs.depth == rhs.depth && lhs.selectedID == rhs.selectedID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                model.selectHTMLNode(id: node.id)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: hasChildren ? "chevron.down" : "circle.fill")
                        .font(.system(size: hasChildren ? 8 : 4, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.84) : MaterialTheme.muted.opacity(0.62))
                        .frame(width: 10, height: 12)

                    Image(systemName: node.chiseloIconName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white : MaterialTheme.primaryDark)
                        .frame(width: 14, height: 14)

                    Text(node.chiseloTypeLabel)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(isSelected ? Color.white : MaterialTheme.primaryDark)
                        .frame(width: 56, alignment: .leading)

                    Text(node.label)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? Color.white : MaterialTheme.ink)
                    Spacer(minLength: 0)
                }
                .padding(.leading, CGFloat(depth) * 10)
                .padding(.vertical, 6)
                .padding(.horizontal, 7)
                .background(
                    RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                        .fill(rowFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                        .stroke(isSelected ? Color.clear : MaterialTheme.separator, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(node.path)

            if let children = node.children {
                ForEach(children) { child in
                    HTMLTreeRow(node: child, depth: depth + 1, selectedID: selectedID)
                        .equatable()
                }
            }
        }
    }

    private var isSelected: Bool {
        selectedID == node.id
    }

    private var hasChildren: Bool {
        !(node.children?.isEmpty ?? true)
    }

    private var rowFill: Color {
        if isSelected { return MaterialTheme.primary }
        return depth == 0 ? MaterialTheme.surfaceStrong : MaterialTheme.surfaceTint.opacity(0.66)
    }
}

private enum InspectorTab: String, CaseIterable, Identifiable {
    case layout = "几何"
    case style = "样式"
    case arrange = "层级"
    case html = "精修"

    var id: String { rawValue }
}

private struct InspectorPanel: View {
    @EnvironmentObject private var model: EditorModel
    @State private var selectedTab: InspectorTab = .layout

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MaterialPanelHeader(title: "属性", subtitle: "对象控制")
                .padding(MaterialTheme.panelPadding)

            if let element = model.selectedElement {
                InspectorSelectionHeader(element: element, path: element.htmlPath ?? model.selectionPath)
                    .padding(.horizontal, MaterialTheme.panelPadding)
                    .padding(.bottom, 10)

                Picker("属性区域", selection: $selectedTab) {
                    ForEach(availableTabs) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, MaterialTheme.panelPadding)
                .padding(.bottom, 8)
                .onAppear(perform: normalizeSelectedTab)
                .onChange(of: model.documentMode) { _ in
                    normalizeSelectedTab()
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        inspectorContent(for: element)
                    }
                    .padding(MaterialTheme.panelPadding)
                    .groupBoxStyle(MaterialGroupBoxStyle())
                }
            } else {
                emptySelection
            }
        }
        .background(MaterialSidebarBackground())
    }

    private var availableTabs: [InspectorTab] {
        model.documentMode == "html" ? InspectorTab.allCases : [.layout, .style, .arrange]
    }

    private var activeTab: InspectorTab {
        availableTabs.contains(selectedTab) ? selectedTab : .layout
    }

    private func normalizeSelectedTab() {
        if !availableTabs.contains(selectedTab) {
            selectedTab = .layout
        }
    }

    @ViewBuilder
    private func inspectorContent(for element: EditorElement) -> some View {
        switch activeTab {
        case .layout:
            objectGroup(element)
            geometryGroup
            quickAdjustGroup
            alignmentGroup(for: element)
        case .style:
            styleGroups(for: element)
            boxStyleGroup
            htmlAssetGroups
        case .arrange:
            layerStackGroup
            layerGroup
            alignmentGroup(for: element)
        case .html:
            htmlControlsGroup
        }
    }

    private var emptySelection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: 26))
                        .foregroundStyle(MaterialTheme.primary)
                    Text("请选择一个对象")
                        .font(.headline)
                        .foregroundStyle(MaterialTheme.ink)
                    Text("位置、层级、对齐等精准控制会显示在这里。")
                        .font(.callout)
                        .foregroundStyle(MaterialTheme.muted)
                }
                .padding(18)
                .materialCard()

                if model.documentMode != "html", !model.currentSlideElements.isEmpty {
                    layerStackGroup
                }
            }
            .padding(MaterialTheme.panelPadding)
            .groupBoxStyle(MaterialGroupBoxStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func objectGroup(_ element: EditorElement) -> some View {
        GroupBox("对象") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("对象", value: element.chiseloTypeLabel)
                LabeledContent("ID", value: element.id)
                if let tagName = element.tagName {
                    LabeledContent("原始标签", value: tagName)
                }
                if let layoutMode = element.layoutMode {
                    LabeledContent("布局", value: layoutMode)
                }
                if let path = element.htmlPath ?? model.selectionPath {
                    Text("原始位置")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(MaterialTheme.primary)
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var geometryGroup: some View {
        GroupBox("几何") {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    NumberField(label: "X", value: binding(\.x))
                    NumberField(label: "Y", value: binding(\.y))
                }
                GridRow {
                    NumberField(label: "W", value: binding(\.w))
                    NumberField(label: "H", value: binding(\.h))
                }
                GridRow {
                    NumberField(label: "旋转", value: binding(\.rotation))
                    NumberField(label: "Z", value: binding(\.z))
                }
            }
        }
    }

    private var quickAdjustGroup: some View {
        GroupBox("快速调整") {
            VStack(spacing: 10) {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        CommandButton(title: "上", icon: "align.vertical.top", command: "alignTop")
                        CommandButton(title: "中", icon: "align.vertical.center", command: "alignMiddle")
                        CommandButton(title: "下", icon: "align.vertical.bottom", command: "alignBottom")
                    }
                    GridRow {
                        CommandButton(title: "左", icon: "align.horizontal.left", command: "alignLeft")
                        CommandButton(title: "居中", icon: "align.horizontal.center", command: "alignCenter")
                        CommandButton(title: "右", icon: "align.horizontal.right", command: "alignRight")
                    }
                    GridRow {
                        CommandButton(title: "适宽", icon: "arrow.left.and.right", command: "fitWidth")
                        CommandButton(title: "适高", icon: "arrow.up.and.down", command: "fitHeight")
                        CommandButton(title: "满页", icon: "rectangle.inset.filled", command: "fitPage")
                    }
                }

                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        Spacer()
                        CommandButton(title: "上移", icon: "arrow.up", command: "nudgeUp")
                        Spacer()
                    }
                    GridRow {
                        CommandButton(title: "左移", icon: "arrow.left", command: "nudgeLeft")
                        CommandButton(title: "吸附", icon: "grid", command: "snapToGrid")
                        CommandButton(title: "右移", icon: "arrow.right", command: "nudgeRight")
                    }
                    GridRow {
                        Spacer()
                        CommandButton(title: "下移", icon: "arrow.down", command: "nudgeDown")
                        Spacer()
                    }
                }

                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        CommandButton(title: "-10 X", icon: "arrow.left.to.line", command: "nudgeLeftBig")
                        CommandButton(title: "+10 X", icon: "arrow.right.to.line", command: "nudgeRightBig")
                    }
                    GridRow {
                        CommandButton(title: "-10 Y", icon: "arrow.up.to.line", command: "nudgeUpBig")
                        CommandButton(title: "+10 Y", icon: "arrow.down.to.line", command: "nudgeDownBig")
                    }
                }
            }
        }
    }

    private var textStyleGroup: some View {
        GroupBox("文字样式") {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    NumberField(label: "字号", value: styleDoubleBinding(\.fontSize, defaultValue: 16))
                    NumberField(label: "字重", value: styleDoubleBinding(\.fontWeight, defaultValue: 400))
                }
                GridRow {
                    NumberField(label: "行高", value: styleDoubleBinding(\.lineHeight, defaultValue: 1.2), fractionLength: 2)
                    StyleTextField(label: "颜色", value: styleStringBinding(\.color, defaultValue: "#111827"))
                }
                GridRow {
                    StyleTextField(label: "字体", value: styleStringBinding(\.fontFamily, defaultValue: "-apple-system"))
                    StyleTextField(label: "对齐", value: styleStringBinding(\.textAlign, defaultValue: "left"))
                }
            }
        }
    }

    @ViewBuilder
    private func styleGroups(for element: EditorElement) -> some View {
        if supportsTextControls(element) {
            textStyleGroup
        }

        if supportsImageControls(element) {
            imageInfoGroup
        }
    }

    private var imageInfoGroup: some View {
        GroupBox("图片") {
            VStack(spacing: 10) {
                StyleTextField(label: "来源", value: imageSourceBinding(defaultValue: ""))
                StyleTextField(label: "ALT", value: imageAltBinding(defaultValue: ""))

                if model.documentMode == "html" {
                    Button {
                        model.replaceSelectedImage()
                    } label: {
                        Label("替换图片", systemImage: "photo.on.rectangle.angled")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MaterialButtonStyle(filled: true))
                }
            }
        }
    }

    private var boxStyleGroup: some View {
        GroupBox("盒子样式") {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    StyleTextField(label: "填充", value: styleStringBinding(\.fill, defaultValue: "transparent"))
                    StyleTextField(label: "描边", value: styleStringBinding(\.stroke, defaultValue: "transparent"))
                }
                GridRow {
                    NumberField(label: "边框", value: styleDoubleBinding(\.strokeWidth, defaultValue: 0))
                    NumberField(label: "圆角", value: styleDoubleBinding(\.radius, defaultValue: 0))
                }
            }
        }
    }

    @ViewBuilder
    private var htmlAssetGroups: some View {
        if model.documentMode == "html" {
            if isTableSelection {
                tableGroup
            }

            if isCellSelection {
                cellStyleGroup
            }
        }
    }

    private var tableGroup: some View {
        GroupBox("表格") {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    CommandButton(title: "+行", icon: "plus.square", command: "tableAddRowAfter")
                    CommandButton(title: "-行", icon: "minus.square", command: "tableDeleteRow")
                }
                GridRow {
                    CommandButton(title: "+列", icon: "plus.rectangle.on.rectangle", command: "tableAddColumnAfter")
                    CommandButton(title: "-列", icon: "minus.rectangle", command: "tableDeleteColumn")
                }
            }
        }
    }

    private var cellStyleGroup: some View {
        GroupBox("单元格样式") {
            VStack(spacing: 10) {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        StyleTextField(label: "填充", value: styleStringBinding(\.fill, defaultValue: "transparent"))
                        StyleTextField(label: "文字", value: styleStringBinding(\.color, defaultValue: "#111827"))
                    }
                    GridRow {
                        StyleTextField(label: "边框", value: styleStringBinding(\.stroke, defaultValue: "transparent"))
                        NumberField(label: "宽度", value: styleDoubleBinding(\.strokeWidth, defaultValue: 0))
                    }
                    GridRow {
                        NumberField(label: "圆角", value: styleDoubleBinding(\.radius, defaultValue: 0))
                        StyleTextField(label: "对齐", value: styleStringBinding(\.textAlign, defaultValue: "left"))
                    }
                }

                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        CommandButton(title: "左", icon: "text.alignleft", command: "cellAlignLeft")
                        CommandButton(title: "中", icon: "text.aligncenter", command: "cellAlignCenter")
                        CommandButton(title: "右", icon: "text.alignright", command: "cellAlignRight")
                    }
                    GridRow {
                        CommandButton(title: "表头", icon: "tablecells.badge.ellipsis", command: "cellStyleHeader")
                        CommandButton(title: "柔和", icon: "paintbrush", command: "cellStyleSoft")
                    }
                }
            }
        }
    }

    private var layerGroup: some View {
        GroupBox("层级") {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    CommandButton(title: "置顶", icon: "square.3.layers.3d.top.filled", command: "bringToFront")
                    CommandButton(title: "置底", icon: "square.3.layers.3d.down.right", command: "sendToBack")
                }
                GridRow {
                    CommandButton(title: "上移层", icon: "arrow.up.square", command: "bringForward")
                    CommandButton(title: "下移层", icon: "arrow.down.square", command: "sendBackward")
                }
                GridRow {
                    CommandButton(title: "锁定", icon: "lock", command: "toggleLock")
                    CommandButton(title: "删除", icon: "trash", command: "delete")
                }
                GridRow {
                    CommandButton(title: "复制", icon: "plus.square.on.square", command: "duplicate")
                }
            }
        }
    }

    private var layerStackGroup: some View {
        GroupBox("当前页对象") {
            LayerStackList(
                elements: model.currentSlideElements.sorted { left, right in
                    if left.z == right.z { return left.id < right.id }
                    return left.z > right.z
                },
                selectedID: model.selectedElement?.id
            )
        }
    }

    private func alignmentGroup(for element: EditorElement) -> some View {
        GroupBox("对齐") {
            VStack(spacing: 8) {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        CommandButton(title: "左", icon: "align.horizontal.left", command: "alignLeft")
                        CommandButton(title: "居中", icon: "align.horizontal.center", command: "alignCenter")
                    }
                    GridRow {
                        CommandButton(title: "右", icon: "align.horizontal.right", command: "alignRight")
                        CommandButton(title: "垂直中", icon: "align.vertical.center", command: "alignMiddle")
                    }
                }

                if element.type == "html-group" {
                    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                        GridRow {
                            CommandButton(title: "同宽", icon: "arrow.left.and.right.square", command: "matchWidth")
                            CommandButton(title: "同高", icon: "arrow.up.and.down.square", command: "matchHeight")
                        }
                        GridRow {
                            CommandButton(title: "横等距", icon: "arrow.left.and.right", command: "distributeHorizontal")
                            CommandButton(title: "纵等距", icon: "arrow.up.and.down", command: "distributeVertical")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var htmlControlsGroup: some View {
        if model.documentMode == "html" {
            GroupBox("布局模式") {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        CommandButton(title: "自由", icon: "arrow.up.left.and.arrow.down.right", command: "setLayoutFree")
                        CommandButton(title: "变换", icon: "move.3d", command: "setLayoutTransform")
                    }
                }
            }

            GroupBox("层级导航") {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        CommandButton(title: "上层", icon: "arrow.up.to.line", command: "selectParent")
                        CommandButton(title: "下层", icon: "arrow.down.to.line", command: "selectFirstChild")
                    }
                    GridRow {
                        CommandButton(title: "上一个", icon: "arrow.left.to.line", command: "selectPreviousSibling")
                        CommandButton(title: "下一个", icon: "arrow.right.to.line", command: "selectNextSibling")
                    }
                    GridRow {
                        CommandButton(title: "子对象", icon: "square.grid.2x2", command: "selectVisibleChildren")
                        CommandButton(title: "同类", icon: "rectangle.on.rectangle", command: "selectSameClass")
                    }
                    GridRow {
                        CommandButton(title: "清除", icon: "xmark.square", command: "clearSelection")
                    }
                }
            }
        } else {
            Text("HTML 工具仅在 HTML 文档模式下可用。")
                .font(.callout)
                .foregroundStyle(MaterialTheme.muted)
                .materialCard()
        }
    }

    private var selectedTagName: String {
        model.selectedElement?.tagName?.lowercased() ?? ""
    }

    private var isSelectedImage: Bool {
        selectedTagName == "img" || model.selectedElement?.type == "image"
    }

    private var isCellSelection: Bool {
        selectedTagName == "td" || selectedTagName == "th"
    }

    private var isTableSelection: Bool {
        ["table", "thead", "tbody", "tfoot", "tr", "td", "th", "caption"].contains(selectedTagName)
    }

    private func supportsTextControls(_ element: EditorElement) -> Bool {
        if element.type == "text" { return true }
        return ["h1", "h2", "h3", "h4", "h5", "h6", "p", "span", "li", "button", "a", "label", "td", "th", "caption"].contains(selectedTagName)
    }

    private func supportsImageControls(_ element: EditorElement) -> Bool {
        element.type == "image" || selectedTagName == "img"
    }

    private func binding(_ keyPath: WritableKeyPath<EditorElement, Double>) -> Binding<Double> {
        Binding {
            model.selectedElement?[keyPath: keyPath] ?? 0
        } set: { value in
            guard var element = model.selectedElement else { return }
            element[keyPath: keyPath] = value
            model.updateElement(element)
        }
    }

    private func styleDoubleBinding(_ keyPath: WritableKeyPath<EditorElementStyle, Double?>, defaultValue: Double) -> Binding<Double> {
        Binding {
            model.selectedElement?.style?[keyPath: keyPath] ?? defaultValue
        } set: { value in
            guard var element = model.selectedElement else { return }
            var style = element.style ?? .empty
            style[keyPath: keyPath] = value
            element.style = style
            model.updateElement(element)
        }
    }

    private func styleStringBinding(_ keyPath: WritableKeyPath<EditorElementStyle, String?>, defaultValue: String) -> Binding<String> {
        Binding {
            model.selectedElement?.style?[keyPath: keyPath] ?? defaultValue
        } set: { value in
            guard var element = model.selectedElement else { return }
            var style = element.style ?? .empty
            style[keyPath: keyPath] = value.isEmpty ? nil : value
            element.style = style
            model.updateElement(element)
        }
    }

    private func imageSourceBinding(defaultValue: String) -> Binding<String> {
        Binding {
            model.selectedElement?.imageSource ?? defaultValue
        } set: { value in
            guard var element = model.selectedElement else { return }
            element.imageSource = value.isEmpty ? nil : value
            model.updateElement(element)
        }
    }

    private func imageAltBinding(defaultValue: String) -> Binding<String> {
        Binding {
            model.selectedElement?.imageAlt ?? defaultValue
        } set: { value in
            guard var element = model.selectedElement else { return }
            element.imageAlt = value.isEmpty ? nil : value
            model.updateElement(element)
        }
    }
}

private struct InspectorSelectionHeader: View {
    var element: EditorElement
    var path: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MaterialTheme.primary)
                .frame(width: 30, height: 30)
                .background(MaterialTheme.primary.opacity(0.11), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                        .lineLimit(1)
                    Text(element.chiseloTypeLabel)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(MaterialTheme.primaryDark)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(MaterialTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall - 2))
                }

                Text("\(Int(element.w)) x \(Int(element.h))  ·  X \(Int(element.x)), Y \(Int(element.y))")
                    .font(.caption)
                    .foregroundStyle(MaterialTheme.muted)

                if let path, !path.isEmpty {
                    Text(path)
                        .font(.caption2)
                        .foregroundStyle(MaterialTheme.muted.opacity(0.82))
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(MaterialTheme.hairline, lineWidth: 1)
        )
    }

    private var title: String {
        element.chiseloDisplayTitle
    }

    private var iconName: String {
        element.chiseloIconName
    }
}

private struct LayerStackList: View {
    var elements: [EditorElement]
    var selectedID: String?

    var body: some View {
        LazyVStack(spacing: 6) {
            if elements.isEmpty {
                Text("当前页没有对象。")
                    .font(.callout)
                    .foregroundStyle(MaterialTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(elements) { element in
                    LayerStackRow(element: element, isSelected: element.id == selectedID)
                        .equatable()
                }
            }
        }
    }
}

private struct LayerStackRow: View, Equatable {
    @EnvironmentObject private var model: EditorModel

    var element: EditorElement
    var isSelected: Bool

    static func == (lhs: LayerStackRow, rhs: LayerStackRow) -> Bool {
        lhs.element == rhs.element && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        Button {
            model.selectElement(id: element.id)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? Color.white : MaterialTheme.primary)
                    .frame(width: 24, height: 24)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall - 2))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(title)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if element.locked == true {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8, weight: .heavy))
                        }
                    }

                    Text("\(Int(element.x)), \(Int(element.y)) · \(Int(element.w)) x \(Int(element.h))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.78) : MaterialTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text("Z \(Int(element.z))")
                    .font(.system(size: 9, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.white.opacity(0.88) : MaterialTheme.primaryDark)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(zBadgeBackground, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall - 2))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : MaterialTheme.ink)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(isSelected ? Color.clear : MaterialTheme.hairline, lineWidth: 1)
        )
        .help("选择 \(title)")
    }

    private var title: String {
        if let text = element.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }

        if let alt = element.imageAlt?.trimmingCharacters(in: .whitespacesAndNewlines), !alt.isEmpty {
            return alt
        }

        return element.chiseloTypeLabel
    }

    private var iconName: String {
        element.chiseloIconName
    }

    private var rowBackground: Color {
        isSelected ? MaterialTheme.primary : MaterialTheme.surfaceTint
    }

    private var iconBackground: Color {
        isSelected ? Color.white.opacity(0.20) : MaterialTheme.primary.opacity(0.10)
    }

    private var zBadgeBackground: Color {
        isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.55)
    }
}

private extension EditorElement {
    var chiseloDisplayTitle: String {
        if let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }

        if let alt = imageAlt?.trimmingCharacters(in: .whitespacesAndNewlines), !alt.isEmpty {
            return alt
        }

        return chiseloTypeLabel
    }

    var chiseloTypeLabel: String {
        if let semanticLabel, !semanticLabel.isEmpty {
            return semanticLabel
        }

        switch tagName?.lowercased() {
        case "img":
            return "图片"
        case "table":
            return "表格"
        case "td", "th":
            return "单元格"
        case "h1", "h2", "h3", "h4", "h5", "h6":
            return "标题"
        case "p":
            return "段落"
        case "li":
            return "列表项"
        case "section", "article":
            return "模块"
        case "header":
            return "标题区"
        case "footer":
            return "页脚"
        case "group":
            return "多选对象"
        default:
            if type == "text" { return "文本" }
            if type == "image" { return "图片" }
            if type == "html-group" { return "多选对象" }
            return "对象"
        }
    }

    var chiseloIconName: String {
        switch semanticRole ?? "" {
        case "heading", "paragraph", "text", "list-item", "caption":
            return "textformat"
        case "image", "figure":
            return "photo"
        case "table", "table-section", "table-row", "table-cell", "table-header-cell", "table-like":
            return "tablecells"
        case "page":
            return "doc"
        case "header":
            return "rectangle.topthird.inset.filled"
        case "footer":
            return "rectangle.bottomthird.inset.filled"
        case "card", "module", "container":
            return "square.3.layers.3d"
        case "selection-group":
            return "square.grid.2x2"
        case "graphic", "visual":
            return "chart.xyaxis.line"
        case "media":
            return "play.rectangle"
        case "link":
            return "link"
        case "button", "form-control", "form":
            return "slider.horizontal.3"
        default:
            switch type {
            case "text":
                return "textformat"
            case "image":
                return "photo"
            default:
                return tagName?.lowercased() == "img" ? "photo" : "square.on.square"
            }
        }
    }
}

private extension HTMLTreeNode {
    var chiseloTypeLabel: String {
        if let semanticLabel, !semanticLabel.isEmpty {
            return semanticLabel
        }

        switch tagName.lowercased() {
        case "img":
            return "图片"
        case "table":
            return "表格"
        case "td", "th":
            return "单元格"
        case "h1", "h2", "h3", "h4", "h5", "h6":
            return "标题"
        case "p":
            return "段落"
        case "li":
            return "列表项"
        case "section", "article":
            return "模块"
        case "header":
            return "标题区"
        default:
            return "对象"
        }
    }

    var chiseloIconName: String {
        switch semanticRole ?? "" {
        case "heading", "paragraph", "text", "list-item", "caption":
            return "textformat"
        case "image", "figure":
            return "photo"
        case "table", "table-section", "table-row", "table-cell", "table-header-cell", "table-like":
            return "tablecells"
        case "page":
            return "doc"
        case "header":
            return "rectangle.topthird.inset.filled"
        case "footer":
            return "rectangle.bottomthird.inset.filled"
        case "card", "module", "container":
            return "square.3.layers.3d"
        case "graphic", "visual":
            return "chart.xyaxis.line"
        case "media":
            return "play.rectangle"
        case "link":
            return "link"
        case "button", "form-control", "form":
            return "slider.horizontal.3"
        default:
            return tagName.lowercased() == "img" ? "photo" : "square"
        }
    }
}

private struct NumberField: View {
    var label: String
    @Binding var value: Double
    var fractionLength: Int = 0

    @State private var draftValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(MaterialTheme.primary)
            TextField(label, text: $draftValue)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(MaterialInputBackground())
                .frame(minWidth: 86)
                .focused($isFocused)
                .onSubmit(commitDraft)
                .onAppear {
                    draftValue = formatted(value)
                }
                .onChange(of: value) { nextValue in
                    if !isFocused {
                        draftValue = formatted(nextValue)
                    }
                }
                .onChange(of: isFocused) { focused in
                    if focused {
                        draftValue = formatted(value)
                    } else {
                        commitDraft()
                    }
                }
        }
    }

    private func commitDraft() {
        let normalized = draftValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard let nextValue = Double(normalized), nextValue.isFinite else {
            draftValue = formatted(value)
            return
        }

        if abs(nextValue - value) > 0.0001 {
            value = nextValue
        }
        draftValue = formatted(nextValue)
    }

    private func formatted(_ value: Double) -> String {
        if fractionLength == 0 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.\(fractionLength)f", value)
    }
}

private struct StyleTextField: View {
    var label: String
    @Binding var value: String

    @State private var draftValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(MaterialTheme.primary)
            TextField(label, text: $draftValue)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(MaterialInputBackground())
                .frame(minWidth: 86)
                .focused($isFocused)
                .onSubmit(commitDraft)
                .onAppear {
                    draftValue = value
                }
                .onChange(of: value) { nextValue in
                    if !isFocused {
                        draftValue = nextValue
                    }
                }
                .onChange(of: isFocused) { focused in
                    if focused {
                        draftValue = value
                    } else {
                        commitDraft()
                    }
                }
        }
    }

    private func commitDraft() {
        if draftValue != value {
            value = draftValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

private extension EditorElementStyle {
    static var empty: EditorElementStyle {
        EditorElementStyle(
            fontFamily: nil,
            fontSize: nil,
            fontWeight: nil,
            lineHeight: nil,
            color: nil,
            fill: nil,
            stroke: nil,
            strokeWidth: nil,
            radius: nil,
            textAlign: nil
        )
    }
}

private struct CommandButton: View {
    @EnvironmentObject private var model: EditorModel

    var title: String
    var icon: String
    var command: String

    var body: some View {
        Button {
            model.editorCommand(command)
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MaterialButtonStyle(compact: true))
    }
}

private struct StatusBar: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        HStack {
            Text(model.status)
                .font(.caption)
                .foregroundStyle(MaterialTheme.muted)
                .lineLimit(1)

            if let element = model.selectedElement {
                StatusSelectionSummary(element: element)
            }

            Spacer()

            if model.hasOpenDocument, let canvas = model.deck?.canvas {
                Text("\(Int(canvas.width)) x \(Int(canvas.height))")
                    .font(.caption)
                    .foregroundStyle(MaterialTheme.primary)
            } else if model.hasOpenDocument, model.documentMode == "html" {
                Text("HTML 文档")
                    .font(.caption)
                    .foregroundStyle(MaterialTheme.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(MaterialTheme.hairline).frame(height: 1), alignment: .top)
    }
}

private struct StatusSelectionSummary: View {
    var element: EditorElement

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(MaterialTheme.separator)
                .frame(width: 4, height: 4)
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .bold))
            Text("\(title)  \(Int(element.w)) x \(Int(element.h))")
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(MaterialTheme.primaryDark)
        .padding(.leading, 6)
        .accessibilityLabel("已选中 \(title)，尺寸 \(Int(element.w)) x \(Int(element.h))")
    }

    private var title: String {
        element.chiseloTypeLabel
    }

    private var iconName: String {
        element.chiseloIconName
    }
}

private struct MaterialPanelHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(MaterialTheme.ink)
            Text(subtitle)
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.7)
                .foregroundStyle(MaterialTheme.primary)
        }
    }
}

private struct MaterialDivider: View {
    var body: some View {
        Rectangle()
            .fill(MaterialTheme.separator)
            .frame(width: 1, height: 26)
            .padding(.horizontal, 2)
    }
}

private struct MaterialSidebarBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: MaterialTheme.radiusPanel)
            .fill(.thinMaterial)
            .background(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusPanel)
                    .fill(MaterialTheme.surfaceStrong.opacity(0.54))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusPanel)
                    .stroke(MaterialTheme.hairline.opacity(0.86), lineWidth: 1)
            )
            .shadow(color: MaterialTheme.shadow.opacity(0.07), radius: 12, x: 0, y: 4)
    }
}

private struct MaterialInputBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
            .fill(MaterialTheme.surfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .stroke(MaterialTheme.separator.opacity(0.82), lineWidth: 1)
            )
    }
}

private struct MaterialGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.8)
                .foregroundStyle(MaterialTheme.primary)
            configuration.content
        }
        .padding(MaterialTheme.panelPadding)
        .materialCard()
    }
}

private struct MaterialButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var filled: Bool = false
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .bold))
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, compact ? 9 : MaterialTheme.panelPadding)
            .padding(.vertical, compact ? 7 : 9)
            .background(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .fill(backgroundColor)
                    .shadow(
                        color: MaterialTheme.shadow.opacity(isEnabled ? (configuration.isPressed ? 0.10 : 0.18) : 0.04),
                        radius: isEnabled ? (configuration.isPressed ? 2 : 7) : 2,
                        x: 0,
                        y: isEnabled ? (configuration.isPressed ? 1 : 2) : 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .stroke(filled || !isEnabled ? Color.clear : MaterialTheme.hairline, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.56)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return MaterialTheme.muted
        }
        return filled ? Color.white : MaterialTheme.primaryDark
    }

    private var backgroundColor: Color {
        if !isEnabled {
            return MaterialTheme.surface.opacity(0.72)
        }
        return filled ? MaterialTheme.primary : MaterialTheme.surface
    }
}

private struct MaterialCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(MaterialTheme.panelPadding)
            .background(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                    .fill(.regularMaterial)
                    .shadow(color: MaterialTheme.shadow.opacity(0.14), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                    .stroke(MaterialTheme.hairline, lineWidth: 1)
            )
    }
}

private extension View {
    func materialCard() -> some View {
        modifier(MaterialCardModifier())
    }
}

private func cssLinearGradient(_ value: String?) -> CSSLinearGradient? {
    guard let rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          rawValue.lowercased().hasPrefix("linear-gradient("),
          rawValue.hasSuffix(")") else {
        return nil
    }

    let start = rawValue.index(rawValue.startIndex, offsetBy: "linear-gradient(".count)
    let end = rawValue.index(before: rawValue.endIndex)
    var arguments = splitCSSArguments(String(rawValue[start..<end]))
    guard arguments.count >= 2 else { return nil }

    let direction = gradientDirection(from: arguments[0])
    if direction != nil {
        arguments.removeFirst()
    }

    let rawStops = arguments.compactMap(cssGradientStop)
    guard rawStops.count >= 2 else { return nil }

    let fallbackDenominator = max(1, rawStops.count - 1)
    let stops = rawStops.enumerated().map { index, rawStop in
        Gradient.Stop(
            color: rawStop.color,
            location: CGFloat(rawStop.location ?? Double(index) / Double(fallbackDenominator))
        )
    }

    let points = gradientPoints(for: direction ?? 180)
    return CSSLinearGradient(startPoint: points.start, endPoint: points.end, stops: stops)
}

private func splitCSSArguments(_ value: String) -> [String] {
    var output: [String] = []
    var current = ""
    var depth = 0
    var quote: Character?

    for character in value {
        if let activeQuote = quote {
            current.append(character)
            if character == activeQuote {
                quote = nil
            }
            continue
        }

        if character == "\"" || character == "'" {
            quote = character
            current.append(character)
            continue
        }

        if character == "(" {
            depth += 1
            current.append(character)
            continue
        }

        if character == ")" {
            depth = max(0, depth - 1)
            current.append(character)
            continue
        }

        if character == "," && depth == 0 {
            output.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
            current = ""
            continue
        }

        current.append(character)
    }

    let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
    if !tail.isEmpty {
        output.append(tail)
    }
    return output
}

private func gradientDirection(from value: String) -> Double? {
    let lowercased = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if lowercased.hasSuffix("deg"),
       let angle = Double(lowercased.dropLast(3).trimmingCharacters(in: .whitespacesAndNewlines)) {
        return angle
    }

    guard lowercased.hasPrefix("to ") else { return nil }
    let tokens = Set(lowercased.dropFirst(3).split(separator: " ").map(String.init))
    switch (tokens.contains("top"), tokens.contains("right"), tokens.contains("bottom"), tokens.contains("left")) {
    case (true, true, false, false):
        return 45
    case (false, true, true, false):
        return 135
    case (false, false, true, true):
        return 225
    case (true, false, false, true):
        return 315
    case (true, false, false, false):
        return 0
    case (false, true, false, false):
        return 90
    case (false, false, true, false):
        return 180
    case (false, false, false, true):
        return 270
    default:
        return nil
    }
}

private func gradientPoints(for angle: Double) -> (start: UnitPoint, end: UnitPoint) {
    let radians = angle * Double.pi / 180
    let dx = sin(radians)
    let dy = -cos(radians)
    let start = UnitPoint(x: clampUnit(0.5 - dx / 2), y: clampUnit(0.5 - dy / 2))
    let end = UnitPoint(x: clampUnit(0.5 + dx / 2), y: clampUnit(0.5 + dy / 2))
    return (start, end)
}

private func clampUnit(_ value: Double) -> Double {
    max(0, min(1, value))
}

private func cssGradientStop(_ value: String) -> (color: Color, location: Double?)? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let colorToken: String
    let remainder: String
    if trimmed.lowercased().hasPrefix("rgb"),
       let close = trimmed.firstIndex(of: ")") {
        colorToken = String(trimmed[...close])
        remainder = String(trimmed[trimmed.index(after: close)...])
    } else {
        let parts = trimmed.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
        colorToken = String(parts.first ?? "")
        remainder = parts.count > 1 ? String(parts[1]) : ""
    }

    let color = cssColor(colorToken, fallback: .clear)
    let position = remainder
        .split(whereSeparator: { $0.isWhitespace || $0 == "," })
        .compactMap { cssStopLocation(String($0)) }
        .first
    return (color, position)
}

private func cssStopLocation(_ value: String) -> Double? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasSuffix("%"),
       let percent = Double(trimmed.dropLast()) {
        return clampUnit(percent / 100)
    }

    guard let number = Double(trimmed) else { return nil }
    return clampUnit(number)
}

private func cssColor(_ value: String?, fallback: Color) -> Color {
    guard let rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
        return fallback
    }

    let lowercased = rawValue.lowercased()
    if lowercased == "transparent" || lowercased == "none" {
        return Color.clear
    }

    if let namedColor = namedCSSColor(lowercased) {
        return namedColor
    }

    if lowercased.hasPrefix("#") {
        let hex = String(lowercased.dropFirst())
        return colorFromHex(hex) ?? fallback
    }

    if lowercased.hasPrefix("rgb") {
        return colorFromRGBFunction(lowercased) ?? fallback
    }

    return fallback
}

private func colorFromHex(_ hex: String) -> Color? {
    let expanded: String
    if hex.count == 3 || hex.count == 4 {
        expanded = hex.map { "\($0)\($0)" }.joined()
    } else {
        expanded = hex
    }

    guard expanded.count == 6 || expanded.count == 8,
          let value = Int(expanded, radix: 16) else {
        return nil
    }

    let hasAlpha = expanded.count == 8
    let redShift = hasAlpha ? 24 : 16
    let greenShift = hasAlpha ? 16 : 8
    let blueShift = hasAlpha ? 8 : 0

    let red = Double((value >> redShift) & 0xFF) / 255
    let green = Double((value >> greenShift) & 0xFF) / 255
    let blue = Double((value >> blueShift) & 0xFF) / 255
    let alpha = hasAlpha ? Double(value & 0xFF) / 255 : 1
    return Color(red: red, green: green, blue: blue, opacity: alpha)
}

private func colorFromRGBFunction(_ value: String) -> Color? {
    guard let open = value.firstIndex(of: "("),
          let close = value.lastIndex(of: ")"),
          open < close else {
        return nil
    }

    let body = value[value.index(after: open)..<close]
    let parts = body
        .split { $0 == "," || $0 == " " || $0 == "/" }
        .map(String.init)
        .filter { !$0.isEmpty }

    guard parts.count >= 3,
          let red = rgbChannel(parts[0]),
          let green = rgbChannel(parts[1]),
          let blue = rgbChannel(parts[2]) else {
        return nil
    }

    let alpha = parts.count >= 4 ? alphaChannel(parts[3]) : 1
    return Color(
        red: red,
        green: green,
        blue: blue,
        opacity: max(0, min(1, alpha))
    )
}

private func rgbChannel(_ value: String) -> Double? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasSuffix("%"),
       let percent = Double(trimmed.dropLast()) {
        return max(0, min(1, percent / 100))
    }

    guard let number = Double(trimmed) else { return nil }
    return max(0, min(255, number)) / 255
}

private func alphaChannel(_ value: String) -> Double {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasSuffix("%"),
       let percent = Double(trimmed.dropLast()) {
        return max(0, min(1, percent / 100))
    }

    return max(0, min(1, Double(trimmed) ?? 1))
}

private func namedCSSColor(_ value: String) -> Color? {
    switch value {
    case "black":
        return .black
    case "white":
        return .white
    case "red":
        return .red
    case "green":
        return .green
    case "blue":
        return .blue
    case "gray", "grey":
        return .gray
    case "yellow":
        return .yellow
    case "orange":
        return .orange
    case "purple":
        return .purple
    case "pink":
        return .pink
    case "brown":
        return .brown
    case "cyan":
        return .cyan
    case "magenta":
        return Color(red: 1, green: 0, blue: 1)
    default:
        return nil
    }
}

private func nsImageFromDataURL(_ value: String?) -> NSImage? {
    guard let value,
          value.lowercased().hasPrefix("data:image"),
          let commaIndex = value.firstIndex(of: ",") else {
        return nil
    }

    let metadata = value[..<commaIndex].lowercased()
    let payload = String(value[value.index(after: commaIndex)...])
    let data: Data?
    if metadata.contains(";base64") {
        data = Data(base64Encoded: payload)
    } else {
        data = payload.removingPercentEncoding?.data(using: .utf8)
    }

    guard let data else { return nil }
    return NSImage(data: data)
}
