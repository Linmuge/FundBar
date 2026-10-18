import SwiftUI
import UniformTypeIdentifiers
import AppKit


/// 设计令牌 —— macOS 27 · 方向 A「通透 Clear Glass」
/// 规格来源:macos27-demos/direction-A.html(经用户选定,保真落地)
enum FundBarDesign {
    static let menuWidth: CGFloat = 396
    static let menuCornerRadius: CGFloat = 28

    static let windowRadius: CGFloat = 16   // 窗口级玻璃
    static let panelRadius: CGFloat = 18    // 浮起玻璃面板(macOS 27 尺度的圆角)
    static let innerRadius: CGFloat = 12    // 面板内嵌块(hero 内盒/输入区)
    static let compactPanelRadius: CGFloat = 12 // 兼容旧引用(= innerRadius)
    static let controlRadius: CGFloat = 10  // 图标按钮/下拉
    static let rowRadius: CGFloat = 8       // 列表行 hover 高亮
    static let gutter: CGFloat = 14         // 面板呼吸缝(透出壁纸)
    static let railGap: CGFloat = 12        // 右栏面板间距
}

extension Color {
    /// 红涨绿跌 —— 精炼的中国红(非消防红)。自动适配亮/暗模式。
    static let fundUp = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil {
            return NSColor(srgbRed: 0xFF/255, green: 0x5A/255, blue: 0x4D/255, alpha: 1) // #ff5a4d 暗色
        }
        return NSColor(srgbRed: 0xD8/255, green: 0x39/255, blue: 0x2F/255, alpha: 1)    // #d8392f 亮色
    })

    /// 绿跌 —— 自信的绿。自动适配亮/暗模式。
    static let fundDown = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil {
            return NSColor(srgbRed: 0x34/255, green: 0xC7/255, blue: 0x59/255, alpha: 1) // #34c759 暗色
        }
        return NSColor(srgbRed: 0x2B/255, green: 0x9F/255, blue: 0x5E/255, alpha: 1)    // #2b9f5e 亮色
    })

    /// 数据文字用的深一档红(Hero 大数字用 fundUp,表格/胶囊文字用 ink 变体)
    static let fundUpInk = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil {
            return NSColor(srgbRed: 0xFF/255, green: 0x6A/255, blue: 0x60/255, alpha: 1) // #ff6a60
        }
        return NSColor(srgbRed: 0xC2/255, green: 0x31/255, blue: 0x2A/255, alpha: 1)    // #c2312a
    })

    /// 数据文字用的深一档绿
    static let fundDownInk = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil {
            return NSColor(srgbRed: 0x3D/255, green: 0xD6/255, blue: 0x78/255, alpha: 1) // #3dd678
        }
        return NSColor(srgbRed: 0x1E/255, green: 0x7A/255, blue: 0x49/255, alpha: 1)    // #1e7a49
    })

    /// 定投 / 买入动作色(暖橙)
    static let fundDCA = Color(red: 0.91, green: 0.35, blue: 0.05) // #e8590c

    /// 窗口底色:亮色=明确浅灰(修「发白」,白卡片有层次);暗色=深灰蓝黑
    static let fundWindowBG = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil {
            return NSColor(srgbRed: 0x1E/255, green: 0x1F/255, blue: 0x25/255, alpha: 1) // #1e1f25
        }
        return NSColor(srgbRed: 0xE7/255, green: 0xE8/255, blue: 0xED/255, alpha: 1)    // #e7e8ed
    })

    /// 卡片面:亮色=纯白;暗色=比窗口亮一档的深灰
    static let fundCardBG = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil {
            return NSColor(srgbRed: 0x29/255, green: 0x2B/255, blue: 0x31/255, alpha: 1) // #292b31
        }
        return NSColor.white
    })

    /// 品牌蓝(渐变胶囊按钮 / 徽标)
    static let fundPromoTop = Color(red: 0x16/255, green: 0x77/255, blue: 0xEE/255) // #1677ee
    static let fundPromoBottom = Color(red: 0x0A/255, green: 0x58/255, blue: 0xC8/255) // #0a58c8
    static let fundBadgeTop = Color(red: 0x1A/255, green: 0x7B/255, blue: 0xF2/255)  // #1a7bf2

    /// 由数值正负取语义色
    static func fundTrend(_ value: Double) -> Color {
        value > 0 ? .fundUp : (value < 0 ? .fundDown : .secondary)
    }

    /// 数据文字变体(表格/胶囊内)
    static func fundTrendInk(_ value: Double) -> Color {
        value > 0 ? .fundUpInk : (value < 0 ? .fundDownInk : .secondary)
    }

    /// 基金类型色(环形图/圆点)—— 方向 A 规格:按类型着色
    static func fundTypeColor(_ type: String) -> Color {
        if type.contains("股票") { return Color(red: 0.91, green: 0.35, blue: 0.05) }   // #e8590c
        if type.contains("混合") { return Color(red: 0.54, green: 0.25, blue: 0.99) }   // #8a3ffc
        if type.contains("债券") { return Color(red: 0.11, green: 0.49, blue: 0.84) }   // #1c7ed6
        if type.contains("指数") { return Color(red: 0.04, green: 0.58, blue: 0.59) }   // #0a9396
        if type.contains("货币") { return Color(red: 0.596, green: 0.635, blue: 0.70) } // #98a2b3
        if type.contains("QDII") { return Color(red: 0.21, green: 0.31, blue: 0.78) }   // #364fc7
        if type.contains("FOF") { return .mint }
        return .secondary
    }

    /// 基金类型标签文字色(比圆点深一档,保证对比度)
    static func fundTypeInk(_ type: String) -> Color {
        if type.contains("股票") { return Color(red: 0.74, green: 0.27, blue: 0.03) }   // #bd4507
        if type.contains("混合") { return Color(red: 0.54, green: 0.25, blue: 0.99) }   // #8a3ffc
        if type.contains("债券") { return Color(red: 0.04, green: 0.37, blue: 0.75) }   // #0a5ec0
        if type.contains("指数") { return Color(red: 0.03, green: 0.50, blue: 0.51) }   // #087f83
        if type.contains("货币") { return Color(red: 0.44, green: 0.48, blue: 0.54) }   // #707a8a
        if type.contains("QDII") { return Color(red: 0.18, green: 0.27, blue: 0.68) }   // #2f44ad
        if type.contains("FOF") { return .mint }
        return .secondary
    }
}

