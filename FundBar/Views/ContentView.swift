import SwiftUI

/// 主面板视图
struct ContentView: View {
    @StateObject private var viewModel = FundViewModel()
    @State private var showAddFund = false

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

            // 总收益率汇总
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

            // 底部栏
            footerView
        }
        .frame(width: 340)
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
                    FundRowView(fund: fund) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.removeFund(code: fund.fundcode)
                        }
                    }

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
            Text("总收益率")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text("\(viewModel.funds.count) 只基金")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            Text(viewModel.totalChangeDisplay)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(summaryColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(summaryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var summaryColor: Color {
        let avg = viewModel.funds.map(\.changePercent).reduce(0, +) / Double(viewModel.funds.count)
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
