import Charts
import SwiftUI
import WeatherData

/// The Today tab: temperature and dew point through the coming hours, and every
/// point where the word changes.
struct TodayView: View {
    let model: ConditionsModel

    var body: some View {
        NavigationStack {
            Group {
                if model.hours.isEmpty {
                    ContentUnavailableView(
                        "No forecast yet",
                        systemImage: "clock",
                        description: Text("The hourly forecast appears here once it loads.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForecastChart(hours: model.hours)
                                .card()
                            ChangeList(changes: model.forecastChanges)
                                .card()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background)
            .navigationTitle("Today")
        }
    }
}

/// Temperature (white) and dew point (accent) by hour. The gap between the lines is
/// the point: the closer they run, the stickier it feels.
private struct ForecastChart: View {
    let hours: [ForecastHour]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart {
                ForEach(hours, id: \.date) { hour in
                    if hour.precipitation != nil {
                        RectangleMark(
                            xStart: .value("Hour", hour.date),
                            xEnd: .value("Hour", hour.date.addingTimeInterval(3600))
                        )
                        .foregroundStyle(Color.accentColor.opacity(0.15))
                    }
                }
                ForEach(hours, id: \.date) { hour in
                    LineMark(x: .value("Hour", hour.date), y: .value("°F", hour.temperatureF), series: .value("Series", "Temperature"))
                        .foregroundStyle(Color.primary)
                    LineMark(x: .value("Hour", hour.date), y: .value("°F", hour.dewpointF), series: .value("Series", "Dew point"))
                        .foregroundStyle(Color.accentColor)
                }
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.25, lineCap: .round))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let degrees = value.as(Double.self) {
                            Text("\(Int(degrees))°")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .frame(height: 180)
            .accessibilityLabel("Temperature and dew point for the next \(hours.count) hours")

            HStack(spacing: 16) {
                legend("Temperature", Color.primary)
                legend("Dew point", Color.accentColor)
                if hours.contains(where: { $0.precipitation != nil }) {
                    legend("Precipitation", Color.accentColor.opacity(0.3), swatchHeight: 10)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func legend(_ title: String, _ color: Color, swatchHeight: CGFloat = 3) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 14, height: swatchHeight)
            Text(title)
        }
    }
}

/// Every word change in the forecast, the first labeled "Now".
private struct ChangeList: View {
    let changes: [WordChange]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 14) {
            ForEach(Array(changes.enumerated()), id: \.element.date) { index, change in
                if index > 0 {
                    Divider().gridCellUnsizedAxes(.horizontal)
                }
                WordChangeRow(change: change, label: index == 0 ? "Now" : nil)
            }
        }
    }
}

extension View {
    /// The rounded panel the iPhone screens group content in.
    func card() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}