// MARK: - 通用小组件

/// 交易中状态点(绿点 + 光晕)
struct LiveDot: View {
    var size: CGFloat = 7
    var active: Bool = true

    var body: some View {
        Circle()
            .fill(active ? Color(red: 0.184, green: 0.749, blue: 0.373) : Color.secondary.opacity(0.7)) // #2fbf5f
            .frame(width: size, height: size)
            .shadow(color: active ? Color(red: 0.204, green: 0.78, blue: 0.349).opacity(0.75) : .clear, radius: size * 0.55)
            .overlay(
                Circle().stroke(active ? Color(red: 0.204, green: 0.78, blue: 0.349).opacity(0.16) : .clear, lineWidth: size * 0.42)
            )
    }
}

/// 基金类型小标签(9.5pt / 圆角 4 / 类型色浅底)
struct FundTypeTag: View {
    let type: String

    var body: some View {
        Text(type)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(Color.fundTypeInk(type))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.fundTypeColor(type).opacity(0.11), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

/// 「估」小标(估算净值未确认)
struct EstTag: View {
    var body: some View {
        Text("估")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color(red: 0.74, green: 0.27, blue: 0.03)) // #bd4507
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.fundDCA.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

/// 涨跌胶囊(全圆角,浅色语义底)
struct ChangePill: View {
    let text: String
    let value: Double
    var small = false

    var body: some View {
        let color = value > 0 ? Color.fundUpInk : (value < 0 ? Color.fundDownInk : Color.secondary)
        Text(text)
            .font(.system(size: small ? 10.5 : 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(color)
            .padding(.horizontal, small ? 7 : 8)
            .padding(.vertical, small ? 2.5 : 3.5)
            .background(
                (value > 0 ? Color.fundUp.opacity(0.12) : (value < 0 ? Color.fundDown.opacity(0.14) : Color.secondary.opacity(0.10))),
                in: Capsule()
            )
    }
}

/// 分段控件 —— 直接用系统 Picker(.segmented):
/// macOS 26+ 的系统分段控件本身就是液态玻璃 + 原生滑动动画,自制只会更复古。
struct GlassSegmented<Option: Hashable>: View {
    let items: [(label: String, value: Option)]
    @Binding var selection: Option
    var small = false

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(items, id: \.value) { item in
                Text(item.label).tag(item.value)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(small ? .small : .regular)
        .labelsHidden()
    }
}

// MARK: - 主面板(菜单栏弹出窗)· 方向 A「镜像主窗口」定稿落地
// 规格:macos27-demos/menu-A.html(细化版)—— Hero 副行+迷你柱图+三联条 / 三列列表+清仓折叠 / 底部时间+四钮

struct ContentView: View {
    @ObservedObject var viewModel: FundViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow
    @State private var showAddFundOverlay = false
    @State private var showSettingsOverlay = false
    @State private var showClearedFunds = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.bottom, 9)

            if viewModel.hasAnyHolding {
                summaryView
                    .padding(.bottom, 10)
            }

            fundListRegion

            Spacer(minLength: 0)

            footerView
                .padding(.top, 10)
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 11)
        .frame(width: 396, height: menuHeight, alignment: .top)
        .background(windowBackground)
    }

    /// 菜单最大高度:屏幕高度的固定比例,截断到 380 ~ 660pt;内容更少时按内容收缩。
    private var menuHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        return min(max(screenHeight * 0.62, 380), 660)
    }

    // MARK: - 头部(徽标 + 标题 + 排序/刷新/⊕)

    private var headerView: some View {
        HStack(spacing: 8) {
            FundIconBadge(systemName: "chart.line.uptrend.xyaxis", color: .blue, size: 14, diameter: 24)

            VStack(alignment: .leading, spacing: 1.5) {
                Text("FundBar")
                    .font(.system(size: 12.5, weight: .bold))
                HStack(spacing: 4) {
                    LiveDot(size: 5, active: viewModel.isTradingTime)
                    Text(viewModel.isTradingTime ? "交易中" : (viewModel.isTradingDay ? "非交易时段" : "休市"))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Menu {
                ForEach(FundSortMode.allCases, id: \.self) { mode in
                    Button {
                        viewModel.sortMode = mode
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                            if viewModel.sortMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("排序:\(shortSortLabel(viewModel.sortMode))", systemImage: "arrow.up.arrow.down")
                    .labelStyle(.titleAndIcon)
            }
            .controlSize(.small)
            .fixedSize()
            .help("排序")

            Button {
                Task { await viewModel.refresh(reloadHistory: true) }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
            .disabled(viewModel.isLoading)
            .help("刷新")

            Button {
                animateOverlay {
                    showAddFundOverlay.toggle()
                    if showAddFundOverlay { showSettingsOverlay = false }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .frame(width: 24, height: 24) // 正方形外框 → 胶囊成圆,与主窗口加号同形
            .help("添加基金")
        }
        .frame(height: 34)
    }

    private func shortSortLabel(_ mode: FundSortMode) -> String {
        switch mode {
        case .manual: return "手动"
        case .changeDesc: return "涨幅"
        case .changeAsc: return "跌幅"
        case .profitDesc: return "盈亏"
        }
    }

    // MARK: - Hero(预估收益 + 副行 + 迷你柱图 + 三联条)

    private var summaryView: some View {
        let ep = viewModel.todayEstimatedProfit
        let isTrading = viewModel.isTradingDay
        let heroColor = isTrading ? Color.fundTrend(ep) : Color.secondary
        let profitData = buildProfitData()

        return VStack(alignment: .leading, spacing: 10) {
            Text("今日预估收益")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if isTrading {
                            Text(ep >= 0 ? "+" : "−")
                                .font(.system(size: 17, weight: .medium).monospacedDigit())
                                .foregroundStyle(heroColor.opacity(0.8))
                            Text(String(format: "%.2f", abs(ep)))
                                .font(.system(size: 30, weight: .semibold).monospacedDigit())
                                .foregroundStyle(heroColor)
                                .kerning(-0.7)
                        } else {
                            Text("休市")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(heroColor)
                        }
                        Text("元")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(heroColor.opacity(0.55))
                    }

                    Text("组合均值 \(isTrading ? percentText(viewModel.totalChangePercent) : "--") · 总市值 ¥\(moneyText(viewModel.totalMarketValue))")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                if profitData.count >= 2 {
                    MiniProfitBars(daily: dailyProfits(from: profitData))
                        .frame(width: 150)
                }
            }

            Divider()

            HStack(spacing: 0) {
                trioCell("总市值", "¥\(moneyText(viewModel.totalMarketValue))", "\(viewModel.funds.count) 只基金", .primary, .secondary)
                trioCell("浮动盈亏", signedMoney(viewModel.totalProfitLoss), percentText(viewModel.totalProfitPercent), Color.fundTrendInk(viewModel.totalProfitLoss), Color.fundTrendInk(viewModel.totalProfitLoss))
                trioCell("已实现盈亏", signedMoney(viewModel.totalRealizedProfit), "卖出累计", Color.fundTrendInk(viewModel.totalRealizedProfit), .secondary)
            }
        }
        .padding(14)
        .fundPanelSurface(cornerRadius: FundBarDesign.compactPanelRadius, tint: isTrading ? heroColor.opacity(0.08) : nil)
    }

    private func trioCell(_ title: String, _ value: String, _ sub: String, _ valueColor: Color, _ subColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 1.5) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            Text(value)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(sub)
                .font(.system(size: 8.5).monospacedDigit())
                .foregroundStyle(subColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    // MARK: - 列表区(三列 + 清仓折叠 + 覆盖层)

    /// 已清仓基金(有交易记录但当前份额为 0)
    private var clearedFunds: [Fund] {
        viewModel.sortedFunds.filter {
            viewModel.getWatchedFund(code: $0.fundcode)?.isCleared == true
        }
    }

    private var activeFunds: [Fund] {
        viewModel.sortedFunds.filter {
            !(viewModel.getWatchedFund(code: $0.fundcode)?.isCleared == true)
        }
    }

    private var fundListRegion: some View {
        ZStack(alignment: .top) {
            if activeFunds.isEmpty && clearedFunds.isEmpty {
                emptyView
            } else {
                fundList
            }

            if showAddFundOverlay {
                overlayPanel {
                    AddFundView(viewModel: viewModel, isPresented: $showAddFundOverlay)
                }
                .transition(panelTransition)
            }

            if showSettingsOverlay {
                overlayPanel {
                    settingsContent
                        .padding(14)
                }
                .transition(panelTransition)
            }
        }
        .frame(maxHeight: .infinity)
        .fundPanelSurface(cornerRadius: FundBarDesign.compactPanelRadius)
    }

    private var fundList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 列头(三列)
                HStack(spacing: 8) {
                    Text("基金")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("涨跌")
                        .frame(width: 58, alignment: .center)
                    HStack(spacing: 3) {
                        Text("盈亏")
                        if viewModel.sortMode == .profitDesc {
                            Image(systemName: "arrowdown")
                                .font(.system(size: 7, weight: .semibold))
                        }
                    }
                    .frame(width: 74, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(height: 24)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.primary.opacity(0.09)).frame(height: 0.5)
                }
                .padding(.horizontal, 10)

                ForEach(Array(activeFunds.enumerated()), id: \.element.id) { idx, fund in
                    FundRowView(
                        fund: fund,
                        holding: viewModel.getWatchedFund(code: fund.fundcode),
                        isTradingDay: viewModel.isTradingDay,
                        isLast: idx == activeFunds.count - 1 && clearedFunds.isEmpty,
                        onDelete: {
                            animateOverlay {
                                viewModel.removeFund(code: fund.fundcode)
                            }
                        },
                        onEditHolding: {
                            openEditWindow(fund: fund, inputMode: 0)
                        }
                    )
                }

                if !clearedFunds.isEmpty {
                    clearedSection
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
    }

    /// 已清仓折叠行
    private var clearedSection: some View {
        let realizedTotal = clearedFunds.reduce(0.0) { sum, fund in
            sum + (viewModel.getWatchedFund(code: fund.fundcode)?.realizedProfit ?? 0)
        }

        return VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.15)) {
                    showClearedFunds.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showClearedFunds ? 90 : 0))
                    Text("已清仓 · \(clearedFunds.count) 只")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                    Text("已实现合计 \(signedMoney(realizedTotal))")
                        .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.fundTrendInk(realizedTotal))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showClearedFunds ? "收起已清仓" : "展开已清仓")
            .overlay(alignment: .top) {
                Rectangle().fill(Color.primary.opacity(0.09)).frame(height: 0.5)
            }

            if showClearedFunds {
                ForEach(Array(clearedFunds.enumerated()), id: \.element.id) { idx, fund in
                    FundRowView(
                        fund: fund,
                        holding: viewModel.getWatchedFund(code: fund.fundcode),
                        isTradingDay: viewModel.isTradingDay,
                        isLast: idx == clearedFunds.count - 1,
                        onDelete: {
                            animateOverlay {
                                viewModel.removeFund(code: fund.fundcode)
                            }
                        },
                        onEditHolding: {
                            openEditWindow(fund: fund, inputMode: 0)
                        }
                    )
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 空态

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.flattrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("暂未添加基金")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text("点击右上角 + 添加自选基金")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - 设置覆盖层

    @ViewBuilder
    private func overlayPanel<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        animateOverlay {
                            showAddFundOverlay = false
                            showSettingsOverlay = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭")
                    .help("关闭")
                }
                .padding(.bottom, 6)

                content()
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fundPanelSurface(cornerRadius: FundBarDesign.compactPanelRadius)
    }

    private var settingsContent: some View {
        VStack(spacing: 12) {
            HStack {
                Label("设置", systemImage: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            HStack {
                Label("开机自启", systemImage: "power")
                    .font(.system(size: 12))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.launchAtLogin = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            HStack {
                Label("菜单栏显示", systemImage: "menubar.rectangle")
                    .font(.system(size: 12))
                Spacer()
                Picker("", selection: $viewModel.menuBarMode) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .controlSize(.small)
            }

            HStack {
                Label("涨跌通知", systemImage: "bell")
                    .font(.system(size: 12))
                Spacer()
                Picker("", selection: $viewModel.notifyThreshold) {
                    Text("关闭").tag(0.0)
                    Text("1%").tag(1.0)
                    Text("2%").tag(2.0)
                    Text("3%").tag(3.0)
                    Text("5%").tag(5.0)
                }
                .pickerStyle(.menu)
                .fixedSize()
                .controlSize(.small)
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    exportData()
                } label: {
                    Label("导出数据", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11))
                }
                .fundGlassButtonStyle()
                .controlSize(.small)

                Button {
                    importData()
                } label: {
                    Label("导入数据", systemImage: "square.and.arrow.down")
                        .font(.system(size: 11))
                }
                .fundGlassButtonStyle()
                .controlSize(.small)

                Spacer()
            }
        }
    }

    // MARK: - 底栏(更新时间 + 四钮)

    private var footerView: some View {
        HStack(spacing: 0) {
            if let time = viewModel.lastUpdateTime {
                Text("更新 \(time, format: .dateTime.hour().minute().second())")
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    openWindow(id: "main")
                } label: {
                    ToolbarIcon(systemName: "macwindow", size: 13, diameter: 27)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开主窗口")
                .help("打开主窗口")

                Button {
                    viewModel.showAIPanel = true
                    openWindow(id: "main")
                } label: {
                    ToolbarIcon(systemName: "sparkles", size: 13, diameter: 27, isActive: viewModel.isAIAnalyzing)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开 AI 分析")
                .help("AI 分析")

                Button {
                    animateOverlay {
                        showSettingsOverlay.toggle()
                        if showSettingsOverlay { showAddFundOverlay = false }
                    }
                } label: {
                    ToolbarIcon(systemName: "gearshape", size: 13, diameter: 27, isActive: showSettingsOverlay)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showSettingsOverlay ? "收起设置" : "打开设置")
                .help("设置")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    ToolbarIcon(systemName: "power", size: 13, diameter: 27, tint: Color.fundUpInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("退出 FundBar")
                .help("退出")
            }
        }
        .frame(height: 30)
    }

    // MARK: - 数据构建

    /// 近 7 日累计收益(与主窗口同口径)
    private func buildProfitData() -> [ProfitChartView.ProfitPoint] {
        let holdingFunds = viewModel.watchedFunds.filter { $0.hasHolding }
        guard !holdingFunds.isEmpty else { return [] }

        var dateSet: Set<String> = []
        for wf in holdingFunds {
            if let history = viewModel.fundHistory[wf.code] {
                for h in history { dateSet.insert(h.date) }
            }
        }
        let dates = Array(dateSet.sorted().suffix(8))
        guard dates.count >= 2 else { return [] }

        return dates.map { date in
            let totalProfit = holdingFunds.reduce(0.0) { sum, wf in
                guard let history = viewModel.fundHistory[wf.code],
                      let nav = history.first(where: { $0.date == date })?.nav else { return sum }
                return sum + wf.profitLoss(nav: nav)
            }
            return ProfitChartView.ProfitPoint(date: date, profit: totalProfit)
        }
    }

    /// 累计 → 每日
    private func dailyProfits(from data: [ProfitChartView.ProfitPoint]) -> [(date: String, profit: Double)] {
        guard data.count >= 2 else { return [] }
        return (1..<data.count).map { i in
            (date: data[i].date, profit: data[i].profit - data[i - 1].profit)
        }
    }

    // MARK: - 动作

    private func openEditWindow(fund: Fund, inputMode: Int) {
        viewModel.pendingEditFund = fund
        viewModel.pendingEditInputMode = inputMode
        openWindow(id: "edit-holding")
    }

    private func exportData() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "FundBar_Data.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            viewModel.exportData(to: url)
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            viewModel.importData(from: url)
        }
    }

    private var panelTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom))
    }

    private var windowBackground: some View {
        // 与主窗口完全同源:中性灰底
        Color.fundWindowBG
            .ignoresSafeArea()
    }

    private func animateOverlay(_ updates: () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.easeInOut(duration: 0.2), updates)
        }
    }

