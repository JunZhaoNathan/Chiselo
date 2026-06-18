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
                    Text("HTML / Chiselo 项目文件")
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
                Text("支持 HTML、HTM、XHTML 和 Chiselo 项目文件")
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
                Text("HTML精修 · 交付预检")
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

            ToolbarActionButton(title: "转为可编辑版", icon: "viewfinder") {
                model.freezeCurrentHTMLLayout()
            }
            .disabled(!model.hasOpenDocument)
            .help("捕获当前渲染结果，转换为可拖拽、可改字、可替换图片的稳定编辑版")

            MaterialDivider()

            ToolbarCommandGroup {
                ToolbarIconButton(icon: "arrow.uturn.backward", title: "撤销") {
                    model.editorCommand("undo")
                }
                .disabled(!model.hasOpenDocument || !model.canUndoEdit)
                .help(model.nextUndoLabel.map { "撤销：\($0)" } ?? "没有可撤销的编辑")

                ToolbarIconButton(icon: "arrow.uturn.forward", title: "重做") {
                    model.editorCommand("redo")
                }
                .disabled(!model.hasOpenDocument || !model.canRedoEdit)
                .help(model.nextRedoLabel.map { "重做：\($0)" } ?? "没有可重做的编辑")
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
                .help(model.documentMode == "html" ? "精修当前 HTML 页面/文档" : "在固定画布中精修当前内容")
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
        return model.documentMode == "html" ? "页面精修" : "画布精修"
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
            if (diagnostics.visualChangeCount ?? 0) > 0 {
                VisualChangeReviewCard(
                    diagnostics: diagnostics,
                    snapshots: model.htmlVisualSnapshotPair,
                    isCapturingSnapshot: model.isCapturingHTMLVisualSnapshot,
                    onRefreshSnapshot: {
                        model.refreshHTMLVisualReviewSnapshot()
                    },
                    onSelectTarget: { elementId in
                        dismiss()
                        model.selectHTMLNode(id: elementId)
                    },
                    onRevertChange: { changeKey in
                        model.revertHTMLVisualChange(changeKey: changeKey)
                    }
                )
            }
            PPTXMappingReportCard(diagnostics: diagnostics) { elementId in
                dismiss()
                model.selectHTMLNode(id: elementId)
            }
            if diagnostics.hasPPTXRepairActions {
                PPTXRepairActionCard(
                    diagnostics: diagnostics,
                    onSelectTarget: { elementId in
                        dismiss()
                        model.selectHTMLNode(id: elementId)
                    },
                    onConvertEditable: {
                        closeThen { model.freezeCurrentHTMLLayout() }
                    },
                    onExportPDF: {
                        closeThen { model.exportPDF() }
                    }
                )
            }

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

                PreflightNoteRow(icon: "rectangle.2.swap", title: "视觉变更", detail: (diagnostics.visualChangeCount ?? 0) > 0 ? "\(diagnostics.visualChangeCount ?? 0) 个对象相对打开时发生变化，导出前建议逐项复核。" : "当前画面与打开时未检测到明显对象级变化。")
                PreflightNoteRow(icon: "rectangle.split.3x1", title: "响应式", detail: diagnostics.responsiveReviewDetail)
                PreflightNoteRow(icon: "tablecells", title: "表格", detail: diagnostics.spanTableCount > 0 ? "合并单元格会降低 PPTX 对象映射稳定性。" : "普通表格仍建议导出后抽查行列和文字框。")
                PreflightNoteRow(icon: "scribble.variable", title: "矢量/SVG", detail: diagnostics.svgCount > 0 ? "SVG 或复杂矢量可能会转成形状或图片，需要复核可编辑程度。" : "未检测到明显 SVG 风险。")
                PreflightNoteRow(icon: "camera.filters", title: "视觉效果", detail: (diagnostics.pptxEffectRiskCount ?? 0) > 0 ? "\(diagnostics.pptxEffectRiskCount ?? 0) 个复杂 CSS 效果导出 PPTX 后需要复核。" : "未检测到明显复杂 CSS 效果风险。")
                PreflightNoteRow(icon: "square.stack.3d.up", title: "层叠", detail: (diagnostics.overlapCount ?? 0) > 0 ? "重叠对象导出 PPTX 后要检查层级顺序。" : "未检测到明显重叠风险。")
            }
        }
    }

    private var deckPreflightContent: some View {
        let editableSummary = model.deck?.editableVersionSummary

        return VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ExportTargetScoreCard(
                    title: "HTML",
                    subtitle: "画布导出",
                    score: 96,
                    icon: "doc.text",
                    detail: "当前内容已经是固定画布，HTML 导出风险较低。",
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
                    subtitle: editableSummary.map { "可编辑性 \($0.pptxEditabilityScore)%" } ?? "对象可编辑",
                    score: editableSummary?.pptxEditabilityScore ?? 90,
                    icon: "rectangle.on.rectangle.angled",
                    detail: editableSummary?.pptxDetail ?? "文本、图片和形状会尽量保留为可编辑对象。",
                    color: scoreColor(editableSummary?.pptxEditabilityScore ?? 90)
                )
            }

            if let editableSummary {
                EditableVersionQualityCard(summary: editableSummary, isExpanded: true)
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
        return "固定画布可导出 HTML、PDF 和 PPTX"
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
            items.append(("rectangle.on.rectangle.angled", "导出可编辑 PPTX 时，表格、SVG、复杂视觉效果、重叠对象和合并单元格需要重点复核。", Color(red: 0.78, green: 0.47, blue: 0.06)))
        } else {
            items.append(("rectangle.on.rectangle.angled", "PPTX 可编辑性风险较低，可导出后检查文本框、图片和对象层级。", Color(red: 0.06, green: 0.52, blue: 0.26)))
        }

        if (diagnostics.visualChangeCount ?? 0) > 0 {
            items.append(("rectangle.2.swap", "已检测到相对打开时的对象级视觉变化，导出前建议逐项确认改动范围是否符合预期。", Color(red: 0.78, green: 0.47, blue: 0.06)))
        }

        if diagnostics.runtimeCompatibilityRiskCount > 0 {
            items.append(("viewfinder", "脚本渲染、嵌入页面或画布内容不一定能拆成普通对象。需要像交付稿一样稳定微调时，优先转为可编辑版再精修。", Color(red: 0.78, green: 0.47, blue: 0.06)))
        }
        return items
    }
}

private struct VisualChangeReviewCard: View {
    var diagnostics: HTMLDiagnostics
    var snapshots: HTMLVisualSnapshotPair
    var isCapturingSnapshot: Bool
    var onRefreshSnapshot: () -> Void
    var onSelectTarget: (String) -> Void
    var onRevertChange: (String) -> Void

    @State private var targetIndex = 0
    @State private var selectedFilter: VisualChangeFilter = .all

    var body: some View {
        let changeCount = diagnostics.visualChangeCount ?? 0
        let previewItems = diagnostics.visualChangePreviewItems
        let filteredItems = selectedFilter.items(from: previewItems)
        let targetIds = diagnostics.visualChangeTargetIds(for: selectedFilter)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.2.swap")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(warningColor)
                    .frame(width: 22, height: 22)
                    .background(warningColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 1) {
                    Text("视觉变更复核")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(visualChangeSubtitle(changeCount: changeCount, targetCount: targetIds.count))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(warningColor)
                }

                Spacer()
            }

            Text("导出前逐项确认改动范围，避免误改文字、图片、尺寸、位置或关键样式。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if !previewItems.isEmpty {
                VisualChangeFilterPicker(
                    selection: $selectedFilter,
                    items: previewItems,
                    color: warningColor
                )
            }

            VisualSnapshotComparison(
                snapshots: snapshots,
                isCapturingSnapshot: isCapturingSnapshot,
                color: warningColor,
                onRefresh: onRefreshSnapshot
            )

