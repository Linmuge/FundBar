import SwiftUI

/// 持仓占比饼图
struct HoldingPieView: View {
    let slices: [PieSlice]

    struct PieSlice: Identifiable {
        let id = UUID()
        let name: String
        let value: Double
        let color: Color
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("持仓分布")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(totalValueText)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if slices.isEmpty {
                Text("暂无持仓数据")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(height: 100)
            } else {
                HStack(spacing: 16) {
                    // 饼图
                    pieChart
                        .frame(width: 90, height: 90)

                    // 图例
                    VStack(alignment: .leading, spacing: 4) {
                        let total = slices.reduce(0) { $0 + $1.value }
                        ForEach(slices) { slice in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(slice.color)
                                    .frame(width: 6, height: 6)
                                Text(slice.name)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                                Spacer()
                                Text(String(format: "%.1f%%", total > 0 ? (slice.value / total * 100) : 0))
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .fundRowSurface(isHovered: false, cornerRadius: 12)
    }

    private var pieChart: some View {
        Canvas { context, size in
            let total = slices.reduce(0) { $0 + $1.value }
            guard total > 0 else { return }

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2

            var startAngle = Angle.degrees(-90)

            for slice in slices {
                let sweepAngle = Angle.degrees(slice.value / total * 360)
                let endAngle = startAngle + sweepAngle

                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius,
                           startAngle: startAngle, endAngle: endAngle,
                           clockwise: false)
                path.closeSubpath()

                context.fill(path, with: .color(slice.color))

                startAngle = endAngle
            }
        }
        .frame(width: 90, height: 90)
        .background(Color.primary.opacity(0.026), in: Circle())
    }

    private var totalValueText: String {
        let total = slices.reduce(0) { $0 + $1.value }
        guard total > 0 else { return "暂无" }
        return String(format: "%.0f", total)
    }
}
