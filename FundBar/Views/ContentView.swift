import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// 设计系统令牌（原生精炼方向：收紧圆角、克制留白）
enum FundBarDesign {
    static let menuWidth: CGFloat = 396
    static let menuCornerRadius: CGFloat = 28
    static let panelRadius: CGFloat = 18      // 收紧：22 → 18
    static let compactPanelRadius: CGFloat = 14 // 18 → 14
    static let rowRadius: CGFloat = 11          // 14 → 11
    static let controlRadius: CGFloat = 9       // 10 → 9
    static let heroRadius: CGFloat = 18
}

extension Color {
    /// 红涨绿跌 —— 精炼的中国红（非消防红）。自动适配亮/暗模式。
    static let fundUp = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil {
            return NSColor(srgbRed: 0xFF/255, green: 0x5A/255, blue: 0x4D/255, alpha: 1) // #ff5a4d 暗色
        }
        return NSColor(srgbRed: 0xD8/255, green: 0x39/255, blue: 0x2F/255, alpha: 1)    // #d8392f 亮色
    })

    /// 绿跌 —— 自信的绿。自动适配亮/暗模式。
    static let fundDown = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil {
            return NSColor(srgbRed: 0x34/255, green: 0xC7/255, blue: 0x59/255, alpha: 1) // #34c759 暗色
        }
        return NSColor(srgbRed: 0x2B/255, green: 0x9F/255, blue: 0x5E/255, alpha: 1)    // #2b9f5e 亮色
    })

    /// 定投 / 买入动作色（暖橙）
    static let fundDCA = Color(red: 0.91, green: 0.35, blue: 0.05) // #e8590c

    /// 由数值正负取语义色
    static func fundTrend(_ value: Double) -> Color {
        value > 0 ? .fundUp : (value < 0 ? .fundDown : .secondary)
    }
}

/// 主面板视图
struct ContentView: View {
    @ObservedObject var viewModel: FundViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow
    @State private var showAddFund = false
    @State private var editingFundCode: String?
    @State private var editingFundName: String?
    @State private var showEditHolding = false
    @State private var showSettings = false
    @State private var editHoldingInputMode = 0
    @State private var showCharts = UserDefaults.standard.bool(forKey: FundViewModel.showChartsKey)

