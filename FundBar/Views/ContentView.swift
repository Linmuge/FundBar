import SwiftUI
import UniformTypeIdentifiers
import AppKit


/// 设计系统令牌（原生精炼方向：收紧圆角、克制留白）
enum FundBarDesign {
    static let menuWidth: CGFloat = 396
    static let menuCornerRadius: CGFloat = 28
    static let panelRadius: CGFloat = 18      // 收紧：22 → 18
    static let compactPanelRadius: CGFloat = 14 // 18 → 14
    static let rowRadius: CGFloat = 11          // 14 → 11
    static let controlRadius: CGFloat = 9       // 10 → 9
    static let heroRadius: CGFloat = 18
}

extension Color {
    /// 红涨绿跌 —— 精炼的中国红（非消防红）。自动适配亮/暗模式。
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

    /// 定投 / 买入动作色（暖橙）
    static let fundDCA = Color(red: 0.91, green: 0.35, blue: 0.05) // #e8590c

    /// 由数值正负取语义色
    static func fundTrend(_ value: Double) -> Color {
        value > 0 ? .fundUp : (value < 0 ? .fundDown : .secondary)
    }
}

/// 主面板视图
///
/// 重设计后的固定骨架（从上到下，永远是这四段，不再随面板切换而跳高）：
/// 1. Header（slim 工具条）
/// 2. Hero（今日预估收益，固定高度）
/// 3. 列表（flex 滚动区，占满剩余高度）
/// 4. Footer（更新时间 + 功能入口）
///
/// 添加基金 / 设置 不再内联挤压列表，改为盖在列表上方的覆盖层（Header/Footer 仍可见）。
/// 点击基金 → 弹出独立窗口（`openWindow(id: "edit-holding")`），彻底避开 popover
/// 高度约束导致的保存按钮失效问题。
struct ContentView: View {
    @ObservedObject var viewModel: FundViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow
    @State private var showAddFundOverlay = false
    @State private var showSettingsOverlay = false

    var body: some View {
        VStack(spacing: 8) {
            headerView

            if viewModel.hasAnyHolding {
                summaryView
            }

            // 列表区 —— 始终存在，固定占据剩余高度
            fundListRegion

            footerView
        }
        .padding(10)
        .frame(width: FundBarDesign.menuWidth, height: menuHeight, alignment: .top)
        .background(windowBackground)
    }

