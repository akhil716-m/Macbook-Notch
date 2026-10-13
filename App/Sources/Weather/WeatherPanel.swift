import NotchCore
import SwiftUI

/// The Weather tool: now, plus the next three days. First time in, it asks
/// where you are.
struct WeatherPanel: View {
    @ObservedObject var weather: WeatherService
    @ObservedObject var settings: AppSettings
    @State private var choosingPlace = false
    @State private var query = ""

    var body: some View {
        Group {
            if settings.weatherLocation == nil || choosingPlace {
                placeChooser
            } else if let snapshot = weather.snapshot {
                forecast(snapshot)
            } else {
                statusView
            }
        }
        .onAppear { weather.refreshIfNeeded() }
    }

    // MARK: Forecast

    private func forecast(_ snapshot: WeatherSnapshot) -> some View {
        HStack(alignment: .center, spacing: NotchStyle.Space.l) {
            Image(systemName: snapshot.condition.symbolName(isDay: snapshot.isDay))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: NotchStyle.Weather.symbolSize))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: NotchStyle.Space.xxs) {
                Text(TemperatureFormat.short(snapshot.temperature))
                    .font(NotchStyle.Weather.temperature)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                Text(snapshot.condition.text)
                    .font(NotchStyle.Font.subtitle)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                if let feels = snapshot.apparentTemperature {
                    Text("Feels like \(TemperatureFormat.short(feels))")
                        .font(NotchStyle.Font.caption)
                        .foregroundStyle(NotchStyle.Palette.secondaryText)
                }
            }

            Spacer(minLength: NotchStyle.Space.s)

            HStack(spacing: NotchStyle.Space.xs) {
                ForEach(Array(snapshot.days.prefix(4).enumerated()), id: \.offset) { index, day in
                    DayColumn(day: day, isToday: index == 0)
                }
            }

            VStack(alignment: .trailing, spacing: NotchStyle.Space.s) {
                Text(snapshot.locationName)
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
                    .lineLimit(1)
                HStack(spacing: 0) {
                    IconButton(symbol: "arrow.clockwise", label: "Refresh") { weather.refresh() }
                    IconButton(symbol: "magnifyingglass", label: "Change place") { choosingPlace = true }
                }
                if case .failed = weather.status {
                    Text("Offline")
                        .font(NotchStyle.Font.caption)
                        .foregroundStyle(NotchStyle.Palette.overdue)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(snapshot.locationName): \(TemperatureFormat.short(snapshot.temperature)), \(snapshot.condition.text)")
    }

    @ViewBuilder
    private var statusView: some View {
        switch weather.status {
        case .failed(let message):
            PermissionPrompt(
                symbol: "wifi.exclamationmark",
                title: "No weather right now",
                message: message,
                buttonTitle: "Try Again",
                action: { weather.refresh() }
            )
        case .idle, .loading:
            EmptyToolState(symbol: "cloud.sun", title: "Loading the weather…", message: settings.weatherLocation?.name ?? "")
                .onAppear { weather.refreshIfNeeded() }
        }
    }

    // MARK: Choosing a place

    private var placeChooser: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
            HStack(spacing: NotchStyle.Space.s) {
                TextField("Search for a city", text: $query)
                    .textFieldStyle(.plain)
                    .font(NotchStyle.Font.body)
                    .padding(.horizontal, NotchStyle.Space.m)
                    .frame(height: NotchStyle.Chip.height + NotchStyle.Space.xs)
                    .background(
                        RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                            .fill(NotchStyle.Palette.rowBackground)
                    )
                    .onChange(of: query) { _, newValue in weather.search(newValue) }
                Button(weather.isLocating ? "Locating…" : "Use My Location") {
                    weather.useCurrentLocation()
                    choosingPlace = false
                }
                .buttonStyle(ChipButtonStyle(isProminent: true))
                .disabled(weather.isLocating)
                if settings.weatherLocation != nil {
                    Button("Cancel") {
                        choosingPlace = false
                        query = ""
                    }
                    .buttonStyle(ChipButtonStyle())
                }
            }
            if case .failed(let message) = weather.status {
                Text(message)
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.overdue)
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: NotchStyle.Space.xxs) {
                    ForEach(weather.searchResults) { place in
                        Button {
                            weather.choose(place)
                            choosingPlace = false
                            query = ""
                        } label: {
                            Text(place.fullName)
                                .font(NotchStyle.Font.body)
                                .foregroundStyle(NotchStyle.Palette.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, NotchStyle.Space.m)
                                .padding(.vertical, NotchStyle.Space.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                                        .fill(NotchStyle.Palette.rowBackground)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct DayColumn: View {
    let day: DailyForecast
    let isToday: Bool

    var body: some View {
        VStack(spacing: NotchStyle.Space.xxs) {
            Text(isToday ? "Today" : Self.weekday(day.day))
                .font(NotchStyle.Font.caption)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
            Image(systemName: WeatherCondition(code: day.code ?? 3).symbolName(isDay: true))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: NotchStyle.Weather.daySymbolSize))
            Text(TemperatureFormat.short(day.high))
                .font(NotchStyle.Font.caption)
                .foregroundStyle(NotchStyle.Palette.primaryText)
            Text(TemperatureFormat.short(day.low))
                .font(NotchStyle.Font.caption)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
        }
        .frame(width: NotchStyle.Weather.dayColumn)
        .accessibilityElement(children: .combine)
    }

    /// "2026-10-14" → "Wed", in the user's language.
    private static func weekday(_ isoDay: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: isoDay) else { return "" }
        let output = DateFormatter()
        output.timeZone = TimeZone(identifier: "UTC")
        output.setLocalizedDateFormatFromTemplate("EEE")
        return output.string(from: date)
    }
}
