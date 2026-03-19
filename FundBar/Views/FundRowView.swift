import SwiftUI

/// 单只基金估值行视图
struct FundRowView: View {
    let fund: Fund
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 左侧: 基金名称 + 代码
            VStack(alignment: .leading, spacing: 3) {
                Text(fund.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(fund.fundcode)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 右侧: 估算净值 + 涨跌幅
            VStack(alignment: .trailing, spacing: 3) {
                Text(fund.gsz)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())

                Text(changeText)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(changeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(changeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
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
