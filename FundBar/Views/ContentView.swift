import SwiftUI

/// 主面板视图
struct ContentView: View {
    @StateObject private var viewModel = FundViewModel()
    @State private var showAddFund = false
    @State private var editingFundCode: String?
    @State private var editingFundName: String?
    @State private var showEditHolding = false

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
                    if showAddFund { showEditHolding = false }
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
        .frame(maxHeight: 400)
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
                    // 总市值
                    HStack(spacing: 4) {
                        Text("总市值")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f", viewModel.totalMarketValue))
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    }

                    // 今日预估 + 持仓盈亏
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

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 8) {
            if let time = viewModel.lastUpdateTime {
                Text("更新: \(time, format: .dateTime.hour().minute().second())")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // 数据源切换
            Menu {
                ForEach(DataSource.allCases, id: \.self) { source in
                    Button {
                        viewModel.currentDataSource = source
                    } label: {
                        HStack {
                            Text(source.rawValue)
                            if viewModel.currentDataSource == source {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 9))
                    Text(viewModel.currentDataSource.rawValue)
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

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
}
