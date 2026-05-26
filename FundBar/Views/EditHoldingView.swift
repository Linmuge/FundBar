import SwiftUI

/// 编辑持仓（支持多笔记录 + 定投计划 + 定投统计）
struct EditHoldingView: View {
    @ObservedObject var viewModel: FundViewModel
    @Binding var isPresented: Bool
    @Binding var inputMode: Int
    let fundCode: String
    let fundName: String
    var usesPanelSurface = true

    // inputMode: 0 = 按份额买入, 1 = 按金额买入, 2 = 卖出
    @State private var sharesText = ""
    @State private var costPriceText = ""
    @State private var buyAmountText = ""
    @State private var feeText = ""
    @State private var buyDate = Date()
    @State private var isBefore3PM = true
    @State private var sellSharesText = ""
    @State private var sellPriceText = ""
    @State private var sellFeeText = ""
    @State private var sellDate = Date()

    @State private var confirmingRecordId: String? = nil
    @State private var confirmSharesText = ""
    @State private var confirmCostText = ""

    // 定投设置
    @State private var dcaAmount = ""
    @State private var dcaFrequency: DCAFrequency = .monthly

    private var watchedFund: WatchedFund? {
        viewModel.getWatchedFund(code: fundCode)
    }

    private var holdings: [HoldingRecord] {
        watchedFund?.holdings ?? []
    }

    private var availableShares: Double {
        watchedFund?.shares ?? 0
    }

    /// 最多显示的持仓记录数
    private let maxVisibleRecords = 5

