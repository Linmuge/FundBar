import SwiftUI
import AppKit

/// 基金行列宽(列头与行严格对齐;列间 16pt 间距,避免相邻列内容相叠)
private enum FundCols {
    static let holding: CGFloat = 84
    static let nav: CGFloat = 108
    static let change: CGFloat = 70
    static let pnl: CGFloat = 78
    static let spacing: CGFloat = 16
}

/// 应用主窗口 —— 方向 A「通透 Clear Glass」
/// 骨架:整窗清玻璃(壁纸透窗)→ 工具条 / Hero(全宽) / 左列(三联指标 + 基金列表) + 右栏(周图表 / 快捷设置 / 最近交易)
/// 所有面板为独立浮起玻璃片,面板间呼吸缝(gutter 14)透出壁纸。
struct MainWindowView: View {
    @ObservedObject var viewModel: FundViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow
    @State private var showAddFund = false
    @State private var showEditHolding = false
    @State private var editingFundCode: String?
    @State private var editingFundName: String?
    @State private var editHoldingInputMode = 0
    @State private var showClearedFunds = false

    var body: some View {
        ZStack(alignment: .trailing) {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        portfolioHero

                        HStack(alignment: .top, spacing: FundBarDesign.gutter) {
                            VStack(spacing: FundBarDesign.gutter) {
                                secondaryMetrics
                                portfolioPanel
                            }
                            .frame(maxWidth: .infinity, alignment: .top)

                            VStack(spacing: FundBarDesign.railGap) {
                                weekPanel
                                allocationPanel
                                quickSettingsPanel
                                recentTradesPanel
                            }
                            .frame(width: 320)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(minWidth: proxy.size.width, alignment: .top)
                }
            }

            if showEditHolding {
                // 遮罩:独立于卡片滑入,慢慢淡入淡出
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { closeEditHolding() }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.45), value: showEditHolding)
                    .zIndex(1)
            }

            if showEditHolding, let code = editingFundCode, let name = editingFundName {
                editHoldingOverlay(code: code, name: name)
                    .zIndex(2) // 转场移除中仍保持在遮罩与主内容之上
            }

            if viewModel.showAIPanel {
                AIAnalysisPageView(viewModel: viewModel, onClose: {
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.1)) {
                        viewModel.showAIPanel = false
                    }
                })
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(3)
            }
        }
        .frame(minWidth: 960, minHeight: 700)
        .fundWindowBackground()
        .animation(reduceMotion ? nil : .spring(duration: 0.42, bounce: 0.12), value: showEditHolding)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.1)) {
                        viewModel.showAIPanel.toggle()
                    }
                } label: {
                    Label("AI 分析", systemImage: "sparkles")
                }
                .labelStyle(.titleAndIcon)
                .help(viewModel.showAIPanel ? "关闭 AI 分析" : "打开 AI 分析")
            }

            ToolbarItem(placement: .primaryAction) {
                sortMenu
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.refresh(reloadHistory: true) }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .help("刷新基金估值")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddFund = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .help("添加基金")
            }

        }
        .sheet(isPresented: $showAddFund) {
            AddFundView(viewModel: viewModel, isPresented: $showAddFund)
        }
    }

    // MARK: - 排序下拉(系统 Menu,macOS 26+ 自动玻璃渲染)

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
            Label("排序:\(shortSortLabel(viewModel.sortMode))", systemImage: "arrow.up.arrow.down")
                .labelStyle(.titleAndIcon)
        }
        .fixedSize()
        .help("排序")
    }

    private func shortSortLabel(_ mode: FundSortMode) -> String {
        switch mode {
        case .manual: return "手动"
        case .changeDesc: return "涨幅"
        case .changeAsc: return "跌幅"
        case .profitDesc: return "盈亏"
        }
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
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .frame(width: 448)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: FundBarDesign.panelRadius + 2, style: .continuous)
                    .fill(Color.fundCardBG)
                    .shadow(color: .black.opacity(0.22), radius: 26, x: -6, y: 0)
                    .shadow(color: .black.opacity(0.10), radius: 60, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FundBarDesign.panelRadius + 2, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                        lineWidth: 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: FundBarDesign.panelRadius + 2, style: .continuous))
            .padding(.top, 12)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private func closeEditHolding() {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.38, bounce: 0.10)) {
            showEditHolding = false
        }
    }

    // MARK: - Hero(今日预估收益,全宽玻璃卡,微红 tint)

    private var portfolioHero: some View {
        let ep = viewModel.todayEstimatedProfit
        let isTrading = viewModel.isTradingDay
        let heroColor = isTrading ? Color.fundTrend(ep) : Color.secondary
        let profitData = buildProfitData()

        return HStack(spacing: 26) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    LiveDot(size: 7, active: viewModel.isTradingTime)
                    Text("今日预估收益 · \(viewModel.isTradingTime ? "交易中" : (viewModel.isTradingDay ? "非交易时段" : "休市"))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if isTrading {
                        Text(ep >= 0 ? "+" : "−")
                            .font(.system(size: 26, weight: .medium).monospacedDigit())
                            .foregroundStyle(heroColor.opacity(0.8))
                        Text(String(format: "%.2f", abs(ep)))
                            .font(.system(size: 44, weight: .semibold).monospacedDigit())
                            .foregroundStyle(heroColor)
                            .kerning(-1.2)
                            .fundNumericTransition(text: String(format: "%.2f", abs(ep)))
                    } else {
                        Text("休市")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(heroColor)
                    }
                    Text("元")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(heroColor.opacity(0.55))
                }

                HStack(spacing: 14) {
                    Text("组合均值")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                    Text(isTrading ? percentText(viewModel.totalChangePercent) : "--")
                        .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(heroColor)
                    Text("总市值")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                    Text("¥\(moneyText(viewModel.totalMarketValue))")
                        .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.primary)
                }
            }

            Spacer(minLength: 12)

            if profitData.count >= 2 {
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("近 7 日走势")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        if isTrading {
                            Text("今日 \(signedMoneyText(ep))")
                                .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Color.fundTrendInk(ep))
                        }
                    }
                    HeroSparkline(
                        points: profitData.map { ($0.date, $0.profit) },
                        assetSeries: buildAssetSeries(dates: profitData),
                        height: 104
                    )
                    .frame(width: 352)
                }
                .frame(width: 352)
            }
        }
        .padding(.horizontal, 28)
        .frame(height: 140)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, tint: isTrading ? heroColor : nil, interactive: true)
    }

    // MARK: - 三联指标(安静数据块)

    private var secondaryMetrics: some View {
        HStack(spacing: FundBarDesign.gutter) {
            SecondaryStatCard(
                title: "总市值",
                icon: "clock",
                value: "¥\(moneyText(viewModel.totalMarketValue))",
                sub: "\(viewModel.funds.count) 只基金 · 全部持仓"
            )
            SecondaryStatCard(
                title: "浮动盈亏",
                icon: profitArrowIcon(viewModel.totalProfitLoss),
                value: signedMoneyText(viewModel.totalProfitLoss),
                sub: percentText(viewModel.totalProfitPercent),
                valueColor: Color.fundTrendInk(viewModel.totalProfitLoss),
                subColor: Color.fundTrendInk(viewModel.totalProfitLoss),
                subWeight: .semibold
            )
            SecondaryStatCard(
                title: "已实现盈亏",
                icon: "checkmark",
                value: signedMoneyText(viewModel.totalRealizedProfit),
                sub: viewModel.totalRealizedProfit == 0 ? "暂无卖出" : "卖出累计",
                valueColor: Color.fundTrendInk(viewModel.totalRealizedProfit)
            )
        }
    }

    private func profitArrowIcon(_ value: Double) -> String {
        value >= 0 ? "arrow.up.right" : "arrow.down.right"
    }

    // MARK: - 基金列表面板

    private var portfolioPanel: some View {
        // 单次求值缓存:避免同一次布局里反复过滤/查找(滚动性能)
        let funds = scopedFunds
        let cleared = clearedFunds
        let subtitle = {
            var text = "\(funds.count) 条记录 · 点击行管理持仓"
            if !cleared.isEmpty {
                text += " · \(cleared.count) 只已清仓"
            }
            return text
        }()

        return VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("自选基金")
                        .font(.system(size: 15, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let time = viewModel.lastUpdateTime {
                    Text("更新 \(time, format: .dateTime.hour().minute().second())")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

            }
            .padding(14)

            if funds.isEmpty && cleared.isEmpty {
                emptyPortfolioView
            } else {
                fundColumnHeader
                    .padding(.horizontal, 10)
                LazyVStack(spacing: 0) {
                    ForEach(Array(funds.enumerated()), id: \.element.id) { idx, fund in
                        MainFundRow(
                            fund: fund,
                            holding: viewModel.getWatchedFund(code: fund.fundcode),
                            isTradingDay: viewModel.isTradingDay,
                            isLast: idx == funds.count - 1,
                            showPnlSortArrow: viewModel.sortMode == .profitDesc,
                            onTap: { openEdit(fund: fund, inputMode: 0) }
                        )
                    }

                    if !cleared.isEmpty {
                        clearedFundsSection(cleared)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
    }

    /// 已清仓折叠分组:表头(数量 + 已实现合计)+ 展开后的行
    private func clearedFundsSection(_ cleared: [Fund]) -> some View {
        let realizedTotal = cleared.reduce(0.0) { sum, fund in
            sum + (viewModel.getWatchedFund(code: fund.fundcode)?.realizedProfit ?? 0)
        }

        return VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.15)) {
                    showClearedFunds.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showClearedFunds ? 90 : 0))
                    Text("已清仓 · \(cleared.count) 只")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text("已实现合计 \(signedMoneyText(realizedTotal))")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.fundTrendInk(realizedTotal))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showClearedFunds ? "收起已清仓" : "展开已清仓")
            .overlay(alignment: .top) {
                Rectangle().fill(Color.primary.opacity(0.10)).frame(height: 0.5)
            }

            if showClearedFunds {
                ForEach(Array(cleared.enumerated()), id: \.element.id) { idx, fund in
                    MainFundRow(
                        fund: fund,
                        holding: viewModel.getWatchedFund(code: fund.fundcode),
                        isTradingDay: viewModel.isTradingDay,
                        isLast: idx == cleared.count - 1,
                        isCleared: true,
                        showPnlSortArrow: false,
                        onTap: { openEdit(fund: fund, inputMode: 0) }
                    )
                }
            }
        }
    }

    /// 已清仓基金(有交易记录但当前份额为 0),单独折叠显示
    private var clearedFunds: [Fund] {
        viewModel.sortedFunds.filter {
            viewModel.getWatchedFund(code: $0.fundcode)?.isCleared == true
        }
    }

    /// 列表显示全部未清仓基金(已清仓的在折叠分组)
    private var scopedFunds: [Fund] {
        viewModel.sortedFunds.filter {
            !(viewModel.getWatchedFund(code: $0.fundcode)?.isCleared == true)
        }
    }

    /// 列头:与基金行严格对齐的 5 列节奏(规格同设计稿 .lhead)
    private var fundColumnHeader: some View {
        HStack(spacing: FundCols.spacing) {
            Text("基金")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("持仓均价")
                .frame(width: FundCols.holding, alignment: .trailing)
            Text("净值估算")
                .frame(width: FundCols.nav, alignment: .leading)
            Text("涨跌")
                .frame(width: FundCols.change, alignment: .center)
            HStack(spacing: 3) {
                Text("盈亏")
                if viewModel.sortMode == .profitDesc {
                    Image(systemName: "arrowdown")
                        .font(.system(size: 7, weight: .semibold))
                }
            }
            .frame(width: FundCols.pnl, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.tertiary)
        .frame(height: 30)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.10)).frame(height: 0.5)
        }
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
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding(24)
    }

    // MARK: - 右栏 · 近 7 日 + 持仓配置

    private var weekPanel: some View {
        let profitData = buildProfitData()
        let weekTotal = profitData.last?.profit

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("近 7 日盈亏")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let total = weekTotal {
                    Text(signedMoneyText(total))
                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.fundTrendInk(total))
                }
            }

            if profitData.count >= 2 {
                DailyProfitBars(daily: dailyProfits(from: profitData))
                    .padding(.top, 5)
            } else {
                Text("数据不足")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 52)
                    .padding(.top, 5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
    }

    // MARK: - 右栏 · 持仓配置(独立面板)

    private var allocationPanel: some View {
        let pieSlices = buildPieSlices()
        // 图例最多 6 行:Top 5 + 其余合并
        let legendSlices: [AllocationDonut.PieSlice] = {
            if pieSlices.count > 6 {
                let rest = pieSlices.dropFirst(5).reduce(0) { $0 + $1.value }
                return Array(pieSlices.prefix(5)) + [
                    AllocationDonut.PieSlice(name: "其他 \(pieSlices.count - 5) 只", value: rest, color: Color.secondary)
                ]
            }
            return pieSlices
        }()

        return VStack(alignment: .leading, spacing: 3) {
            Text("持仓配置 · 按市值")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            if pieSlices.isEmpty {
                Text("添加持仓后显示配置")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 78, alignment: .center)
            } else {
                HStack(spacing: 11) {
                    AllocationDonut(
                        slices: pieSlices,
                        centerTitle: "总市值",
                        centerValue: "¥\(moneyText(viewModel.totalMarketValue))"
                    )
                    .frame(width: 96, height: 96)

                    VStack(alignment: .leading, spacing: 2) {
                        let total = pieSlices.reduce(0) { $0 + $1.value }
                        ForEach(legendSlices) { slice in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(slice.color)
                                    .frame(width: 6.5, height: 6.5)
                                Text(slice.name)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 4)
                                Text(String(format: "%.0f%%", total > 0 ? slice.value / total * 100 : 0))
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
    }

    // MARK: - 右栏 · 快捷设置

    // MARK: - 右栏 · 快捷设置(设置页式行布局)

    private var quickSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text("快捷设置")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 2)

            quickSettingRow(label: "菜单栏显示", divider: true) {
                Picker("", selection: $viewModel.menuBarMode) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(shortMenuLabel(mode)).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.regular)
                .labelsHidden()
                .fixedSize()
            }

            quickSettingRow(label: "涨跌通知", divider: true) {
                Picker("", selection: $viewModel.notifyThreshold) {
                    Text("关闭").tag(0.0)
                    Text("1%").tag(1.0)
                    Text("2%").tag(2.0)
                    Text("3%").tag(3.0)
                    Text("5%").tag(5.0)
                }
                .pickerStyle(.menu)
                .controlSize(.regular)
                .labelsHidden()
                .fixedSize()
            }

            quickSettingRow(label: "开机自启", divider: false) {
                Toggle("", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.launchAtLogin = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius)
    }

    /// 设置行:标签 + 右侧下拉/控件,行间细分隔线
    @ViewBuilder
    private func quickSettingRow<C: View>(label: String, divider: Bool, @ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                content()
            }
            .padding(.vertical, 7)
            .frame(minHeight: 30)

            if divider {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 0.5)
            }
        }
    }

    private func shortMenuLabel(_ mode: MenuBarDisplayMode) -> String {
        switch mode {
        case .todayProfit: return "今日盈亏"
        case .changePercent: return "平均涨跌"
        case .totalProfit: return "总盈亏"
        case .hidden: return "仅图标"
        }
    }

    // MARK: - 右栏 · 最近交易

    private var recentTradesPanel: some View {
        let trades = recentTrades
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近交易")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.bottom, 3)

            if trades.isEmpty {
                Text("暂无交易记录")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(trades.enumerated()), id: \.element.id) { idx, item in
                        tradeRow(item)
                            .overlay(alignment: .top) {
                                if idx > 0 {
                                    Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)
                                }
                            }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(minHeight: 96)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius)
    }

    /// 交易行:日期 | 类型 chip | 名称 | 金额/已实现
    private func tradeRow(_ item: RecentTrade) -> some View {
        HStack(spacing: 7) {
            Text(item.record.date.isEmpty ? "--" : String(item.record.date.suffix(5)))
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 34, alignment: .leading)

            TradeChip(record: item.record)

            Text(item.name)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            tradeRight(item)
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func tradeRight(_ item: RecentTrade) -> some View {
        let record = item.record
        if record.transactionType == .sell, let rp = record.realizedProfit, rp != 0 {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("已实现")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text((rp >= 0 ? "+" : "−") + String(format: "%.2f", abs(rp)))
                    .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.fundTrendInk(rp))
            }
        } else if record.isDCA {
            // buyAmount 仅待确认记录有值;按份额记录的定投回退用 份额×成本 计算
            let amount = record.buyAmount ?? (record.shares * record.costPrice)
            Text("\(String(format: "%.2f", amount)) 元")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.primary)
        } else if record.status == .pending {
            Text("待确认")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        } else {
            Text("\(String(format: "%.2f", record.shares)) 份")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.primary)
        }
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

    // MARK: - 数据构建

    /// 近 7 日累计收益(真实历史净值)
    private func buildProfitData() -> [ProfitChartView.ProfitPoint] {
        let holdingFunds = viewModel.watchedFunds.filter { $0.hasHolding }
        guard !holdingFunds.isEmpty else { return [] }

        var dateSet: Set<String> = []
        for wf in holdingFunds {
            if let history = viewModel.fundHistory[wf.code] {
                for h in history { dateSet.insert(h.date) }
            }
        }
        let dates = Array(dateSet.sorted().suffix(8)) // 近 7 日:8 个净值日 → 7 根日盈亏柱
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

    /// 累计序列 → 每日盈亏
    private func dailyProfits(from data: [ProfitChartView.ProfitPoint]) -> [(date: String, profit: Double)] {
        guard data.count >= 2 else { return [] }
        return (1..<data.count).map { i in
            (date: data[i].date, profit: data[i].profit - data[i - 1].profit)
        }
    }

    /// 总资产趋势:当前持仓按各历史日净值估算的市值总和(与收益序列同期)
    private func buildAssetSeries(dates: [ProfitChartView.ProfitPoint]) -> [Double]? {
        let holdingFunds = viewModel.watchedFunds.filter { $0.hasHolding }
        guard !holdingFunds.isEmpty, dates.count >= 2 else { return nil }

        var values: [Double] = []
        for p in dates {
            let total = holdingFunds.reduce(0.0) { sum, wf in
                guard let history = viewModel.fundHistory[wf.code],
                      let nav = history.first(where: { $0.date == p.date })?.nav else { return sum }
                return sum + wf.marketValue(nav: nav)
            }
            values.append(total)
        }
        return values.count >= 2 ? values : nil
    }

    /// 持仓配置(类型色,按市值降序)
    private func buildPieSlices() -> [AllocationDonut.PieSlice] {
        var slices: [AllocationDonut.PieSlice] = []
        for wf in viewModel.watchedFunds where wf.hasHolding {
            if let fund = viewModel.funds.first(where: { $0.fundcode == wf.code }) {
                slices.append(AllocationDonut.PieSlice(
                    name: wf.name.isEmpty ? wf.code : String(wf.name.prefix(4)),
                    value: wf.marketValue(nav: fund.bestNav),
                    color: Color.fundTypeColor(wf.fundType)
                ))
            }
        }
        return slices.sorted { $0.value > $1.value }
    }

    // MARK: - 文本格式化

    private func moneyText(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func signedMoneyText(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.2f", abs(value)))"
    }

    private func percentText(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.2f", abs(value)))%"
    }
}

// MARK: - 三联指标卡

private struct SecondaryStatCard: View {
    let title: String
    let icon: String
    let value: String
    let sub: String
    var valueColor: Color = .primary
    var subColor: Color = .secondary
    var subWeight: Font.Weight = .regular

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 20, weight: .semibold).monospacedDigit())
                .foregroundStyle(valueColor)
                .kerning(-0.3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fundNumericTransition(text: value)
                .padding(.top, 6)

            Text(sub)
                .font(.system(size: 11, weight: subWeight).monospacedDigit())
                .foregroundStyle(subColor)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 13)
        .frame(height: 82, alignment: .top)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius)
    }
}

