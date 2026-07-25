import SwiftUI
import AppKit

/// 编辑持仓独立窗口的内容视图。
///
/// 设计动机：原先 `EditHoldingView` 作为内联条件视图塞在 `MenuBarExtra` popover 的
/// `ContentView` 里。长列表时它被挤出 popover 可见/可点击区域，叠加 30s 自动刷新会
/// 重建 `ContentView` 冲掉本地 `@State`，导致「保存没反应」。
///
/// 这里把它挪到真正的 `Window` 中（由 `openWindow(id: "edit-holding")` 触发），
/// 脱离 popover 的高度约束：保存按钮永远可点、菜单关掉也不丢输入、自动刷新不再
/// 冲掉表单状态。数据层（FundViewModel 的 add/remove/... → UserDefaults）无需改动。
struct EditHoldingWindowView: View {
    @ObservedObject var viewModel: FundViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let fund = viewModel.pendingEditFund {
                ScrollView {
                    EditHoldingView(
                        viewModel: viewModel,
                        // 关闭由窗口的 dismiss 驱动，而不是这个 binding（这里恒 true）
                        isPresented: .constant(true),
                        inputMode: $viewModel.pendingEditInputMode,
                        fundCode: fund.fundcode,
                        fundName: fund.name,
                        usesPanelSurface: false,
                        onClose: { dismiss() }
                    )
                    .padding(20)
                    // ScrollView 内容必须显式撑满宽度，否则会按 intrinsic 宽度
                    // 缩在左侧，造成右侧大片空白。
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.automatic)
                .frame(maxWidth: .infinity)
            } else {
                placeholderView
            }
        }
        .frame(minWidth: 440, idealWidth: 460, minHeight: 560, idealHeight: 680)
        // 编辑窗口需要不透底，否则 regularMaterial 会把后面的主窗口内容
        // 混入表单，造成整窗内容重影和颜色串入。
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .background(EditHoldingWindowConfigurator())
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "pencil.line")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("未选择基金")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("请从状态栏或主窗口点击一只基金进行编辑")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 配置编辑持仓窗口的标题栏：透明 titlebar、交通灯对齐到左侧（与主窗口一致）。
private struct EditHoldingWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.toolbar = nil
        window.isMovableByWindowBackground = true
        alignTrafficLights(in: window)
    }

    private func alignTrafficLights(in window: NSWindow) {
        let buttons = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton)
        ].compactMap { $0 }

        guard buttons.count == 3, let superview = buttons[0].superview else { return }

        let centerYFromTop: CGFloat = 22
        let centersX: [CGFloat] = [20, 40, 60]

        for (button, centerX) in zip(buttons, centersX) {
            let targetX = centerX - button.frame.width / 2
            let targetY = superview.bounds.height - centerYFromTop - button.frame.height / 2
            button.setFrameOrigin(NSPoint(x: targetX, y: targetY))
        }
    }
}