            if !previewItems.isEmpty {
                if filteredItems.isEmpty {
                    VisualChangeEmptyFilter(filter: selectedFilter)
                } else {
                    VisualChangeMap(
                        items: filteredItems,
                        totalCount: selectedFilter == .all ? changeCount : filteredItems.count,
                        canvasWidth: diagnostics.visualChangePreviewCanvasWidth,
                        canvasHeight: diagnostics.visualChangePreviewCanvasHeight,
                        color: warningColor,
                        onSelectTarget: onSelectTarget
                    )

                    VisualChangePreviewList(
                        items: Array(filteredItems.prefix(6)),
                        totalCount: selectedFilter == .all ? changeCount : filteredItems.count,
                        previewCount: filteredItems.count,
                        color: warningColor,
                        onSelectTarget: onSelectTarget,
                        onRevertChange: onRevertChange
                    )
                }
            }

            if !targetIds.isEmpty {
                PPTXTargetNavigator(
                    title: selectedFilter == .all ? "视觉变更" : selectedFilter.title,
                    icon: "rectangle.2.swap",
                    count: targetIds.count,
                    targetIds: targetIds,
                    color: warningColor,
                    index: $targetIndex,
                    onSelectTarget: onSelectTarget
                )
            } else {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(MaterialTheme.muted)
                    Text("这次变化主要来自已删除或无法定位的对象，请结合画面和历史版本复核。")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
            }
        }
        .padding(14)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(warningColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var warningColor: Color {
        Color(red: 0.78, green: 0.47, blue: 0.06)
    }

    private func visualChangeSubtitle(changeCount: Int, targetCount: Int) -> String {
        let revertableCount = diagnostics.revertableVisualChangeCount ?? 0
        let targetPart = targetCount == 0 ? "含不可定位对象" : "\(targetCount) 处可定位"
        if revertableCount > 0 {
            return "\(changeCount) 处变化，\(targetPart)，\(revertableCount) 处可一键回退"
        }
        return "\(changeCount) 处变化，\(targetPart)"
    }
}

private struct VisualChangeFilterPicker: View {
    @Binding var selection: VisualChangeFilter
    var items: [HTMLVisualChangeItem]
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("变化类型", selection: $selection) {
                ForEach(VisualChangeFilter.allCases) { filter in
                    Text("\(filter.title) \(count(for: filter))")
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Text(selection == .all ? "显示全部对象级变化。" : "仅显示\(selection.title)相关变化。")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
        }
        .padding(8)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }

    private func count(for filter: VisualChangeFilter) -> Int {
        filter.items(from: items).count
    }
}

private struct VisualChangeEmptyFilter: View {
    var filter: VisualChangeFilter

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(MaterialTheme.muted)
            Text("当前没有\(filter.title)类变化。")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }
}

private struct VisualSnapshotComparison: View {
    var snapshots: HTMLVisualSnapshotPair
    var isCapturingSnapshot: Bool
    var color: Color
    var onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(color)
                    .frame(width: 18, height: 18)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))

                VStack(alignment: .leading, spacing: 1) {
                    Text("截图前后对照")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                }

                Spacer(minLength: 0)

                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .heavy))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(color)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                .disabled(isCapturingSnapshot)
                .help("刷新当前截图")
            }

            if snapshots.hasImages {
                LazyVGrid(columns: snapshotColumns, spacing: 8) {
                    VisualSnapshotTile(title: "打开时", image: snapshots.baseline, color: color)
                    VisualSnapshotTile(title: "当前", image: snapshots.current, color: color)
                    VisualSnapshotTile(title: "差异热图", image: snapshots.diff?.heatmap, color: diffColor)
                }

                if let diff = snapshots.diff {
                    HStack(spacing: 8) {
                        VisualDiffMetric(
                            value: percentText(diff.changedPixelRatio),
                            label: "变化像素",
                            icon: "square.grid.3x3.fill",
                            color: diffColor
                        )
                        VisualDiffMetric(
                            value: percentText(diff.averageDelta),
                            label: "平均差异",
                            icon: "waveform.path.ecg",
                            color: diffColor
                        )
                        VisualDiffMetric(
                            value: percentText(diff.maxDelta),
                            label: "峰值差异",
                            icon: "exclamationmark.triangle.fill",
                            color: diffColor
                        )
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .opacity(isCapturingSnapshot ? 1 : 0)
                    Text(isCapturingSnapshot ? "正在捕获当前画面..." : "暂无截图，点击刷新捕获当前画面。")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
            }
        }
        .padding(10)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }

    private var subtitle: String {
        if isCapturingSnapshot { return "正在刷新当前画面" }
        if let diff = snapshots.diff {
            return diff.hasMeaningfulChange ? "已生成截图差异热图" : "截图差异很轻微"
        }
        if snapshots.baseline != nil && snapshots.current != nil { return "打开时与当前画面" }
        if snapshots.baseline != nil { return "已保存打开时画面，等待当前截图" }
        if snapshots.current != nil { return "当前画面已捕获" }
        return "用于导出前人工对比"
    }

    private var snapshotColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    }

    private var diffColor: Color {
        guard let diff = snapshots.diff else { return color }
        if diff.changedPixelRatio >= 0.12 || diff.averageDelta >= 0.055 {
            return MaterialTheme.accentDanger
        }
        if diff.hasMeaningfulChange {
            return color
        }
        return Color(red: 0.06, green: 0.52, blue: 0.26)
    }

    private func percentText(_ value: Double) -> String {
        let percent = value * 100
        if percent < 0.1 && percent > 0 {
            return "<0.1%"
        }
        return "\(Int(percent.rounded()))%"
    }
}

private struct VisualSnapshotTile: View {
    var title: String
    var image: NSImage?
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(MaterialTheme.muted)

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(MaterialTheme.surfaceStrong)

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .padding(4)
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: "photo")
                            .font(.system(size: 16, weight: .heavy))
                        Text("未捕获")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(MaterialTheme.muted)
                }
            }
            .frame(height: 150)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(image == nil ? 0.10 : 0.18), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }
}

private struct VisualDiffMetric: View {
    var value: String
    var label: String
    var icon: String
    var color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
            Text(value)
                .font(.system(size: 11, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

private struct VisualChangeMap: View {
    var items: [HTMLVisualChangeItem]
    var totalCount: Int
    var canvasWidth: Int
    var canvasHeight: Int
    var color: Color
    var onSelectTarget: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(color)
                    .frame(width: 18, height: 18)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))

                VStack(alignment: .leading, spacing: 1) {
                    Text("视觉变更地图")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text(mapSubtitle)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                }

                Spacer(minLength: 0)
            }

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(MaterialTheme.surfaceStrong)
                    pageGrid
                    ForEach(items) { item in
                        heatZone(for: item, in: proxy.size)
                    }
                }
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxHeight: 230)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(color.opacity(0.18), lineWidth: 1)
            )
        }
        .padding(10)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }

    private var pageGrid: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white.opacity(0.72), MaterialTheme.surfaceTint.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Path { path in
                let step: CGFloat = 24
                let maxLine: CGFloat = 4000
                var position: CGFloat = step
                while position < maxLine {
                    path.move(to: CGPoint(x: position, y: 0))
                    path.addLine(to: CGPoint(x: position, y: maxLine))
                    path.move(to: CGPoint(x: 0, y: position))
                    path.addLine(to: CGPoint(x: maxLine, y: position))
                    position += step
                }
            }
            .stroke(MaterialTheme.primary.opacity(0.045), lineWidth: 1)
        }
    }

    private var mapSubtitle: String {
        if items.count < totalCount {
            return "显示前 \(items.count) / \(totalCount) 处热区"
        }
        return "\(totalCount) 处热区"
    }

    private var aspectRatio: CGFloat {
        let width = max(CGFloat(canvasWidth), 1)
        let height = max(CGFloat(canvasHeight), 1)
        return width / height
    }

    @ViewBuilder
    private func heatZone(for item: HTMLVisualChangeItem, in size: CGSize) -> some View {
        let rect = normalizedRect(for: item, in: size)
        let zone = RoundedRectangle(cornerRadius: 4)
            .fill(fillColor(for: item).opacity(item.elementId == nil ? 0.20 : 0.28))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(fillColor(for: item).opacity(item.elementId == nil ? 0.50 : 0.82), lineWidth: 1.4)
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .help(item.elementId == nil ? "\(item.kind)：\(item.label)" : "定位：\(item.kind) \(item.label)")

        if let elementId = item.elementId {
            Button {
                onSelectTarget(elementId)
            } label: {
                zone
            }
            .buttonStyle(.plain)
        } else {
            zone
        }
    }

    private func normalizedRect(for item: HTMLVisualChangeItem, in size: CGSize) -> CGRect {
        let width = max(CGFloat(canvasWidth), 1)
        let height = max(CGFloat(canvasHeight), 1)
        let itemX = min(max(CGFloat(item.x), 0), width)
        let itemY = min(max(CGFloat(item.y), 0), height)
        let itemW = min(max(CGFloat(item.w), 1), width - itemX)
        let itemH = min(max(CGFloat(item.h), 1), height - itemY)
        let x = itemX / width * size.width
        let y = itemY / height * size.height
        let w = max(itemW / width * size.width, 5)
        let h = max(itemH / height * size.height, 5)
        return CGRect(
            x: min(max(x, 0), max(size.width - w, 0)),
            y: min(max(y, 0), max(size.height - h, 0)),
            width: min(w, size.width),
            height: min(h, size.height)
        )
    }

    private func fillColor(for item: HTMLVisualChangeItem) -> Color {
        if item.kind.contains("删除") { return MaterialTheme.accentDanger }
        if item.kind.contains("新增") { return Color(red: 0.06, green: 0.52, blue: 0.26) }
        return color
    }
}

