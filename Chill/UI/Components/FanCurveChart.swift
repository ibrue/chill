import SwiftUI

/// Renders the active fan profile's curve with a live "you are here" dot.
/// The dot's vertical position uses the exact same linear interpolation that
/// `ProfileEngine.computeTargetRPM` uses, so what the user sees is what the
/// helper would target.
struct FanCurveChart: View {
    let curve: [TempCurvePoint]
    let currentTemp: Float
    var tempRange: ClosedRange<Float> = 25...100

    private let yGridStops: [Float] = [0.0, 0.25, 0.50, 0.75, 1.0]
    private let xGridStops: [Float] = [30, 50, 70, 90]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                grid(in: geo.size)
                curvePath(in: geo.size)
                    .stroke(curveGradient, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .shadow(color: dotTint.opacity(0.35), radius: 4, x: 0, y: 1)
                hereDot(in: geo.size)
                xAxisLabels(in: geo.size)
            }
        }
        .frame(height: 130)
        .accessibilityLabel("Fan curve, current temperature \(Int(currentTemp)) degrees")
    }

    // MARK: - Geometry

    private func point(temp: Float, rpmPercent: Float, in size: CGSize) -> CGPoint {
        let leftInset: CGFloat = 4
        let rightInset: CGFloat = 4
        let topInset: CGFloat = 6
        let bottomInset: CGFloat = 18  // leave room for x-axis labels

        let width = size.width - leftInset - rightInset
        let height = size.height - topInset - bottomInset

        let tNorm = (CGFloat(temp - tempRange.lowerBound)) /
                    CGFloat(tempRange.upperBound - tempRange.lowerBound)
        let x = leftInset + max(0, min(1, tNorm)) * width

        let yNorm = CGFloat(max(0, min(1, rpmPercent)))
        let y = topInset + (1 - yNorm) * height

        return CGPoint(x: x, y: y)
    }

    private func curvePath(in size: CGSize) -> Path {
        let sorted = curve.sorted { $0.tempCelsius < $1.tempCelsius }
        return Path { p in
            guard let first = sorted.first else { return }

            // Anchor the line at the chart's left edge using the first point's RPM%.
            let left = point(temp: tempRange.lowerBound, rpmPercent: first.rpmPercent, in: size)
            p.move(to: left)

            for pt in sorted {
                p.addLine(to: point(temp: pt.tempCelsius, rpmPercent: pt.rpmPercent, in: size))
            }

            // Extend to the right edge using the last point's RPM%.
            if let last = sorted.last {
                p.addLine(to: point(temp: tempRange.upperBound, rpmPercent: last.rpmPercent, in: size))
            }
        }
    }

    private var dotTint: Color { Brand.tierColor(for: currentTemp) }

    private var curveGradient: LinearGradient {
        LinearGradient(
            colors: [Brand.primary, Brand.secondary, Brand.warm, Brand.hot],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    @ViewBuilder
    private func hereDot(in size: CGSize) -> some View {
        let rpm = interpolatedRPMPercent(for: currentTemp)
        let pos = point(temp: clampedTemp, rpmPercent: rpm, in: size)
        ZStack {
            Circle()
                .fill(dotTint.opacity(0.25))
                .frame(width: 22, height: 22)
            Circle()
                .fill(dotTint)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
                .shadow(color: dotTint.opacity(0.6), radius: 5, x: 0, y: 1)
        }
        .position(pos)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: pos)
        .animation(.easeInOut(duration: 0.3), value: dotTint)
    }

    private var clampedTemp: Float {
        min(max(currentTemp, tempRange.lowerBound), tempRange.upperBound)
    }

    /// Linear interpolation matching ProfileEngine.computeTargetRPM, in [0,1].
    private func interpolatedRPMPercent(for temp: Float) -> Float {
        let sorted = curve.sorted { $0.tempCelsius < $1.tempCelsius }
        guard let first = sorted.first, let last = sorted.last else { return 0.3 }
        if temp <= first.tempCelsius { return first.rpmPercent }
        if temp >= last.tempCelsius  { return last.rpmPercent }
        for i in 0..<(sorted.count - 1) {
            let a = sorted[i], b = sorted[i + 1]
            if temp >= a.tempCelsius && temp < b.tempCelsius {
                let r = (temp - a.tempCelsius) / (b.tempCelsius - a.tempCelsius)
                return a.rpmPercent + r * (b.rpmPercent - a.rpmPercent)
            }
        }
        return 0.5
    }

    // MARK: - Grid + labels

    @ViewBuilder
    private func grid(in size: CGSize) -> some View {
        Path { p in
            for y in yGridStops {
                let a = point(temp: tempRange.lowerBound, rpmPercent: y, in: size)
                let b = point(temp: tempRange.upperBound, rpmPercent: y, in: size)
                p.move(to: a); p.addLine(to: b)
            }
            for x in xGridStops {
                let a = point(temp: x, rpmPercent: 0, in: size)
                let b = point(temp: x, rpmPercent: 1, in: size)
                p.move(to: a); p.addLine(to: b)
            }
        }
        .stroke(.white.opacity(0.08), lineWidth: 1)
    }

    @ViewBuilder
    private func xAxisLabels(in size: CGSize) -> some View {
        ForEach(xGridStops, id: \.self) { temp in
            let pos = point(temp: temp, rpmPercent: 0, in: size)
            Text("\(Int(temp))°")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.secondary)
                .position(x: pos.x, y: size.height - 7)
        }
    }
}

#Preview {
    let auto: [TempCurvePoint] = [
        .init(temp: 30, rpmPercent: 0.20),
        .init(temp: 50, rpmPercent: 0.30),
        .init(temp: 70, rpmPercent: 0.60),
        .init(temp: 90, rpmPercent: 1.00),
    ]
    return VStack {
        FanCurveChart(curve: auto, currentTemp: 58)
    }
    .padding()
    .frame(width: 300)
    .background(.black)
}