    var body: some View {
        VStack(spacing: 12) {
            headerView

            if viewModel.funds.isEmpty && !viewModel.isLoading {
                emptyView
            } else {
                fundListView
            }

            if !viewModel.funds.isEmpty {
                summaryView
            }

            if showAddFund {
                AddFundView(viewModel: viewModel, isPresented: $showAddFund)
                    .transition(panelTransition)
            }

            if showEditHolding, let code = editingFundCode, let name = editingFundName {
                EditHoldingView(
                    viewModel: viewModel,
                    isPresented: $showEditHolding,
                    inputMode: $editHoldingInputMode,
                    fundCode: code,
                    fundName: name
                )
                .transition(panelTransition)
            }

            if showSettings {
                settingsView
                    .transition(panelTransition)
            }

            if showCharts && viewModel.hasAnyHolding {
                chartsSection
                    .transition(panelTransition)
            }

            footerView
        }
        .padding(12)
        .background(windowBackground)
        .frame(width: FundBarDesign.menuWidth)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 10) {
            FundIconBadge(systemName: "chart.line.uptrend.xyaxis", color: .blue, size: 15, diameter: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("基金估值")
                    .font(.system(size: 14, weight: .semibold))

                HStack(spacing: 5) {
                    Circle()
                        .fill(viewModel.isTradingTime ? .green : .secondary)
                        .frame(width: 6, height: 6)
                    Text(viewModel.isTradingTime ? "交易中" : (viewModel.isTradingDay ? "非交易时段" : "休市"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Menu {
                ForEach(FundSortMode.allCases, id: \.self) { mode in
                    Button {
                        viewModel.sortMode = mode
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                            if viewModel.sortMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                ToolbarIcon(systemName: "arrow.up.arrow.down", isActive: viewModel.sortMode != .manual)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("排序")

            Button {
                Task {
                    await viewModel.refresh(reloadHistory: true)
                }
            } label: {
                ToolbarIcon(systemName: "arrow.clockwise", isActive: viewModel.isLoading, rotatesWhenActive: true)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .accessibilityLabel("刷新基金估值")
            .help("刷新")

            Button {
                animatePanels {
                    showAddFund.toggle()
                    if showAddFund {
                        showEditHolding = false
                        showSettings = false
                    }
                }
            } label: {
                ToolbarIcon(systemName: showAddFund ? "minus" : "plus", isActive: showAddFund)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showAddFund ? "收起添加基金" : "添加基金")
            .help(showAddFund ? "收起添加" : "添加基金")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
    }

    // MARK: - Fund List

    private var fundListView: some View {
        let displayFunds = viewModel.sortedFunds
        return ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(displayFunds) { fund in
                    FundRowView(
                        fund: fund,
                        holding: viewModel.getWatchedFund(code: fund.fundcode),
                        historyData: viewModel.fundHistory[fund.fundcode] ?? [],
                        hasDCAPlan: viewModel.getWatchedFund(code: fund.fundcode)?.dcaPlan != nil,
                        isTradingDay: viewModel.isTradingDay,
                        onDelete: {
                            animatePanels {
                                viewModel.removeFund(code: fund.fundcode)
                            }
                        },
                        onEditHolding: {
                            animatePanels {
                                openEditHolding(fund: fund, inputMode: 0)
                            }
                        }
                    )
                }
            }
            .padding(8)
        }
        .frame(height: min(listIdealHeight + 16, listMaxHeight))
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius)
    }

    /// 列表理想高度
    private var listIdealHeight: CGFloat {
        let funds = viewModel.funds
        guard !funds.isEmpty else { return 80 }
        let total = funds.reduce(CGFloat(0)) { sum, fund in
            let hasHolding = viewModel.getWatchedFund(code: fund.fundcode)?.hasHolding ?? false
            let hasChart = viewModel.fundHistory[fund.fundcode] != nil
            // 基础高度 + 持仓附加 + 迷你图附加
            var rowHeight: CGFloat = 56
            if hasHolding { rowHeight += 18 }
            if hasChart { rowHeight += 8 }
            return sum + rowHeight
        }
        return total
    }

    /// 列表最大高度
    private var listMaxHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        // 图表/编辑面板展开时缩减列表高度给其他区域腾出空间
        var reserve: CGFloat = 0
        if showCharts && viewModel.hasAnyHolding { reserve += 300 }
        if showEditHolding { reserve += 200 }
        return max(screenHeight * 0.7 - reserve, 200)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.flattrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("暂未添加基金")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Text("点击右上角 + 添加自选基金")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius)
    }

    // MARK: - Summary

    /// 菜单栏 Hero：今日预估收益作为一眼答案
    private var summaryView: some View {
        let ep = viewModel.todayEstimatedProfit
        let isTrading = viewModel.isTradingDay
        let heroColor = isTrading ? Color.fundTrend(ep) : Color.secondary

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("今日预估")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    animatePanels {
                        showCharts.toggle()
                        UserDefaults.standard.set(showCharts, forKey: FundViewModel.showChartsKey)
                    }
                } label: {
                    Image(systemName: showCharts ? "chart.pie.fill" : "chart.pie")
                        .font(.system(size: 10))
                        .foregroundStyle(showCharts ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(showCharts ? "收起图表" : "展开图表")
                if isTrading {
                    Text("\(percentText(viewModel.totalChangePercent)) 均值")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(heroColor)
                } else {
                    Text("休市")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if isTrading {
                    Text(ep >= 0 ? "+" : "−")
                        .font(.system(size: 18, weight: .medium).monospacedDigit())
                        .foregroundStyle(heroColor.opacity(0.8))
                    Text(String(format: "%.2f", abs(ep)))
                        .font(.system(size: 26, weight: .semibold).monospacedDigit())
                        .foregroundStyle(heroColor)
                } else {
                    Text("休市")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(heroColor)
                }
                Text("元")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(heroColor.opacity(0.55))
                Spacer(minLength: 0)
            }

            if viewModel.hasAnyHolding {
                HStack(spacing: 0) {
                    summaryStripCell("总市值", "¥\(compact(viewModel.totalMarketValue))", .primary)
                    VDivider(height: 22)
                    summaryStripCell("浮动盈亏", signedCompact(viewModel.totalProfitLoss), Color.fundTrend(viewModel.totalProfitLoss))
                    VDivider(height: 22)
                    summaryStripCell("已实现", signedCompact(viewModel.totalRealizedProfit), Color.fundTrend(viewModel.totalRealizedProfit))
                }
                .padding(.top, 8)
            }
        }
        .padding(14)
        .fundPanelSurface(cornerRadius: 14, tint: heroColor.opacity(0.05))
    }

    private func summaryStripCell(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percentText(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }

    private func compact(_ value: Double) -> String {
        Int(value).formatted(.number)
    }

    private func signedCompact(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(Int(abs(value)).formatted(.number))"
    }

    // MARK: - Charts (#7 走势图 + #13 饼图)

    private var chartsSection: some View {
        VStack(spacing: 10) {
            let profitData = buildProfitData()
            if !profitData.isEmpty {
                ProfitChartView(data: profitData)
            }

            let pieSlices = buildPieSlices()
            if !pieSlices.isEmpty {
                HoldingPieView(slices: pieSlices)
            }
        }
        .padding(10)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
    }

    private func buildProfitData() -> [ProfitChartView.ProfitPoint] {
        let holdingFunds = viewModel.watchedFunds.filter { $0.hasHolding }
        guard !holdingFunds.isEmpty else { return [] }

        var dateSet: Set<String> = []
        for wf in holdingFunds {
            if let history = viewModel.fundHistory[wf.code] {
                for h in history { dateSet.insert(h.date) }
            }
        }
        let dates = dateSet.sorted()
        guard dates.count >= 2 else { return [] }

        return dates.map { date in
            let totalProfit = holdingFunds.reduce(0.0) { sum, wf in
                guard let history = viewModel.fundHistory[wf.code],
                      let nav = history.first(where: { $0.date == date })?.nav else { return sum }
                return sum + wf.profitLoss(nav: nav)
            }
            return ProfitChartView.ProfitPoint(date: date, profit: totalProfit)
        }
    }

    private func buildPieSlices() -> [HoldingPieView.PieSlice] {
        let colors: [Color] = [.orange, .blue, .purple, .teal, .pink, .indigo, .mint, .cyan, .yellow, .brown]
        var slices: [HoldingPieView.PieSlice] = []
        for (i, wf) in viewModel.watchedFunds.enumerated() where wf.hasHolding {
            if let fund = viewModel.funds.first(where: { $0.fundcode == wf.code }) {
                let mv = wf.marketValue(nav: fund.bestNav)
                slices.append(HoldingPieView.PieSlice(
                    name: wf.name.isEmpty ? wf.code : String(wf.name.prefix(6)),
                    value: mv,
                    color: colors[i % colors.count]
                ))
            }
        }
        return slices
    }

    // MARK: - Settings

    private var settingsView: some View {
        VStack(spacing: 12) {
            HStack {
                Label("设置", systemImage: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    animatePanels {
                        showSettings = false
                    }
                } label: {
                    ToolbarIcon(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭设置")
                .help("关闭")
            }

            // 开机自启
            HStack {
                Label("开机自启", systemImage: "power")
                    .font(.system(size: 12))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.launchAtLogin = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            // 菜单栏显示
            HStack {
                Label("菜单栏显示", systemImage: "menubar.rectangle")
                    .font(.system(size: 12))
                Spacer()
                Picker("", selection: $viewModel.menuBarMode) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .controlSize(.small)
            }

            // 涨跌通知
            HStack {
                Label("涨跌通知", systemImage: "bell")
                    .font(.system(size: 12))
                Spacer()
                Picker("", selection: $viewModel.notifyThreshold) {
                    Text("关闭").tag(0.0)
                    Text("1%").tag(1.0)
                    Text("2%").tag(2.0)
                    Text("3%").tag(3.0)
                    Text("5%").tag(5.0)
                }
                .pickerStyle(.menu)
                .fixedSize()
                .controlSize(.small)
            }

            Divider()

            // 导出 / 导入
            HStack(spacing: 12) {
                Button {
                    exportData()
                } label: {
                    Label("导出数据", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11))
                }
                .fundGlassButtonStyle()
                .controlSize(.small)

                Button {
                    importData()
                } label: {
                    Label("导入数据", systemImage: "square.and.arrow.down")
                        .font(.system(size: 11))
                }
                .fundGlassButtonStyle()
                .controlSize(.small)

                Spacer()
            }
        }
        .padding(16)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 8) {
            if let time = viewModel.lastUpdateTime {
                Text("更新: \(time, format: .dateTime.hour().minute().second())")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                openWindow(id: "main")
            } label: {
                ToolbarIcon(systemName: "macwindow", size: 11, diameter: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开主窗口")
            .help("打开主窗口")

            Button {
                openWindow(id: "ai-analysis")
            } label: {
                ToolbarIcon(systemName: "sparkles", size: 11, diameter: 26, isActive: viewModel.isAIAnalyzing)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开 AI 分析")
            .help("AI 分析")

            // 设置按钮
            Button {
                animatePanels {
                    showSettings.toggle()
                    if showSettings {
                        showAddFund = false
                        showEditHolding = false
                    }
                }
            } label: {
                ToolbarIcon(systemName: "gearshape", size: 11, diameter: 26, isActive: showSettings)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showSettings ? "收起设置" : "打开设置")
            .help("设置")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                ToolbarIcon(systemName: "power", size: 11, diameter: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("退出 FundBar")
            .help("退出")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .fundPanelSurface(cornerRadius: FundBarDesign.compactPanelRadius)
    }

    // MARK: - Data Export/Import

    private func exportData() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "FundBar_Data.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            viewModel.exportData(to: url)
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            viewModel.importData(from: url)
        }
    }

    private func openEditHolding(fund: Fund, inputMode: Int) {
        editingFundCode = fund.fundcode
        editingFundName = fund.name
        editHoldingInputMode = inputMode
        showEditHolding = true
        showAddFund = false
        showSettings = false
    }

    private var panelTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom))
    }

    private var windowBackground: some View {
        let shape = RoundedRectangle(cornerRadius: FundBarDesign.menuCornerRadius, style: .continuous)

        // 原生精炼：去掉浑浊的 accent→green 渐变，只留干净的半透明材质 + 极淡的中性提亮
        return shape
            .fill(reduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.regularMaterial))
            .overlay {
                if !reduceTransparency {
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.03),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                }
            }
            .overlay {
                shape.strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 22, x: 0, y: 12)
    }

    private func animatePanels(_ updates: () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.easeInOut(duration: 0.2), updates)
        }
    }
}

struct ToolbarIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    let systemName: String
    var size: CGFloat = 12
    var diameter: CGFloat = 28
    var isActive: Bool = false
    var rotatesWhenActive: Bool = false
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: min(FundBarDesign.controlRadius, diameter * 0.38), style: .continuous)

        icon
            .frame(width: diameter, height: diameter)
            .background {
                if #available(macOS 26.0, *), !reduceTransparency {
                    Color.clear
                } else {
                    shape.fill(isActive ? Color.accentColor.opacity(0.16) : Color.primary.opacity(isHovered ? 0.07 : 0.045))
                }
            }
            .modifier(ToolbarGlassModifier(shape: shape, tint: toolbarTint))
            .overlay {
                shape.strokeBorder(Color.primary.opacity(strokeOpacity), lineWidth: 0.65)
            }
            .contentShape(shape)
            .scaleEffect(isHovered && !reduceMotion ? 1.035 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var icon: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isActive ? Color.accentColor : (isHovered ? Color.primary : Color.secondary))
            .rotationEffect(.degrees(iconRotationDegrees))
            .animation(iconRotationAnimation, value: isActive)
    }

    private var toolbarTint: Color? {
        if isActive {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.12)
        }
        if isHovered {
            return Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05)
        }
        return nil
    }

    private var strokeOpacity: Double {
        if isActive { return colorScheme == .dark ? 0.18 : 0.12 }
        if isHovered { return colorScheme == .dark ? 0.16 : 0.10 }
        return colorScheme == .dark ? 0.10 : 0.065
    }

    private var iconRotationDegrees: Double {
        rotatesWhenActive && isActive && !reduceMotion ? 360 : 0
    }

    private var iconRotationAnimation: Animation? {
        guard rotatesWhenActive, !reduceMotion else { return nil }
        return isActive ? .linear(duration: 1).repeatForever(autoreverses: false) : .default
    }
}

