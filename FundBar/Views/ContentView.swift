import SwiftUI
import UniformTypeIdentifiers

/// 主面板视图
struct ContentView: View {
    @ObservedObject var viewModel: FundViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.openWindow) private var openWindow
    @State private var showAddFund = false
    @State private var editingFundCode: String?
    @State private var editingFundName: String?
    @State private var showEditHolding = false
    @State private var showSettings = false
    @State private var editHoldingInputMode = 0
    @State private var showCharts = UserDefaults.standard.bool(forKey: FundViewModel.showChartsKey)

    var body: some View {
        VStack(spacing: 10) {
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
        .padding(10)
        .background(windowBackground)
        .frame(width: 386)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(.blue.opacity(0.12), in: Circle())

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
                ToolbarIcon(systemName: "arrow.clockwise", isActive: viewModel.isLoading)
                    .rotationEffect(.degrees(viewModel.isLoading && !reduceMotion ? 360 : 0))
                    .animation(
                        reduceMotion ? nil : (viewModel.isLoading
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default),
                        value: viewModel.isLoading
                    )
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
        .fundPanelSurface(cornerRadius: 20, tint: .blue.opacity(0.08), interactive: true)
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
        .fundPanelSurface(cornerRadius: 18)
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
        .fundPanelSurface(cornerRadius: 18)
    }

    // MARK: - Summary

    private var summaryView: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                if viewModel.hasAnyHolding {
                    HStack(spacing: 4) {
                        Text("总市值")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f", viewModel.totalMarketValue))
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())

                        // 图表切换
                        Button {
                            animatePanels {
                                showCharts.toggle()
                                UserDefaults.standard.set(showCharts, forKey: FundViewModel.showChartsKey)
                            }
                        } label: {
                            Image(systemName: showCharts ? "chart.pie.fill" : "chart.pie")
                                .font(.system(size: 10))
                                .foregroundColor(showCharts ? .blue : .secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        if viewModel.isTradingDay {
                            let ep = viewModel.todayEstimatedProfit
                            let epSign = ep >= 0 ? "+" : ""
                            HStack(spacing: 2) {
                                Text("今日")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                Text("\(epSign)\(String(format: "%.2f", ep))")
                                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                                    .foregroundStyle(ep >= 0 ? .red : .green)
                            }
                        } else {
                            HStack(spacing: 2) {
                                Text("今日")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                Text("休市")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        let pl = viewModel.totalProfitLoss
                        let plSign = pl >= 0 ? "+" : ""
                        HStack(spacing: 2) {
                            Text("浮盈")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Text("\(plSign)\(String(format: "%.2f", pl))")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(pl >= 0 ? .red : .green)
                        }

                        if viewModel.totalRealizedProfit != 0 {
                            let rp = viewModel.totalRealizedProfit
                            let rpSign = rp >= 0 ? "+" : ""
                            HStack(spacing: 2) {
                                Text("已实现")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                Text("\(rpSign)\(String(format: "%.2f", rp))")
                                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                                    .foregroundStyle(rp >= 0 ? .red : .green)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Text("总收益率")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        if viewModel.totalRealizedProfit != 0 {
                            let rp = viewModel.totalRealizedProfit
                            let rpSign = rp >= 0 ? "+" : ""
                            Text("已实现 \(rpSign)\(String(format: "%.2f", rp))")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(rp >= 0 ? .red : .green)
                        } else {
                            Text("\(viewModel.funds.count) 只基金")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if viewModel.isTradingDay {
                    Text(viewModel.totalChangeDisplay)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(summaryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(summaryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                } else {
                    Text("休市")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }

                if viewModel.hasAnyHolding {
                    let pp = viewModel.totalProfitPercent
                    let ppSign = pp >= 0 ? "+" : ""
                    Text("持仓 \(ppSign)\(String(format: "%.2f", pp))%")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(pp >= 0 ? .red : .green)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .fundPanelSurface(cornerRadius: 18, tint: summaryColor.opacity(0.08))
    }

    private var summaryColor: Color {
        let avg = viewModel.totalChangePercent
        if avg > 0 { return .red }
        if avg < 0 { return .green }
        return .secondary
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
        .fundPanelSurface(cornerRadius: 18, tint: .purple.opacity(0.06), interactive: true)
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
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    importData()
                } label: {
                    Label("导入数据", systemImage: "square.and.arrow.down")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }
        }
        .padding(16)
        .fundPanelSurface(cornerRadius: 18, interactive: true)
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
        .fundPanelSurface(cornerRadius: 16)
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
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(reduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.ultraThinMaterial))
            .opacity(0.82)
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let systemName: String
    var size: CGFloat = 12
    var diameter: CGFloat = 28
    var isActive: Bool = false

    var body: some View {
        let shape = Circle()

        icon
            .frame(width: diameter, height: diameter)
            .background {
                if #available(macOS 26.0, *), !reduceTransparency {
                    Color.clear
                } else {
                    shape.fill(isActive ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.045))
                }
            }
            .modifier(ToolbarGlassModifier(shape: shape, tint: isActive ? Color.accentColor.opacity(0.10) : nil))
            .overlay {
                shape.stroke(Color.primary.opacity(isActive ? 0.10 : 0.06), lineWidth: 0.5)
            }
            .contentShape(shape)
    }

    private var icon: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
    }
}

extension View {
    func fundPanelSurface(cornerRadius: CGFloat = 18, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(FundPanelSurfaceModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }

    func fundRowSurface(isHovered: Bool, cornerRadius: CGFloat = 12) -> some View {
        modifier(FundRowSurfaceModifier(isHovered: isHovered, cornerRadius: cornerRadius))
    }

    func fundWindowBackground() -> some View {
        modifier(FundWindowBackgroundModifier())
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
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                Rectangle()
                    .fill(.regularMaterial)
                    .opacity(colorScheme == .dark ? 0.28 : 0.38)
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(colorScheme == .dark ? 0.055 : 0.04),
                        Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.20 : 0.34),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            Color(nsColor: .windowBackgroundColor)
        }
    }
}

private struct FundPanelSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(macOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
                .overlay {
                    shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        } else if reduceTransparency {
            content
                .background(Color(nsColor: .windowBackgroundColor), in: shape)
                .overlay {
                    shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

private struct FundRowSurfaceModifier: ViewModifier {
    let isHovered: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape.fill(Color.primary.opacity(isHovered ? 0.055 : 0.028))
            }
            .overlay {
                shape.stroke(Color.primary.opacity(isHovered ? 0.10 : 0.055), lineWidth: 0.5)
            }
    }
}
