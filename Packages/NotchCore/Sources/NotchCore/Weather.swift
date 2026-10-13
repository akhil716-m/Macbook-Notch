import Foundation

public struct WeatherLocation: Codable, Hashable, Sendable, Identifiable {
    public var name: String
    public var region: String?
    public var country: String?
    public var latitude: Double
    public var longitude: Double

    public init(name: String, region: String? = nil, country: String? = nil, latitude: Double, longitude: Double) {
        self.name = name
        self.region = region
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }

    public var id: String { "\(latitude),\(longitude)" }

    /// "Pune, Maharashtra, India"
    public var fullName: String {
        [name, region, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

public enum TemperatureUnit: String, CaseIterable, Codable, Sendable, Identifiable {
    case celsius
    case fahrenheit

    public var id: String { rawValue }
    public var symbol: String { self == .celsius ? "°C" : "°F" }
    public var title: String { self == .celsius ? "Celsius" : "Fahrenheit" }

    /// The unit most people in a region expect.
    public static func preferred(usesMetric: Bool) -> TemperatureUnit {
        usesMetric ? .celsius : .fahrenheit
    }
}

public struct DailyForecast: Codable, Hashable, Sendable {
    /// "yyyy-MM-dd" in the location's time zone.
    public var day: String
    public var high: Double?
    public var low: Double?
    public var code: Int?

    public init(day: String, high: Double?, low: Double?, code: Int?) {
        self.day = day
        self.high = high
        self.low = low
        self.code = code
    }
}

public struct WeatherSnapshot: Codable, Equatable, Sendable {
    public var locationName: String
    public var temperature: Double
    public var apparentTemperature: Double?
    public var code: Int
    public var isDay: Bool
    public var windSpeed: Double?
    public var days: [DailyForecast]
    public var unit: TemperatureUnit
    public var fetchedAt: Date

    public init(
        locationName: String,
        temperature: Double,
        apparentTemperature: Double?,
        code: Int,
        isDay: Bool,
        windSpeed: Double?,
        days: [DailyForecast],
        unit: TemperatureUnit,
        fetchedAt: Date
    ) {
        self.locationName = locationName
        self.temperature = temperature
        self.apparentTemperature = apparentTemperature
        self.code = code
        self.isDay = isDay
        self.windSpeed = windSpeed
        self.days = days
        self.unit = unit
        self.fetchedAt = fetchedAt
    }

    public var condition: WeatherCondition { WeatherCondition(code: code) }

    public func isStale(at date: Date, maxAge: TimeInterval) -> Bool {
        date.timeIntervalSince(fetchedAt) > maxAge
    }
}

/// WMO weather interpretation codes, as used by Open-Meteo and most
/// forecast services, turned into words and an SF Symbol.
public struct WeatherCondition: Equatable, Sendable {
    public let code: Int

    public init(code: Int) {
        self.code = code
    }

    public var text: String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63: return "Rain"
        case 65: return "Heavy rain"
        case 66, 67: return "Freezing rain"
        case 71, 73: return "Snow"
        case 75: return "Heavy snow"
        case 77: return "Snow grains"
        case 80, 81: return "Showers"
        case 82: return "Heavy showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown"
        }
    }

    public func symbolName(isDay: Bool) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 66, 67, 80, 81: return "cloud.rain.fill"
        case 65, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

/// Requests and responses for Open-Meteo (open-meteo.com): free, no key.
/// Its free tier is for non-commercial use; a paid app needs their
/// commercial plan or a different provider (WeatherKit) before launch.
public enum OpenMeteo {
    public static func forecastURL(for location: WeatherLocation, unit: TemperatureUnit) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", location.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "temperature_unit", value: unit.rawValue),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7"),
        ]
        return components?.url
    }

    public static func searchURL(for query: String) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "count", value: "6"),
            URLQueryItem(name: "format", value: "json"),
        ]
        return components?.url
    }

    public static func decodeForecast(
        _ data: Data,
        locationName: String,
        unit: TemperatureUnit,
        fetchedAt: Date
    ) throws -> WeatherSnapshot {
        let response = try JSONDecoder().decode(ForecastResponse.self, from: data)
        var days: [DailyForecast] = []
        if let daily = response.daily {
            for (index, day) in daily.time.enumerated() {
                days.append(DailyForecast(
                    day: day,
                    high: daily.highs.indices.contains(index) ? daily.highs[index] : nil,
                    low: daily.lows.indices.contains(index) ? daily.lows[index] : nil,
                    code: daily.codes.indices.contains(index) ? daily.codes[index] : nil
                ))
            }
        }
        return WeatherSnapshot(
            locationName: locationName,
            temperature: response.current.temperature,
            apparentTemperature: response.current.apparentTemperature,
            code: response.current.code,
            isDay: (response.current.isDay ?? 1) == 1,
            windSpeed: response.current.windSpeed,
            days: days,
            unit: unit,
            fetchedAt: fetchedAt
        )
    }

    public static func decodeSearch(_ data: Data) throws -> [WeatherLocation] {
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        return (response.results ?? []).map {
            WeatherLocation(name: $0.name, region: $0.admin1, country: $0.country, latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    private struct ForecastResponse: Decodable {
        struct Current: Decodable {
            let temperature: Double
            let apparentTemperature: Double?
            let code: Int
            let isDay: Int?
            let windSpeed: Double?

            enum CodingKeys: String, CodingKey {
                case temperature = "temperature_2m"
                case apparentTemperature = "apparent_temperature"
                case code = "weather_code"
                case isDay = "is_day"
                case windSpeed = "wind_speed_10m"
            }
        }

        struct Daily: Decodable {
            let time: [String]
            let highs: [Double?]
            let lows: [Double?]
            let codes: [Int?]

            enum CodingKeys: String, CodingKey {
                case time
                case highs = "temperature_2m_max"
                case lows = "temperature_2m_min"
                case codes = "weather_code"
            }
        }

        let current: Current
        let daily: Daily?
    }

    private struct SearchResponse: Decodable {
        struct Result: Decodable {
            let name: String
            let latitude: Double
            let longitude: Double
            let country: String?
            let admin1: String?
        }

        let results: [Result]?
    }
}

public enum TemperatureFormat {
    /// "21°" (the unit is shown once elsewhere).
    public static func short(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "–" }
        return "\(Int(value.rounded()))°"
    }
}
