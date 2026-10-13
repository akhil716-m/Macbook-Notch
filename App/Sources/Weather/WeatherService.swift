import CoreLocation
import Foundation
import NotchCore

/// Current conditions and a short forecast for one place. The place is
/// either a city the user picked or their current location. Refreshes when
/// the Weather tool opens and the reading is over 30 minutes old.
@MainActor
final class WeatherService: ObservableObject {
    enum Status: Equatable {
        case idle
        case loading
        case failed(String)
    }

    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var status: Status = .idle
    @Published private(set) var searchResults: [WeatherLocation] = []
    @Published private(set) var isLocating = false

    private let settings: AppSettings
    private let cache: LocalFile<WeatherSnapshot>
    private let locator = LocationFetcher()
    private var searchTask: Task<Void, Never>?

    private static let maxAge: TimeInterval = 30 * 60

    init(settings: AppSettings, cacheURL: URL) {
        self.settings = settings
        cache = LocalFile(url: cacheURL)
    }

    func start() {
        snapshot = cache.load()
    }

    var location: WeatherLocation? { settings.weatherLocation }

    /// Refresh if there's no reading, it's old, or the unit or place changed.
    func refreshIfNeeded() {
        guard let location = settings.weatherLocation else { return }
        if let snapshot,
           !snapshot.isStale(at: Date(), maxAge: Self.maxAge),
           snapshot.unit == settings.temperatureUnit,
           snapshot.locationName == location.name {
            return
        }
        refresh()
    }

    func refresh() {
        guard let location = settings.weatherLocation,
              let url = OpenMeteo.forecastURL(for: location, unit: settings.temperatureUnit)
        else { return }
        let unit = settings.temperatureUnit
        status = .loading
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                let snapshot = try OpenMeteo.decodeForecast(data, locationName: location.name, unit: unit, fetchedAt: Date())
                self.snapshot = snapshot
                self.cache.save(snapshot)
                self.status = .idle
            } catch {
                self.status = .failed("Couldn't load the weather. Check your connection.")
            }
        }
    }

    // MARK: Choosing a place

    /// Debounced city search.
    func search(_ query: String) {
        searchTask?.cancel()
        guard let url = OpenMeteo.searchURL(for: query) else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            guard let response = try? await URLSession.shared.data(from: url),
                  let results = try? OpenMeteo.decodeSearch(response.0),
                  !Task.isCancelled
            else { return }
            self.searchResults = results
        }
    }

    func choose(_ location: WeatherLocation) {
        settings.weatherLocation = location
        searchResults = []
        snapshot = nil
        refresh()
    }

    func useCurrentLocation() {
        isLocating = true
        status = .idle
        Task {
            defer { self.isLocating = false }
            do {
                let found = try await self.locator.currentLocation()
                let name = await Self.placeName(for: found) ?? "Current location"
                self.choose(WeatherLocation(
                    name: name,
                    latitude: found.coordinate.latitude,
                    longitude: found.coordinate.longitude
                ))
            } catch {
                self.status = .failed("Location isn't available. Allow it in System Settings › Privacy & Security › Location Services, or search for a city.")
            }
        }
    }

    private static func placeName(for location: CLLocation) async -> String? {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        return placemarks?.first?.locality ?? placemarks?.first?.name
    }
}

/// One-shot "where am I?" over CLLocationManager's delegate callbacks.
final class LocationFetcher: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Runs on the main thread, where CLLocationManager delivers its callbacks.
    @MainActor
    func currentLocation() async throws -> CLLocation {
        // Only one request at a time; a second caller cancels the first.
        continuation?.resume(throwing: CancellationError())
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                finish(.failure(CLError(.denied)))
            default:
                manager.requestLocation()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            break
        case .denied, .restricted:
            finish(.failure(CLError(.denied)))
        default:
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            finish(.success(location))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        let pending = continuation
        continuation = nil
        pending?.resume(with: result)
    }
}
