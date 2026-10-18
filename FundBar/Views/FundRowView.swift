import SwiftUI

/// 菜单栏浮窗的基金行 —— 方向 A 定稿:三列(基金 | 涨跌 | 盈亏)
/// 名称 13pt/代码+类型标签次行;行高 42pt,悬停浅底,行间发丝线;点击编辑持仓。
struct FundRowView: View {
    let fund: Fund
    let holding: WatchedFund?
    var isTradingDay: Bool = true
    var isLast: Bool = false
    let onDelete: () -> Void
    let onEditHolding: () -> Void
    @State private var isHovered = false

    init(
        fund: Fund,
        holding: WatchedFund?,
        isTradingDay: Bool = true,
        isLast: Bool = false,
        onDelete: @escaping () -> Void,
        onEditHolding: @escaping () -> Void
    ) {
        self.fund = fund
        self.holding = holding
        self.isTradingDay = isTradingDay
        self.isLast = isLast
        self.onDelete = onDelete
        self.onEditHolding = onEditHolding
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(fund.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(fund.fundcode)
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(.tertiary)

                    if let h = holding, !h.fundType.isEmpty {
                        FundTypeTag(type: h.fundType)
                    }

                    if holding?.isCleared == true {
                        Text("已清仓")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
            }

            Spacer(minLength: 8)

            if isTradingDay {
                ChangePill(text: changeText, value: fund.changePercent, small: true)
                    .frame(width: 58, alignment: .center)
            } else {
                Text("休市")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .frame(width: 58, alignment: .center)
            }

            pnlText
                .frame(width: 74, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 42)
        .contentShape(Rectangle())
        .fundRowSurface(isHovered: isHovered)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.primary.opacity(0.065)).frame(height: 0.5).padding(.horizontal, 10)
            }
        }
        .onHover { isHovered = $0 }
        .onTapGesture { onEditHolding() }
        .help("点击或右键编辑持仓")
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

    @ViewBuilder
    private var pnlText: some View {
        if let h = holding, h.isCleared {
            // 已清仓:显示已实现盈亏
            let rp = h.realizedProfit
            Text(signedText(rp))
                .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(rp >= 0 ? Color.fundUpInk : Color.fundDownInk)
        } else if let h = holding, h.hasHolding {
            let pl = h.profitLoss(nav: fund.bestNav)
            Text(signedText(pl))
                .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(pl >= 0 ? Color.fundUpInk : Color.fundDownInk)
        } else {
            Text("—")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
        }
    }

    private func signedText(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.2f", abs(value)))"
    }

    private var changeText: String {
        // 估值数据缺失时诚实显示 "—"
        guard !fund.gszzl.isEmpty else { return "—" }
        let sign = fund.changePercent >= 0 ? "+" : "−"
        return "\(sign)\(fund.gszzl)%"
    }
}