    /// 菜单总高度：屏幕高度的固定比例（不再因面板切换而变化）。
    /// 截断到 360 ~ 640pt，避免极端屏幕过矮或过高。
    private var menuHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        return min(max(screenHeight * 0.62, 360), 640)
    }

    // MARK: - Header（slim 工具条）

    private var headerView: some View {
        HStack(spacing: 8) {
            FundIconBadge(systemName: "chart.line.uptrend.xyaxis", color: .blue, size: 13, diameter: 26)

            HStack(spacing: 5) {
                Circle()
                    .fill(viewModel.isTradingTime ? .green : .secondary)
                    .frame(width: 5, height: 5)
                Text(viewModel.isTradingTime ? "交易中" : (viewModel.isTradingDay ? "非交易时段" : "休市"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
                ToolbarIcon(systemName: "arrow.up.arrow.down", size: 11, diameter: 24, isActive: viewModel.sortMode != .manual)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("排序")

            Button {
                Task { await viewModel.refresh(reloadHistory: true) }
            } label: {
                ToolbarIcon(systemName: "arrow.clockwise", size: 11, diameter: 24, isActive: viewModel.isLoading, rotatesWhenActive: true)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .help("刷新")

            Button {
                animateOverlay {
                    showAddFundOverlay.toggle()
                    if showAddFundOverlay { showSettingsOverlay = false }
                }
            } label: {
                ToolbarIcon(systemName: showAddFundOverlay ? "minus" : "plus", size: 11, diameter: 24, isActive: showAddFundOverlay)
            }
            .buttonStyle(.plain)
            .help(showAddFundOverlay ? "收起添加" : "添加基金")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
    }

    // MARK: - 列表区（含覆盖层）

    @ViewBuilder
    private var fundListRegion: some View {
        ZStack(alignment: .top) {
            // 基础层：列表
            if viewModel.funds.isEmpty && !viewModel.isLoading {
                emptyView
            } else {
                fundListView
            }

            // 覆盖层：添加基金 / 设置（盖在列表上，不挤压骨架）
            if showAddFundOverlay {
                overlayPanel {
                    AddFundView(viewModel: viewModel, isPresented: $showAddFundOverlay)
                        .padding(14)
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
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius)
    }

    /// 覆盖层容器：圆角面板，盖住列表区，顶部带标题行（含关闭按钮）
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
                        ToolbarIcon(systemName: "xmark", size: 11, diameter: 22)
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
        .fundPanelSurface(cornerRadius: FundBarDesign.panelRadius, interactive: true)
    }

    // MARK: - Fund List

    private var fundListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(viewModel.sortedFunds) { fund in
                    FundRowView(
                        fund: fund,
                        holding: viewModel.getWatchedFund(code: fund.fundcode),
                        historyData: viewModel.fundHistory[fund.fundcode] ?? [],
                        hasDCAPlan: viewModel.getWatchedFund(code: fund.fundcode)?.dcaPlan != nil,
                        isTradingDay: viewModel.isTradingDay,
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
            .padding(8)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.flattrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("暂未添加基金")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Text("点击右上角 + 添加自选基金")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Summary Hero

    /// 菜单栏 Hero：今日预估收益作为一眼答案
    private var summaryView: some View {
        let ep = viewModel.todayEstimatedProfit
        let isTrading = viewModel.isTradingDay
        let heroColor = isTrading ? Color.fundTrend(ep) : Color.secondary

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("今日预估")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if isTrading {
                    Text("\(percentText(viewModel.totalChangePercent)) 均值")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(heroColor)
                } else {
                    Text("休市")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if isTrading {
                    Text(ep >= 0 ? "+" : "−")
                        .font(.system(size: 16, weight: .medium).monospacedDigit())
                        .foregroundStyle(heroColor.opacity(0.8))
                    Text(String(format: "%.2f", abs(ep)))
                        .font(.system(size: 24, weight: .semibold).monospacedDigit())
                        .foregroundStyle(heroColor)
                } else {
                    Text("休市")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(heroColor)
                }
                Text("元")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(heroColor.opacity(0.55))
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                summaryStripCell("总市值", "¥\(compact(viewModel.totalMarketValue))", .primary)
                VDivider(height: 22)
                summaryStripCell("浮动盈亏", signedCompact(viewModel.totalProfitLoss), Color.fundTrend(viewModel.totalProfitLoss))
                VDivider(height: 22)
                summaryStripCell("已实现", signedCompact(viewModel.totalRealizedProfit), Color.fundTrend(viewModel.totalRealizedProfit))
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .fundPanelSurface(cornerRadius: FundBarDesign.heroRadius, tint: heroColor.opacity(0.05))
    }

    private func summaryStripCell(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percentText(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }

    private func compact(_ value: Double) -> String {
        Int(value).formatted(.number)
    }

    private func signedCompact(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(Int(abs(value)).formatted(.number))"
    }

    // MARK: - Settings (overlay content)

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

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 8) {
            if let time = viewModel.lastUpdateTime {
                Text("更新: \(time, format: .dateTime.hour().minute().second())")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                openWindow(id: "main")
            } label: {
                ToolbarIcon(systemName: "macwindow", size: 10, diameter: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开主窗口")
            .help("打开主窗口")

            Button {
                openWindow(id: "ai-analysis")
            } label: {
                ToolbarIcon(systemName: "sparkles", size: 10, diameter: 22, isActive: viewModel.isAIAnalyzing)
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
                ToolbarIcon(systemName: "gearshape", size: 10, diameter: 22, isActive: showSettingsOverlay)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showSettingsOverlay ? "收起设置" : "打开设置")
            .help("设置")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                ToolbarIcon(systemName: "power", size: 10, diameter: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("退出 FundBar")
            .help("退出")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .fundPanelSurface(cornerRadius: FundBarDesign.compactPanelRadius)
    }

    // MARK: - Actions

    /// 打开编辑持仓独立窗口。关键：先把目标基金写入 viewModel.pendingEditFund，
    /// 再 openWindow。这避免了原来内联 EditHoldingView 时的状态丢失问题。
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
        // 外层不画圆角/描边/阴影 —— 外层轮廓由 MenuBarExtra(.window) 系统容器提供。
        // 这里只填干净的半透明材质 + 极淡对角线提亮，让内层各分区面板(panelRadius)
        // 成为唯一可见的圆角，避免「外大内小」双层圆角。
        ZStack {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Color(nsColor: .windowBackgroundColor)
                    .opacity(0.001) // 占位保持几何，真正的不透明材质交给 regularMaterial
                Rectangle()
                    .fill(.regularMaterial)
            }

            if !reduceTransparency {
                LinearGradient(
                    colors: [
                        Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.03),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }

    private func animateOverlay(_ updates: () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.easeInOut(duration: 0.2), updates)
        }
    }
}

struct ToolbarIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    let systemName: String
    var size: CGFloat = 12
    var diameter: CGFloat = 28
    var isActive: Bool = false
    var rotatesWhenActive: Bool = false
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: min(FundBarDesign.controlRadius, diameter * 0.38), style: .continuous)

        icon
            .frame(width: diameter, height: diameter)
            .background {
                if #available(macOS 26.0, *), !reduceTransparency {
                    Color.clear
                } else {
                    shape.fill(isActive ? Color.accentColor.opacity(0.16) : Color.primary.opacity(isHovered ? 0.07 : 0.045))
                }
            }
            .modifier(ToolbarGlassModifier(shape: shape, tint: toolbarTint))
            .overlay {
                shape.strokeBorder(Color.primary.opacity(strokeOpacity), lineWidth: 0.65)
            }
            .contentShape(shape)
            .scaleEffect(isHovered && !reduceMotion ? 1.035 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var icon: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isActive ? Color.accentColor : (isHovered ? Color.primary : Color.secondary))
            .rotationEffect(.degrees(iconRotationDegrees))
            .animation(iconRotationAnimation, value: isActive)
    }

    private var toolbarTint: Color? {
        if isActive {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.12)
        }
        if isHovered {
            return Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05)
        }
        return nil
    }

    private var strokeOpacity: Double {
        if isActive { return colorScheme == .dark ? 0.18 : 0.12 }
        if isHovered { return colorScheme == .dark ? 0.16 : 0.10 }
        return colorScheme == .dark ? 0.10 : 0.065
    }

    private var iconRotationDegrees: Double {
        rotatesWhenActive && isActive && !reduceMotion ? 360 : 0
    }

    private var iconRotationAnimation: Animation? {
        guard rotatesWhenActive, !reduceMotion else { return nil }
        return isActive ? .linear(duration: 1).repeatForever(autoreverses: false) : .default
    }
}

struct FundIconBadge: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    let systemName: String
    let color: Color
    var size: CGFloat = 15
    var diameter: CGFloat = 32

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: min(12, diameter * 0.36), style: .continuous)

        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .frame(width: diameter, height: diameter)
            .background {
                if #available(macOS 26.0, *), !reduceTransparency {
                    Color.clear
                } else {
                    shape.fill(color.opacity(colorScheme == .dark ? 0.20 : 0.13))
                }
            }
            .modifier(ToolbarGlassModifier(shape: shape, tint: color.opacity(colorScheme == .dark ? 0.14 : 0.10)))
            .overlay {
                shape.strokeBorder(color.opacity(colorScheme == .dark ? 0.16 : 0.12), lineWidth: 0.65)
            }
    }
}