    private func moneyText(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func signedMoney(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.2f", abs(value)))"
    }

    private func percentText(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.2f", abs(value)))%"
    }
}

// MARK: - 迷你 7 日柱图(浮窗 Hero 专用,46pt 紧凑版)

struct MiniProfitBars: View {
    let daily: [(date: String, profit: Double)]
    var height: CGFloat = 46

    var body: some View {
        VStack(spacing: 3) {
            Canvas { ctx, size in
                let n = max(daily.count, 1)
                let colW = size.width / CGFloat(n)
                let half = size.height / 2
                let maxAbs = max(daily.map { abs($0.profit) }.max() ?? 1, 0.0001)
                let barW = min(11, max(5, colW - 6))

                var axis = Path()
                axis.move(to: CGPoint(x: 0, y: half))
                axis.addLine(to: CGPoint(x: size.width, y: half))
                ctx.stroke(axis, with: .color(Color.primary.opacity(0.14)), lineWidth: 1)

                for (i, item) in daily.enumerated() {
                    let isUp = item.profit >= 0
                    let h = max(CGFloat(abs(item.profit) / maxAbs) * (half - 3), item.profit == 0 ? 0 : 2.5)
                    let x = colW * CGFloat(i) + (colW - barW) / 2
                    let rect = CGRect(x: x, y: isUp ? half - h : half, width: barW, height: h)
                    guard rect.height > 0 else { continue }
                    let color: Color = isUp ? .fundUp : .fundDown
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
                }
            }
            .frame(height: height)

            HStack {
                Text(daily.first.map { String($0.date.suffix(5)) } ?? "")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
                Spacer()
                Text("今日")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(Color.fundTrendInk(daily.last?.profit ?? 0))
            }
        }
    }
}

// MARK: - 工具条图标(系统化:仅悬停底色,无自制 chrome)

struct ToolbarIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let systemName: String
    var size: CGFloat = 13
    var diameter: CGFloat = 30
    var isActive: Bool = false
    var rotatesWhenActive: Bool = false
    var tint: Color? = nil
    @State private var isHovered = false

