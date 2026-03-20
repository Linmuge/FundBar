import SwiftUI

/// 单只基金估值行视图
struct FundRowView: View {
    let fund: Fund
    let holding: WatchedFund?
    let historyData: [Double]
    let onDelete: () -> Void
    let onEditHolding: () -> Void

    init(fund: Fund, holding: WatchedFund?, historyData: [Double] = [], onDelete: @escaping () -> Void, onEditHolding: @escaping () -> Void) {
        self.fund = fund
        self.holding = holding
        self.historyData = historyData
        self.onDelete = onDelete
        self.onEditHolding = onEditHolding
    }

    var body: some View {
        HStack(spacing: 10) {
            // 左侧: 基金名称 + 代码 + 持仓
            VStack(alignment: .leading, spacing: 3) {
                Text(fund.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(fund.fundcode)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if let h = holding, h.hasHolding {
                        Text("\(String(format: "%.0f", h.shares))份")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
            }

            Spacer()

            // 中间: 迷你图
            if !historyData.isEmpty {
                MiniChartView(data: historyData, width: 48, height: 24)
            }

            // 右侧: 净值 + 涨跌幅 + 盈亏
            VStack(alignment: .trailing, spacing: 3) {
                // 始终显示净值
                HStack(spacing: 3) {
                    Text(fund.isNavUpdatedToday ? "净值" : "昨净")
                        .font(.system(size: 9))
                        .foregroundStyle(fund.isNavUpdatedToday ? Color.blue : Color.gray)
                    Text(fund.dwjz)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                }

                // 估算涨跌幅
                HStack(spacing: 4) {
                    if !fund.isNavUpdatedToday && fund.gsz != fund.dwjz {
                        Text("估 \(fund.gsz)")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(changeText)
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(changeColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(changeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }

                if let h = holding, h.hasHolding {
                    let pl = h.profitLoss(nav: fund.bestNav)
                    let plSign = pl >= 0 ? "+" : ""
                    Text("\(plSign)\(String(format: "%.2f", pl))")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(pl >= 0 ? .red : .green)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onEditHolding()
            } label: {
                Label("编辑持仓", systemImage: "pencil.line")
            }
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("移除", systemImage: "trash")
            }
        }
    }

    // MARK: - Private

    private var changeText: String {
        let sign = fund.changePercent >= 0 ? "+" : ""
        return "\(sign)\(fund.gszzl)%"
    }

    private var changeColor: Color {
        if fund.isUp {
            return .red
        } else if fund.isDown {
            return .green
        }
        return .secondary
    }
}
