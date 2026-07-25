import Foundation

/// 基金估值估算服务
///
/// 公共实时估值接口（fundgz.1234567.com.cn）失效后，自行根据基金持仓 + 个股/指数实时行情计算估算净值。
///
/// 估算策略（按优先级）：
/// 1. **跟踪指数估算**（ETF / 指数基金）：`估算涨跌幅 = 跟踪指数今日涨跌幅`
///    - 适用：前十大重仓覆盖太低（如 ETF 仅 1%）的基金
/// 2. **重仓股加权估算**（主动权益基金）：
///    `估算涨跌幅 = Σ(重仓股i 今日涨跌幅 × 重仓股i 占净值比 / 100)`
///
/// 最终：`估算净值 = 上一交易日确认净值 × (1 + 估算涨跌幅/100)`
///
/// 任何环节失败时（无重仓股、无跟踪指数、行情拉取失败），原样返回该 Fund，由调用方回退到净值兜底。
final class EstimateService {

    static let shared = EstimateService()

    private init() {}

    // MARK: - Public

    /// 对一批 Fund 注入本地估算的 gsz / gszzl
    ///
    /// - 传入的 `funds` 必须已包含 dwjz（上一交易日确认净值）
    /// - 净值已确认当日（isNavUpdatedToday）的 Fund 跳过估算（权威数据优先）
    /// - 无可用估算数据的 Fund 原样返回
    func applyEstimates(to funds: [Fund]) async -> [Fund] {
        guard !funds.isEmpty else { return funds }

        // 1) 过滤出需要估算的基金（净值未确认的）
        let fundsToEstimate = funds.filter { !$0.isNavUpdatedToday }
        guard !fundsToEstimate.isEmpty else { return funds }

        // 2) 批量拉取估算元数据（重仓股 + 跟踪指数）
        let fundCodes = fundsToEstimate.map { $0.fundcode }
        let metaMap = await HoldingsService.shared.getEstimateMeta(for: fundCodes)

        // 3) 收集所有需要的 secid（股票 + 指数，去重）
        var allSecids = Set<String>()
        for (_, meta) in metaMap {
            // 指数基金：加指数 secid（需按指数代码判断市场）
            if let indexCode = meta.trackingIndexCode, !indexCode.isEmpty {
                if let indexSecid = Self.indexSecid(for: indexCode) {
                    allSecids.insert(indexSecid)
                }
            }
            // 重仓股：加股票 secid
            for h in meta.holdings {
                allSecids.insert("\(h.marketCode).\(h.code)")
            }
        }
        guard !allSecids.isEmpty else { return funds }

        // 4) 批量拉取行情（股票 + 指数混在一起一次请求）
        let quotes = await StockQuoteService.shared.fetchQuotes(secids: Array(allSecids))
        guard !quotes.isEmpty else { return funds }

        // 5) 对每只 Fund 计算估算值
        let now = Self.currentTimestamp()
        var result: [Fund] = []
        result.reserveCapacity(funds.count)

        for fund in funds {
            if fund.isNavUpdatedToday {
                // 已确认净值 → 不估
                result.append(fund)
                continue
            }

            guard let meta = metaMap[fund.fundcode] else {
                result.append(fund)
                continue
            }

            guard let estimateChange = computeEstimateChange(meta: meta, quotes: quotes) else {
                result.append(fund)
                continue
            }

            let lastNav = fund.unitValue
            guard lastNav > 0 else {
                result.append(fund)
                continue
            }
            let estimateNAV = lastNav * (1 + estimateChange / 100)

            // 重建 Fund，注入估算值
            // 精度对齐 syncConfirmedNav 现有格式：gsz=%.4f, gszzl=%.2f
            result.append(Fund(
                fundcode: fund.fundcode,
                name: fund.name,
                dwjz: fund.dwjz,
                gsz: String(format: "%.4f", estimateNAV),
                gszzl: String(format: "%.2f", estimateChange),
                gztime: now,
                jzrq: fund.jzrq,
                isEstimatedLocally: true
            ))
        }

        return result
    }

    // MARK: - 估算算法

    /// 计算单只基金的估算涨跌幅（%）
    /// 优先用跟踪指数，其次用前十大重仓股加权
    private func computeEstimateChange(
        meta: HoldingsService.FundEstimateMeta,
        quotes: [String: StockQuoteService.Quote]
    ) -> Double? {
        // 策略 1：跟踪指数（ETF / 指数基金）
        if let indexCode = meta.trackingIndexCode, !indexCode.isEmpty,
           let indexSecid = Self.indexSecid(for: indexCode),
           let q = quotes[indexSecid] {
            return q.changePercent
        }

        // 策略 2：前十大重仓股加权
        guard !meta.holdings.isEmpty else { return nil }

        var totalChange = 0.0
        var hasAnyContribution = false

        for h in meta.holdings {
            let secid = "\(h.marketCode).\(h.code)"
            guard let quote = quotes[secid] else { continue }

            // weight=9.23 表示占净值 9.23%
            // contribution = 股票涨跌幅 × (持仓占净值比)
            //              = quote.changePercent × (h.weight / 100)
            let contribution = quote.changePercent * h.weight / 100
            totalChange += contribution
            hasAnyContribution = true
        }

        return hasAnyContribution ? totalChange : nil
    }

    // MARK: - 工具

    /// 指数代码 → 东方财富 secid（判断市场）
    /// 规则：
    ///   - 000xxx / 950xxx：沪市发布的指数（沪深300、上证50 等）→ "1.000xxx"
    ///   - 399xxx：深市发布的指数（创业板指、深证成指 等）→ "0.399xxx"
    ///   - 其他（如 930xxx 中证定制指数）：默认沪市，查不到由调用方 fallback
    private static func indexSecid(for indexCode: String) -> String? {
        guard !indexCode.isEmpty else { return nil }
        if indexCode.hasPrefix("399") {
            return "0.\(indexCode)"
        }
        // 000xxx、950xxx、930xxx 等中证系列默认沪市
        return "1.\(indexCode)"
    }

    private static func currentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
}