    var body: some View {
        let radius = min(FundBarDesign.controlRadius, diameter * 0.32)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        icon
            .frame(width: diameter, height: diameter - (diameter > 30 ? 2 : 0))
            .background {
                shape.fill(hoverFill)
            }
            .contentShape(shape)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var hoverFill: Color {
        if isActive { return Color.accentColor.opacity(0.14) }
        if isHovered { return Color.primary.opacity(0.06) }
        return Color.clear
    }

    private var icon: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(iconColor)
            .rotationEffect(.degrees(iconRotationDegrees))
            .animation(iconRotationAnimation, value: isActive)
    }

    private var iconColor: Color {
        if let tint { return isHovered ? tint.opacity(0.9) : tint }
        if isActive { return Color.accentColor }
        return isHovered ? Color.primary : Color.secondary
    }

    private var iconRotationDegrees: Double {
        rotatesWhenActive && isActive && !reduceMotion ? 360 : 0
    }

    private var iconRotationAnimation: Animation? {
        guard rotatesWhenActive, !reduceMotion else { return nil }
        return isActive ? .linear(duration: 1).repeatForever(autoreverses: false) : .default
    }
}

/// 品牌徽标(蓝渐变圆角方块,规格同设计稿 .badge)
struct FundIconBadge: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    let systemName: String
    let color: Color
    var size: CGFloat = 16
    var diameter: CGFloat = 28

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
            .background(
                shape.fill(
                    LinearGradient(colors: [.fundBadgeTop, .fundPromoBottom],
                                   startPoint: .top, endPoint: .bottom)
                )
            )
            .overlay(
                shape.fill(
                    LinearGradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0)],
                                   startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.5))
                )
                .allowsHitTesting(false)
            )
            .shadow(color: Color(red: 18/255, green: 92/255, blue: 205/255).opacity(0.35), radius: 2.5, x: 0, y: 2)
    }
}

