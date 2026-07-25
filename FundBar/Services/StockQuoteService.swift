import Foundation

/// GBK / GB18030 编码支持（腾讯股票接口返回 GBK）
extension String.Encoding {
    /// GB18030 编码（兼容 GBK / GB2312）
    static var gbk: String.Encoding {
        // CFStringEncodings.GB_18030_2000 = 1512
        let cfEncoding = CFStringEncodings.GB_18030_2000
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfEncoding.rawValue))
        return String.Encoding(rawValue: nsEncoding)
    }
}

/// 个股实时行情服务 - 批量获取股票现价和涨跌幅
///
/// 数据来自腾讯股票接口 `qt.gtimg.cn`（实测稳定，支持 A 股 + 港股批量查询）。
/// 行情是实时数据，不做缓存。
final class StockQuoteService {

    static let shared = StockQuoteService()

    /// 单只股票实时行情
    struct Quote {
        let price: Double          // 当前价格
        let changePercent: Double  // 涨跌幅 (%)
    }

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public

    /// 批量获取股票行情
    ///
    /// - Parameter secids: 股票标识数组，格式为 `前缀.代码`（如 `1.600519`、`0.000001`、`116.00700`）
    /// - Returns: `[secid: Quote]` 字典，查询失败的股票不在结果中
    func fetchQuotes(secids: [String]) async -> [String: Quote] {
        guard !secids.isEmpty else { return [:] }

        // 腾讯接口参数格式：sh600519,sz000001,hk00700
        let tencentCodes = secids.compactMap { Self.toTencentCode($0) }
        guard !tencentCodes.isEmpty else { return [:] }

        let joined = tencentCodes.joined(separator: ",")
        let urlString = "https://qt.gtimg.cn/q=\(joined)"
        guard let url = URL(string: urlString) else { return [:] }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return [:]
            }

            // 腾讯接口返回 GBK 编码；优先 GBK，失败回退 UTF-8
            let gbkEncoding = String.Encoding.gbk
            let text = String(data: data, encoding: gbkEncoding) ?? String(data: data, encoding: .utf8) ?? ""
            guard !text.isEmpty else {
                return [:]
            }

            return Self.parseTencentResponse(text: text, originalSecids: secids)
        } catch {
            return [:]
        }
    }

    // MARK: - 腾讯接口格式转换

    /// `1.600519` → `sh600519`；`0.000001` → `sz000001`；`116.00700` → `hk00700`
    private static func toTencentCode(_ secid: String) -> String? {
        let parts = secid.split(separator: ".", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let market = String(parts[0])
        let code = String(parts[1])

        let prefix: String
        switch market {
        case "1":   prefix = "sh"    // 沪市
        case "0":   prefix = "sz"    // 深市
        case "116": prefix = "hk"    // 港股
        default:    return nil
        }
        return prefix + code
    }

    /// 反向：腾讯代码 → secid（用于结果映射回原始 key）
    private static func fromTencentCode(_ tencentCode: String) -> String? {
        guard tencentCode.count > 2 else { return nil }
        let prefix = String(tencentCode.prefix(2))
        let code = String(tencentCode.dropFirst(2))

        let market: String
        switch prefix {
        case "sh": market = "1"
        case "sz": market = "0"
        case "hk": market = "116"
        default:   return nil
        }
        return "\(market).\(code)"
    }

    /// 解析腾讯返回的 `v_sh600519="...";v_sz000001="...";` 格式
    private static func parseTencentResponse(text: String, originalSecids: [String]) -> [String: Quote] {
        var result: [String: Quote] = [:]

        // 匹配 v_xxx="yyy"; 每个条目
        let pattern = #"v_([^=]+)=\"([^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let keyRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text) else {
                continue
            }
            let tencentCode = String(text[keyRange])
            let value = String(text[valueRange])

            guard let secid = fromTencentCode(tencentCode),
                  let quote = parseQuoteValue(value) else {
                continue
            }
            result[secid] = quote
        }

        return result
    }

    /// 解析腾讯单条记录：`1~贵州茅台~600519~1301.69~1327.50~...~-25.81~-1.94~...`
    /// 关键字段位置（A 股）：
    ///   - 索引 3: 当前价格
    ///   - 索引 4: 昨收价
    ///   - 索引 32: 涨跌幅 (%)
    /// 港股字段位置略有差异，但 3/32 大体一致
    private static func parseQuoteValue(_ value: String) -> Quote? {
        let fields = value.split(separator: "~", omittingEmptySubsequences: false).map(String.init)
        guard fields.count > 32 else { return nil }

        guard let price = Double(fields[3]),
              let changePercent = Double(fields[32]) else {
            return nil
        }

        // 价格为 0 表示停牌或无数据
        guard price > 0 else { return nil }

        return Quote(price: price, changePercent: changePercent)
    }
}