struct FundIconBadge: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    let systemName: String
    let color: Color
    var size: CGFloat = 15
    var diameter: CGFloat = 32

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: min(12, diameter * 0.36), style: .continuous)

        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .frame(width: diameter, height: diameter)
            .background {
                if #available(macOS 26.0, *), !reduceTransparency {
                    Color.clear
                } else {
                    shape.fill(color.opacity(colorScheme == .dark ? 0.20 : 0.13))
                }
            }
            .modifier(ToolbarGlassModifier(shape: shape, tint: color.opacity(colorScheme == .dark ? 0.14 : 0.10)))
            .overlay {
                shape.strokeBorder(color.opacity(colorScheme == .dark ? 0.16 : 0.12), lineWidth: 0.65)
            }
    }
}

/// 紧凑趋势线（折线 + 渐变填充 + 末端高亮点）。用于 hero 与侧栏的"近 7 日累计"。
struct TrendSparkline: View {
    let values: [Double]
    var color: Color = .fundUp
    var height: CGFloat = 46
    var showFill: Bool = true

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = maxV - minV
            let safeRange = range == 0 ? 1 : range
            let stepX = size.width / CGFloat(values.count - 1)
            let plotH = size.height - 6

            var path = Path()
            for (i, v) in values.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height - CGFloat((v - minV) / safeRange) * plotH - 3
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }

            if showFill {
                var fill = path
                fill.addLine(to: CGPoint(x: size.width, y: size.height))
                fill.addLine(to: CGPoint(x: 0, y: size.height))
                fill.closeSubpath()
                context.fill(fill, with: .linearGradient(
                    Gradient(colors: [color.opacity(0.26), color.opacity(0)]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)
                ))
            }

            context.stroke(path, with: .color(color), lineWidth: 1.8)

            if let last = values.last {
                let x = CGFloat(values.count - 1) * stepX
                let y = size.height - CGFloat((last - minV) / safeRange) * plotH - 3
                context.fill(Circle().path(in: CGRect(x: x - 6, y: y - 6, width: 12, height: 12)), with: .color(color.opacity(0.18)))
                context.fill(Circle().path(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(color))
            }
        }
        .frame(height: height)
    }
}