    var body: some View {
        VStack(spacing: 12) {
            // 标题
            HStack {
                Label("编辑持仓", systemImage: "pencil.line")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    ToolbarIcon(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭编辑持仓")
                .help("关闭")
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
                        if confirmingRecordId == record.id {
                            VStack(spacing: 6) {
                                HStack {
                                    Text("确认其实际份额")
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                }
                                HStack(spacing: 8) {
                                    TextField("最终份额", text: $confirmSharesText)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11).monospacedDigit())
                                    TextField("成本净值", text: $confirmCostText)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11).monospacedDigit())
                                }
                                HStack {
                                    Spacer()
                                    Button("取消") { confirmingRecordId = nil }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 11))
                                    Button("保存") {
                                        let finalShares = Double(confirmSharesText) ?? 0
                                        let finalCost = Double(confirmCostText) ?? 0
                                        if finalShares > 0 && finalCost > 0 {
                                            viewModel.confirmPendingHolding(code: fundCode, recordId: record.id, finalShares: finalShares, finalCost: finalCost)
                                            confirmingRecordId = nil
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.mini)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                        } else {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    if record.status == .pending {
                                        HStack(spacing: 4) {
                                            Text("金额 \(String(format: "%.2f", record.buyAmount ?? 0))元")
                                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                            Text("待确认")
                                                .font(.system(size: 8))
                                                .foregroundStyle(.orange)
                                                .padding(.horizontal, 3)
                                                .padding(.vertical, 1)
                                                .background(.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                        }
                                        HStack(spacing: 4) {
                                            Text("目标净值日: \(record.targetConfirmDate ?? "--")")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                            if let fee = record.fee, fee > 0 {
                                                Text("手续费 \(String(format: "%.2f", fee))")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    } else if record.transactionType == .sell {
                                        HStack(spacing: 4) {
                                            Text("卖出 \(String(format: "%.2f", record.shares)) 份")
                                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                            Text("卖出")
                                                .font(.system(size: 8))
                                                .foregroundStyle(.red)
                                                .padding(.horizontal, 3)
                                                .padding(.vertical, 1)
                                                .background(.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                        }
                                        HStack(spacing: 4) {
                                            Text("卖出价 \(String(format: "%.4f", record.costPrice))")
                                                .font(.system(size: 10).monospacedDigit())
                                                .foregroundStyle(.secondary)
                                            if let profit = record.realizedProfit {
                                                let sign = profit >= 0 ? "+" : ""
                                                Text("已实现 \(sign)\(String(format: "%.2f", profit))")
                                                    .font(.system(size: 10).monospacedDigit())
                                                    .foregroundStyle(profit >= 0 ? .red : .green)
                                            }
                                            if let fee = record.fee, fee > 0 {
                                                Text("费 \(String(format: "%.2f", fee))")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.tertiary)
                                            }
                                            if !record.date.isEmpty {
                                                Text(record.date.suffix(5))
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    } else {
                                        HStack(spacing: 4) {
                                            Text("买入 \(String(format: "%.2f", record.shares)) 份")
                                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                            if record.isDCA {
                                                Text("定投")
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.blue)
                                                    .padding(.horizontal, 3)
                                                    .padding(.vertical, 1)
                                                    .background(.blue.opacity(0.16), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
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
                                }

                                Spacer()

                                if record.status == .pending {
                                    Button("确认份额") {
                                        confirmingRecordId = record.id
                                        let nav = viewModel.getConfirmNav(code: fundCode, targetDate: record.targetConfirmDate)
                                        let amt = (record.buyAmount ?? 0) - (record.fee ?? 0)
                                        if nav > 0 && amt > 0 {
                                            confirmSharesText = String(format: "%.2f", amt / nav)
                                        } else {
                                            confirmSharesText = ""
                                        }
                                        confirmCostText = nav > 0 ? String(format: "%.4f", nav) : ""
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }

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
                        }

                        if record.id != visibleRecords.last?.id {
                            Divider()
                        }
                    }
                }
                .fundPanelSurface(cornerRadius: 12)

                // 汇总
                if let wf = watchedFund {
                    HStack {
                        Text("剩余 \(String(format: "%.2f", wf.shares)) 份 (\(holdings.count)笔)")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                        Spacer()
                        if wf.realizedProfit != 0 {
                            let sign = wf.realizedProfit >= 0 ? "+" : ""
                            Text("已实现 \(sign)\(String(format: "%.2f", wf.realizedProfit))")
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(wf.realizedProfit >= 0 ? .red : .green)
                        }
                        Text("均价 \(String(format: "%.4f", wf.costPrice))")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // 新增交易
            HStack {
                Text("添加交易记录")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $inputMode) {
                    Text("份额买入").tag(0)
                    Text("金额买入").tag(1)
                    Text("卖出").tag(2)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.mini)
                .frame(width: 190)
            }

            if inputMode == 0 {
                HStack(spacing: 8) {
                    TextField("份额", text: $sharesText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12).monospacedDigit())
                    TextField("成本净值", text: $costPriceText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12).monospacedDigit())
                }
            } else if inputMode == 1 {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("买入金额", text: $buyAmountText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12).monospacedDigit())
                        TextField("预估手续费", text: $feeText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12).monospacedDigit())
                    }
                    HStack {
                        DatePicker("", selection: $buyDate, displayedComponents: .date)
                            .labelsHidden()
                            .controlSize(.mini)
                        Picker("买入时间", selection: $isBefore3PM) {
                            Text("15:00 前").tag(true)
                            Text("15:00 后").tag(false)
                        }
                        .pickerStyle(.menu)
                        .controlSize(.mini)
                        .font(.system(size: 11))
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("卖出份额", text: $sellSharesText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12).monospacedDigit())
                            .onChange(of: sellSharesText) { _, newValue in
                                sellSharesText = numericText(from: newValue)
                            }
                        TextField("卖出净值", text: $sellPriceText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12).monospacedDigit())
                            .onChange(of: sellPriceText) { _, newValue in
                                sellPriceText = numericText(from: newValue)
                            }
                        TextField("手续费", text: $sellFeeText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12).monospacedDigit())
                            .onChange(of: sellFeeText) { _, newValue in
                                sellFeeText = numericText(from: newValue)
                            }
                    }
                    HStack {
                        Text("当前 \(String(format: "%.2f", availableShares)) 份")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        DatePicker("", selection: $sellDate, displayedComponents: .date)
                            .labelsHidden()
                            .controlSize(.mini)
                    }
                }
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
                    if inputMode == 0 {
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
                    } else if inputMode == 1 {
                        let amount = abs(Double(buyAmountText) ?? 0)
                        let fee = abs(Double(feeText) ?? 0)
                        guard amount > 0 else { return }
                        viewModel.addPendingHolding(code: fundCode, buyAmount: amount, fee: fee, buyDate: buyDate, isBefore3PM: isBefore3PM)
                        buyAmountText = ""
                        feeText = ""
                    } else {
                        let shares = abs(Double(sellSharesText) ?? 0)
                        let price = abs(Double(sellPriceText) ?? 0)
                        let fee = abs(Double(sellFeeText) ?? 0)
                        if viewModel.addSellHolding(code: fundCode, shares: shares, sellPrice: price, date: dateString(sellDate), fee: fee) {
                            sellSharesText = ""
                            sellPriceText = ""
                            sellFeeText = ""
                        }
                    }
                } label: {
                    Text(inputMode == 2 ? "添加卖出" : "添加")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isAddButtonDisabled)
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
        .modifier(EditHoldingSurfaceModifier(enabled: usesPanelSurface))
        .onAppear {
            if let plan = watchedFund?.dcaPlan {
                dcaAmount = String(format: "%.0f", plan.amount)
                dcaFrequency = plan.frequency
            }
        }
    }

    private var isAddButtonDisabled: Bool {
        switch inputMode {
        case 0:
            return (Double(sharesText) ?? 0) <= 0 || (Double(costPriceText) ?? 0) <= 0
        case 1:
            return (Double(buyAmountText) ?? 0) <= 0
        default:
            let shares = Double(sellSharesText) ?? 0
            let price = Double(sellPriceText) ?? 0
            return shares <= 0 || price <= 0 || shares > availableShares + 0.000001
        }
    }

    private func numericText(from value: String) -> String {
        String(value.filter { $0.isNumber || $0 == "." })
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
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

private struct EditHoldingSurfaceModifier: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .fundPanelSurface(cornerRadius: 18, tint: .orange.opacity(0.05), interactive: true)
        } else {
            content
        }
    }
}