private struct VisualChangePreviewList: View {
    var items: [HTMLVisualChangeItem]
    var totalCount: Int
    var previewCount: Int
    var color: Color
    var onSelectTarget: (String) -> Void
    var onRevertChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("变化清单")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Spacer(minLength: 0)
                if totalCount > items.count {
                    Text("前 \(items.count) 项")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MaterialTheme.muted)
                }
            }

            ForEach(items) { item in
                VisualChangePreviewRow(item: item, color: color, onSelectTarget: onSelectTarget, onRevertChange: onRevertChange)
            }

            if totalCount > previewCount {
                Text("其余 \(totalCount - previewCount) 处变化未放入缩略预览，可通过逐项定位继续复核。")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }
}

private struct VisualChangePreviewRow: View {
    var item: HTMLVisualChangeItem
    var color: Color
    var onSelectTarget: (String) -> Void
    var onRevertChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(rowColor)
                    .frame(width: 18, height: 18)
                    .background(rowColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.label.isEmpty ? "对象" : item.label)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                        .lineLimit(1)
                    Text("\(item.kind) · x \(item.x), y \(item.y), \(item.w) x \(item.h)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MaterialTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)

                actionBar
            }

            if let detail = item.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .lineLimit(2)
            }

            if hasBeforeAfter {
                HStack(spacing: 6) {
                    VisualChangeValuePill(title: "打开时", value: item.beforeValue, color: MaterialTheme.muted)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(MaterialTheme.muted)
                    VisualChangeValuePill(title: "当前", value: item.afterValue, color: rowColor)
                }
            } else if let reason = item.revertReason, !(item.canRevert ?? false) {
                Text(reason)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(rowColor.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: 5) {
            if let changeKey = item.changeKey, item.canRevert == true {
                Button {
                    onRevertChange(changeKey)
                } label: {
                    Label("回退", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(rowColor)
                .background(rowColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .help("只回退这一处视觉变更")
            }

            if let elementId = item.elementId {
                Button {
                    onSelectTarget(elementId)
                } label: {
                    Label("定位", systemImage: "scope")
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(rowColor)
                .background(rowColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .help("定位这处变化")
            } else {
                Text("不可定位")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(MaterialTheme.muted)
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var hasBeforeAfter: Bool {
        !(item.beforeValue ?? "").isEmpty || !(item.afterValue ?? "").isEmpty
    }

    private var icon: String {
        if item.kind.contains("删除") { return "minus.square" }
        if item.kind.contains("新增") { return "plus.square" }
        if item.kind.contains("位置") || item.kind.contains("尺寸") { return "arrow.up.left.and.arrow.down.right" }
        if item.kind.contains("文字") { return "textformat" }
        if item.kind.contains("样式") { return "paintpalette" }
        return "rectangle.2.swap"
    }

    private var rowColor: Color {
        if item.kind.contains("删除") { return MaterialTheme.accentDanger }
        if item.kind.contains("新增") { return Color(red: 0.06, green: 0.52, blue: 0.26) }
        return color
    }
}

private struct VisualChangeValuePill: View {
    var title: String
    var value: String?
    var color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(color)
            Text(displayValue)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
    }

    private var displayValue: String {
        let text = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "空" : text
    }
}

private struct PPTXMappingReportCard: View {
    var diagnostics: HTMLDiagnostics
    var onSelectTarget: ((String) -> Void)?

    @State private var textTargetIndex = 0
    @State private var imageTargetIndex = 0
    @State private var shapeTargetIndex = 0
    @State private var reviewTargetIndex = 0
    @State private var fallbackTargetIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(reportColor)
                    .frame(width: 22, height: 22)
                    .background(reportColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 1) {
                    Text("PPTX 可编辑对象")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text("\(diagnostics.pptxEditableEstimate)% 预计可编辑")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(reportColor)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                MappingMetric(value: "\(diagnostics.pptxTextObjectCount ?? 0)", label: "文字", icon: "textformat", elementId: diagnostics.pptxTextElementId, action: onSelectTarget)
                MappingMetric(value: "\(diagnostics.pptxImageObjectCount ?? 0)", label: "图片", icon: "photo", elementId: diagnostics.pptxImageElementId, action: onSelectTarget)
                MappingMetric(value: "\(diagnostics.pptxShapeObjectCount ?? 0)", label: "形状", icon: "square.on.circle", elementId: diagnostics.pptxShapeElementId, action: onSelectTarget)
                MappingMetric(value: "\(diagnostics.pptxReviewObjectCount ?? 0)", label: "需复核", icon: "checklist", elementId: diagnostics.pptxReviewElementId, action: onSelectTarget)
                MappingMetric(value: "\(diagnostics.pptxFallbackObjectCount ?? 0)", label: "整体对象", icon: "rectangle.dashed", elementId: diagnostics.pptxFallbackElementId, action: onSelectTarget)
                MappingMetric(value: "\(diagnostics.pptxMappingTotalObjectCount)", label: "合计", icon: "square.grid.2x2")
            }

            if let onSelectTarget, hasTargetNavigation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("逐项定位")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)

                    if diagnostics.pptxTextTargetIds.count > 1 {
                        PPTXTargetNavigator(
                            title: "文字",
                            icon: "textformat",
                            count: diagnostics.pptxTextObjectCount ?? 0,
                            targetIds: diagnostics.pptxTextTargetIds,
                            color: MaterialTheme.primary,
                            index: $textTargetIndex,
                            onSelectTarget: onSelectTarget
                        )
                    }

                    if diagnostics.pptxImageTargetIds.count > 1 {
                        PPTXTargetNavigator(
                            title: "图片",
                            icon: "photo",
                            count: diagnostics.pptxImageObjectCount ?? 0,
                            targetIds: diagnostics.pptxImageTargetIds,
                            color: MaterialTheme.primary,
                            index: $imageTargetIndex,
                            onSelectTarget: onSelectTarget
                        )
                    }

                    if diagnostics.pptxShapeTargetIds.count > 1 {
                        PPTXTargetNavigator(
                            title: "形状",
                            icon: "square.on.circle",
                            count: diagnostics.pptxShapeObjectCount ?? 0,
                            targetIds: diagnostics.pptxShapeTargetIds,
                            color: MaterialTheme.primary,
                            index: $shapeTargetIndex,
                            onSelectTarget: onSelectTarget
                        )
                    }

                    if !diagnostics.pptxReviewTargetIds.isEmpty {
                        PPTXTargetNavigator(
                            title: "需复核",
                            icon: "checklist",
                            count: diagnostics.pptxReviewObjectCount ?? 0,
                            targetIds: diagnostics.pptxReviewTargetIds,
                            color: Color(red: 0.78, green: 0.47, blue: 0.06),
                            index: $reviewTargetIndex,
                            onSelectTarget: onSelectTarget
                        )
                    }

                    if !diagnostics.pptxFallbackTargetIds.isEmpty {
                        PPTXTargetNavigator(
                            title: "整体对象",
                            icon: "rectangle.dashed",
                            count: diagnostics.pptxFallbackObjectCount ?? 0,
                            targetIds: diagnostics.pptxFallbackTargetIds,
                            color: MaterialTheme.accentDanger,
                            index: $fallbackTargetIndex,
                            onSelectTarget: onSelectTarget
                        )
                    }
                }
                .padding(10)
                .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
            }

            Text(diagnostics.pptxMappingRecommendation)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MaterialTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(reportColor.opacity(0.20), lineWidth: 1)
        )
    }

    private var reportColor: Color {
        if diagnostics.pptxFallbackObjectCount ?? 0 > 0 { return MaterialTheme.accentDanger }
        if diagnostics.pptxReviewObjectCount ?? 0 > 0 { return Color(red: 0.78, green: 0.47, blue: 0.06) }
        return Color(red: 0.06, green: 0.52, blue: 0.26)
    }

    private var hasTargetNavigation: Bool {
        diagnostics.pptxTextTargetIds.count > 1
            || diagnostics.pptxImageTargetIds.count > 1
            || diagnostics.pptxShapeTargetIds.count > 1
            || !diagnostics.pptxReviewTargetIds.isEmpty
            || !diagnostics.pptxFallbackTargetIds.isEmpty
    }
}

private struct MappingMetric: View {
    var value: String
    var label: String
    var icon: String
    var elementId: String?
    var action: ((String) -> Void)?

    var body: some View {
        Group {
            if let elementId, let action {
                Button {
                    action(elementId)
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .foregroundStyle(MaterialTheme.primaryDark)
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(isActionable ? MaterialTheme.primary.opacity(0.18) : Color.clear, lineWidth: 1)
        )
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .help(isActionable ? "点击定位第一处\(label)" : "\(label)统计")
    }

    private var content: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
            Text(value)
                .font(.system(size: 11, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .bold))
        }
    }

    private var isActionable: Bool {
        elementId != nil && action != nil
    }

    private var backgroundColor: Color {
        isActionable ? MaterialTheme.primary.opacity(0.10) : MaterialTheme.surfaceTint
    }
}

private struct PPTXTargetNavigator: View {
    var title: String
    var icon: String
    var count: Int
    var targetIds: [String]
    var color: Color
    @Binding var index: Int
    var onSelectTarget: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Text("\(currentIndex + 1)/\(max(targetIds.count, 1)) 可定位，合计 \(count)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
            }

            Spacer(minLength: 0)

            Button {
                move(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .heavy))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(targetIds.count <= 1)
            .help("上一处\(title)")

            Button {
                onSelectTarget(targetIds[currentIndex])
            } label: {
                Label("定位", systemImage: "scope")
                    .font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 8)
                    .frame(height: 24)
            }
            .buttonStyle(.plain)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .help("定位当前\(title)")

            Button {
                move(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .heavy))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(targetIds.count <= 1)
            .help("下一处\(title)")
        }
        .foregroundStyle(MaterialTheme.primaryDark)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(color.opacity(0.16), lineWidth: 1)
        )
        .onChange(of: targetIds) { _ in
            index = currentIndex
        }
    }

    private var currentIndex: Int {
        guard !targetIds.isEmpty else { return 0 }
        return min(max(index, 0), targetIds.count - 1)
    }

    private func move(_ delta: Int) {
        guard !targetIds.isEmpty else { return }
        let nextIndex = (currentIndex + delta + targetIds.count) % targetIds.count
        index = nextIndex
        onSelectTarget(targetIds[nextIndex])
    }
}