/// 紧凑趋势线（折线 + 渐变填充 + 末端高亮点）。用于 hero 与侧栏的"近 7 日累计"。
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

/// 极细竖向分隔线（hero 副信息之间）
struct VDivider: View {
    var height: CGFloat = 11
    var opacity: Double = 0.1
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(opacity))
            .frame(width: 1, height: height)
    }
}

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
}

private struct ToolbarGlassModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S
    let tint: Color?

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(.regular.tint(tint).interactive(true), in: shape)
        } else {
            content
        }
    }
}

private struct FundWindowBackgroundModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                windowBackground
                    .ignoresSafeArea()
            }
    }

    @ViewBuilder
    private var windowBackground: some View {
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else if #available(macOS 26.0, *) {
            // 原生精炼：干净的半透明材质，不再叠 accent/绿渐变
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                Rectangle()
                    .fill(.regularMaterial)
                    .opacity(colorScheme == .dark ? 0.30 : 0.40)
            }
        } else {
            Color(nsColor: .windowBackgroundColor)
        }
    }
}

private struct FundGlassButtonStyleModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            if prominent {
                content.buttonStyle(.borderedProminent)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}

private struct FundPanelSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(macOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
                .overlay {
                    shape.strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.13 : 0.08), lineWidth: 0.65)
                }
                .shadow(color: .black.opacity(interactive ? (colorScheme == .dark ? 0.18 : 0.08) : 0.035), radius: interactive ? 14 : 7, x: 0, y: interactive ? 8 : 3)
        } else if reduceTransparency {
            content
                .background(Color(nsColor: .windowBackgroundColor), in: shape)
                .overlay {
                    shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.65)
                }
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape.strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 0.65)
                }
        }
    }
}

private struct FundRowSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    let isHovered: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                if reduceTransparency {
                    shape.fill(Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.86 : 0.62))
                } else {
                    shape.fill(Color.primary.opacity(rowFillOpacity))
                }
            }
            .overlay {
                shape.strokeBorder(Color.primary.opacity(isHovered ? 0.12 : 0.06), lineWidth: 0.65)
            }
            .shadow(color: .black.opacity(isHovered && !reduceTransparency ? (colorScheme == .dark ? 0.14 : 0.06) : 0), radius: 8, x: 0, y: 4)
    }

    private var rowFillOpacity: Double {
        if isHovered {
            return colorScheme == .dark ? 0.08 : 0.055
        }
        return colorScheme == .dark ? 0.042 : 0.026
    }
}
