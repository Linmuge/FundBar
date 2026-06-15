import SwiftUI
import AppKit

struct AIAnalysisPageView: View {
    @ObservedObject var viewModel: FundViewModel
    @State private var isPromptEditorPresented = false
    @State private var promptDraft = ""

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            settingsPanel
                .frame(width: 340)

            resultPanel
        }
        .padding(20)
        .frame(minWidth: 900, minHeight: 620)
        .fundWindowBackground()
        .sheet(isPresented: $isPromptEditorPresented) {
            PromptEditorSheet(
                promptDraft: $promptDraft,
                isAnalyzing: viewModel.isAIAnalyzing,
                onReset: {
                    promptDraft = FundViewModel.defaultAISystemPrompt
                },
                onCancel: {
                    isPromptEditorPresented = false
                },
                onSave: {
                    viewModel.aiSystemPrompt = promptDraft
                    isPromptEditorPresented = false
                }
            )
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("AI 分析", systemImage: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                        Text(viewModel.isAIAnalyzing ? "正在生成基金组合建议" : "配置接口后生成当天基金组合分析")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("完整接口 URL", text: $viewModel.aiBaseURL)
                        SecureField("API Key", text: $viewModel.aiAPIKey)
                        TextField("模型", text: $viewModel.aiModel)

                        HStack {
                            Text("超时")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("", selection: $viewModel.aiTimeoutSeconds) {
                                Text("60 秒").tag(60.0)
                                Text("120 秒").tag(120.0)
                                Text("180 秒").tag(180.0)
                                Text("300 秒").tag(300.0)
                            }
                            .labelsHidden()
                            .frame(width: 96)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isAIAnalyzing)

                    promptSection

                    disclaimerSection

                    if let error = viewModel.aiErrorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        infoRow(title: "基金数", value: "\(viewModel.funds.count)")
                        infoRow(title: "今日预估", value: signedMoneyText(viewModel.todayEstimatedProfit), valueColor: Color.fundTrend(viewModel.todayEstimatedProfit))
                        infoRow(title: "浮动盈亏", value: signedMoneyText(viewModel.totalProfitLoss), valueColor: Color.fundTrend(viewModel.totalProfitLoss))
                        infoRow(title: "超时设置", value: "\(Int(viewModel.aiTimeoutSeconds)) 秒")
                        infoRow(title: "免责确认", value: viewModel.aiDisclaimerAccepted ? "已确认" : "未确认")
                    }
                }
            }
            .scrollIndicators(.hidden)

            Button {
                Task { await viewModel.analyzeTodayWithAI() }
            } label: {
                if viewModel.isAIAnalyzing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("分析中")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Label("分析今日走势", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
            }
            .fundGlassButtonStyle(prominent: true)
            .controlSize(.large)
            .disabled(!viewModel.canAnalyzeWithAI || viewModel.isAIAnalyzing)
        }
        .padding(16)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("基金交易员 Prompt", systemImage: "text.quote")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }

            Button {
                promptDraft = viewModel.aiSystemPrompt
                isPromptEditorPresented = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                    Text("编辑基金交易员 Prompt")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
            .fundGlassButtonStyle()
            .controlSize(.regular)
            .disabled(viewModel.isAIAnalyzing)

            Text("默认隐藏，点击后可查看和调整分析口吻、结构与风控要求。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI 生成与免责声明", systemImage: "exclamationmark.triangle")
                .font(.system(size: 12, weight: .semibold))

            Text("分析内容由 AI 生成，可能存在错误、遗漏或滞后，不构成投资、理财、买卖或收益承诺。基金交易由你自行判断并承担风险。点击分析会把基金代码、持仓、盈亏和历史净值等数据发送到你配置的 AI 接口。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("我已阅读并同意以上说明", isOn: $viewModel.aiDisclaimerAccepted)
                .font(.system(size: 12, weight: .medium))
                .toggleStyle(.checkbox)
                .disabled(viewModel.isAIAnalyzing)
        }
        .padding(.vertical, 4)
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("分析结果")
                            .font(.system(size: 16, weight: .semibold))
                        Text("AI 生成")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.12), in: Capsule())
                    }
                    Text("仅供参考，不构成投资建议")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    copyAnalysis()
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                .fundGlassButtonStyle()
                .controlSize(.small)
                .disabled(viewModel.aiAnalysisText.isEmpty)
            }

            if viewModel.aiAnalysisText.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 34))
                        .foregroundStyle(.tertiary)
                    Text("暂无 Markdown 分析结果")
                        .font(.system(size: 13, weight: .medium))
                    Text("生成后会按标题、列表、加粗和代码块格式显示")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    MarkdownAnalysisView(markdown: viewModel.aiAnalysisText)
                        .padding(16)
                }
                .background(Color.primary.opacity(0.024), in: RoundedRectangle(cornerRadius: FundBarDesign.compactPanelRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FundBarDesign.compactPanelRadius, style: .continuous)
                        .stroke(.primary.opacity(0.06), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
    }

    private func infoRow(title: String, value: String, valueColor: Color? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(valueColor ?? Color.primary)
        }
    }

    private func signedMoneyText(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))"
    }

    private func copyAnalysis() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.aiAnalysisText, forType: .string)
    }
}