/// 极细竖向分隔线（hero 副信息之间）
struct VDivider: View {
    var height: CGFloat = 11
    var opacity: Double = 0.1
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(opacity))
            .frame(width: 1, height: height)
    }
}

extension View {
    func fundPanelSurface(cornerRadius: CGFloat = FundBarDesign.panelRadius, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(FundPanelSurfaceModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }

    func fundRowSurface(isHovered: Bool, cornerRadius: CGFloat = FundBarDesign.rowRadius) -> some View {
        modifier(FundRowSurfaceModifier(isHovered: isHovered, cornerRadius: cornerRadius))
    }

    func fundWindowBackground() -> some View {
        modifier(FundWindowBackgroundModifier())
    }

    func fundGlassButtonStyle(prominent: Bool = false) -> some View {
        modifier(FundGlassButtonStyleModifier(prominent: prominent))
    }
}

private struct ToolbarGlassModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S
    let tint: Color?

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(.regular.tint(tint).interactive(true), in: shape)
        } else {
            content
        }
    }
}

private struct FundWindowBackgroundModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                windowBackground
                    .ignoresSafeArea()
            }
    }

    @ViewBuilder
    private var windowBackground: some View {
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else if #available(macOS 26.0, *) {
            // 原生精炼：干净的半透明材质，不再叠 accent/绿渐变
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                Rectangle()
                    .fill(.regularMaterial)
                    .opacity(colorScheme == .dark ? 0.30 : 0.40)
            }
        } else {
            Color(nsColor: .windowBackgroundColor)
        }
    }
}