private struct PPTXRepairActionCard: View {
    var diagnostics: HTMLDiagnostics
    var onSelectTarget: (String) -> Void
    var onConvertEditable: () -> Void
    var onExportPDF: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("建议操作")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(MaterialTheme.ink)

            VStack(spacing: 8) {
                if diagnostics.tableCount > 0 {
                    PPTXRepairActionRow(
                        icon: diagnostics.spanTableCount > 0 ? "tablecells.badge.ellipsis" : "tablecells",
                        title: "复核表格",
                        detail: diagnostics.spanTableCount > 0 ? "\(diagnostics.tableCount) 个表格，含合并单元格" : "\(diagnostics.tableCount) 个表格",
                        color: warningColor,
                        buttonTitle: "定位"
                    ) {
                        if let elementId = diagnostics.tableElementId {
                            onSelectTarget(elementId)
                        }
                    }
                    .disabled(diagnostics.tableElementId == nil)
                }

                if diagnostics.svgCount > 0 {
                    PPTXRepairActionRow(
                        icon: "scribble.variable",
                        title: "复核矢量",
                        detail: "\(diagnostics.svgCount) 个 SVG/矢量对象",
                        color: warningColor,
                        buttonTitle: "定位"
                    ) {
                        if let elementId = diagnostics.svgElementId {
                            onSelectTarget(elementId)
                        }
                    }
                    .disabled(diagnostics.svgElementId == nil)
                }

                if (diagnostics.pptxEffectRiskCount ?? 0) > 0 {
                    PPTXRepairActionRow(
                        icon: "camera.filters",
                        title: "复核效果",
                        detail: "\(diagnostics.pptxEffectRiskCount ?? 0) 个复杂视觉效果",
                        color: warningColor,
                        buttonTitle: "定位"
                    ) {
                        if let elementId = diagnostics.pptxEffectRiskElementId {
                            onSelectTarget(elementId)
                        }
                    }
                    .disabled(diagnostics.pptxEffectRiskElementId == nil)
                }

                if (diagnostics.overlapCount ?? 0) > 0 {
                    PPTXRepairActionRow(
                        icon: "square.stack.3d.up",
                        title: "复核层叠",
                        detail: "\(diagnostics.overlapCount ?? 0) 处重叠对象",
                        color: warningColor,
                        buttonTitle: "定位"
                    ) {
                        if let elementId = diagnostics.overlapElementId {
                            onSelectTarget(elementId)
                        }
                    }
                    .disabled(diagnostics.overlapElementId == nil)
                }

                if diagnostics.shouldOfferEditableConversion {
                    PPTXRepairActionRow(
                        icon: "viewfinder",
                        title: "转为可编辑版",
                        detail: diagnostics.runtimeCompatibilityDetail,
                        color: MaterialTheme.primary,
                        buttonTitle: "转换"
                    ) {
                        onConvertEditable()
                    }
                }

                if diagnostics.shouldOfferPDFFallback {
                    PPTXRepairActionRow(
                        icon: "doc.richtext",
                        title: "保真交付",
                        detail: "视觉一致优先时使用 PDF",
                        color: Color(red: 0.06, green: 0.52, blue: 0.26),
                        buttonTitle: "导出PDF"
                    ) {
                        onExportPDF()
                    }
                }
            }
        }
        .padding(14)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
    }

    private var warningColor: Color {
        Color(red: 0.78, green: 0.47, blue: 0.06)
    }
}

private struct PPTXRepairActionRow: View {
    var icon: String
    var title: String
    var detail: String
    var color: Color
    var buttonTitle: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(color)
                .frame(width: 20, height: 20)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(MaterialTheme.ink)
                Text(detail)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)

            Button(buttonTitle) {
                action()
            }
            .font(.system(size: 10, weight: .heavy))
            .buttonStyle(.plain)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(color.opacity(0.14), lineWidth: 1)
        )
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

private struct EditableVersionSummary: Equatable {
    var pageCount: Int
    var totalObjects: Int
    var editableTextCount: Int
    var replaceableImageCount: Int
    var adjustableShapeCount: Int
    var approximatedCount: Int
    var wholeObjectCount: Int
    var iframeFallbackCount: Int
    var canvasFallbackCount: Int
    var pptxEditabilityScore: Int

    var directEditableCount: Int {
        editableTextCount + replaceableImageCount + adjustableShapeCount
    }

    var fallbackDetail: String {
        if wholeObjectCount == 0 {
            return "无整体 fallback 对象"
        }

        var parts: [String] = []
        if iframeFallbackCount > 0 { parts.append("\(iframeFallbackCount) 个嵌入页面") }
        if canvasFallbackCount > 0 { parts.append("\(canvasFallbackCount) 个画布") }
        let other = wholeObjectCount - iframeFallbackCount - canvasFallbackCount
        if other > 0 { parts.append("\(other) 个媒体/嵌入对象") }
        return parts.joined(separator: "，")
    }