// MARK: - 图表组件

/// 紧凑趋势线(单色,用于次要位置)
struct TrendSparkline: View {
    let values: [Double]
    var color: Color = .fundUp
    var height: CGFloat = 46
    var showFill: Bool = true

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = maxV - minV
            let safeRange = range == 0 ? 1 : range
            let stepX = size.width / CGFloat(values.count - 1)
            let plotH = size.height - 6

            var path = Path()
            for (i, v) in values.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height - CGFloat((v - minV) / safeRange) * plotH - 3
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }

            if showFill {
                var fill = path
                fill.addLine(to: CGPoint(x: size.width, y: size.height))
                fill.addLine(to: CGPoint(x: 0, y: size.height))
                fill.closeSubpath()
                context.fill(fill, with: .linearGradient(
                    Gradient(colors: [color.opacity(0.26), color.opacity(0)]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)
                ))
            }

            context.stroke(path, with: .color(color), lineWidth: 1.8)

            if let last = values.last {
                let x = CGFloat(values.count - 1) * stepX
                let y = size.height - CGFloat((last - minV) / safeRange) * plotH - 3
                context.fill(Circle().path(in: CGRect(x: x - 6, y: y - 6, width: 12, height: 12)), with: .color(color.opacity(0.18)))
                context.fill(Circle().path(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(color))
            }
        }
        .frame(height: height)
    }
}