private struct FundGlassButtonStyleModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            if prominent {
                content.buttonStyle(.borderedProminent)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}

private struct FundPanelSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(macOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
                .overlay {
                    shape.strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.13 : 0.08), lineWidth: 0.65)
                }
                .shadow(color: .black.opacity(interactive ? (colorScheme == .dark ? 0.18 : 0.08) : 0.035), radius: interactive ? 14 : 7, x: 0, y: interactive ? 8 : 3)
        } else if reduceTransparency {
            content
                .background(Color(nsColor: .windowBackgroundColor), in: shape)
                .overlay {
                    shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.65)
                }
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape.strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 0.65)
                }
        }
    }
}

private struct FundRowSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    let isHovered: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                if reduceTransparency {
                    shape.fill(Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.86 : 0.62))
                } else {
                    shape.fill(Color.primary.opacity(rowFillOpacity))
                }
            }
            .overlay {
                shape.strokeBorder(Color.primary.opacity(isHovered ? 0.12 : 0.06), lineWidth: 0.65)
            }
            .shadow(color: .black.opacity(isHovered && !reduceTransparency ? (colorScheme == .dark ? 0.14 : 0.06) : 0), radius: 8, x: 0, y: 4)
    }

    private var rowFillOpacity: Double {
        if isHovered {
            return colorScheme == .dark ? 0.08 : 0.055
        }
        return colorScheme == .dark ? 0.042 : 0.026
    }
}