    var pptxDetail: String {
        if pptxEditabilityScore >= 85 {
            return "文本、图片和形状占比较高，PPTX 可编辑性较好。"
        }
        if pptxEditabilityScore >= 65 {
            return "存在近似或整体对象，PPTX 导出后需要重点复核对象层级。"
        }
        return "整体 fallback 较多，PPTX 更适合复核版式，不宜期待完全可拆编辑。"
    }

    var qualityTitle: String {
        if pptxEditabilityScore >= 85 { return "可编辑性较好" }
        if pptxEditabilityScore >= 65 { return "可编辑性中等" }
        return "需要复核"
    }

    var qualityIcon: String {
        if pptxEditabilityScore >= 85 { return "checkmark.seal.fill" }
        if pptxEditabilityScore >= 65 { return "exclamationmark.triangle.fill" }
        return "rectangle.dashed"
    }

    var qualityColor: Color {
        if pptxEditabilityScore >= 85 { return Color(red: 0.06, green: 0.52, blue: 0.26) }
        if pptxEditabilityScore >= 65 { return Color(red: 0.78, green: 0.47, blue: 0.06) }
        return MaterialTheme.accentDanger
    }
}

private struct EditableVersionQualityCard: View {
    var summary: EditableVersionSummary
    var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: summary.qualityIcon)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(summary.qualityColor)
                    .frame(width: 22, height: 22)
                    .background(summary.qualityColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("可编辑版质量")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(MaterialTheme.ink)
                    Text("\(summary.qualityTitle) · PPTX \(summary.pptxEditabilityScore)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(summary.qualityColor)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                EditableQualityMetric(value: "\(summary.editableTextCount)", label: "文本", icon: "textformat")
                EditableQualityMetric(value: "\(summary.replaceableImageCount)", label: "图片", icon: "photo")
                EditableQualityMetric(value: "\(summary.adjustableShapeCount)", label: "形状", icon: "square")
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 7) {
                    PreflightNoteRow(icon: "square.grid.2x2", title: "直接可编辑对象", detail: "\(summary.directEditableCount) / \(summary.totalObjects) 个对象可直接改字、换图或调形状")
                    PreflightNoteRow(icon: "wand.and.rays", title: "近似还原", detail: "\(summary.approximatedCount) 个伪元素或复杂视觉已转成近似对象")
                    PreflightNoteRow(icon: "rectangle.dashed", title: "整体保真", detail: summary.fallbackDetail)
                }
            } else if summary.wholeObjectCount > 0 || summary.approximatedCount > 0 {
                Text("\(summary.approximatedCount) 个近似对象，\(summary.wholeObjectCount) 个整体保真对象")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .lineLimit(2)
            } else {
                Text("当前转换结果主要由可编辑文本、图片和形状组成。")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MaterialTheme.muted)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(MaterialTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusMedium)
                .stroke(summary.qualityColor.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: MaterialTheme.shadow.opacity(0.10), radius: 8, x: 0, y: 3)
    }
}

private struct EditableQualityMetric: View {
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
        .frame(maxWidth: .infinity)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

private extension EditorDeck {
    var editableVersionSummary: EditableVersionSummary? {
        guard irVersion == "layout-ir-v1" || sourceKind == "runtime-html-snapshot" else { return nil }

        let elements = slides.flatMap(\.elements)
        guard !elements.isEmpty else { return nil }

        var editableText = 0
        var replaceableImages = 0
        var adjustableShapes = 0
        var approximated = 0
        var wholeObjects = 0
        var iframeFallbacks = 0
        var canvasFallbacks = 0

        for element in elements {
            switch element.editability {
            case "text-editable":
                editableText += 1
            case "replaceable":
                replaceableImages += 1
            case "style-editable":
                adjustableShapes += 1
            case "whole-object":
                wholeObjects += 1
                if element.tagName == "iframe" { iframeFallbacks += 1 }
                if element.tagName == "canvas" { canvasFallbacks += 1 }
            default:
                break
            }

            if element.fidelity == "approximated" {
                approximated += 1
            }
        }

        let total = elements.count
        let score = min(100, max(0,
            100
            - min(45, wholeObjects * 12)
            - min(24, approximated * 4)
            - max(0, total - editableText - replaceableImages - adjustableShapes - wholeObjects) * 2
        ))

        return EditableVersionSummary(
            pageCount: slides.count,
            totalObjects: total,
            editableTextCount: editableText,
            replaceableImageCount: replaceableImages,
            adjustableShapeCount: adjustableShapes,
            approximatedCount: approximated,
            wholeObjectCount: wholeObjects,
            iframeFallbackCount: iframeFallbacks,
            canvasFallbackCount: canvasFallbacks,
            pptxEditabilityScore: score
        )
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
        if (visualChangeCount ?? 0) > 0 {
            return "\(visualChangeCount ?? 0) 处视觉变更待复核"
        }
        return "HTML、PDF、PPTX 可进入导出复核"
    }

    var preflightIcon: String {
        if blockingExportRiskCount > 0 { return "exclamationmark.triangle.fill" }
        if pptxReviewRiskCount > 0 { return "checklist" }
        if (visualChangeCount ?? 0) > 0 { return "rectangle.2.swap" }
        return "checkmark.seal.fill"
    }

    var blockingExportRiskCount: Int {
        var count = 0
        count += brokenImages
        count += brokenMedia
        if !cleanExport { count += 1 }
        count += textOverflowCount ?? 0
        count += outOfBoundsCount ?? 0
        count += overlayBlockerCount ?? 0
        return count
    }

    var pptxReviewRiskCount: Int {
        var count = 0
        if tableCount > 0 { count += 1 }
        if spanTableCount > 0 { count += 1 }
        if svgCount > 0 { count += 1 }
        if (pptxEffectRiskCount ?? 0) > 0 { count += 1 }
        if (overlapCount ?? 0) > 0 { count += 1 }
        if runtimeCompatibilityRiskCount > 0 { count += 1 }
        return count
    }

    var runtimeCompatibilityRiskCount: Int {
        runtimeRiskCount ?? 0
    }

    var pptxNativeObjectCount: Int {
        (pptxTextObjectCount ?? 0) + (pptxImageObjectCount ?? 0) + (pptxShapeObjectCount ?? 0)
    }

    var pptxMappingTotalObjectCount: Int {
        pptxNativeObjectCount + (pptxReviewObjectCount ?? 0) + (pptxFallbackObjectCount ?? 0)
    }

    var pptxEditableEstimate: Int {
        let total = pptxMappingTotalObjectCount
        guard total > 0 else { return 100 }
        return boundedScore(Int((Double(pptxNativeObjectCount) / Double(total) * 100).rounded()))
    }

    var pptxMappingRecommendation: String {
        if (pptxFallbackObjectCount ?? 0) > 0 {
            return "存在只能整体保留或高风险对象。若目标是可编辑 PPTX，建议先转为可编辑版；若目标是视觉完全一致，优先导出 PDF。"
        }
        if (pptxReviewObjectCount ?? 0) > 0 {
            return "大部分对象可编辑导出，但表格、矢量、复杂效果或层叠对象需要导出后重点复核。"
        }
        return "主要由文字、图片和简单形状组成，适合导出可编辑 PPTX，仍建议抽查文本框和图片。"
    }

    var hasPPTXRepairActions: Bool {
        tableCount > 0
            || svgCount > 0
            || (pptxEffectRiskCount ?? 0) > 0
            || (overlapCount ?? 0) > 0
            || shouldOfferEditableConversion
            || shouldOfferPDFFallback
    }

    var shouldOfferEditableConversion: Bool {
        (pptxFallbackObjectCount ?? 0) > 0 || runtimeCompatibilityRiskCount > 0
    }

    var shouldOfferPDFFallback: Bool {
        (pptxFallbackObjectCount ?? 0) > 0
            || (pptxEffectRiskCount ?? 0) > 0
            || pptxEditabilityScore < 65
    }

    var pptxTextTargetIds: [String] {
        normalizedTargetIds(pptxTextElementIds, fallback: pptxTextElementId)
    }