/// Hero 趋势线(方向 A 规格):双色折线(按当日涨跌分段红/绿)+ 参考虚线 +
/// 端点光晕与数值 + 首末日期标签。
struct HeroSparkline: View {
    /// 累计收益序列(date: "MM-dd" 或完整日期,profit: 累计值)
    let points: [(date: String, profit: Double)]
    /// 可选:总资产趋势(与 points 同期,独立归一化绘制为灰色细线)
    var assetSeries: [Double]? = nil
    var height: CGFloat = 96

    var body: some View {
        Canvas { ctx, size in
            guard points.count >= 2 else { return }
            let values = points.map(\.profit)
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = maxV - minV
            let safeRange = range == 0 ? 1 : range
            let insetX: CGFloat = 14
            let plotW = size.width - insetX * 2
            let plotH = size.height - 26
            let stepX = plotW / CGFloat(values.count - 1)

            // 单线全幅;底部预留节点金额标签空间
            func pos(_ i: Int) -> CGPoint {
                let t = CGFloat((values[i] - minV) / safeRange)
                return CGPoint(x: insetX + CGFloat(i) * stepX,
                               y: 8 + (1 - t) * (plotH - 18))
            }

            let assets = assetSeries
            let assetsValid = assets != nil && assets!.count == points.count && assets!.count >= 2

            // 参考虚线(首日水平)
            let refY = pos(0).y
            var dash = Path()
            dash.move(to: CGPoint(x: insetX, y: refY))
            dash.addLine(to: CGPoint(x: size.width - insetX, y: refY))
            ctx.stroke(dash, with: .color(Color.primary.opacity(0.16)), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 4]))

            // 分段折线:段颜色取「当日涨跌」语义(后值-前值)
            for i in 0..<(values.count - 1) {
                let daily = values[i + 1] - values[i]
                let color: Color = daily >= 0 ? .fundUp : .fundDown
                var seg = Path()
                seg.move(to: pos(i))
                seg.addLine(to: pos(i + 1))
                ctx.stroke(seg, with: .color(color), style: StrokeStyle(lineWidth: i == values.count - 2 ? 2.2 : 2, lineCap: .round, lineJoin: .round))
            }

            // 历史点
            for i in 0..<(values.count - 1) {
                let daily = i == 0 ? 0 : values[i] - values[i - 1]
                let color: Color = i == 0 ? .fundDown : (daily >= 0 ? .fundUp : .fundDown)
                let p = pos(i)
                ctx.fill(Circle().path(in: CGRect(x: p.x - 2.3, y: p.y - 2.3, width: 4.6, height: 4.6)), with: .color(color))
            }

            // 端点(今日):光晕 + 实心点
            let lastIdx = values.count - 1
            let lastDaily = values[lastIdx] - values[lastIdx - 1]
            let lastColor: Color = lastDaily >= 0 ? .fundUp : .fundDown
            let ep = pos(lastIdx)
            ctx.fill(Circle().path(in: CGRect(x: ep.x - 6.5, y: ep.y - 6.5, width: 13, height: 13)), with: .color(lastColor.opacity(0.16)))
            ctx.fill(Circle().path(in: CGRect(x: ep.x - 3.2, y: ep.y - 3.2, width: 6.4, height: 6.4)), with: .color(lastColor))

