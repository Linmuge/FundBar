import SwiftUI

/// 7日净值迷你走势图
struct MiniChartView: View {
    let data: [Double]
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        if data.count >= 2 {
            chartPath
                .frame(width: width, height: height)
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(width: width, height: height)
        }
    }

    private var chartPath: some View {
        let values = data.reversed() // API 返回最新在前，图表需要从左到右
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        let range = maxVal - minVal
        let safeRange = range == 0 ? 1 : range
        let isUp = (values.last ?? 0) >= (values.first ?? 0)

        return Canvas { context, size in
            let stepX = size.width / CGFloat(values.count - 1)

            var path = Path()
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height - (CGFloat((value - minVal) / safeRange) * size.height)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            let color: Color = isUp ? .red : .green
            context.stroke(path, with: .color(color), lineWidth: 1.2)

            // 填充渐变
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
    }
}
