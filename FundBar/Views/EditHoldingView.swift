import SwiftUI

/// 编辑持仓（支持多笔记录 + 定投计划 + 定投统计）
///
/// 重设计要点（视觉层重构，数据逻辑不变）：
/// - Hero 基金状态卡：基金名+代码+类型+涨跌胶囊+四联指标，涨跌色 tint
/// - 持仓记录：彩色 chip 时间线（买入蓝/定投橙/卖出红/待确认橙虚框）
/// - 新增交易：收进独立圆角盒（分段+浮动 label 输入+按钮）
/// - 定投计划：折叠为一行摘要，点击展开
/// - 定投统计：独立四联指标条
struct EditHoldingView: View {
    @ObservedObject var viewModel: FundViewModel
    @Binding var isPresented: Bool
    @Binding var inputMode: Int
    let fundCode: String
    let fundName: String
    var usesPanelSurface = true
    /// 关闭回调（独立窗口模式下由它驱动 dismiss；popover 模式下走 isPresented）
    var onClose: (() -> Void)? = nil

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
    @State private var showDCASettings = false

    private var watchedFund: WatchedFund? {
        viewModel.getWatchedFund(code: fundCode)
    }

    private var currentFund: Fund? {
        viewModel.funds.first(where: { $0.fundcode == fundCode })
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
        VStack(spacing: 14) {
            // 顶部标题栏（带关闭按钮）——独立窗口模式下 onClose 驱动 dismiss；
            // popover 模式下 onClose 为 nil，走 isPresented = false
            HStack {
                Text("编辑持仓")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    if let onClose {
                        onClose()
                    } else {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }

            heroCard

            if !holdings.isEmpty {
                holdingsSection
            }

            addTradeBox

            dcaSummaryRow

            if showDCASettings {
                dcaSettingsContent
            }

            if let wf = watchedFund, wf.dcaCount > 0 {
                dcaStatsBar(wf: wf)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(usesPanelSurface ? 16 : 0)
        .modifier(EditHoldingSurfaceModifier(enabled: usesPanelSurface))
        .onAppear {
            if let plan = watchedFund?.dcaPlan {
                dcaAmount = String(format: "%.0f", plan.amount)
                dcaFrequency = plan.frequency
            }
        }
    }

    // MARK: - Hero 基金状态卡

    private var heroCard: some View {
        let fund = currentFund
        let wf = watchedFund
        let changePct = fund?.changePercent ?? 0
        let heroColor = Color.fundTrend(changePct)
        let nav = fund?.bestNav ?? 0
        let hasHolding = wf?.hasHolding ?? false

        return VStack(spacing: 11) {
            // 顶部：基金名 + 涨跌胶囊
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(fundName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    HStack(spacing: 6) {
                        Text(fundCode)
                            .font(.system(size: 10.5).monospacedDigit())
                            .foregroundStyle(.tertiary)
                        if let type = wf?.fundType, !type.isEmpty {
                            Text(type)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(fundTypeColor(type))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(fundTypeColor(type).opacity(0.14), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        if let fund = fund {
                            Text("\(fund.isNavUpdatedToday ? "净值" : "昨净") \(fund.dwjz)")
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer(minLength: 8)

                if let fund = fund, fund.changePercent != 0 {
                    let sign = changePct >= 0 ? "+" : ""
                    Text("\(sign)\(String(format: "%.2f", changePct))%")
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(heroColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(heroColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }

            // 四联指标
            if hasHolding {
                HStack(spacing: 0) {
                    heroStat("持仓份额", Int(wf?.shares ?? 0).formatted(.number))
                    heroStatSep
                    heroStat("持仓市值", "¥\(moneyText(wf?.marketValue(nav: nav) ?? 0))")
                    heroStatSep
                    heroStat("浮动盈亏", signedMoney(wf?.profitLoss(nav: nav) ?? 0),
                             color: Color.fundTrend(wf?.profitLoss(nav: nav) ?? 0))
                    heroStatSep
                    heroStat("均价", String(format: "%.4f", wf?.costPrice ?? 0))
                }
                .padding(.top, 10)
                .overlay(alignment: .top) { Divider() }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(heroColor.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(heroColor.opacity(0.18), lineWidth: 1)
        }
    }

    private func heroStat(_ title: String, _ value: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroStatSep: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 22)
            .padding(.horizontal, 6)
    }

    // MARK: - 持仓记录（彩色 chip 时间线）

    private var holdingsSection: some View {
        VStack(spacing: 9) {
            sectionHeader("持仓记录", trailing: "\(holdings.count) 笔", extraTrailing: realizedTrailing)

            let visibleRecords = Array(holdings.suffix(maxVisibleRecords))
            let hiddenCount = holdings.count - visibleRecords.count

            VStack(spacing: 0) {
                if hiddenCount > 0 {
                    Text("还有 \(hiddenCount) 条更早记录未显示")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                    Divider()
                }

                ForEach(visibleRecords) { record in
                    if confirmingRecordId == record.id {
                        confirmRecordRow(record)
                    } else {
                        recordRow(record, isLast: record.id == visibleRecords.last?.id)
                    }
                }
            }
            .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.65)
            }
        }
    }

    private var realizedTrailing: String? {
        guard let wf = watchedFund, wf.realizedProfit != 0 else { return nil }
        let sign = wf.realizedProfit >= 0 ? "+" : ""
        return "已实现 \(sign)\(String(format: "%.2f", wf.realizedProfit))"
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, trailing: String? = nil, extraTrailing: String? = nil) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            if let extraTrailing {
                Text(extraTrailing)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(Color.fundTrend(watchedFund?.realizedProfit ?? 0))
            }
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func recordRow(_ record: HoldingRecord, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 11) {
            recordChip(record)

            VStack(alignment: .leading, spacing: 2) {
                recordMainText(record)
                recordSubText(record)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            recordRight(record)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(record.status == .pending ? Color.fundDCA.opacity(0.04) : Color.clear)
        .overlay(alignment: .bottom) {
            if !isLast { Divider() }
        }
    }

    @ViewBuilder
    private func recordChip(_ record: HoldingRecord) -> some View {
        let isPending = record.status == .pending
        let isSell = record.transactionType == .sell
        let isDCA = record.isDCA

        Group {
            if isPending {
                // 待确认：橙色虚框
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.fundDCA.opacity(0.5), lineWidth: 1, antialiased: false)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.fundDCA)
                    }
            } else {
                let color: Color = isSell ? .fundUp : (isDCA ? .fundDCA : .accentColor)
                let icon = isSell ? "minus" : "plus"
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
        }
    }

    @ViewBuilder
    private func recordMainText(_ record: HoldingRecord) -> some View {
        if record.status == .pending {
            HStack(spacing: 5) {
                Text("¥\(String(format: "%.2f", record.buyAmount ?? 0))")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                pendingBadge
            }
        } else if record.transactionType == .sell {
            HStack(spacing: 5) {
                Text("卖出 \(String(format: "%.2f", record.shares)) 份")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                sellBadge
            }
        } else {
            HStack(spacing: 5) {
                Text("买入 \(String(format: "%.2f", record.shares)) 份")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                if record.isDCA { dcaBadge }
            }
        }
    }

    private var pendingBadge: some View {
        Text("待确认")
            .font(.system(size: 8.5, weight: .semibold))
            .foregroundStyle(Color.fundDCA)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.fundDCA.opacity(0.16), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var dcaBadge: some View {
        Text("定投")
            .font(.system(size: 8.5, weight: .semibold))
            .foregroundStyle(Color.fundDCA)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.fundDCA.opacity(0.16), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var sellBadge: some View {
        Text("卖出")
            .font(.system(size: 8.5, weight: .semibold))
            .foregroundStyle(Color.fundUp)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.fundUp.opacity(0.14), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    @ViewBuilder
    private func recordSubText(_ record: HoldingRecord) -> some View {
        if record.status == .pending {
            HStack(spacing: 8) {
                Text("目标净值日 \(record.targetConfirmDate ?? "--")")
                if let fee = record.fee, fee > 0 {
                    dotSep
                    Text("费 \(String(format: "%.2f", fee))")
                }
            }
            .font(.system(size: 9.5).monospacedDigit())
            .foregroundStyle(.tertiary)
        } else if record.transactionType == .sell {
            HStack(spacing: 8) {
                Text("卖价 \(String(format: "%.4f", record.costPrice))")
                if !record.date.isEmpty {
                    dotSep
                    Text(record.date.suffix(5))
                }
            }
            .font(.system(size: 9.5).monospacedDigit())
            .foregroundStyle(.tertiary)
        } else {
            HStack(spacing: 8) {
                Text("成本 \(String(format: "%.4f", record.costPrice))")
                if !record.date.isEmpty {
                    dotSep
                    Text(record.date.suffix(5))
                }
            }
            .font(.system(size: 9.5).monospacedDigit())
            .foregroundStyle(.tertiary)
        }
    }

    private var dotSep: some View {
        Circle()
            .fill(Color.secondary.opacity(0.5))
            .frame(width: 2, height: 2)
    }

    @ViewBuilder
    private func recordRight(_ record: HoldingRecord) -> some View {
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
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(Color.fundDCA)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.fundDCA.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .buttonStyle(.plain)
        } else if record.transactionType == .sell, let profit = record.realizedProfit, profit != 0 {
            let sign = profit >= 0 ? "+" : ""
            Text("\(sign)\(String(format: "%.2f", profit))")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(Color.fundTrend(profit))
        } else {
            Button {
                viewModel.removeHolding(code: fundCode, recordId: record.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("删除此记录")
        }
    }

    @ViewBuilder
    private func confirmRecordRow(_ record: HoldingRecord) -> some View {
        VStack(spacing: 7) {
            HStack {
                Text("确认实际份额")
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
            HStack(spacing: 6) {
                Spacer()
                Button("取消") { confirmingRecordId = nil }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button("保存") {
                    let finalShares = Double(confirmSharesText) ?? 0
                    let finalCost = Double(confirmCostText) ?? 0
                    if finalShares > 0 && finalCost > 0 {
                        viewModel.confirmPendingHolding(code: fundCode, recordId: record.id, finalShares: finalShares, finalCost: finalCost)
                        confirmingRecordId = nil
                    }
                }
                .fundGlassButtonStyle(prominent: true)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - 新增交易操作盒

    private var addTradeBox: some View {
        VStack(spacing: 10) {
            Picker("", selection: $inputMode) {
                Text("份额买入").tag(0)
                Text("金额买入").tag(1)
                Text("卖出").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if inputMode == 0 {
                HStack(spacing: 8) {
                    floatingField("份额", text: $sharesText)
                    floatingField("成本净值", text: $costPriceText)
                }
            } else if inputMode == 1 {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        floatingField("买入金额", text: $buyAmountText)
                        floatingField("预估手续费", text: $feeText)
                    }
                    HStack(spacing: 8) {
                        DatePicker("", selection: $buyDate, displayedComponents: .date)
                            .labelsHidden()
                            .controlSize(.small)
                        Picker("", selection: $isBefore3PM) {
                            Text("15:00 前").tag(true)
                            Text("15:00 后").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.mini)
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        floatingField("卖出份额", text: $sellSharesText, filterNumeric: true)
                        floatingField("卖出净值", text: $sellPriceText, filterNumeric: true)
                        floatingField("手续费", text: $sellFeeText, filterNumeric: true)
                    }
                    HStack {
                        Text("当前 \(String(format: "%.2f", availableShares)) 份")
                            .font(.system(size: 9.5).monospacedDigit())
                            .foregroundStyle(.tertiary)
                        Spacer()
                        DatePicker("", selection: $sellDate, displayedComponents: .date)
                            .labelsHidden()
                            .controlSize(.small)
                    }
                }
            }

            HStack(spacing: 8) {
                if !holdings.isEmpty {
                    Button {
                        viewModel.clearHoldings(code: fundCode)
                    } label: {
                        Text("清空全部")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    addCurrentTrade()
                } label: {
                    Text(inputMode == 2 ? "添加卖出" : "添加记录")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 16)
                }
                .fundGlassButtonStyle(prominent: true)
                .controlSize(.small)
                .disabled(isAddButtonDisabled)
            }
        }
        .padding(13)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.65)
        }
    }

    /// 带边框的圆角输入框（placeholder 作为 label）
    private func floatingField(_ label: String, text: Binding<String>, filterNumeric: Bool = false) -> some View {
        TextField(label, text: text)
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12.5).monospacedDigit())
            .onChange(of: text.wrappedValue) { _, newValue in
                if filterNumeric {
                    text.wrappedValue = numericText(from: newValue)
                }
            }
    }

    private func addCurrentTrade() {
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

    // MARK: - 定投计划（折叠摘要 + 展开设置）

    private var dcaSummaryRow: some View {
        let hasPlan = watchedFund?.dcaPlan != nil

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDCASettings.toggle()
            }
        } label: {
            HStack(spacing: 11) {
                // 橙色图标
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.fundDCA)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text("定投计划")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 5) {
                        if hasPlan {
                            Circle()
                                .fill(.green)
                                .frame(width: 5, height: 5)
                            if let plan = watchedFund?.dcaPlan {
                                Text("已开启 · \(plan.frequency.rawValue) \(String(format: "%.0f", plan.amount)) 元")
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            if watchedFund?.dcaCount ?? 0 > 0 {
                                Text("· 已投 \(watchedFund?.dcaCount ?? 0) 期")
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                        } else {
                            Text("未开启 · 点击设置定期定额投资")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(showDCASettings ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.fundDCA.opacity(0.06), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.fundDCA.opacity(0.15), lineWidth: 0.65)
        }
    }

    @ViewBuilder
    private var dcaSettingsContent: some View {
        if showDCASettings {
            VStack(spacing: 10) {
                Picker("", selection: $dcaFrequency) {
                    ForEach(DCAFrequency.allCases, id: \.self) { freq in
                        Text(freq.rawValue).tag(freq)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    floatingField("金额", text: $dcaAmount)
                        .frame(maxWidth: 120)
                    Text("元")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        let amount = Double(dcaAmount) ?? 0
                        guard amount > 0 else { return }
                        viewModel.setDCAPlan(code: fundCode, frequency: dcaFrequency, amount: amount)
                    } label: {
                        Text(watchedFund?.dcaPlan != nil ? "更新计划" : "设置定投")
                            .font(.system(size: 11.5, weight: .semibold))
                            .padding(.horizontal, 12)
                    }
                    .fundGlassButtonStyle(prominent: true)
                    .controlSize(.small)
                    .disabled(dcaAmount.isEmpty || (Double(dcaAmount) ?? 0) <= 0)
                }

                if watchedFund?.dcaPlan != nil {
                    Button {
                        viewModel.removeDCAPlan(code: fundCode)
                        dcaAmount = ""
                    } label: {
                        Text("取消定投")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(13)
            .background(Color.fundDCA.opacity(0.04), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.fundDCA.opacity(0.1), lineWidth: 0.65)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - 定投统计（独立四联指标条）

    private func dcaStatsBar(wf: WatchedFund) -> some View {
        let fund = currentFund
        let nav = fund?.bestNav ?? 0
        let profitPct = wf.dcaProfitPercent(nav: nav)

        return HStack(spacing: 0) {
            dcaStatItem("定投次数", "\(wf.dcaCount) 次")
            dcaStatSep
            dcaStatItem("总投入", "¥\(String(format: "%.0f", wf.dcaTotalInvested))")
            dcaStatSep
            dcaStatItem("均价", String(format: "%.4f", wf.dcaAverageCost))
            dcaStatSep
            let sign = profitPct >= 0 ? "+" : ""
            dcaStatItem("收益率", "\(sign)\(String(format: "%.2f", profitPct))%",
                        color: Color.fundTrend(profitPct))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.65)
        }
    }

    private func dcaStatItem(_ title: String, _ value: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var dcaStatSep: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 1, height: 22)
    }

    // MARK: - Helpers

    private func moneyText(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func signedMoney(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))"
    }

    private func fundTypeColor(_ type: String) -> Color {
        if type.contains("股票") { return .orange }
        if type.contains("混合") { return .purple }
        if type.contains("债券") { return .blue }
        if type.contains("指数") { return .teal }
        if type.contains("货币") { return .gray }
        if type.contains("QDII") { return .indigo }
        if type.contains("FOF") { return .mint }
        return .secondary
    }
}

private struct EditHoldingSurfaceModifier: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
        } else {
            content
        }
    }
}
