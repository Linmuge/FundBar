import SwiftUI

/// 7日净值迷你走势图（支持悬浮提示）
struct MiniChartView: View {
    let data: [HistoryNav]
    let width: CGFloat
    let height: CGFloat

    @State private var hoverIndex: Int?

    var body: some View {
        if data.count >= 2 {
            chartView
                .frame(width: width, height: height)
                .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
                .frame(width: width, height: height)
        }
    }

    private var chartView: some View {
        let values = Array(data.reversed()) // API 返回最新在前，图表左到右

        return ZStack(alignment: .topLeading) {
            // 图表
            Canvas { context, size in
                let minVal = values.map(\.nav).min() ?? 0
                let maxVal = values.map(\.nav).max() ?? 1
                let range = maxVal - minVal
                let safeRange = range == 0 ? 1 : range
                let isUp = (values.last?.nav ?? 0) >= (values.first?.nav ?? 0)
                let stepX = size.width / CGFloat(values.count - 1)

                var path = Path()
                for (index, item) in values.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = size.height - (CGFloat((item.nav - minVal) / safeRange) * size.height)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                let color: Color = isUp ? .red : .green
                context.stroke(path, with: .color(color), lineWidth: 1.2)

                var fillPath = path
                fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
                fillPath.addLine(to: CGPoint(x: 0, y: size.height))
                fillPath.closeSubpath()

                context.fill(fillPath, with: .linearGradient(
                    Gradient(colors: [color.opacity(0.2), color.opacity(0.02)]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)
                ))
            }

            // Tooltip
            if let idx = hoverIndex, idx < values.count {
                let item = values[idx]
                Text("\(item.date.suffix(5)) \(String(format: "%.4f", item.nav))")
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(2)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 3))
                    .offset(y: -14)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                let stepX = width / CGFloat(values.count - 1)
                let idx = Int((location.x / stepX).rounded())
                hoverIndex = min(max(idx, 0), values.count - 1)
            case .ended:
                hoverIndex = nil
            @unknown default:
                hoverIndex = nil
            }
        }
    }
}