    var pptxImageTargetIds: [String] {
        normalizedTargetIds(pptxImageElementIds, fallback: pptxImageElementId)
    }

    var pptxShapeTargetIds: [String] {
        normalizedTargetIds(pptxShapeElementIds, fallback: pptxShapeElementId)
    }

    var pptxReviewTargetIds: [String] {
        normalizedTargetIds(pptxReviewElementIds, fallback: pptxReviewElementId)
    }

    var pptxFallbackTargetIds: [String] {
        normalizedTargetIds(pptxFallbackElementIds, fallback: pptxFallbackElementId)
    }

    var visualChangePreviewCanvasWidth: Int {
        if let visualChangeCanvasWidth, visualChangeCanvasWidth > 0 {
            return visualChangeCanvasWidth
        }
        return max(visualChangePreviewItems.map { $0.x + $0.w }.max() ?? 1, 1)
    }

    var visualChangePreviewCanvasHeight: Int {
        if let visualChangeCanvasHeight, visualChangeCanvasHeight > 0 {
            return visualChangeCanvasHeight
        }
        return max(visualChangePreviewItems.map { $0.y + $0.h }.max() ?? 1, 1)
    }

    var runtimeCompatibilityDetail: String {
        let risks = runtimeCompatibilityRiskCount
        if risks == 0 {
            return "普通 HTML 对象，可直接精修"
        }

        var parts: [String] = []
        if (scriptCount ?? 0) > 0 || (runtimeRootCount ?? 0) > 0 {
            parts.append("脚本渲染")
        }
        if (iframeCount ?? 0) > 0 {
            parts.append("\(iframeCount ?? 0) 个嵌入页面")
        }
        if (canvasCount ?? 0) > 0 {
            parts.append("\(canvasCount ?? 0) 个画布")
        }
        if (shadowRootCount ?? 0) > 0 {
            parts.append("\(shadowRootCount ?? 0) 个封装组件")
        }
        if (overlayBlockerCount ?? 0) > 0 {
            parts.append("\(overlayBlockerCount ?? 0) 个遮罩")
        }
        if (externalResourceCount ?? 0) > 0 {
            parts.append("\(externalResourceCount ?? 0) 个外部资源")
        }
        return parts.isEmpty ? "\(risks) 项动态内容风险" : parts.joined(separator: "，")
    }

    var responsiveReviewDetail: String {
        let responsiveRules = responsiveRuleCount ?? 0
        let responsiveRisks = responsiveLayoutRiskCount ?? 0
        if responsiveRisks == 0 {
            return "未检测到明显响应式规则，常规宽度复核即可。"
        }
        if responsiveRules > 0 {
            return "\(responsiveRules) 条响应式规则或容器规则，修改后建议检查窄屏和宽屏。"
        }
        return "\(responsiveRisks) 个弹性/网格/粘性布局对象，修改后建议做多宽度预览。"
    }

    var sourcePollutionReviewCount: Int {
        max(0, inlineStyleChangeCount ?? 0) + max(0, externalStylesheetCount ?? 0)
    }

    var sourcePollutionReviewDetail: String {
        let inlineChanges = inlineStyleChangeCount ?? 0
        let stylesheets = stylesheetCount ?? 0
        let externalSheets = externalStylesheetCount ?? 0
        if inlineChanges > 0 && stylesheets > 0 {
            return "\(inlineChanges) 个变化写入 inline style；原稿含 \(stylesheets) 个样式表，保存前建议抽查源码。"
        }
        if externalSheets > 0 {
            return "\(externalSheets) 个外部样式表影响 class 样式，当前以对象级写回为主。"
        }
        if inlineChanges > 0 {
            return "\(inlineChanges) 个对象发生 inline style 写回。"
        }
        return "未检测到明显源码污染风险。"
    }

    var htmlReadinessScore: Int {
        boundedScore(
            100
            - (brokenImages + brokenMedia) * 18
            - (cleanExport ? 0 : 30)
            - (textOverflowCount ?? 0) * 10
            - (outOfBoundsCount ?? 0) * 10
            - min(12, (overlayBlockerCount ?? 0) * 6)
            - min(8, (responsiveLayoutRiskCount ?? 0) * 2)
            - min(18, (overlapCount ?? 0) * 3)
        )
    }

    var pdfFidelityScore: Int {
        boundedScore(
            100
            - (brokenImages + brokenMedia) * 22
            - (textOverflowCount ?? 0) * 12
            - (outOfBoundsCount ?? 0) * 12
            - min(10, (overlayBlockerCount ?? 0) * 5)
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
            - min(22, (pptxEffectRiskCount ?? 0) * 4)
            - min(28, runtimeCompatibilityRiskCount * 4)
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
            return "PPTX 可编辑性中等，导出后重点检查表格、SVG、复杂效果、动态组件和层级。"
        }
        return "PPTX 可编辑性风险较高，建议先处理红色问题并复核复杂效果、脚本渲染、嵌入页面和整体对象。"
    }

    private func boundedScore(_ value: Int) -> Int {
        min(100, max(0, value))
    }