            // 文本绘制工具
            func drawLabel(_ text: String, at point: CGPoint, alignment: String, color: Color, size: CGFloat = 9.5, weight: Font.Weight = .regular) {
                let resolved = ctx.resolve(Text(text).font(.system(size: size, weight: weight).monospacedDigit()).foregroundColor(color))
                let textSize = resolved.measure(in: CGSize(width: 200, height: 14))
                let origin: CGPoint
                if alignment == "end" {
                    origin = CGPoint(x: point.x - textSize.width, y: point.y)
                } else if alignment == "centered" {
                    origin = CGPoint(x: point.x - textSize.width / 2, y: point.y)
                } else {
                    origin = CGPoint(x: point.x, y: point.y)
                }
                ctx.draw(resolved, at: CGPoint(x: origin.x + textSize.width / 2, y: origin.y + textSize.height / 2))
            }

            // 每个节点的总资产金额(灰色,标在收益折线节点下方)
            if assetsValid {
                for i in 0..<assets!.count {
                    var labelY = pos(i).y + 11
                    labelY = min(labelY, size.height - 22)
                    drawLabel(compactAsset(assets![i]),
                              at: CGPoint(x: pos(i).x, y: labelY),
                              alignment: "centered",
                              color: Color.secondary.opacity(0.9),
                              size: 7.5)
                }
            }

            // 每个节点的累计收益值:不标注(趋势看线,今日值在右上角;避免与资产标签混读)

            // 日期标签
            drawLabel(shortDate(points[0].date), at: CGPoint(x: insetX, y: size.height - 12), alignment: "start", color: Color(nsColor: .tertiaryLabelColor))
            drawLabel(shortDate(points[lastIdx].date) + " · 今日", at: CGPoint(x: size.width - insetX, y: size.height - 12), alignment: "end", color: Color(nsColor: .tertiaryLabelColor))
        }
        .frame(height: height)
    }

    private func shortDate(_ date: String) -> String {
        String(date.suffix(5))
    }

    /// 收益数值压缩:+126 / −118
    private func compactSigned(_ v: Double) -> String {
        let sign = v >= 0 ? "+" : "−"
        let a = abs(v)
        if a >= 1000 {
            return "\(sign)\(String(format: "%.1fk", a / 1000))"
        }
        return "\(sign)\(Int(a.rounded()))"
    }

    /// 资产数值压缩:¥4.8万 / ¥9,850
    private func compactAsset(_ v: Double) -> String {
        if v >= 10000 {
            return "¥\(String(format: "%.1f万", v / 10000))"
        }
        return "¥\(Int(v).formatted(.number))"
    }
}

/// 近 7 日每日盈亏柱(中轴上下分布,涨红跌绿,规格同设计稿 .bars)
struct DailyProfitBars: View {
    /// 每日盈亏(非累计)
    let daily: [(date: String, profit: Double)]
    var chartHeight: CGFloat = 136