// MARK: - 基金行

private struct MainFundRow: View {
    let fund: Fund
    let holding: WatchedFund?
    let isTradingDay: Bool
    let isLast: Bool
    var isCleared: Bool = false
    let showPnlSortArrow: Bool
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: FundCols.spacing) {
            // 基金(名称 + 代码/类型标签)
            VStack(alignment: .leading, spacing: 3) {
                Text(fund.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(fund.fundcode)
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(.tertiary)
                    if let type = holding?.fundType, !type.isEmpty {
                        FundTypeTag(type: type)
                    }
                    if isCleared {
                        Text("已清仓")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 持仓均价(上:均价 下:份额)
            Group {
                if let holding, holding.hasHolding {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(String(format: "%.4f", holding.costPrice))
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(.primary)
                        Text("\(Int(holding.shares).formatted(.number)) 份")
                            .font(.system(size: 10.5).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("—")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: FundCols.holding, alignment: .trailing)

            // 净值估算(上:估算[估] 下:净值)
            Group {
                if isTradingDay && !fund.isNavUpdatedToday && fund.gsz != fund.dwjz {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            EstTag()
                            Text(fund.gsz)
                                .font(.system(size: 13, weight: .medium).monospacedDigit())
                                .foregroundStyle(.primary)
                        }
                        Text("净值 \(fund.dwjz)")
                            .font(.system(size: 10.5).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fund.dwjz)
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(.primary)
                        Text(fund.isNavUpdatedToday ? "净值已更新" : "昨日净值")
                            .font(.system(size: 10.5).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(width: FundCols.nav, alignment: .leading)

            // 涨跌(胶囊居中)
            Group {
                if isTradingDay {
                    ChangePill(text: changeText, value: fund.changePercent)
                } else {
                    Text("休市")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: FundCols.change, alignment: .center)

            // 盈亏(在持=浮动盈亏;已清仓=已实现盈亏)
            Group {
                if isCleared, let holding {
                    Text(signedMoneyText(holding.realizedProfit))
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.fundTrendInk(holding.realizedProfit))
                } else if let holding, holding.hasHolding {
                    let pl = holding.profitLoss(nav: fund.bestNav)
                    Text(signedMoneyText(pl))
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(pl >= 0 ? Color.fundUpInk : Color.fundDownInk)
                } else {
                    Text("—")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: FundCols.pnl, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
        .fundRowSurface(isHovered: isHovered)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.primary.opacity(0.075)).frame(height: 0.5).padding(.horizontal, 12)
            }
        }
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
        .help("点击管理持仓")
    }

    private var changeText: String {
        guard !fund.gszzl.isEmpty else { return "—" }
        let sign = fund.changePercent >= 0 ? "+" : "−"
        return "\(sign)\(fund.gszzl)%"
    }

    private func signedMoneyText(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.2f", abs(value)))"
    }
}

// MARK: - 交易类型 chip(定投橙 / 买入蓝 / 卖出红)

struct TradeChip: View {
    let record: HoldingRecord

    var body: some View {
        let (text, color, ink): (String, Color, Color) = {
            if record.transactionType == .sell {
                return ("卖出", .fundUp, .fundUpInk)
            }
            if record.isDCA {
                return ("定投", .fundDCA, Color(red: 0.74, green: 0.27, blue: 0.03))
            }
            return ("买入", Color(red: 0.04, green: 0.4, blue: 0.8), Color(red: 0.04, green: 0.37, blue: 0.75))
        }()

        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}


private struct RecentTrade {
    let id = UUID()
    let name: String
    let record: HoldingRecord
}

