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

/// 持仓记录状态
enum HoldingStatus: String, Codable {
    case confirmed = "已确认"
    case pending = "待确认"
}

/// 单笔持仓记录
struct HoldingRecord: Codable, Identifiable, Equatable {
    let id: String  // UUID 字符串（而非 UUID 类型）以兼容 Codable 自动合成
    var shares: Double     // 本次买入份额
    var costPrice: Double  // 本次买入成本净值
    var date: String       // 买入日期 yyyy-MM-dd
    var note: String       // 备注
    var isDCA: Bool        // 是否定投记录

    // --- 新增扩展字段 ---
    var status: HoldingStatus // 持仓状态
    var buyAmount: Double?    // 买入金额 (仅待确认使用)
    var fee: Double?          // 手续费 (仅待确认使用)
    var targetConfirmDate: String? // 预计确认份额的净值日期

    /// 正常确认持仓
    init(shares: Double, costPrice: Double, date: String = "", note: String = "", isDCA: Bool = false) {
        self.id = UUID().uuidString
        self.shares = shares
        self.costPrice = costPrice
        self.date = date
        self.note = note
        self.isDCA = isDCA
        self.status = .confirmed
    }

    /// 待确认金额买入
    static func pending(buyAmount: Double, fee: Double?, date: String, targetConfirmDate: String) -> HoldingRecord {
        var record = HoldingRecord(shares: 0, costPrice: 0, date: date, note: "金额买入", isDCA: false)
        record.status = .pending
        record.buyAmount = buyAmount
        record.fee = fee
        record.targetConfirmDate = targetConfirmDate
        return record
    }

    // 向后兼容旧数据
    enum CodingKeys: String, CodingKey {
        case id, shares, costPrice, date, note, isDCA
        case status, buyAmount, fee, targetConfirmDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        shares = try container.decode(Double.self, forKey: .shares)
        costPrice = try container.decode(Double.self, forKey: .costPrice)
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        isDCA = try container.decodeIfPresent(Bool.self, forKey: .isDCA) ?? false
        
        status = try container.decodeIfPresent(HoldingStatus.self, forKey: .status) ?? .confirmed
        buyAmount = try container.decodeIfPresent(Double.self, forKey: .buyAmount)
        fee = try container.decodeIfPresent(Double.self, forKey: .fee)
        targetConfirmDate = try container.decodeIfPresent(String.self, forKey: .targetConfirmDate)
    }
}

/// 定投频率
enum DCAFrequency: String, Codable, CaseIterable {
    case daily = "每交易日"
    case weekly = "每周"
    case biweekly = "每两周"
    case monthly = "每月"
}

/// 定投计划
struct DCAPlan: Codable, Equatable {
    var frequency: DCAFrequency  // 定投频率
    var amount: Double           // 每期金额（元）

    init(frequency: DCAFrequency = .monthly, amount: Double = 0) {
        self.frequency = frequency
        self.amount = amount
    }
}

/// 自选基金 - 用于持久化存储（含持仓信息）
struct WatchedFund: Codable, Identifiable, Equatable {
    let code: String
    var name: String        // 基金名称（持久化）
    var fundType: String    // 基金类型（股票型/债券型等）
    var sortIndex: Int
    var holdings: [HoldingRecord]  // 持仓记录（支持多笔）
    var dcaPlan: DCAPlan?          // 定投计划（可选）

    var id: String { code }

    init(code: String, name: String = "", fundType: String = "", sortIndex: Int, shares: Double = 0, costPrice: Double = 0) {
        self.code = code
        self.name = name
        self.fundType = fundType
        self.sortIndex = sortIndex
        // 向后兼容：单笔持仓转换为 holdings 数组
        if shares > 0 && costPrice > 0 {
            self.holdings = [HoldingRecord(shares: shares, costPrice: costPrice)]
        } else {
            self.holdings = []
        }
    }

    enum CodingKeys: String, CodingKey {
        case code, name, fundType, sortIndex, shares, costPrice, holdings, dcaPlan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        fundType = try container.decodeIfPresent(String.self, forKey: .fundType) ?? ""
        sortIndex = try container.decode(Int.self, forKey: .sortIndex)
        dcaPlan = try container.decodeIfPresent(DCAPlan.self, forKey: .dcaPlan)

        // 优先读取 holdings 数组，超旧数据回退读 shares/costPrice
        if let h = try container.decodeIfPresent([HoldingRecord].self, forKey: .holdings), !h.isEmpty {
            holdings = h
        } else {
            let s = try container.decodeIfPresent(Double.self, forKey: .shares) ?? 0
            let c = try container.decodeIfPresent(Double.self, forKey: .costPrice) ?? 0
            holdings = (s > 0 && c > 0) ? [HoldingRecord(shares: s, costPrice: c)] : []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(name, forKey: .name)
        try container.encode(fundType, forKey: .fundType)
        try container.encode(sortIndex, forKey: .sortIndex)
        try container.encode(holdings, forKey: .holdings)
        try container.encode(dcaPlan, forKey: .dcaPlan)
        // 向后兼容写入聚合值
        try container.encode(shares, forKey: .shares)
        try container.encode(costPrice, forKey: .costPrice)
    }

    // MARK: - 聚合计算
    // 注意：shares 和 costPrice 是计算属性（从 holdings 聚合），
    // 同时也是 CodingKeys 的成员（用于向后兼容写入）。
    // 解码时优先读 holdings，仅旧数据回退读 shares/costPrice。

    /// 获取所有已确认的有效持仓记录 (待确认记录不计入份额和市值)
    var confirmedHoldings: [HoldingRecord] {
        holdings.filter { $0.status == .confirmed }
    }

    /// 总份额（从 confirmedHoldings 聚合）
    var shares: Double {
        confirmedHoldings.reduce(0) { $0 + $1.shares }
    }

    /// 加权平均成本净值（从 confirmedHoldings 聚合）
    var costPrice: Double {
        let totalShares = shares
        guard totalShares > 0 else { return 0 }
        return totalCost / totalShares
    }

    /// 是否有持仓数据
    var hasHolding: Bool {
        shares > 0
    }

    /// 计算持仓市值
    func marketValue(nav: Double) -> Double {
        shares * nav
    }

    /// 计算持仓成本
    var totalCost: Double {
        confirmedHoldings.reduce(0) { $0 + $1.shares * $1.costPrice }
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

    // MARK: - 定投统计

    /// 定投记录
    var dcaRecords: [HoldingRecord] {
        confirmedHoldings.filter { $0.isDCA }
    }

    /// 定投次数
    var dcaCount: Int {
        dcaRecords.count
    }

    /// 定投总投入金额
    var dcaTotalInvested: Double {
        dcaRecords.reduce(0) { $0 + $1.shares * $1.costPrice }
    }

    /// 定投总份额
    var dcaTotalShares: Double {
        dcaRecords.reduce(0) { $0 + $1.shares }
    }

    /// 定投平均成本
    var dcaAverageCost: Double {
        guard dcaTotalShares > 0 else { return 0 }
        return dcaTotalInvested / dcaTotalShares
    }

    /// 定投收益率
    func dcaProfitPercent(nav: Double) -> Double {
        guard dcaTotalInvested > 0 else { return 0 }
        let currentValue = dcaTotalShares * nav
        return (currentValue - dcaTotalInvested) / dcaTotalInvested * 100
    }
}