    private func normalizedTargetIds(_ values: [String]?, fallback: String?) -> [String] {
        var seen = Set<String>()
        var ids: [String] = []
        for value in values ?? [] {
            guard !value.isEmpty, seen.insert(value).inserted else { continue }
            ids.append(value)
        }
        if let fallback, !fallback.isEmpty, seen.insert(fallback).inserted {
            ids.append(fallback)
        }
        return ids
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
            Text("覆盖保存 HTML 或 Chiselo 项目文件后，Chiselo 会自动把旧版本放进 `.chiselo-history`，之后就能在这里复查和恢复。")
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

                    if let summary = model.deck?.editableVersionSummary {
                        EditableVersionQualityCard(summary: summary, isExpanded: false)
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

                if (diagnostics.visualChangeCount ?? 0) > 0 {
                    DeliveryCheckRow(
                        icon: "rectangle.2.swap",
                        title: "视觉变更",
                        detail: "\(diagnostics.visualChangeCount ?? 0) 个对象相对打开时变化",
                        color: warningColor,
                        isClickable: !diagnostics.visualChangeTargetIds.isEmpty
                    ) {
                        if let elementId = diagnostics.visualChangeTargetIds.first {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if diagnostics.runtimeCompatibilityRiskCount > 0 {
                    DeliveryCheckRow(
                        icon: "wand.and.rays",
                        title: "动态内容风险",
                        detail: diagnostics.runtimeCompatibilityDetail,
                        color: warningColor,
                        isClickable: diagnostics.runtimeRiskElementId != nil
                    ) {
                        if let elementId = diagnostics.runtimeRiskElementId {
                            model.selectHTMLNode(id: elementId)
                        }
                    }
                }

                if diagnostics.responsiveLayoutRiskCount ?? 0 > 0 {
                    DeliveryCheckRow(
                        icon: "rectangle.split.3x1",
                        title: "多宽度复核",
                        detail: diagnostics.responsiveReviewDetail,
                        color: warningColor,
                        isClickable: false
                    )
                }

                if diagnostics.sourcePollutionReviewCount > 0 {
                    DeliveryCheckRow(
                        icon: "curlybraces.square",
                        title: "源码写回",
                        detail: diagnostics.sourcePollutionReviewDetail,
                        color: warningColor,
                        isClickable: false
                    )
                }

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
        case "pptx-effect-risk":
            return "camera.filters"
        case "visual-change":
            return "rectangle.2.swap"
        case "responsive-review":
            return "rectangle.split.3x1"
        case "source-pollution-review", "stylesheet-edit-review":
            return "curlybraces.square"
        case "runtime-rendered", "external-runtime-resource":
            return "wand.and.rays"
        case "iframe-content":
            return "rectangle.inset.filled"
        case "canvas-content":
            return "square.dashed"
        case "shadow-content":
            return "shippingbox"
        case "selection-overlay":
            return "rectangle.stack.badge.minus"
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

private struct GeometryMetrics {
    var element: EditorElement
    var frame: EditorElementFrame

    var frameLabel: String {
        frame.label?.isEmpty == false ? frame.label! : "画布"
    }

    var left: Double { element.x - frame.x }
    var top: Double { element.y - frame.y }
    var right: Double { frame.x + frame.w - element.x - element.w }
    var bottom: Double { frame.y + frame.h - element.y - element.h }
    var centerXOffset: Double { element.x + element.w / 2 - (frame.x + frame.w / 2) }
    var centerYOffset: Double { element.y + element.h / 2 - (frame.y + frame.h / 2) }

    var summary: String {
        [
            "对象: \(element.chiseloTypeLabel)",
            "位置: X \(rounded(element.x)), Y \(rounded(element.y)), W \(rounded(element.w)), H \(rounded(element.h))",
            "\(frameLabel): W \(rounded(frame.w)), H \(rounded(frame.h))",
            "边距: 左 \(rounded(left)), 上 \(rounded(top)), 右 \(rounded(right)), 下 \(rounded(bottom))",
            "中心偏移: X \(signed(centerXOffset)), Y \(signed(centerYOffset))"
        ].joined(separator: "\n")
    }

    private func rounded(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    private func signed(_ value: Double) -> String {
        let roundedValue = Int(value.rounded())
        return roundedValue > 0 ? "+\(roundedValue)" : "\(roundedValue)"
    }
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
                if let status = element.chiseloEditabilityStatus {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: status.icon)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(status.color)
                            .frame(width: 18, height: 18)
                            .background(status.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.title)
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(MaterialTheme.ink)
                            Text(status.detail)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(MaterialTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(9)
                    .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
                }
                if element.groupLabel != nil || element.groupId != nil {
                    GroupMembershipBadge(element: element, compact: false)
                    if element.type != "deck-group" {
                        CommandButton(title: "选择模块", icon: "square.3.layers.3d", command: "selectModuleGroup")
                            .help("选中所属模块，进行整组移动、对齐和吸附")
                    }
                }
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
            VStack(alignment: .leading, spacing: 12) {
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

                if let metrics = selectedGeometryMetrics {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(metrics.frameLabel, systemImage: "viewfinder")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(MaterialTheme.primary)
                            Spacer()
                            Text("\(formatMetric(metrics.frame.w)) x \(formatMetric(metrics.frame.h))")
                                .font(.caption)
                                .foregroundStyle(MaterialTheme.muted)
                        }

                        GeometryMetricGrid(metrics: metrics)

                        Button {
                            copyGeometrySummary(metrics)
                        } label: {
                            Label("复制几何", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MaterialButtonStyle(compact: true))
                        .help("复制位置、尺寸、边距和中心偏移，便于修改前后复查")
                    }
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
        GroupBox("文字") {
            VStack(alignment: .leading, spacing: 12) {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        NumberField(label: "字号", value: styleDoubleBinding(\.fontSize, defaultValue: 16))
                        NumberField(label: "字重", value: styleDoubleBinding(\.fontWeight, defaultValue: 400))
                    }
                    GridRow {
                        NumberField(label: "行高", value: styleDoubleBinding(\.lineHeight, defaultValue: 1.2), fractionLength: 2)
                        StyleTextField(label: "字体名称", value: styleStringBinding(\.fontFamily, defaultValue: "-apple-system"))
                    }
                }

                styleColorSwatches(
                    title: "文字颜色",
                    value: styleStringBinding(\.color, defaultValue: "#111827"),
                    presets: textColorPresets
                )
                StyleTextField(label: "精确颜色", value: styleStringBinding(\.color, defaultValue: "#111827"))
                styleChoiceRow(
                    title: "文字对齐",
                    value: styleStringBinding(\.textAlign, defaultValue: "left"),
                    options: textAlignmentPresets
                )
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
                styleChoiceRow(
                    title: "显示方式",
                    value: styleStringBinding(\.objectFit, defaultValue: "cover"),
                    options: imageFitPresets
                )

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
        GroupBox("外观") {
            VStack(alignment: .leading, spacing: 12) {
                styleColorSwatches(
                    title: "填充",
                    value: styleStringBinding(\.fill, defaultValue: "transparent"),
                    presets: fillColorPresets
                )
                StyleTextField(label: "精确填充", value: styleStringBinding(\.fill, defaultValue: "transparent"))
                styleColorSwatches(
                    title: "描边",
                    value: styleStringBinding(\.stroke, defaultValue: "transparent"),
                    presets: strokeColorPresets
                )
                StyleTextField(label: "精确描边", value: styleStringBinding(\.stroke, defaultValue: "transparent"))

                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        NumberField(label: "边框", value: styleDoubleBinding(\.strokeWidth, defaultValue: 0))
                        NumberField(label: "圆角", value: styleDoubleBinding(\.radius, defaultValue: 0))
                    }
                }

                styleChoiceRow(
                    title: "阴影",
                    value: styleStringBinding(\.shadow, defaultValue: "none"),
                    options: shadowPresets
                )
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
                styleColorSwatches(
                    title: "单元格填充",
                    value: styleStringBinding(\.fill, defaultValue: "transparent"),
                    presets: fillColorPresets
                )
                styleColorSwatches(
                    title: "单元格文字",
                    value: styleStringBinding(\.color, defaultValue: "#111827"),
                    presets: textColorPresets
                )
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        StyleTextField(label: "精确填充", value: styleStringBinding(\.fill, defaultValue: "transparent"))
                        StyleTextField(label: "精确文字", value: styleStringBinding(\.color, defaultValue: "#111827"))
                    }
                    GridRow {
                        StyleTextField(label: "边框", value: styleStringBinding(\.stroke, defaultValue: "transparent"))
                        NumberField(label: "宽度", value: styleDoubleBinding(\.strokeWidth, defaultValue: 0))
                    }
                    GridRow {
                        NumberField(label: "圆角", value: styleDoubleBinding(\.radius, defaultValue: 0))
                        StyleTextField(label: "精确对齐", value: styleStringBinding(\.textAlign, defaultValue: "left"))
                    }
                }

                styleChoiceRow(
                    title: "单元格对齐",
                    value: styleStringBinding(\.textAlign, defaultValue: "left"),
                    options: textAlignmentPresets
                )

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

                if element.type == "html-group" || element.type == "deck-group" {
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

    private var selectedGeometryMetrics: GeometryMetrics? {
        guard let element = model.selectedElement else { return nil }
        let frame = element.frame ?? selectedCanvasFrame
        guard let frame else { return nil }
        return GeometryMetrics(element: element, frame: frame)
    }

    private var selectedCanvasFrame: EditorElementFrame? {
        if let canvas = model.deck?.canvas {
            return EditorElementFrame(label: "画布", x: 0, y: 0, w: canvas.width, h: canvas.height)
        }

        if model.documentMode == "html", let element = model.selectedElement {
            return EditorElementFrame(label: "画布", x: 0, y: 0, w: max(element.x + element.w, element.w), h: max(element.y + element.h, element.h))
        }

        return nil
    }

    private func copyGeometrySummary(_ metrics: GeometryMetrics) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(metrics.summary, forType: .string)
        model.status = "已复制几何复核信息"
    }

    private func formatMetric(_ value: Double) -> String {
        String(Int(value.rounded()))
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

    private var textAlignmentPresets: [StylePresetOption] {
        [
            StylePresetOption(title: "左", value: "left", icon: "text.alignleft"),
            StylePresetOption(title: "中", value: "center", icon: "text.aligncenter"),
            StylePresetOption(title: "右", value: "right", icon: "text.alignright")
        ]
    }

    private var imageFitPresets: [StylePresetOption] {
        [
            StylePresetOption(title: "裁切", value: "cover", icon: "crop"),
            StylePresetOption(title: "完整", value: "contain", icon: "rectangle.dashed"),
            StylePresetOption(title: "拉伸", value: "fill", icon: "arrow.left.and.right")
        ]
    }

    private var shadowPresets: [StylePresetOption] {
        [
            StylePresetOption(title: "无", value: "none", icon: "circle.slash"),
            StylePresetOption(title: "柔和", value: "0 10px 24px rgba(15, 23, 42, 0.16)", icon: "square"),
            StylePresetOption(title: "明显", value: "0 18px 44px rgba(15, 23, 42, 0.24)", icon: "square.fill")
        ]
    }

    private var textColorPresets: [StyleColorPreset] {
        [
            StyleColorPreset(title: "深色", value: "#111827"),
            StyleColorPreset(title: "灰色", value: "#4b5563"),
            StyleColorPreset(title: "蓝色", value: "#0a84ff"),
            StyleColorPreset(title: "红色", value: "#c0262d"),
            StyleColorPreset(title: "白色", value: "#ffffff")
        ]
    }

    private var fillColorPresets: [StyleColorPreset] {
        [
            StyleColorPreset(title: "透明", value: "transparent"),
            StyleColorPreset(title: "白色", value: "#ffffff"),
            StyleColorPreset(title: "浅灰", value: "#f3f6fb"),
            StyleColorPreset(title: "浅蓝", value: "#e8f3ff"),
            StyleColorPreset(title: "浅绿", value: "#eaf7ef"),
            StyleColorPreset(title: "浅黄", value: "#fff6d8")
        ]
    }

    private var strokeColorPresets: [StyleColorPreset] {
        [
            StyleColorPreset(title: "透明", value: "transparent"),
            StyleColorPreset(title: "浅灰", value: "#d9e1e8"),
            StyleColorPreset(title: "深灰", value: "#6b7280"),
            StyleColorPreset(title: "蓝色", value: "#0a84ff"),
            StyleColorPreset(title: "红色", value: "#c0262d")
        ]
    }

    private func styleChoiceRow(title: String, value: Binding<String>, options: [StylePresetOption]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(MaterialTheme.primary)
            HStack(spacing: 8) {
                ForEach(options) { option in
                    StyleChoiceButton(option: option, selection: value)
                }
            }
        }
    }

    private func styleColorSwatches(title: String, value: Binding<String>, presets: [StyleColorPreset]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(MaterialTheme.primary)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 34, maximum: 38), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(presets) { preset in
                    StyleSwatchButton(preset: preset, selection: value)
                }
            }
        }
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

private struct GroupMembershipBadge: View {
    var element: EditorElement
    var compact: Bool
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: compact ? 8 : 10, weight: .heavy))
            Text(compact ? element.chiseloGroupDisplayLabel : "所属模块：\(element.chiseloGroupDisplayLabel)")
                .font(.system(size: compact ? 9 : 10, weight: .heavy))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 6)
        .background(background, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
    }

    private var foreground: Color {
        isSelected ? Color.white.opacity(0.90) : MaterialTheme.primaryDark
    }

    private var background: Color {
        isSelected ? Color.white.opacity(0.16) : MaterialTheme.primary.opacity(0.10)
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

                    if element.groupLabel != nil || element.groupId != nil {
                        GroupMembershipBadge(element: element, compact: true, isSelected: isSelected)
                    }
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
    typealias EditabilityStatus = (title: String, detail: String, icon: String, color: Color)

    var chiseloEditabilityStatus: EditabilityStatus? {
        guard editability != nil || fidelity != nil || captureNote != nil else { return nil }

        let note = captureNote?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch editability ?? "" {
        case "text-editable":
            return ("可编辑文本", note?.isEmpty == false ? note! : "文字可直接修改，并保留当前字体、颜色和位置。", "textformat", Color(red: 0.06, green: 0.52, blue: 0.26))
        case "replaceable":
            return ("可替换图片", note?.isEmpty == false ? note! : "图片保持为独立对象，可继续替换和调整。", "photo", Color(red: 0.06, green: 0.52, blue: 0.26))
        case "style-editable":
            return ("可调样式对象", note?.isEmpty == false ? note! : "形状、背景或边框已转为可调整对象。", "square.on.square", MaterialTheme.primary)
        case "whole-object":
            return ("整体保真对象", note?.isEmpty == false ? note! : "该区域不能可靠拆分，已作为整体对象保留。", "rectangle.dashed", Color(red: 0.78, green: 0.47, blue: 0.06))
        default:
            if fidelity == "approximated" {
                return ("近似还原", note?.isEmpty == false ? note! : "复杂视觉效果已转成可编辑近似对象。", "wand.and.rays", Color(red: 0.78, green: 0.47, blue: 0.06))
            }
            return ("捕获对象", note?.isEmpty == false ? note! : "由当前渲染页面捕获。", "viewfinder", MaterialTheme.primary)
        }
    }

    var chiseloDisplayTitle: String {
        if let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }

        if let alt = imageAlt?.trimmingCharacters(in: .whitespacesAndNewlines), !alt.isEmpty {
            return alt
        }

        return chiseloTypeLabel
    }

    var chiseloGroupDisplayLabel: String {
        if let groupLabel = groupLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !groupLabel.isEmpty {
            return groupLabel
        }

        if let groupRole = groupRole?.trimmingCharacters(in: .whitespacesAndNewlines), !groupRole.isEmpty {
            return groupRole
        }

        return "模块"
    }

    var chiseloTypeLabel: String {
        if let semanticLabel, !semanticLabel.isEmpty {
            return semanticLabel
        }

        if type == "deck-group" { return "模块组" }

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
            if type == "deck-group" { return "模块组" }
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
        case "module-group":
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

private struct StylePresetOption: Identifiable {
    var title: String
    var value: String
    var icon: String?

    var id: String { value }
}

private struct StyleColorPreset: Identifiable {
    var title: String
    var value: String

    var id: String { value }
}

private struct StyleChoiceButton: View {
    var option: StylePresetOption
    @Binding var selection: String

    private var isSelected: Bool {
        selection.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == option.value.lowercased()
    }

    var body: some View {
        Button {
            selection = option.value
        } label: {
            if let icon = option.icon {
                Label(option.title, systemImage: icon)
                    .frame(maxWidth: .infinity)
            } else {
                Text(option.title)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(MaterialButtonStyle(filled: isSelected, compact: true))
    }
}

private struct StyleSwatchButton: View {
    var preset: StyleColorPreset
    @Binding var selection: String

    private var isSelected: Bool {
        selection.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == preset.value.lowercased()
    }

    var body: some View {
        Button {
            selection = preset.value
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .fill(swatchFill)
                    .overlay(transparentPattern)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(checkColor)
                }
            }
            .frame(width: 34, height: 30)
            .overlay(
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .stroke(isSelected ? MaterialTheme.primary : MaterialTheme.separator, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.title)
    }

    private var swatchFill: Color {
        cssColor(preset.value, fallback: MaterialTheme.surfaceTint)
    }

    @ViewBuilder
    private var transparentPattern: some View {
        if preset.value.lowercased() == "transparent" {
            ZStack {
                RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                    .fill(MaterialTheme.surfaceStrong)
                Path { path in
                    path.move(to: CGPoint(x: 7, y: 23))
                    path.addLine(to: CGPoint(x: 27, y: 7))
                }
                .stroke(MaterialTheme.accentDanger.opacity(0.65), lineWidth: 2)
            }
        }
    }

    private var checkColor: Color {
        preset.value.lowercased() == "#ffffff" || preset.value.lowercased() == "transparent" ? MaterialTheme.primaryDark : Color.white
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

private struct GeometryMetricGrid: View {
    var metrics: GeometryMetrics

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                GeometryMetricCell(title: "左", value: metrics.left)
                GeometryMetricCell(title: "上", value: metrics.top)
            }
            GridRow {
                GeometryMetricCell(title: "右", value: metrics.right)
                GeometryMetricCell(title: "下", value: metrics.bottom)
            }
            GridRow {
                GeometryMetricCell(title: "中心 X", value: metrics.centerXOffset, signed: true)
                GeometryMetricCell(title: "中心 Y", value: metrics.centerYOffset, signed: true)
            }
        }
    }
}

private struct GeometryMetricCell: View {
    var title: String
    var value: Double
    var signed: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(MaterialTheme.primary)
            Spacer(minLength: 6)
            Text(formattedValue)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(value < 0 ? MaterialTheme.accentDanger : MaterialTheme.ink)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(MaterialTheme.surfaceTint, in: RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: MaterialTheme.radiusSmall)
                .stroke(value < 0 ? MaterialTheme.accentDanger.opacity(0.45) : MaterialTheme.separator, lineWidth: 1)
        )
    }

    private var formattedValue: String {
        let rounded = Int(value.rounded())
        if signed, rounded > 0 {
            return "+\(rounded)"
        }
        return "\(rounded)"
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
            shadow: nil,
            textAlign: nil,
            objectFit: nil
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