    var body: some View {
        VStack(spacing: 2) {
            // Canvas 显式坐标绘制:零轴在画布正中,涨柱向上、跌柱向下 —— 布局语义不参与,不可能错位
            Canvas { ctx, size in
                let n = max(daily.count, 1)
                let colW = size.width / CGFloat(n)
                let half = size.height / 2
                let maxAbs = max(daily.map { abs($0.profit) }.max() ?? 1, 0.0001)
                let barW = min(18, max(6, colW - 6))
                let labelPad: CGFloat = 13 // 上下各留出的数值标签区

                // 零轴
                var axis = Path()
                axis.move(to: CGPoint(x: 0, y: half))
                axis.addLine(to: CGPoint(x: size.width, y: half))
                ctx.stroke(axis, with: .color(Color.primary.opacity(0.12)), lineWidth: 1)

                for (i, item) in daily.enumerated() {
                    let isUp = item.profit >= 0
                    let isLast = i == daily.count - 1
                    let h = max(CGFloat(abs(item.profit) / maxAbs) * (half - labelPad), item.profit == 0 ? 0 : 3)
                    let x = colW * CGFloat(i) + (colW - barW) / 2
                    let rect = CGRect(x: x, y: isUp ? half - h : half, width: barW, height: h)
                    if rect.height > 0 {
                        let path = Path(roundedRect: rect, cornerRadius: min(3.5, barW / 2))
                        let colors: [Color] = isUp
                            ? [Color.fundUp.opacity(0.88), .fundUp]
                            : [.fundDown, Color.fundDown.opacity(0.88)]
                        ctx.fill(path, with: .linearGradient(
                            Gradient(colors: colors),
                            startPoint: CGPoint(x: rect.midX, y: rect.minY),
                            endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
                    }

                    // 数值标签:涨=柱顶上方,跌=柱底下方;今日用语义色,其余灰
                    let labelColor: Color = isLast
                        ? Color.fundTrendInk(item.profit)
                        : Color(nsColor: .tertiaryLabelColor)
                    let text = Text(compactValue(item.profit))
                        .font(.system(size: 8, weight: isLast ? .semibold : .regular).monospacedDigit())
                        .foregroundColor(labelColor)
                    let resolved = ctx.resolve(text)
                    let textSize = resolved.measure(in: CGSize(width: colW, height: 12))
                    let labelY = isUp ? rect.minY - textSize.height / 2 - 2.5 : rect.maxY + textSize.height / 2 + 2.5
                    ctx.draw(resolved, at: CGPoint(x: colW * CGFloat(i) + colW / 2, y: labelY))
                }
            }
            .frame(height: chartHeight)

            // 日期标签(与柱同列宽,严格对齐)
            HStack(spacing: 0) {
                ForEach(Array(daily.enumerated()), id: \.offset) { idx, item in
                    Text(shortDate(item.date))
                        .font(.system(size: 9))
                        .foregroundStyle(idx == daily.count - 1 ? Color.fundTrendInk(item.profit) : Color(nsColor: .quaternaryLabelColor))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// 压缩数值:+126 / −118 / 1.2k
    private func compactValue(_ v: Double) -> String {
        let sign = v >= 0 ? "+" : "−"
        let a = abs(v)
        if a >= 1000 {
            return "\(sign)\(String(format: "%.1fk", a / 1000))"
        }
        return "\(sign)\(Int(a.rounded()))"
    }

    private func shortDate(_ date: String) -> String {
        String(date.suffix(5))
    }
}

/// 持仓配置环形图(类型色 + 中心总市值文字)
struct AllocationDonut: View {
    struct PieSlice: Identifiable {
        let id = UUID()
        let name: String
        let value: Double
        let color: Color
    }

    let slices: [PieSlice]
    var centerTitle: String = "总市值"
    var centerValue: String = ""
    var lineWidth: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            let total = slices.reduce(0) { $0 + $1.value }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - lineWidth / 2 - 1

            // 底环
            var track = Path()
            track.addArc(center: center, radius: r, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            context.stroke(track, with: .color(Color.primary.opacity(0.10)), lineWidth: lineWidth)

            guard total > 0 else { return }

            var start = Angle.degrees(-90)
            for slice in slices {
                let sweep = Angle.degrees(slice.value / total * 360)
                let end = start + sweep
                var path = Path()
                path.addArc(center: center, radius: r, startAngle: start, endAngle: end, clockwise: false)
                context.stroke(path, with: .color(slice.color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                start = end
            }
        }
        .overlay {
            VStack(spacing: 1.5) {
                Text(centerTitle)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text(centerValue)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 6)
        }
    }
}

/// 极细竖向分隔线
struct VDivider: View {
    var height: CGFloat = 11
    var opacity: Double = 0.1
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(opacity))
            .frame(width: 1, height: height)
    }
}

// MARK: - 表面修饰(玻璃配方,规格同设计稿 .gwindow / .panel)

extension View {
    func fundPanelSurface(cornerRadius: CGFloat = FundBarDesign.panelRadius, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(FundPanelSurfaceModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }

    func fundRowSurface(isHovered: Bool, cornerRadius: CGFloat = FundBarDesign.rowRadius) -> some View {
        modifier(FundRowSurfaceModifier(isHovered: isHovered, cornerRadius: cornerRadius))
    }

    func fundWindowBackground() -> some View {
        modifier(FundWindowBackgroundModifier())
    }

    func fundGlassButtonStyle(prominent: Bool = false) -> some View {
        modifier(FundGlassButtonStyleModifier(prominent: prominent))
    }

    /// 数字文本的滚动变换(估值刷新时数字灵动滚动,而非生硬跳变)
    func fundNumericTransition(text: String) -> some View {
        contentTransition(.numericText())
            .animation(.spring(duration: 0.45, bounce: 0.2), value: text)
    }
}

/// 窗口底:明确的浅灰(macOS 26/27 语义色偏白,自定义保证层次)
private struct FundWindowBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                Color.fundWindowBG
                    .ignoresSafeArea()
            }
    }
}

/// 按钮一律系统样式:macOS 26+ 的 .bordered/.borderedProminent 自动就是液态玻璃
private struct FundGlassButtonStyleModifier: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if prominent {
            content
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        } else {
            content
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
    }
}

private struct FundPanelSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        // 投影挂在背景形状上(而非内容子树):滚动时无需对内容 alpha 蒙版逐帧模糊
        content
            .background(
                ZStack {
                    shape.fill(Color.fundCardBG)
                    if let tint {
                        shape.fill(tint.opacity(0.10))
                    }
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 8, x: 0, y: 3)
            )
            .overlay(
                shape.strokeBorder(
                    colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                    lineWidth: 0.5
                )
            )
    }
}

/// 列表行:无底色,hover 时轻高亮(方向 A 的分隔线行样式)
/// 菜单栏浮窗玻璃卡:系统液态玻璃(macOS 26+),旧系统回退白色卡
struct MenuGlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var tint: Color? = nil

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: FundBarDesign.compactPanelRadius, style: .continuous)
        if #available(macOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(.regular.tint(tint), in: shape)
        } else {
            content
                .background(Color.fundCardBG, in: shape)
                .overlay(
                    shape.strokeBorder(
                        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                        lineWidth: 0.5
                    )
                )
        }
    }
}

private struct FundRowSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let isHovered: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                if isHovered {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05))
                }
            }
    }
}