private struct PromptEditorSheet: View {
    @Binding var promptDraft: String
    let isAnalyzing: Bool
    let onReset: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    private var canSave: Bool {
        !promptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnalyzing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("编辑基金交易员 Prompt", systemImage: "text.quote")
                        .font(.system(size: 18, weight: .semibold))
                    Text("用于控制 AI 的分析角色、输出结构和风控口径。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("恢复默认") {
                    onReset()
                }
                .controlSize(.small)
                .disabled(isAnalyzing)
            }

            TextEditor(text: $promptDraft)
                .font(.system(size: 13))
                .lineSpacing(4)
                .frame(minWidth: 600, minHeight: 360)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Color.primary.opacity(0.024), in: RoundedRectangle(cornerRadius: FundBarDesign.compactPanelRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FundBarDesign.compactPanelRadius, style: .continuous)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                )
                .disabled(isAnalyzing)

            HStack {
                Text("保存后下次分析会使用新的 Prompt。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Button("保存") {
                    onSave()
                }
                .fundGlassButtonStyle(prominent: true)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 680, height: 520)
        .fundWindowBackground()
    }
}

private struct MarkdownAnalysisView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(parse(markdown)) { block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level, let text):
            inlineText(text, font: headingFont(level), color: .primary)
                .padding(.top, level == 1 ? 4 : 2)
        case .paragraph(let text):
            inlineText(text, font: .system(size: 13), color: .primary)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                inlineText(text, font: .system(size: 13), color: .primary)
            }
        case .numbered(let index, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(index).")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
                inlineText(text, font: .system(size: 13), color: .primary)
            }
        case .quote(let text):
            inlineText(text, font: .system(size: 13), color: .secondary)
                .padding(.leading, 10)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(.secondary.opacity(0.25))
                        .frame(width: 3)
                }
        case .code(let text):
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .table(let rows):
            MarkdownTableView(rows: rows)
        case .divider:
            Divider()
        }
    }

    private func inlineText(_ text: String, font: Font, color: Color) -> some View {
        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        return Text(attributed)
            .font(font)
            .foregroundStyle(color)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1:
            return .system(size: 20, weight: .semibold)
        case 2:
            return .system(size: 17, weight: .semibold)
        default:
            return .system(size: 15, weight: .semibold)
        }
    }

    private func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var codeLines: [String] = []
        var tableLines: [String] = []
        var isInCodeBlock = false

        func appendParagraph() {
            let text = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(MarkdownBlock(id: blocks.count, kind: .paragraph(text)))
            }
            paragraph.removeAll()
        }

        func appendTable() {
            guard !tableLines.isEmpty else { return }
            if let rows = parseMarkdownTable(tableLines) {
                blocks.append(MarkdownBlock(id: blocks.count, kind: .table(rows)))
            } else {
                paragraph.append(contentsOf: tableLines)
            }
            tableLines.removeAll()
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if isInCodeBlock {
                    blocks.append(MarkdownBlock(id: blocks.count, kind: .code(codeLines.joined(separator: "\n"))))
                    codeLines.removeAll()
                    isInCodeBlock = false
                } else {
                    appendParagraph()
                    isInCodeBlock = true
                }
                continue
            }

            if isInCodeBlock {
                codeLines.append(rawLine)
                continue
            }

            if trimmed.isEmpty {
                appendTable()
                appendParagraph()
                continue
            }

            if isPotentialTableLine(trimmed) {
                appendParagraph()
                tableLines.append(rawLine)
                continue
            }

            appendTable()

            if trimmed == "---" || trimmed == "***" {
                appendParagraph()
                blocks.append(MarkdownBlock(id: blocks.count, kind: .divider))
                continue
            }

            if let heading = parseHeading(trimmed) {
                appendParagraph()
                blocks.append(MarkdownBlock(id: blocks.count, kind: .heading(level: heading.level, text: heading.text)))
                continue
            }

            if let bullet = parseBullet(trimmed) {
                appendParagraph()
                blocks.append(MarkdownBlock(id: blocks.count, kind: .bullet(bullet)))
                continue
            }

            if let numbered = parseNumbered(trimmed) {
                appendParagraph()
                blocks.append(MarkdownBlock(id: blocks.count, kind: .numbered(index: numbered.index, text: numbered.text)))
                continue
            }

            if trimmed.hasPrefix("> ") {
                appendParagraph()
                blocks.append(MarkdownBlock(id: blocks.count, kind: .quote(String(trimmed.dropFirst(2)))))
                continue
            }

            paragraph.append(rawLine)
        }

        if isInCodeBlock {
            blocks.append(MarkdownBlock(id: blocks.count, kind: .code(codeLines.joined(separator: "\n"))))
        }
        appendTable()
        appendParagraph()
        return blocks
    }

    private func parseHeading(_ line: String) -> (level: Int, text: String)? {
        let count = line.prefix { $0 == "#" }.count
        guard count > 0, count <= 3, line.dropFirst(count).first == " " else { return nil }
        return (count, String(line.dropFirst(count + 1)))
    }

    private func parseBullet(_ line: String) -> String? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    private func parseNumbered(_ line: String) -> (index: Int, text: String)? {
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let numberText = line[..<dotIndex]
        guard let index = Int(numberText) else { return nil }
        let textStart = line.index(after: dotIndex)
        guard textStart < line.endIndex, line[textStart] == " " else { return nil }
        return (index, String(line[line.index(after: textStart)...]))
    }

    private func isPotentialTableLine(_ line: String) -> Bool {
        line.contains("|") && splitTableCells(line).count >= 2
    }

    private func parseMarkdownTable(_ lines: [String]) -> [[String]]? {
        let rows = lines.map { splitTableCells($0) }
        var parsedRows: [[String]] = []
        var hasSeparator = false

        for row in rows {
            if isTableSeparator(row) {
                hasSeparator = true
                continue
            }
            parsedRows.append(row)
        }

        guard hasSeparator, !parsedRows.isEmpty else { return nil }
        return parsedRows
    }

    private func splitTableCells(_ line: String) -> [String] {
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("|") {
            text.removeFirst()
        }
        if text.hasSuffix("|") {
            text.removeLast()
        }
        return text
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    private func isTableSeparator(_ row: [String]) -> Bool {
        guard !row.isEmpty else { return false }
        return row.allSatisfy { cell in
            let text = cell.trimmingCharacters(in: .whitespaces)
            guard text.contains("-") else { return false }
            return text.allSatisfy { character in
                character == "-" || character == ":" || character == " "
            }
        }
    }
}

