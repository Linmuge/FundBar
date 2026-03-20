import Foundation

/// 数据源类型
enum DataSource: String, Codable, CaseIterable {
    case tiantian = "天天基金"
}

/// 菜单栏显示模式
enum MenuBarDisplayMode: String, Codable, CaseIterable {
    case todayProfit = "今日盈亏"       // 有持仓时显示今日预估盈亏
    case changePercent = "平均涨跌幅"   // 显示所有基金平均涨跌幅
    case totalProfit = "总盈亏"        // 显示持仓总盈亏
    case hidden = "仅图标"             // 不显示文字
}

/// 排序模式
enum FundSortMode: String, Codable, CaseIterable {
    case manual = "手动排序"
    case changeDesc = "涨幅优先"
    case changeAsc = "跌幅优先"
    case profitDesc = "盈亏优先"
}

/// 基金估值数据模型 - 对应 API 返回的数据
struct Fund: Identifiable, Codable, Equatable {
    let fundcode: String   // 基金代码
    let name: String       // 基金名称
    let dwjz: String       // 单位净值
    let gsz: String        // 估算净值
    let gszzl: String      // 估算涨跌幅 (%)
    let gztime: String     // 估算时间
    let jzrq: String       // 净值日期 (yyyy-MM-dd)

    var id: String { fundcode }

    // jzrq 可能缺失（部分数据源），提供默认值
    init(fundcode: String, name: String, dwjz: String, gsz: String, gszzl: String, gztime: String, jzrq: String = "") {
        self.fundcode = fundcode
        self.name = name
        self.dwjz = dwjz
        self.gsz = gsz
        self.gszzl = gszzl
        self.gztime = gztime
        self.jzrq = jzrq
    }

    enum CodingKeys: String, CodingKey {
        case fundcode, name, dwjz, gsz, gszzl, gztime, jzrq
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fundcode = try container.decode(String.self, forKey: .fundcode)
        name = try container.decode(String.self, forKey: .name)
        dwjz = try container.decode(String.self, forKey: .dwjz)
        gsz = try container.decode(String.self, forKey: .gsz)
        gszzl = try container.decode(String.self, forKey: .gszzl)
        gztime = try container.decode(String.self, forKey: .gztime)
        jzrq = try container.decodeIfPresent(String.self, forKey: .jzrq) ?? ""
    }

    /// 最佳可用净值：当日净值已更新则用实际净值，否则用估算净值
    var bestNav: Double {
        if isNavUpdatedToday {
            return unitValue
        }
        return estimatedValue
    }

    /// 当日净值是否已更新（jzrq 与 gztime 同日 = 基金公司已发布实际净值）
    var isNavUpdatedToday: Bool {
        guard !jzrq.isEmpty, gztime.count >= 10 else { return false }
        let tradingDay = String(gztime.prefix(10)) // "yyyy-MM-dd"
        return jzrq == tradingDay
    }

    /// 涨跌幅数值
    var changePercent: Double {
        Double(gszzl) ?? 0
    }

    /// 估算净值数值
    var estimatedValue: Double {
        Double(gsz) ?? 0
    }

    /// 单位净值数值
    var unitValue: Double {
        Double(dwjz) ?? 0
    }

    /// 是否上涨
    var isUp: Bool {
        changePercent > 0
    }

    /// 是否下跌
    var isDown: Bool {
        changePercent < 0
    }
}

/// 自选基金 - 用于持久化存储（含持仓信息）
struct WatchedFund: Codable, Identifiable, Equatable {
    let code: String
    var name: String        // 基金名称（持久化）
    var fundType: String    // 基金类型（股票型/债券型等）
    var sortIndex: Int
    var shares: Double      // 持有份额（0 表示未录入）
    var costPrice: Double   // 持仓成本净值（0 表示未录入）

    var id: String { code }

    // 兼容旧版数据（无 name 字段）
    init(code: String, name: String = "", fundType: String = "", sortIndex: Int, shares: Double, costPrice: Double) {
        self.code = code
        self.name = name
        self.fundType = fundType
        self.sortIndex = sortIndex
        self.shares = shares
        self.costPrice = costPrice
    }

    enum CodingKeys: String, CodingKey {
        case code, name, fundType, sortIndex, shares, costPrice
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        fundType = try container.decodeIfPresent(String.self, forKey: .fundType) ?? ""
        sortIndex = try container.decode(Int.self, forKey: .sortIndex)
        shares = try container.decode(Double.self, forKey: .shares)
        costPrice = try container.decode(Double.self, forKey: .costPrice)
    }

    /// 是否有持仓数据
    var hasHolding: Bool {
        shares > 0 && costPrice > 0
    }

    /// 计算持仓市值
    func marketValue(nav: Double) -> Double {
        shares * nav
    }

    /// 计算持仓成本
    var totalCost: Double {
        shares * costPrice
    }

    /// 计算持仓盈亏
    func profitLoss(nav: Double) -> Double {
        marketValue(nav: nav) - totalCost
    }

    /// 计算盈亏比例
    func profitPercent(nav: Double) -> Double {
        guard totalCost > 0 else { return 0 }
        return (profitLoss(nav: nav) / totalCost) * 100
    }
}
