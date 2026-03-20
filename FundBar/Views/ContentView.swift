import SwiftUI
import UniformTypeIdentifiers

/// 主面板视图
struct ContentView: View {
    @ObservedObject var viewModel: FundViewModel
    @State private var showAddFund = false
    @State private var editingFundCode: String?
    @State private var editingFundName: String?
    @State private var showEditHolding = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            headerView

            Divider()

            // 内容区
            if viewModel.funds.isEmpty && !viewModel.isLoading {
                emptyView
            } else {
                fundListView
            }

            Divider()

            // 持仓汇总
            if !viewModel.funds.isEmpty {
                summaryView
                Divider()
            }

            // 添加基金区域
            if showAddFund {
                AddFundView(viewModel: viewModel, isPresented: $showAddFund)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                Divider()
            }

            // 编辑持仓区域
            if showEditHolding, let code = editingFundCode, let name = editingFundName {
                EditHoldingView(
                    viewModel: viewModel,
                    isPresented: $showEditHolding,
                    fundCode: code,
                    fundName: name
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                Divider()
            }

            // 设置区域
            if showSettings {
                settingsView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                Divider()
            }

            // 底部栏
            footerView
        }
        .frame(width: 360)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)

            Text("基金估值")
                .font(.system(size: 14, weight: .semibold))

            if viewModel.isTradingTime {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
            }

            Spacer()

            // 刷新按钮
            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                    .animation(
                        viewModel.isLoading
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                        value: viewModel.isLoading
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)

            // 添加按钮
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAddFund.toggle()
                    if showAddFund {
                        showEditHolding = false
                        showSettings = false
                    }
                }
            } label: {
                Image(systemName: showAddFund ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Fund List

    private var fundListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.funds) { fund in
                    FundRowView(
                        fund: fund,
                        holding: viewModel.getWatchedFund(code: fund.fundcode),
                        historyData: viewModel.fundHistory[fund.fundcode] ?? [],
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.removeFund(code: fund.fundcode)
                            }
                        },
                        onEditHolding: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                editingFundCode = fund.fundcode
                                editingFundName = fund.name
                                showEditHolding = true
                                showAddFund = false
                                showSettings = false
                            }
                        }
                    )

                    if fund.id != viewModel.funds.last?.id {
                        Divider()
                            .padding(.leading, 14)
                    }
                }
            }
        }
        .frame(height: min(listIdealHeight, listMaxHeight))
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
        return screenHeight * 0.7
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
                    }

                    HStack(spacing: 8) {
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

                        let pl = viewModel.totalProfitLoss
                        let plSign = pl >= 0 ? "+" : ""
                        HStack(spacing: 2) {
                            Text("盈亏")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Text("\(plSign)\(String(format: "%.2f", pl))")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(pl >= 0 ? .red : .green)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Text("总收益率")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\(viewModel.funds.count) 只基金")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(viewModel.totalChangeDisplay)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(summaryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(summaryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))

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
    }

    private var summaryColor: Color {
        let avg = viewModel.totalChangePercent
        if avg > 0 { return .red }
        if avg < 0 { return .green }
        return .secondary
    }

    // MARK: - Settings

    private var settingsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("设置")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSettings = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
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

            // 设置按钮
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings.toggle()
                    if showSettings {
                        showAddFund = false
                        showEditHolding = false
                    }
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            // 退出按钮
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("退出")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
}
