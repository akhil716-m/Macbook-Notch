import NotchCore
import SwiftUI

/// The Weather tool: now, plus the week ahead. First time in, it asks
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
        let offline: Bool = {
            if case .failed = weather.status { return true }
            return false
        }()
        return WeatherForecastView(
            snapshot: snapshot,
            isOffline: offline,
            onRefresh: { weather.refresh() },
            onChangePlace: { choosingPlace = true }
        )
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

/// Now on the left, large; the week on a lighter field to the right. From
/// plain values so it can be drawn with sample data.
struct WeatherForecastView: View {
    let snapshot: WeatherSnapshot
    let isOffline: Bool
    let onRefresh: () -> Void
    let onChangePlace: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: NotchStyle.Space.l) {
            now
                .frame(width: NotchStyle.Weather.nowColumn, alignment: .leading)
            week
        }
        .frame(maxHeight: .infinity)
    }

    private var now: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
            HStack(spacing: NotchStyle.Space.xxs) {
                Button(action: onChangePlace) {
                    Label(snapshot.locationName, systemImage: "location.fill")
                        .labelStyle(.titleOnly)
                        .font(NotchStyle.Font.body.weight(.medium))
                        .foregroundStyle(NotchStyle.Palette.secondaryText)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("Change place")
                .accessibilityLabel("Change place, now \(snapshot.locationName)")
                if isOffline {
                    Text("· Offline")
                        .font(NotchStyle.Font.caption)
                        .foregroundStyle(NotchStyle.Palette.overdue)
                }
                Spacer(minLength: 0)
                IconButton(symbol: "arrow.clockwise", label: "Refresh", action: onRefresh)
            }
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: NotchStyle.Space.s) {
                Image(systemName: snapshot.condition.symbolName(isDay: snapshot.isDay))
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: NotchStyle.Weather.symbolSize))
                    .accessibilityHidden(true)
                Text(TemperatureFormat.short(snapshot.temperature))
                    .font(NotchStyle.Weather.temperature)
                    .tracking(-1)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(snapshot.condition.text)
                .font(NotchStyle.Font.title)
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .lineLimit(1)
            Text(detail)
                .font(NotchStyle.Font.caption)
                .foregroundStyle(NotchStyle.Palette.tertiaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(snapshot.locationName): \(TemperatureFormat.short(snapshot.temperature)), \(snapshot.condition.text)")
    }

    /// "Feels like 21° · H 29° L 22°"
    private var detail: String {
        var parts: [String] = []
        if let feels = snapshot.apparentTemperature {
            parts.append("Feels like \(TemperatureFormat.short(feels))")
        }
        if let today = snapshot.days.first, let high = today.high, let low = today.low {
            parts.append("H \(TemperatureFormat.short(high))  L \(TemperatureFormat.short(low))")
        }
        return parts.joined(separator: " · ")
    }

    private var week: some View {
        HStack(spacing: 0) {
            ForEach(Array(snapshot.days.prefix(7).enumerated()), id: \.offset) { index, day in
                DayColumn(day: day, isToday: index == 0)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, NotchStyle.Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NotchCardBackground(radius: NotchStyle.Card.radius + 4))
    }
}

private struct DayColumn: View {
    let day: DailyForecast
    let isToday: Bool

    var body: some View {
        VStack(spacing: NotchStyle.Space.s) {
            Text(isToday ? "Today" : Self.weekday(day.day))
                .font(NotchStyle.Font.caption.weight(isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? NotchStyle.Palette.primaryText : NotchStyle.Palette.secondaryText)
            Image(systemName: WeatherCondition(code: day.code ?? 3).symbolName(isDay: true))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: NotchStyle.Weather.daySymbolSize))
                .frame(height: NotchStyle.Weather.daySymbolSize + NotchStyle.Space.xs)
            VStack(spacing: NotchStyle.Space.xxs) {
                Text(day.high.map { TemperatureFormat.short($0) } ?? "–")
                    .font(NotchStyle.Font.body.weight(.semibold))
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                Text(day.low.map { TemperatureFormat.short($0) } ?? "–")
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.tertiaryText)
            }
            .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    /// "2026-10-14" → "Wed", in the user's language.
    static func weekday(_ isoDay: String) -> String {
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
