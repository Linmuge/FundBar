import SwiftUI
import AppKit

/// 基金行列宽（列头与行严格对齐）
private enum FundCols {
    static let holding: CGFloat = 112
    static let nav: CGFloat = 92
    static let change: CGFloat = 72
    static let pnl: CGFloat = 96
    static let spacing: CGFloat = 10
}

/// 应用主窗口视图
struct MainWindowView: View {
    @ObservedObject var viewModel: FundViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow
    @State private var showAddFund = false
    @State private var showEditHolding = false
    @State private var editingFundCode: String?
    @State private var editingFundName: String?
    @State private var editHoldingInputMode = 0

    private let pageLeadingInset: CGFloat = 20
    private let pageTrailingInset: CGFloat = 20

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                header

                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: 14) {
                            portfolioHero
                            secondaryMetrics

                            HStack(alignment: .top, spacing: 16) {
                                portfolioPanel

                                VStack(spacing: 16) {
                                    analyticsPanel
                                    quickSettingsPanel
                                    recentTradesPanel
                                }
                                .frame(width: 320)
                            }
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
                        .padding(.leading, pageLeadingInset)
                        .padding(.trailing, pageTrailingInset)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .frame(minWidth: proxy.size.width, alignment: .top)
                    }
                }
            }

            if showEditHolding, let code = editingFundCode, let name = editingFundName {
                editHoldingOverlay(code: code, name: name)
            }
        }
        .frame(minWidth: 920, minHeight: 660)
        .fundWindowBackground()
        .background(FundWindowConfigurator())
        .ignoresSafeArea(.container, edges: .top)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: showEditHolding)
        .sheet(isPresented: $showAddFund) {
            AddFundView(viewModel: viewModel, isPresented: $showAddFund)
                .frame(width: 420)
                .padding(18)
        }
    }

    /// 标题栏：贴顶横条（非浮动圆角面板），交通灯居左、标题居中、工具居右
    private var header: some View {
        HStack(spacing: 8) {
            // 左侧预留给交通灯（由 FundWindowConfigurator 定位）
            Color.clear
                .frame(width: 100, height: 1)
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            sortMenu

            Button {
                openWindow(id: "ai-analysis")
            } label: {
                Label("AI 分析", systemImage: "sparkles")
            }
            .fundGlassButtonStyle()
            .buttonBorderShape(.capsule)
            .help("打开 AI 分析")

            Button {
                Task { await viewModel.refresh(reloadHistory: true) }
            } label: {
                ToolbarIcon(systemName: "arrow.clockwise", isActive: viewModel.isLoading)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .accessibilityLabel("刷新基金估值")
            .help("刷新")

            Button {
                showAddFund = true
            } label: {
                Label("添加基金", systemImage: "plus")
            }
            .fundGlassButtonStyle(prominent: true)
            .buttonBorderShape(.capsule)
        }
        .frame(height: 52)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            Divider()
        }
        // 居中标题：绝对居中，不受左右控件挤压
        .overlay {
            HStack(spacing: 5) {
                Text("FundBar")
                    .font(.system(size: 13, weight: .semibold))
                Text("· 自选基金")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
            .allowsHitTesting(false)
        }
    }

    /// 排序：紧凑的菜单按钮（当前排序 + 下拉符）
    private var sortMenu: some View {
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
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(viewModel.sortMode.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("排序")
    }

    private func editHoldingOverlay(code: String, name: String) -> some View {
        ScrollView {
            EditHoldingView(
                viewModel: viewModel,
                isPresented: $showEditHolding,
                inputMode: $editHoldingInputMode,
                fundCode: code,
                fundName: name,
                usesPanelSurface: false
            )
        }
        .scrollIndicators(.visible)
        .frame(width: 430)
        .frame(maxHeight: .infinity)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 12)
        .padding(.top, 96)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    /// Hero：今日预估收益作为视觉中心（"我今天是涨是跌"一眼作答）
    private var portfolioHero: some View {
        let ep = viewModel.todayEstimatedProfit
        let isTrading = viewModel.isTradingDay
        let heroColor = isTrading ? Color.fundTrend(ep) : Color.secondary
        let sparkValues = buildProfitData().map(\.profit)

        return HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(viewModel.isTradingTime ? Color.green : Color.secondary)
                            .frame(width: 6, height: 6)
                            .shadow(color: viewModel.isTradingTime ? .green.opacity(0.45) : .clear, radius: 3)
                        Text(viewModel.isTradingTime ? "交易中" : (viewModel.isTradingDay ? "非交易时段" : "休市"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(heroColor)
                    }
                    Text("· 今日预估收益")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if isTrading {
                        Text(ep >= 0 ? "+" : "−")
                            .font(.system(size: 26, weight: .medium).monospacedDigit())
                            .foregroundStyle(heroColor.opacity(0.8))
                        Text(String(format: "%.2f", abs(ep)))
                            .font(.system(size: 42, weight: .semibold).monospacedDigit())
                            .foregroundStyle(heroColor)
                    } else {
                        Text("休市")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(heroColor)
                    }
                    Text("元")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(heroColor.opacity(0.55))
                }

                HStack(spacing: 12) {
                    Text("组合均值")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(isTrading ? percentText(viewModel.totalChangePercent) : "--")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(heroColor)
                    VDivider()
                    Text("总市值 ¥\(moneyText(viewModel.totalMarketValue))")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 12)

            if sparkValues.count >= 2 {
                VStack(alignment: .trailing, spacing: 6) {
                    Text("近 7 日累计")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    TrendSparkline(values: sparkValues, color: heroColor, height: 46)
                        .frame(width: 150)
                }
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .fundPanelSurface(cornerRadius: FundBarDesign.heroRadius, tint: heroColor.opacity(0.05), interactive: true)
    }

    /// 其余三个总指标，降级为安静的三联卡（不再与 hero 抢戏）
    private var secondaryMetrics: some View {
        HStack(spacing: 10) {
            SecondaryStatCard(
                title: "总市值",
                value: "¥\(moneyText(viewModel.totalMarketValue))",
                sub: "\(viewModel.funds.count) 只基金 · 全部持仓"
            )
            SecondaryStatCard(
                title: "浮动盈亏",
                value: signedMoneyText(viewModel.totalProfitLoss),
                sub: percentText(viewModel.totalProfitPercent),
                valueColor: color(for: viewModel.totalProfitLoss),
                subColor: color(for: viewModel.totalProfitLoss)
            )
            SecondaryStatCard(
                title: "已实现盈亏",
                value: signedMoneyText(viewModel.totalRealizedProfit),
                sub: viewModel.totalRealizedProfit == 0 ? "暂无卖出" : "卖出累计",
                valueColor: color(for: viewModel.totalRealizedProfit)
            )
        }
    }

    private var portfolioPanel: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("自选基金")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(viewModel.sortedFunds.count) 条记录 · 点击行管理持仓")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let time = viewModel.lastUpdateTime {
                    Text("更新 \(time, format: .dateTime.hour().minute().second())")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)

            if viewModel.sortedFunds.isEmpty {
                emptyPortfolioView
            } else {
                fundColumnHeader
                    .padding(.horizontal, 10)
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.sortedFunds) { fund in
                        MainFundRow(
                            fund: fund,
                            holding: viewModel.getWatchedFund(code: fund.fundcode),
                            isTradingDay: viewModel.isTradingDay,
                            onTap: { openEdit(fund: fund, inputMode: 0) }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
    }

    /// 列头：与基金行严格对齐的 5 列节奏
    private var fundColumnHeader: some View {
        HStack(spacing: FundCols.spacing) {
            Text("基金")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("持仓 / 均价")
                .frame(width: FundCols.holding, alignment: .trailing)
            Text("净值 / 估算")
                .frame(width: FundCols.nav, alignment: .trailing)
            Text("涨跌")
                .frame(width: FundCols.change, alignment: .trailing)
            Text("盈亏")
                .frame(width: FundCols.pnl, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.tertiary)
        .textCase(.uppercase)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private var emptyPortfolioView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("暂未添加基金")
                .font(.system(size: 14, weight: .medium))
            Button {
                showAddFund = true
            } label: {
                Label("添加基金", systemImage: "plus")
            }
            .fundGlassButtonStyle(prominent: true)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding(24)
    }

    /// 分析面板：近 7 日累计收益曲线 + 持仓配置环形图（单一干净面板，不再嵌套子卡）
    private var analyticsPanel: some View {
        let profitData = buildProfitData()
        let pieSlices = buildPieSlices()

        return Group {
            if profitData.isEmpty && pieSlices.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("添加持仓后显示图表")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .padding(16)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    // 近 7 日累计收益
                    VStack(alignment: .leading, spacing: 8) {
                        sidebarTitle("近 7 日累计收益", systemImage: "chart.xyaxis.line")
                        if profitData.count >= 2 {
                            let values = profitData.map(\.profit)
                            let last = values.last ?? 0
                            let curveColor = Color.fundTrend(last)
                            TrendSparkline(values: values, color: curveColor, height: 68)
                            HStack {
                                Text(profitData.first?.date.suffix(5) ?? "")
                                Spacer()
                                Text(signedMoneyText(last))
                                    .foregroundStyle(curveColor)
                                    .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                            }
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.tertiary)
                        } else {
                            Text("数据不足")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 68)
                        }
                    }

                    if !pieSlices.isEmpty {
                        Divider()
                        // 持仓配置
                        VStack(alignment: .leading, spacing: 10) {
                            sidebarTitle("持仓配置", systemImage: "chart.pie")
                            HStack(spacing: 14) {
                                AllocationDonut(slices: pieSlices)
                                    .frame(width: 78, height: 78)
                                VStack(alignment: .leading, spacing: 6) {
                                    let total = pieSlices.reduce(0) { $0 + $1.value }
                                    ForEach(pieSlices) { slice in
                                        HStack(spacing: 7) {
                                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                                .fill(slice.color)
                                                .frame(width: 8, height: 8)
                                            Text(slice.name)
                                                .font(.system(size: 10.5))
                                                .lineLimit(1)
                                                .foregroundStyle(.secondary)
                                            Spacer(minLength: 4)
                                            Text(String(format: "%.0f%%", total > 0 ? slice.value / total * 100 : 0))
                                                .font(.system(size: 10.5).monospacedDigit())
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
    }

    /// 侧栏小标题（图标 + 文字）
    private func sidebarTitle(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
    }

    private var quickSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarTitle("快捷设置", systemImage: "slider.horizontal.3")
                .padding(.bottom, 6)

            settingRow("菜单栏显示") {
                Picker("", selection: $viewModel.menuBarMode) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 134)
            }

            settingRow("涨跌通知") {
                Picker("", selection: $viewModel.notifyThreshold) {
                    Text("关闭").tag(0.0)
                    Text("1%").tag(1.0)
                    Text("2%").tag(2.0)
                    Text("3%").tag(3.0)
                    Text("5%").tag(5.0)
                }
                .labelsHidden()
                .frame(width: 88)
            }

            settingRow("开机自启", divider: false) {
                Toggle("", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.launchAtLogin = $0 }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
        }
        .padding(14)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius)
    }

    /// 设置行：标签左、控件右、行间细分隔线
    @ViewBuilder
    private func settingRow<C: View>(_ title: String, divider: Bool = true, @ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                content()
            }
            .padding(.vertical, 9)
            if divider {
                Divider()
            }
        }
    }

    private var recentTradesPanel: some View {
        let trades = recentTrades
        return VStack(alignment: .leading, spacing: 10) {
            sidebarTitle("最近交易", systemImage: "clock")

            if trades.isEmpty {
                Text("暂无交易记录")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(trades.enumerated()), id: \.element.id) { idx, item in
                        HStack(spacing: 9) {
                            tradeChip(item.record)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .lineLimit(1)
                                Text(tradeDetailText(item.record))
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 4)
                            if item.record.transactionType == .sell, let rp = item.record.realizedProfit, rp != 0 {
                                Text((rp >= 0 ? "+" : "−") + String(format: "%.2f", abs(rp)))
                                    .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Color.fundTrend(rp))
                            }
                        }
                        .padding(.vertical, 7)
                        .overlay(alignment: .bottom) {
                            if idx < trades.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius)
    }

    /// 交易图标：彩色圆角方块（买入=蓝、定投=橙、卖出=红）
    private func tradeChip(_ record: HoldingRecord) -> some View {
        let isSell = record.transactionType == .sell
        let isDCA = record.isDCA
        let color: Color = isSell ? .fundUp : (isDCA ? Color.fundDCA : Color.accentColor)
        let icon = isSell ? "minus" : "plus"
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color)
            .frame(width: 22, height: 22)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            )
    }

    private var recentTrades: [RecentTrade] {
        viewModel.watchedFunds.flatMap { wf in
            wf.holdings.map { record in
                RecentTrade(name: wf.name.isEmpty ? wf.code : wf.name, record: record)
            }
        }
        .suffix(5)
        .reversed()
    }

    private func openEdit(fund: Fund, inputMode: Int) {
        editingFundCode = fund.fundcode
        editingFundName = fund.name
        editHoldingInputMode = inputMode
        showEditHolding = true
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
                slices.append(HoldingPieView.PieSlice(
                    name: wf.name.isEmpty ? wf.code : String(wf.name.prefix(6)),
                    value: wf.marketValue(nav: fund.bestNav),
                    color: colors[i % colors.count]
                ))
            }
        }
        return slices
    }

    private func tradeDetailText(_ record: HoldingRecord) -> String {
        let action = record.transactionType == .sell ? "卖出" : (record.status == .pending ? "待确认" : "买入")
        let amount = record.transactionType == .sell ? record.shares : record.shares
        let date = record.date.isEmpty ? "--" : String(record.date.suffix(5))
        return "\(date) \(action) \(String(format: "%.2f", amount)) 份"
    }

    private func moneyText(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func signedMoneyText(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))"
    }

    private func percentText(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }

    private func color(for value: Double) -> Color {
        if value > 0 { return .fundUp }
        if value < 0 { return .fundDown }
        return .secondary
    }
}

