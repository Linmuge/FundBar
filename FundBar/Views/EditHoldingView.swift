import SwiftUI

/// 编辑持仓弹窗
struct EditHoldingView: View {
    @ObservedObject var viewModel: FundViewModel
    @Binding var isPresented: Bool
    let fundCode: String
    let fundName: String

    @State private var sharesText = ""
    @State private var costPriceText = ""

    var body: some View {
        VStack(spacing: 14) {
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

            // 持有份额
            VStack(alignment: .leading, spacing: 4) {
                Text("持有份额")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("请输入持有份额", text: $sharesText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13).monospacedDigit())
            }

            // 成本净值
            VStack(alignment: .leading, spacing: 4) {
                Text("成本净值")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("请输入成本净值", text: $costPriceText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13).monospacedDigit())
            }

            // 操作按钮
            HStack(spacing: 8) {
                // 清空持仓
                Button {
                    viewModel.updateHolding(code: fundCode, shares: 0, costPrice: 0)
                    isPresented = false
                } label: {
                    Text("清空持仓")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                // 保存
                Button {
                    let shares = Double(sharesText) ?? 0
                    let cost = Double(costPriceText) ?? 0
                    viewModel.updateHolding(code: fundCode, shares: shares, costPrice: cost)
                    isPresented = false
                } label: {
                    Text("保存")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(sharesText.isEmpty || costPriceText.isEmpty)
            }
        }
        .padding(16)
        .onAppear {
            if let wf = viewModel.getWatchedFund(code: fundCode), wf.hasHolding {
                sharesText = String(format: "%.2f", wf.shares)
                costPriceText = String(format: "%.4f", wf.costPrice)
            }
        }
    }
}