private struct MarkdownTableView: View {
    let rows: [[String]]

    private var columnCount: Int {
        max(rows.map(\.count).max() ?? 0, 1)
    }

    private var normalizedRows: [[String]] {
        rows.map { row in
            row + Array(repeating: "", count: max(columnCount - row.count, 0))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(normalizedRows.indices, id: \.self) { rowIndex in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<columnCount, id: \.self) { columnIndex in
                        tableCell(
                            normalizedRows[rowIndex][columnIndex],
                            isHeader: rowIndex == 0,
                            rowIndex: rowIndex,
                            columnIndex: columnIndex
                        )
                    }
                }

                if rowIndex < normalizedRows.count - 1 {
                    Divider()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tableCell(_ text: String, isHeader: Bool, rowIndex: Int, columnIndex: Int) -> some View {
        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)

        return Text(attributed)
            .font(.system(size: isHeader ? 12 : 11, weight: isHeader ? .semibold : .regular))
            .foregroundStyle(isHeader ? Color.primary : Color.primary.opacity(0.9))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(tableCellBackground(isHeader: isHeader, rowIndex: rowIndex))
            .overlay(alignment: .trailing) {
                if columnIndex < columnCount - 1 {
                    Rectangle()
                        .fill(.primary.opacity(0.06))
                        .frame(width: 1)
                }
            }
    }

    private func tableCellBackground(isHeader: Bool, rowIndex: Int) -> Color {
        if isHeader {
            return Color.primary.opacity(0.06)
        }
        return rowIndex.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.025)
    }
}

private struct MarkdownBlock: Identifiable {
    enum Kind {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bullet(String)
        case numbered(index: Int, text: String)
        case quote(String)
        case code(String)
        case table([[String]])
        case divider
    }

    let id: Int
    let kind: Kind
}