private struct MainFundRow: View {
    let fund: Fund
    let holding: WatchedFund?
    let isTradingDay: Bool
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: FundCols.spacing) {
            // 基金
            VStack(alignment: .leading, spacing: 4) {
                Text(fund.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(fund.fundcode)
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(.tertiary)
                    if let type = holding?.fundType, !type.isEmpty {
                        Text(type)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(fundTypeColor(type))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(fundTypeColor(type).opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 持仓 / 均价
            Group {
                if let holding, holding.hasHolding {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(holding.shares).formatted(.number)) 份")
                            .font(.system(size: 12.5, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                        HStack(spacing: 3) {
                            Text("均价")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Text(String(format: "%.4f", holding.costPrice))
                                .font(.system(size: 10.5).monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    Text("—")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: FundCols.holding, alignment: .trailing)

            // 净值 / 估算
            VStack(alignment: .trailing, spacing: 2) {
                Text(fund.dwjz)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                if isTradingDay && !fund.isNavUpdatedToday && fund.gsz != fund.dwjz {
                    HStack(spacing: 2) {
                        Text("估")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                        Text(fund.gsz)
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(width: FundCols.nav, alignment: .trailing)

            // 涨跌
            Group {
                if isTradingDay {
                    Text(changeText)
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(changeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(changeColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                } else {
                    Text("休市")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: FundCols.change, alignment: .trailing)

            // 盈亏
            Group {
                if let holding, holding.hasHolding {
                    let pl = holding.profitLoss(nav: fund.bestNav)
                    let sign = pl >= 0 ? "+" : "−"
                    Text("\(sign)\(String(format: "%.2f", abs(pl)))")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(pl >= 0 ? Color.fundUp : Color.fundDown)
                } else {
                    Text("--")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: FundCols.pnl, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .contentShape(RoundedRectangle(cornerRadius: FundBarDesign.rowRadius, style: .continuous))
        .fundRowSurface(isHovered: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
        .help("点击管理持仓")
    }

    private var changeText: String {
        let sign = fund.changePercent >= 0 ? "+" : ""
        return "\(sign)\(fund.gszzl)%"
    }

    private var changeColor: Color {
        if fund.isUp { return .fundUp }
        if fund.isDown { return .fundDown }
        return .secondary
    }

    private func fundTypeColor(_ type: String) -> Color {
        if type.contains("股票") { return Color(red: 0.91, green: 0.35, blue: 0.05) } // #e8590c
        if type.contains("混合") { return Color(red: 0.54, green: 0.25, blue: 0.99) }  // #8a3ffc
        if type.contains("债券") { return Color(red: 0.11, green: 0.49, blue: 0.84) }  // #1c7ed6
        if type.contains("指数") { return Color(red: 0.04, green: 0.58, blue: 0.59) }  // #0a9396
        if type.contains("货币") { return .secondary }
        if type.contains("QDII") { return Color(red: 0.21, green: 0.31, blue: 0.78) }  // #364fc7
        if type.contains("FOF") { return .mint }
        return .secondary
    }
}

/// 持仓配置环形图（带浅色底环）
private struct AllocationDonut: View {
    let slices: [HoldingPieView.PieSlice]

    var body: some View {
        Canvas { context, size in
            let total = slices.reduce(0) { $0 + $1.value }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - 5
            let lineWidth: CGFloat = 9

            // 底环
            var track = Path()
            track.addArc(center: center, radius: r, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            context.stroke(track, with: .color(Color.primary.opacity(0.08)), lineWidth: lineWidth)

            guard total > 0 else { return }

            var start = Angle.degrees(-90)
            for slice in slices {
                let sweep = Angle.degrees(slice.value / total * 360)
                let end = start + sweep
                var path = Path()
                path.addArc(center: center, radius: r, startAngle: start, endAngle: end, clockwise: false)
                context.stroke(path, with: .color(slice.color), lineWidth: lineWidth)
                start = end
            }
        }
    }
}

private struct SecondaryStatCard: View {
    let title: String
    let value: String
    let sub: String
    var valueColor: Color = .primary
    var subColor: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(sub)
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundStyle(subColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .fundPanelSurface(cornerRadius: FundBarDesign.compactPanelRadius)
    }
}

private struct RecentTrade: Identifiable {
    let id = UUID()
    let name: String
    let record: HoldingRecord
}

private struct FundWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.toolbar = nil
        window.isMovableByWindowBackground = true
        alignTrafficLights(in: window)
    }

    private func alignTrafficLights(in window: NSWindow) {
        let buttons = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton)
        ].compactMap { $0 }

        guard buttons.count == 3, let superview = buttons[0].superview else { return }

        let centerYFromTop: CGFloat = 26
        let centersX: [CGFloat] = [42, 64, 86]

        for (button, centerX) in zip(buttons, centersX) {
            let targetX = centerX - button.frame.width / 2
            let targetY = superview.bounds.height - centerYFromTop - button.frame.height / 2
            button.setFrameOrigin(NSPoint(x: targetX, y: targetY))
        }
    }
}
