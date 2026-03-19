import Foundation

/// 基金估值数据模型 - 对应天天基金 API 返回的 JSONP 数据
struct Fund: Identifiable, Codable, Equatable {
    let fundcode: String   // 基金代码
    let name: String       // 基金名称
    let dwjz: String       // 单位净值
    let gsz: String        // 估算净值
    let gszzl: String      // 估算涨跌幅 (%)
    let gztime: String     // 估算时间

    var id: String { fundcode }

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

/// 自选基金 - 用于持久化存储
struct WatchedFund: Codable, Identifiable, Equatable {
    let code: String
    var sortIndex: Int

    var id: String { code }
}
