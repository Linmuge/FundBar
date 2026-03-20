import Foundation
import Combine
import SwiftUI

/// 基金估值 ViewModel - 管理数据获取、自动刷新和持久化
@MainActor
final class FundViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var funds: [Fund] = []
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    @Published var errorMessage: String?
    @Published var currentDataSource: DataSource = .tiantian {
        didSet {
            service.switchSource(to: currentDataSource)
            UserDefaults.standard.set(currentDataSource.rawValue, forKey: dataSourceKey)
            Task { await refresh() }
        }
    }

    /// 自选基金列表（含持仓信息）- @Published 存储属性，didSet 自动写入 UserDefaults
    @Published var watchedFunds: [WatchedFund] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(watchedFunds) {
                UserDefaults.standard.set(data, forKey: watchedFundsKey)
            }
        }
    }

    // MARK: - Private Properties

    private let service = FundService.shared
    private var refreshTimer: Timer?
    /// 交易时间刷新间隔
    private let tradingRefreshInterval: TimeInterval = 30
    /// 非交易时间刷新间隔
    private let idleRefreshInterval: TimeInterval = 300

    private let watchedFundsKey = "watched_funds_v2"
    private let dataSourceKey = "data_source"

    // MARK: - Computed Properties

    /// 自选基金代码列表
    var watchedCodes: [String] {
        watchedFunds.map(\.code)
    }

    /// 总估算涨跌幅
    var totalChangeDisplay: String {
        guard !funds.isEmpty else { return "--" }
        let avg = funds.map(\.changePercent).reduce(0, +) / Double(funds.count)
        let sign = avg >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", avg))%"
    }

    /// 总估算涨跌幅数值
    var totalChangePercent: Double {
        guard !funds.isEmpty else { return 0 }
        return funds.map(\.changePercent).reduce(0, +) / Double(funds.count)
    }

    /// 是否有持仓数据
    var hasAnyHolding: Bool {
        watchedFunds.contains { $0.hasHolding }
    }

    /// 总持仓市值
    var totalMarketValue: Double {
        watchedFunds.reduce(0) { total, wf in
            guard wf.hasHolding,
                  let fund = funds.first(where: { $0.fundcode == wf.code }) else { return total }
            return total + wf.marketValue(nav: fund.bestNav)
        }
    }

    /// 总持仓成本
    var totalCost: Double {
        watchedFunds.filter(\.hasHolding).reduce(0) { $0 + $1.totalCost }
    }

    /// 总盈亏金额
    var totalProfitLoss: Double {
        totalMarketValue - totalCost
    }

    /// 总盈亏比例
    var totalProfitPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (totalProfitLoss / totalCost) * 100
    }

    /// 今日预估盈亏金额（基于持仓份额 * 昨日净值 * 涨跌幅%）
    var todayEstimatedProfit: Double {
        watchedFunds.reduce(0) { total, wf in
            guard wf.hasHolding,
                  let fund = funds.first(where: { $0.fundcode == wf.code }) else { return total }
            let yesterdayNav = fund.unitValue
            return total + wf.shares * yesterdayNav * (fund.changePercent / 100)
        }
    }

    /// 是否在交易时间
    var isTradingTime: Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)

        guard weekday >= 2 && weekday <= 6 else { return false }

        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let timeValue = hour * 60 + minute

        let morningStart = 9 * 60 + 30
        let morningEnd = 11 * 60 + 30
        let afternoonStart = 13 * 60
        let afternoonEnd = 15 * 60

        return (timeValue >= morningStart && timeValue <= morningEnd) ||
               (timeValue >= afternoonStart && timeValue <= afternoonEnd)
    }

    // MARK: - Lifecycle

    init() {
        // 恢复数据源选择（直接赋值避免触发 didSet）
        if let savedSource = UserDefaults.standard.string(forKey: dataSourceKey),
           let source = DataSource(rawValue: savedSource) {
            _currentDataSource = Published(initialValue: source)
            service.switchSource(to: source)
        }

        // 从 UserDefaults 恢复自选列表（直接赋值避免触发 didSet 写入）
        if let data = UserDefaults.standard.data(forKey: watchedFundsKey),
           let funds = try? JSONDecoder().decode([WatchedFund].self, from: data) {
            _watchedFunds = Published(initialValue: funds)
        } else {
            _watchedFunds = Published(initialValue: migrateFromOldFormat())
        }

        startAutoRefresh()
        Task { await refresh() }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// 添加自选基金
    func addFund(code: String, shares: Double = 0, costPrice: Double = 0) async -> Bool {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCode.count == 6,
              trimmedCode.allSatisfy({ $0.isNumber }) else {
            errorMessage = "请输入6位数字基金代码"
            return false
        }

        guard !watchedCodes.contains(trimmedCode) else {
            errorMessage = "该基金已在自选列表中"
            return false
        }

        do {
            let fund = try await service.fetchEstimate(code: trimmedCode)
            let newWatched = WatchedFund(
                code: trimmedCode,
                name: fund.name,
                sortIndex: watchedFunds.count,
                shares: shares,
                costPrice: costPrice
            )
            watchedFunds.append(newWatched)
            funds.append(fund)
            return true
        } catch {
            errorMessage = "基金代码无效或网络异常"
            return false
        }
    }

    /// 移除自选基金
    func removeFund(code: String) {
        watchedFunds.removeAll { $0.code == code }
        funds.removeAll { $0.fundcode == code }
    }

    /// 更新持仓信息
    func updateHolding(code: String, shares: Double, costPrice: Double) {
        if let index = watchedFunds.firstIndex(where: { $0.code == code }) {
            watchedFunds[index].shares = shares
            watchedFunds[index].costPrice = costPrice
        }
    }

    /// 获取某只基金的持仓信息
    func getWatchedFund(code: String) -> WatchedFund? {
        watchedFunds.first { $0.code == code }
    }

    /// 手动刷新
    func refresh() async {
        let codes = watchedCodes
        guard !codes.isEmpty else {
            funds = []
            return
        }

        isLoading = true
        errorMessage = nil

        var result = await service.fetchMultipleEstimates(codes: codes)

        // 用持久化名称覆盖数据源返回的无效名称，并更新存储名称
        for i in 0..<result.count {
            let code = result[i].fundcode
            if let wIndex = watchedFunds.firstIndex(where: { $0.code == code }) {
                if watchedFunds[wIndex].name.isEmpty && !result[i].name.isEmpty {
                    // 存储名称为空，采用 API 返回的名称
                    watchedFunds[wIndex].name = result[i].name
                } else if !watchedFunds[wIndex].name.isEmpty && result[i].name != watchedFunds[wIndex].name {
                    // 存储名称非空，始终用存储名称覆盖
                    result[i] = Fund(
                        fundcode: result[i].fundcode,
                        name: watchedFunds[wIndex].name,
                        dwjz: result[i].dwjz,
                        gsz: result[i].gsz,
                        gszzl: result[i].gszzl,
                        gztime: result[i].gztime,
                        jzrq: result[i].jzrq
                    )
                }
            }
        }
        // needsSave 时 watchedFunds 的 didSet 已自动触发写入

        withAnimation(.easeInOut(duration: 0.3)) {
            self.funds = result
            self.lastUpdateTime = Date()
            self.isLoading = false
        }
    }

    /// 开始自动刷新（交易时间 30s，非交易时间 5min）
    func startAutoRefresh() {
        refreshTimer?.invalidate()
        let interval = isTradingTime ? tradingRefreshInterval : idleRefreshInterval
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // 动态调整刷新频率
                let shouldUseTradingInterval = self.isTradingTime
                let currentInterval = shouldUseTradingInterval ? self.tradingRefreshInterval : self.idleRefreshInterval
                if currentInterval != interval {
                    self.startAutoRefresh() // 频率变化时重新设置 Timer
                }
                await self.refresh()
            }
        }
    }

    /// 停止自动刷新
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Migration

    /// 从旧版格式迁移
    private func migrateFromOldFormat() -> [WatchedFund] {
        let oldKey = "watched_fund_codes"
        guard let codes = UserDefaults.standard.stringArray(forKey: oldKey) else {
            return []
        }
        let migrated = codes.enumerated().map { index, code in
            WatchedFund(code: code, sortIndex: index, shares: 0, costPrice: 0)
        }
        // 保存为新格式
        if let data = try? JSONEncoder().encode(migrated) {
            UserDefaults.standard.set(data, forKey: watchedFundsKey)
        }
        // 清理旧 key
        UserDefaults.standard.removeObject(forKey: oldKey)
        return migrated
    }
}
