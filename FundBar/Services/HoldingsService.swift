import Foundation

/// 基金估算元数据服务 - 获取基金前十大重仓股和跟踪指数
///
/// 数据来自东方财富移动端接口：
/// - `FundMNInverstPosition` 提供前十大重仓股（季报披露，每季度更新）
/// - `FundMNDetailInformation` 提供跟踪指数代码（INDEXCODE）
///
/// 由于数据更新频率低，采用内存 + UserDefaults 双层缓存，TTL 7 天。
final class HoldingsService {

    static let shared = HoldingsService()

    /// 基金估算所需的元数据
    struct FundEstimateMeta: Codable, Equatable {
        let holdings: [StockHolding]        // 前十大重仓股（可能为空，如纯债基金）
        let trackingIndexCode: String?      // 跟踪指数代码（如 "000300"），仅 ETF/指数基金有
    }

    /// 单只重仓股持仓信息
    struct StockHolding: Codable, Equatable {
        let code: String         // 股票代码（去掉市场前缀，如 600519）
        let name: String         // 股票名称
        let weight: Double       // 占净值比 (%)
        let marketCode: String   // 东方财富市场代码：1=沪, 0=深, 116=港
    }

    /// 缓存条目
    private struct CacheEntry: Codable {
        let meta: FundEstimateMeta
        let fetchDate: Date
    }

    // MARK: - 缓存（内存 + 持久化）

    /// 内存缓存：fundCode -> CacheEntry
    private var memoryCache: [String: CacheEntry] = [:]
    private let cacheQueue = DispatchQueue(label: "com.fundbar.holdings.cache")

    /// UserDefaults 持久化 key
    private let persistedCacheKey = "fund_holdings_cache_v1"

    /// 缓存有效期（秒）。季报数据，7 天足够安全
    private let cacheTTL: TimeInterval = 7 * 24 * 60 * 60

    private let session: URLSession

    // MARK: - Init

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)

        // 启动时载入持久化缓存
        loadPersistedCache()
    }

    // MARK: - Public

    /// 获取单只基金的估算元数据（带缓存）
    func getEstimateMeta(fundCode: String) async -> FundEstimateMeta {
        if let cached = readCache(fundCode: fundCode), !isExpired(cached) {
            return cached.meta
        }
        let meta = await fetchEstimateMetaFromAPI(fundCode: fundCode)
        writeCache(fundCode: fundCode, meta: meta)
        return meta
    }

    /// 批量获取多只基金的估算元数据
    func getEstimateMeta(for fundCodes: [String]) async -> [String: FundEstimateMeta] {
        await withTaskGroup(of: (String, FundEstimateMeta).self, returning: [String: FundEstimateMeta].self) { group in
            for code in fundCodes {
                group.addTask {
                    let meta = await self.getEstimateMeta(fundCode: code)
                    return (code, meta)
                }
            }
            var result: [String: FundEstimateMeta] = [:]
            for await (code, meta) in group {
                result[code] = meta
            }
            return result
        }
    }

    // MARK: - API

    /// 并发拉取重仓股 + 基金详情（取 INDEXCODE）
    private func fetchEstimateMetaFromAPI(fundCode: String) async -> FundEstimateMeta {
        async let holdings = fetchHoldings(fundCode: fundCode)
        async let trackingIndex = fetchTrackingIndexCode(fundCode: fundCode)

        return FundEstimateMeta(
            holdings: await holdings,
            trackingIndexCode: await trackingIndex
        )
    }

    private func fetchHoldings(fundCode: String) async -> [StockHolding] {
        let urlString = "https://fundmobapi.eastmoney.com/FundMNewApi/FundMNInverstPosition?FCODE=\(fundCode)&deviceid=1&plat=Android&appType=ttjj&product=EFund&version=6.2.0"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return []
            }

            let apiResponse = try JSONDecoder().decode(FundHoldingsResponse.self, from: data)
            guard let stocks = apiResponse.datas?.fundStocks else { return [] }

            return stocks.compactMap { item -> StockHolding? in
                guard let code = item.gpdm,
                      let name = item.gpjc,
                      let weightStr = item.jzbl,
                      let weight = Double(weightStr),
                      let marketCode = item.newtexch else {
                    return nil
                }
                guard !code.isEmpty, code != "--" else { return nil }
                return StockHolding(code: code, name: name, weight: weight, marketCode: marketCode)
            }
        } catch {
            return []
        }
    }

    /// 获取基金跟踪指数代码（ETF/指数基金用）
    /// 返回形如 "000300" 的纯代码，或 nil（非指数基金）
    private func fetchTrackingIndexCode(fundCode: String) async -> String? {
        let urlString = "https://fundmobapi.eastmoney.com/FundMNewApi/FundMNDetailInformation?FCODE=\(fundCode)&deviceid=1&plat=Android&appType=ttjj&product=EFund&version=6.2.0"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            let apiResponse = try JSONDecoder().decode(FundDetailResponse.self, from: data)
            let raw = apiResponse.datas?.indexcode
            // 过滤无效值："--" 或空
            guard let raw, !raw.isEmpty, raw != "--" else { return nil }
            return raw
        } catch {
            return nil
        }
    }

    // MARK: - 缓存读写

    private func readCache(fundCode: String) -> CacheEntry? {
        cacheQueue.sync { memoryCache[fundCode] }
    }

    private func writeCache(fundCode: String, meta: FundEstimateMeta) {
        let entry = CacheEntry(meta: meta, fetchDate: Date())
        cacheQueue.sync { memoryCache[fundCode] = entry }
        persistCache()
    }

    private func isExpired(_ entry: CacheEntry) -> Bool {
        Date().timeIntervalSince(entry.fetchDate) > cacheTTL
    }

    private func loadPersistedCache() {
        guard let data = UserDefaults.standard.data(forKey: persistedCacheKey),
              let decoded = try? JSONDecoder().decode([String: CacheEntry].self, from: data) else {
            return
        }
        cacheQueue.sync { memoryCache = decoded }
    }

    private func persistCache() {
        let snapshot = cacheQueue.sync { memoryCache }
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: persistedCacheKey)
        }
    }
}

// MARK: - API 响应模型

private struct FundHoldingsResponse: Codable {
    let datas: FundHoldingsData?

    enum CodingKeys: String, CodingKey {
        case datas = "Datas"
    }
}

private struct FundHoldingsData: Codable {
    let fundStocks: [FundStockItem]?

    enum CodingKeys: String, CodingKey {
        case fundStocks = "fundStocks"
    }
}

private struct FundStockItem: Codable {
    let gpdm: String?        // GPDM     股票代码
    let gpjc: String?        // GPJC     股票名称
    let jzbl: String?        // JZBL     占净值比 (%)
    let newtexch: String?    // NEWTEXCH 市场代码 (1=沪, 0=深, 116=港)

    enum CodingKeys: String, CodingKey {
        case gpdm = "GPDM"
        case gpjc = "GPJC"
        case jzbl = "JZBL"
        case newtexch = "NEWTEXCH"
    }
}

private struct FundDetailResponse: Codable {
    let datas: FundDetailData?

    enum CodingKeys: String, CodingKey {
        case datas = "Datas"
    }
}

private struct FundDetailData: Codable {
    let indexcode: String?    // INDEXCODE 跟踪指数代码（仅 ETF/指数基金）

    enum CodingKeys: String, CodingKey {
        case indexcode = "INDEXCODE"
    }
}
