import SwiftUI

/// 收益走势图（7日估算收益曲线）
struct ProfitChartView: View {
    let data: [ProfitPoint]

    struct ProfitPoint: Identifiable {
        let id = UUID()
        let date: String
        let profit: Double
    }

    @State private var hoverIndex: Int?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("近期收益走势")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let idx = hoverIndex, idx < data.count {
                    let pt = data[idx]
                    let sign = pt.profit >= 0 ? "+" : ""
                    Text("\(pt.date.suffix(5)) \(sign)\(String(format: "%.2f", pt.profit))")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(pt.profit >= 0 ? Color.fundUp : Color.fundDown)
                }
            }

            if data.count >= 2 {
                GeometryReader { geo in
                    chartCanvas(width: geo.size.width)
                }
                .frame(height: 80)
                .padding(8)
                .background(Color.primary.opacity(0.024), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("数据不足")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(height: 80)
            }
        }
        .padding(12)
        .fundRowSurface(isHovered: false, cornerRadius: FundBarDesign.compactPanelRadius)
    }

    private func chartCanvas(width: CGFloat) -> some View {
        let values = data.map(\.profit)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0
        let range = maxVal - minVal
        let safeRange = range == 0 ? 1 : range

        return Canvas { context, size in
            let stepX = size.width / CGFloat(data.count - 1)
            // 零线
            let zeroY = size.height - CGFloat((0 - minVal) / safeRange) * size.height

            var zeroPath = Path()
            zeroPath.move(to: CGPoint(x: 0, y: zeroY))
            zeroPath.addLine(to: CGPoint(x: size.width, y: zeroY))
            context.stroke(zeroPath, with: .color(.secondary.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))

            // 曲线
            var path = Path()
            for (i, value) in values.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height - CGFloat((value - minVal) / safeRange) * size.height
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            let lastValue = values.last ?? 0
            let lineColor: Color = lastValue >= 0 ? .fundUp : .fundDown
            context.stroke(path, with: .color(lineColor), lineWidth: 1.5)

            // 填充
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: size.width, y: zeroY))
            fillPath.addLine(to: CGPoint(x: 0, y: zeroY))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(lineColor.opacity(0.1)))

            // 悬浮指示器
            if let idx = hoverIndex, idx < data.count {
                let x = CGFloat(idx) * stepX
                let y = size.height - CGFloat((values[idx] - minVal) / safeRange) * size.height
                context.fill(Circle().path(in: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(lineColor))
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                let stepX = width / CGFloat(data.count - 1)
                let idx = Int((location.x / stepX).rounded())
                hoverIndex = min(max(idx, 0), data.count - 1)
            case .ended:
                hoverIndex = nil
            @unknown default:
                hoverIndex = nil
            }
        }
    }
}
