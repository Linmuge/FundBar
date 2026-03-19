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

    // MARK: - Private Properties

    private let service = FundService.shared
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 30 // 30 秒自动刷新

    private let watchedCodesKey = "watched_fund_codes"

    // MARK: - Computed Properties

    /// 自选基金代码列表
    var watchedCodes: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: watchedCodesKey) ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: watchedCodesKey)
        }
    }

    /// 总估算涨跌幅
    var totalChangeDisplay: String {
        guard !funds.isEmpty else { return "--" }
        let avg = funds.map(\.changePercent).reduce(0, +) / Double(funds.count)
        let sign = avg >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", avg))%"
    }

    /// 是否在交易时间
    var isTradingTime: Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)

        // 周末不交易  (1=周日, 7=周六)
        guard weekday >= 2 && weekday <= 6 else { return false }

        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let timeValue = hour * 60 + minute

        // 交易时间: 9:30-11:30, 13:00-15:00
        let morningStart = 9 * 60 + 30
        let morningEnd = 11 * 60 + 30
        let afternoonStart = 13 * 60
        let afternoonEnd = 15 * 60

        return (timeValue >= morningStart && timeValue <= morningEnd) ||
               (timeValue >= afternoonStart && timeValue <= afternoonEnd)
    }

    // MARK: - Lifecycle

    init() {
        startAutoRefresh()
        Task {
            await refresh()
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// 添加自选基金
    func addFund(code: String) async -> Bool {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCode.count == 6,
              trimmedCode.allSatisfy({ $0.isNumber }),
              !watchedCodes.contains(trimmedCode) else {
            return false
        }

        // 先尝试获取数据验证基金代码有效
        do {
            let fund = try await service.fetchEstimate(code: trimmedCode)
            watchedCodes.append(trimmedCode)
            funds.append(fund)
            return true
        } catch {
            errorMessage = "基金代码无效或网络异常"
            return false
        }
    }

    /// 移除自选基金
    func removeFund(code: String) {
        watchedCodes.removeAll { $0 == code }
        funds.removeAll { $0.fundcode == code }
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

        let result = await service.fetchMultipleEstimates(codes: codes)

        withAnimation(.easeInOut(duration: 0.3)) {
            self.funds = result
            self.lastUpdateTime = Date()
            self.isLoading = false
        }
    }

    /// 开始自动刷新
    func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    /// 停止自动刷新
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
