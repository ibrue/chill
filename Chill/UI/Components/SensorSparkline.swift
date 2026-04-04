import SwiftUI
import Charts

struct SensorSparkline: View {
    let data: [TimestampedValue]
    let color: Color
    let unit: String
    let yDomain: ClosedRange<Float>?

    var body: some View {
        if data.count < 2 {
            // Not enough data yet — show placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.05))
                .frame(height: 44)
                .overlay(
                    Text("Collecting\u{2026}")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.quaternary)
                )
        } else {
            Chart(data) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value(unit, point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.25), color.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", point.date),
                    y: .value(unit, point.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: computedDomain)
            .frame(height: 44)
        }
    }

    private var computedDomain: ClosedRange<Float> {
        if let yDomain { return yDomain }
        let values = data.map(\.value)
        let lo = (values.min() ?? 0) * 0.85
        let hi = (values.max() ?? 100) * 1.15
        return lo...max(hi, lo + 1)
    }
}

#Preview {
    let sampleData = (0..<30).map { i in
        TimestampedValue(
            id: i,
            date: Date().addingTimeInterval(Double(i) * -2),
            value: Float.random(in: 1200...3500)
        )
    }.reversed()

    SensorSparkline(
        data: Array(sampleData),
        color: .cyan,
        unit: "RPM",
        yDomain: 0...8000
    )
    .padding()
}
