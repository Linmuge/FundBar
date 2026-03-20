import SwiftUI

/// 编辑持仓（支持多笔记录 + 定投计划 + 定投统计）
struct EditHoldingView: View {
    @ObservedObject var viewModel: FundViewModel
    @Binding var isPresented: Bool
    let fundCode: String
    let fundName: String

    @State private var sharesText = ""
    @State private var costPriceText = ""

    // 定投设置
    @State private var dcaAmount = ""
    @State private var dcaFrequency: DCAFrequency = .monthly

    private var watchedFund: WatchedFund? {
        viewModel.getWatchedFund(code: fundCode)
    }

    private var holdings: [HoldingRecord] {
        watchedFund?.holdings ?? []
    }

    /// 最多显示的持仓记录数
    private let maxVisibleRecords = 5

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

            // 已有持仓记录（最多显示 maxVisibleRecords 条）
            if !holdings.isEmpty {
                let visibleRecords = Array(holdings.suffix(maxVisibleRecords))
                let hiddenCount = holdings.count - visibleRecords.count

                VStack(spacing: 0) {
                    if hiddenCount > 0 {
                        Text("... 还有 \(hiddenCount) 条更早记录")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        Divider()
                    }

                    ForEach(visibleRecords) { record in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("\(String(format: "%.2f", record.shares)) 份")
                                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                                    if record.isDCA {
                                        Text("定投")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 3)
                                            .padding(.vertical, 1)
                                            .background(.blue, in: RoundedRectangle(cornerRadius: 2))
                                    }
                                }
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

                        if record.id != visibleRecords.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))

                // 汇总
                if let wf = watchedFund {
                    HStack {
                        Text("合计 \(String(format: "%.2f", wf.shares)) 份 (\(holdings.count)笔)")
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

            Divider()

            // MARK: - 定投计划
            dcaPlanSection

            // MARK: - 定投统计
            if let wf = watchedFund, wf.dcaCount > 0 {
                dcaStatsSection(wf: wf)
            }
        }
        .padding(16)
        .onAppear {
            if let plan = watchedFund?.dcaPlan {
                dcaAmount = String(format: "%.0f", plan.amount)
                dcaFrequency = plan.frequency
            }
        }
    }

    // MARK: - 定投计划区域

    private var dcaPlanSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("定投计划")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if watchedFund?.dcaPlan != nil {
                    Button {
                        viewModel.removeDCAPlan(code: fundCode)
                        dcaAmount = ""
                    } label: {
                        Text("取消定投")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Picker("", selection: $dcaFrequency) {
                    ForEach(DCAFrequency.allCases, id: \.self) { freq in
                        Text(freq.rawValue).tag(freq)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                TextField("金额", text: $dcaAmount)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12).monospacedDigit())
                    .frame(width: 80)

                Text("元")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if let plan = watchedFund?.dcaPlan {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("已设置: \(plan.frequency.rawValue) \(String(format: "%.0f", plan.amount)) 元")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            Button {
                let amount = Double(dcaAmount) ?? 0
                guard amount > 0 else { return }
                viewModel.setDCAPlan(code: fundCode, frequency: dcaFrequency, amount: amount)
            } label: {
                Text(watchedFund?.dcaPlan != nil ? "更新计划" : "设置定投")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(dcaAmount.isEmpty || (Double(dcaAmount) ?? 0) <= 0)
        }
    }

    // MARK: - 定投统计区域

    private func dcaStatsSection(wf: WatchedFund) -> some View {
        let fund = viewModel.funds.first(where: { $0.fundcode == fundCode })
        let nav = fund?.bestNav ?? 0
        let profitPct = wf.dcaProfitPercent(nav: nav)
        let profitSign = profitPct >= 0 ? "+" : ""

        return VStack(spacing: 6) {
            Divider()

            HStack {
                Text("定投统计")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 0) {
                statItem(title: "定投次数", value: "\(wf.dcaCount) 次")
                statItem(title: "总投入", value: String(format: "%.0f元", wf.dcaTotalInvested))
                statItem(title: "均价", value: String(format: "%.4f", wf.dcaAverageCost))
                statItem(title: "收益率", value: "\(profitSign)\(String(format: "%.2f", profitPct))%",
                        color: profitPct >= 0 ? .red : .green)
            }
        }
    }

    private func statItem(title: String, value: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}
