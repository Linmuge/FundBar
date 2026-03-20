import SwiftUI

/// 编辑持仓（支持多笔记录）
struct EditHoldingView: View {
    @ObservedObject var viewModel: FundViewModel
    @Binding var isPresented: Bool
    let fundCode: String
    let fundName: String

    @State private var sharesText = ""
    @State private var costPriceText = ""

    private var holdings: [HoldingRecord] {
        viewModel.getWatchedFund(code: fundCode)?.holdings ?? []
    }

    var body: some View {
        VStack(spacing: 12) {
            // 标题
            HStack {
                Text("编辑持仓")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }

            // 基金信息
            Text("\(fundName) (\(fundCode))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 已有持仓记录
            if !holdings.isEmpty {
                VStack(spacing: 0) {
                    ForEach(holdings) { record in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(String(format: "%.2f", record.shares)) 份")
                                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                                HStack(spacing: 4) {
                                    Text("成本 \(String(format: "%.4f", record.costPrice))")
                                        .font(.system(size: 10).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    if !record.date.isEmpty {
                                        Text(record.date.suffix(5))
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }

                            Spacer()

                            Button {
                                viewModel.removeHolding(code: fundCode, recordId: record.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)

                        if record.id != holdings.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))

                // 汇总
                if let wf = viewModel.getWatchedFund(code: fundCode) {
                    HStack {
                        Text("合计 \(String(format: "%.2f", wf.shares)) 份")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                        Spacer()
                        Text("均价 \(String(format: "%.4f", wf.costPrice))")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // 新增持仓
            Text("添加买入记录")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                TextField("份额", text: $sharesText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12).monospacedDigit())
                TextField("成本净值", text: $costPriceText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12).monospacedDigit())
            }

            // 操作按钮
            HStack(spacing: 8) {
                if !holdings.isEmpty {
                    Button {
                        viewModel.clearHoldings(code: fundCode)
                    } label: {
                        Text("清空全部")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Button {
                    let shares = Double(sharesText) ?? 0
                    let cost = Double(costPriceText) ?? 0
                    guard shares > 0, cost > 0 else { return }
                    let today = {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM-dd"
                        return f.string(from: Date())
                    }()
                    viewModel.addHolding(code: fundCode, shares: shares, costPrice: cost, date: today)
                    sharesText = ""
                    costPriceText = ""
                } label: {
                    Text("添加")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(sharesText.isEmpty || costPriceText.isEmpty)
            }
        }
        .padding(16)
    }
}
