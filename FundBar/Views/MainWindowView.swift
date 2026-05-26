import SwiftUI
import AppKit

/// 应用主窗口视图
struct MainWindowView: View {
    @ObservedObject var viewModel: FundViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                        VStack(spacing: 16) {
                            summaryGrid

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

    private var header: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 62, height: 1)
                .accessibilityHidden(true)

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(.blue.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("FundBar")
                    .font(.system(size: 18, weight: .semibold))
                Text(viewModel.isTradingTime ? "交易中" : (viewModel.isTradingDay ? "非交易时段" : "休市"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $viewModel.sortMode) {
                ForEach(FundSortMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 120)

            Button {
                Task { await viewModel.refresh() }
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
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .fundPanelSurface(cornerRadius: 22, tint: .blue.opacity(0.05), interactive: true)
        .padding(.leading, pageLeadingInset)
        .padding(.trailing, pageTrailingInset)
        .padding(.top, 8)
        .padding(.bottom, 10)
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
        .fundPanelSurface(cornerRadius: 22, tint: .orange.opacity(0.05), interactive: true)
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 12)
        .padding(.top, 96)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            MetricCard(
                title: "总市值",
                value: moneyText(viewModel.totalMarketValue),
                subtitle: "\(viewModel.funds.count) 只基金",
                systemImage: "chart.pie",
                color: .blue
            )
            MetricCard(
                title: viewModel.isTradingDay ? "今日预估" : "今日",
                value: viewModel.isTradingDay ? signedMoneyText(viewModel.todayEstimatedProfit) : "休市",
                subtitle: "交易日估算",
                systemImage: "calendar",
                color: color(for: viewModel.todayEstimatedProfit)
            )
            MetricCard(
                title: "浮动盈亏",
                value: signedMoneyText(viewModel.totalProfitLoss),
                subtitle: percentText(viewModel.totalProfitPercent),
                systemImage: "waveform.path.ecg",
                color: color(for: viewModel.totalProfitLoss)
            )
            MetricCard(
                title: "已实现盈亏",
                value: signedMoneyText(viewModel.totalRealizedProfit),
                subtitle: viewModel.totalRealizedProfit == 0 ? "暂无卖出" : "卖出累计",
                systemImage: "checkmark.seal",
                color: color(for: viewModel.totalRealizedProfit)
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var portfolioPanel: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("自选基金")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(viewModel.sortedFunds.count) 条记录")
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
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.sortedFunds) { fund in
                        MainFundRow(
                            fund: fund,
                            holding: viewModel.getWatchedFund(code: fund.fundcode),
                            isTradingDay: viewModel.isTradingDay,
                            onEdit: { openEdit(fund: fund, inputMode: 0) },
                            onSell: { openEdit(fund: fund, inputMode: 2) }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .fundPanelSurface(cornerRadius: 20, tint: .blue.opacity(0.04), interactive: true)
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
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding(24)
    }

    private var analyticsPanel: some View {
        VStack(spacing: 10) {
            let profitData = buildProfitData()
            let pieSlices = buildPieSlices()

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
                if !profitData.isEmpty {
                    ProfitChartView(data: profitData)
                }
                if !pieSlices.isEmpty {
                    HoldingPieView(slices: pieSlices)
                }
            }
        }
        .padding(10)
        .fundPanelSurface(cornerRadius: 20, tint: .purple.opacity(0.05), interactive: true)
    }

    private var quickSettingsPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Label("快捷设置", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            HStack {
                Text("菜单栏")
                    .font(.system(size: 12))
                Spacer()
                Picker("", selection: $viewModel.menuBarMode) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
            }

            HStack {
                Text("涨跌通知")
                    .font(.system(size: 12))
                Spacer()
                Picker("", selection: $viewModel.notifyThreshold) {
                    Text("关闭").tag(0.0)
                    Text("1%").tag(1.0)
                    Text("2%").tag(2.0)
                    Text("3%").tag(3.0)
                    Text("5%").tag(5.0)
                }
                .labelsHidden()
                .frame(width: 90)
            }

            Toggle("开机自启", isOn: Binding(
                get: { viewModel.launchAtLogin },
                set: { viewModel.launchAtLogin = $0 }
            ))
            .toggleStyle(.switch)
        }
        .padding(14)
        .fundPanelSurface(cornerRadius: 20)
    }

    private var recentTradesPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近交易")
                .font(.system(size: 13, weight: .semibold))

            let trades = recentTrades
            if trades.isEmpty {
                Text("暂无交易记录")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
            } else {
                ForEach(trades) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.record.transactionType == .sell ? "minus.circle.fill" : "plus.circle.fill")
                            .foregroundStyle(item.record.transactionType == .sell ? .red : .blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Text(tradeDetailText(item.record))
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(14)
        .fundPanelSurface(cornerRadius: 20)
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
        if value > 0 { return .red }
        if value < 0 { return .green }
        return .secondary
    }
}

private struct MainFundRow: View {
    let fund: Fund
    let holding: WatchedFund?
    let isTradingDay: Bool
    let onEdit: () -> Void
    let onSell: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(fund.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(fund.fundcode)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let type = holding?.fundType, !type.isEmpty {
                        Text(type)
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let holding, holding.hasHolding {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(String(format: "%.2f", holding.shares)) 份")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                    Text("均价 \(String(format: "%.4f", holding.costPrice))")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(width: 110, alignment: .trailing)
            }

            VStack(alignment: .trailing, spacing: 3) {
                Text(fund.dwjz)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                if isTradingDay {
                    Text(changeText)
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(changeColor)
                } else {
                    Text("休市")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, alignment: .trailing)

            if let holding, holding.hasHolding {
                let profit = holding.profitLoss(nav: fund.bestNav)
                let sign = profit >= 0 ? "+" : ""
                Text("\(sign)\(String(format: "%.2f", profit))")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(profit >= 0 ? .red : .green)
                    .frame(width: 92, alignment: .trailing)
            } else {
                Text("--")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: 92, alignment: .trailing)
            }

            HStack(spacing: 6) {
                Button {
                    onEdit()
                } label: {
                    ToolbarIcon(systemName: "pencil", size: 11, diameter: 26)
                }
                .buttonStyle(.plain)
                .help("编辑持仓")

                Button {
                    onSell()
                } label: {
                    ToolbarIcon(systemName: "minus", size: 11, diameter: 26, isActive: holding?.hasHolding == true)
                }
                .buttonStyle(.plain)
                .disabled(holding?.hasHolding != true)
                .help("记录卖出")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .fundRowSurface(isHovered: isHovered)
        .onHover { isHovered = $0 }
    }

    private var changeText: String {
        let sign = fund.changePercent >= 0 ? "+" : ""
        return "\(sign)\(fund.gszzl)%"
    }

    private var changeColor: Color {
        if fund.isUp { return .red }
        if fund.isDown { return .green }
        return .secondary
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 17, weight: .semibold).monospacedDigit())
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minHeight: 94)
        .fundPanelSurface(cornerRadius: 18, tint: color.opacity(0.05), interactive: true)
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

        let centerYFromTop: CGFloat = 36
        let centersX: [CGFloat] = [42, 64, 86]

        for (button, centerX) in zip(buttons, centersX) {
            let targetX = centerX - button.frame.width / 2
            let targetY = superview.bounds.height - centerYFromTop - button.frame.height / 2
            button.setFrameOrigin(NSPoint(x: targetX, y: targetY))
        }
    }
}
