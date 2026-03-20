import Foundation
import Combine
import SwiftUI
import ServiceManagement

/// 基金估值 ViewModel - 管理数据获取、自动刷新和持久化
@MainActor
final class FundViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var funds: [Fund] = []
    @Published var fundHistory: [String: [HistoryNav]] = [:]  // code -> 7日历史净值
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
    private let launchAtLoginKey = "launch_at_login"
    private let notifyThresholdKey = "notify_threshold"
    private let menuBarModeKey = "menu_bar_mode"
    private let sortModeKey = "sort_mode"
    static let showChartsKey = "showCharts"

    // MARK: - Computed Properties

    /// 自选基金代码列表
    var watchedCodes: [String] {
        watchedFunds.map(\.code)
    }

    /// 菜单栏显示模式
    @Published var menuBarMode: MenuBarDisplayMode = .todayProfit {
        didSet { UserDefaults.standard.set(menuBarMode.rawValue, forKey: menuBarModeKey) }
    }

    /// 排序模式
    @Published var sortMode: FundSortMode = .manual {
        didSet { UserDefaults.standard.set(sortMode.rawValue, forKey: sortModeKey) }
    }

    /// 菜单栏显示文字
    var menuBarText: String {
        switch menuBarMode {
        case .todayProfit:
            if hasAnyHolding {
                let ep = todayEstimatedProfit
                let sign = ep >= 0 ? "+" : ""
                return "\(sign)\(String(format: "%.0f", ep))"
            } else {
                return totalChangeDisplay
            }
        case .changePercent:
            return totalChangeDisplay
        case .totalProfit:
            if hasAnyHolding {
                let pl = totalProfitLoss
                let sign = pl >= 0 ? "+" : ""
                return "\(sign)\(String(format: "%.0f", pl))"
            } else {
                return "--"
            }
        case .hidden:
            return ""
        }
    }

    /// 菜单栏文字颜色
    var menuBarColor: Color {
        switch menuBarMode {
        case .todayProfit:
            let val = hasAnyHolding ? todayEstimatedProfit : totalChangePercent
            if val > 0 { return .red }
            if val < 0 { return .green }
            return .secondary
        case .changePercent:
            let avg = totalChangePercent
            if avg > 0 { return .red }
            if avg < 0 { return .green }
            return .secondary
        case .totalProfit:
            let pl = totalProfitLoss
            if pl > 0 { return .red }
            if pl < 0 { return .green }
            return .secondary
        case .hidden:
            return .secondary
        }
    }

    /// 排序后的基金列表
    var sortedFunds: [Fund] {
        switch sortMode {
        case .manual:
            return funds
        case .changeDesc:
            return funds.sorted { $0.changePercent > $1.changePercent }
        case .changeAsc:
            return funds.sorted { $0.changePercent < $1.changePercent }
        case .profitDesc:
            return funds.sorted { fundProfit($0) > fundProfit($1) }
        }
    }

    /// 开机自启
    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: launchAtLoginKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: launchAtLoginKey)
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Launch at login error: \(error)")
            }
            objectWillChange.send()
        }
    }

    /// 涨跌通知阈值（%，0 = 关闭）
    @Published var notifyThreshold: Double = 0 {
        didSet {
            UserDefaults.standard.set(notifyThreshold, forKey: notifyThresholdKey)
        }
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

    /// 单只基金盈亏（用于排序）
    func fundProfit(_ fund: Fund) -> Double {
        guard let wf = watchedFunds.first(where: { $0.code == fund.fundcode }),
              wf.hasHolding else { return 0 }
        return wf.profitLoss(nav: fund.bestNav)
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

        // 恢复通知阈值
        let savedThreshold = UserDefaults.standard.double(forKey: notifyThresholdKey)
        _notifyThreshold = Published(initialValue: savedThreshold)

        // 恢复菜单栏显示模式
        if let savedMode = UserDefaults.standard.string(forKey: menuBarModeKey),
           let mode = MenuBarDisplayMode(rawValue: savedMode) {
            _menuBarMode = Published(initialValue: mode)
        }

        // 恢复排序模式
        if let savedSort = UserDefaults.standard.string(forKey: sortModeKey),
           let sort = FundSortMode(rawValue: savedSort) {
            _sortMode = Published(initialValue: sort)
        }

        startAutoRefresh()
        Task { await refresh() }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// 添加自选基金
    func addFund(code: String, shares: Double = 0, costPrice: Double = 0, fundType: String = "") async -> Bool {
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
                fundType: fundType,
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

    /// 添加一笔持仓记录
    func addHolding(code: String, shares: Double, costPrice: Double, date: String = "", note: String = "") {
        if let index = watchedFunds.firstIndex(where: { $0.code == code }) {
            watchedFunds[index].holdings.append(
                HoldingRecord(shares: shares, costPrice: costPrice, date: date, note: note)
            )
        }
    }

    /// 移除一笔持仓记录
    func removeHolding(code: String, recordId: String) {
        if let index = watchedFunds.firstIndex(where: { $0.code == code }) {
            watchedFunds[index].holdings.removeAll { $0.id == recordId }
        }
    }

    /// 清空持仓
    func clearHoldings(code: String) {
        if let index = watchedFunds.firstIndex(where: { $0.code == code }) {
            watchedFunds[index].holdings = []
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

        // 涨跌通知检查
        NotificationService.shared.checkAndNotify(funds: result, threshold: notifyThreshold)

        // 异步加载历史数据（不阻塞主刷新）
        Task { await fetchHistoryData(codes: codes) }

        // 从基金名称解析类型并补全
        backfillFundTypesFromName()
    }

    /// 从基金名称解析类型
    private func backfillFundTypesFromName() {
        var changed = false
        for i in 0..<watchedFunds.count {
            if watchedFunds[i].fundType.isEmpty {
                if let fund = funds.first(where: { $0.fundcode == watchedFunds[i].code }) {
                    let parsed = parseFundType(from: fund.name)
                    if !parsed.isEmpty {
                        watchedFunds[i].fundType = parsed
                        changed = true
                    }
                }
            }
        }
        // changed 时 watchedFunds.didSet 已自动持久化
    }

    /// 从基金名称中提取类型关键词
    private func parseFundType(from name: String) -> String {
        // 货币/债券优先（不会被混淆）
        if name.contains("货币") { return "货币型" }
        if name.contains("纯债") || name.contains("信用债") || name.contains("可转债") || name.contains("债券") {
            return "债券型"
        }
        // QDII/FOF 优先（可能包含"混合"等关键词）
        if name.contains("QDII") { return "QDII" }
        if name.contains("FOF") || name.contains("养老目标") { return "FOF" }
        // 指数型优先（可能名称含"股票"但实际是指数）
        if name.contains("ETF") || name.contains("指数") || name.contains("联接") || name.contains("跟踪") {
            return "指数型"
        }
        // 股票型优先于混合型（避免"成长精选股票型"被匹配为混合）
        if name.contains("股票") { return "股票型" }
        // 混合型最后（关键词较广泛）
        if name.contains("混合") || name.contains("灵活配置") || name.contains("平衡") || name.contains("稳健") || name.contains("优选") || name.contains("成长") || name.contains("价值") || name.contains("精选") {
            return "混合型"
        }
        return ""
    }

    /// 获取所有基金的7日历史净值
    private func fetchHistoryData(codes: [String]) async {
        var results: [(String, [HistoryNav])] = []
        await withTaskGroup(of: (String, [HistoryNav]).self) { group in
            for code in codes {
                if fundHistory[code] != nil { continue }
                group.addTask {
                    let history = await self.service.fetchHistory(code: code, days: 7)
                    return (code, history)
                }
            }
            for await result in group {
                results.append(result)
            }
        }
        for (code, navs) in results {
            if !navs.isEmpty {
                fundHistory[code] = navs
            }
        }
    }

    /// 开始自动刷新（交易时间 30s，非交易时间 5min）
    func startAutoRefresh() {
        refreshTimer?.invalidate()
        let interval = isTradingTime ? tradingRefreshInterval : idleRefreshInterval
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // 每日首次刷新时重置通知记录
                NotificationService.shared.resetDailyIfNeeded()
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

    // MARK: - Reorder

    /// 拖拽排序
    func moveFund(from source: IndexSet, to destination: Int) {
        // 拷贝 → 修改 → 整体赋值，只触发一次 didSet 持久化
        var updated = watchedFunds
        updated.move(fromOffsets: source, toOffset: destination)
        for i in 0..<updated.count {
            updated[i].sortIndex = i
        }
        watchedFunds = updated
        // 同步 funds 顺序
        let orderedCodes = watchedFunds.map(\.code)
        funds.sort { a, b in
            (orderedCodes.firstIndex(of: a.fundcode) ?? 0) < (orderedCodes.firstIndex(of: b.fundcode) ?? 0)
        }
    }

    // MARK: - Data Export/Import

    /// 导出数据
    func exportData(to url: URL) {
        struct ExportData: Codable {
            let watchedFunds: [WatchedFund]
            let dataSource: String
            let exportDate: String
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let data = ExportData(
            watchedFunds: watchedFunds,
            dataSource: currentDataSource.rawValue,
            exportDate: formatter.string(from: Date())
        )

        if let jsonData = try? JSONEncoder().encode(data) {
            try? jsonData.write(to: url)
        }
    }

    /// 导入数据
    func importData(from url: URL) {
        struct ExportData: Codable {
            let watchedFunds: [WatchedFund]
            let dataSource: String?
        }

        guard let jsonData = try? Data(contentsOf: url),
              let data = try? JSONDecoder().decode(ExportData.self, from: jsonData) else {
            errorMessage = "导入文件格式无效"
            return
        }

        watchedFunds = data.watchedFunds
        // 使用底层 Published 赋值避免触发 didSet 中的 refresh
        if let sourceStr = data.dataSource, let source = DataSource(rawValue: sourceStr) {
            _currentDataSource = Published(wrappedValue: source)
            service.switchSource(to: source)
            UserDefaults.standard.set(source.rawValue, forKey: dataSourceKey)
        }
        _fundHistory = Published(wrappedValue: [:])  // 清空历史数据以重新加载
        Task { await refresh() }
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
