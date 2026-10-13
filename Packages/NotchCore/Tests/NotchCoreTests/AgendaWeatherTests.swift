import XCTest
@testable import NotchCore

final class AgendaTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 2026-10-13 10:00 UTC
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 10))!
    }

    private func at(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func event(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false) -> AgendaEvent {
        AgendaEvent(id: title, title: title, start: start, end: end, isAllDay: allDay)
    }

    func testTodayAndTomorrowWithEndedEventsDropped() {
        let events = [
            event("standup", at(day: 13, hour: 9), at(day: 13, hour: 9, minute: 15)),   // already over
            event("lunch", at(day: 13, hour: 12), at(day: 13, hour: 13)),
            event("design review", at(day: 13, hour: 9, minute: 30), at(day: 13, hour: 11)), // happening now
            event("holiday", at(day: 13, hour: 0), at(day: 14, hour: 0), allDay: true),
            event("dentist", at(day: 14, hour: 8), at(day: 14, hour: 9)),
            event("next week", at(day: 20, hour: 8), at(day: 20, hour: 9)),
        ]
        let sections = Agenda.sections(events, now: now, calendar: calendar)
        XCTAssertEqual(sections.map(\.title), ["Today", "Tomorrow"])
        XCTAssertEqual(sections[0].events.map(\.title), ["holiday", "design review", "lunch"])
        XCTAssertEqual(sections[1].events.map(\.title), ["dentist"])
        XCTAssertTrue(sections[0].events[1].isHappening(at: now))
    }

    func testEmptyDaysAreLeftOut() {
        let events = [event("dentist", at(day: 14, hour: 8), at(day: 14, hour: 9))]
        XCTAssertEqual(Agenda.sections(events, now: now, calendar: calendar).map(\.title), ["Tomorrow"])
        XCTAssertTrue(Agenda.sections([], now: now, calendar: calendar).isEmpty)
    }

    func testNextEventSkipsAllDayAndStarted() {
        let events = [
            event("holiday", at(day: 13, hour: 0), at(day: 14, hour: 0), allDay: true),
            event("ongoing", at(day: 13, hour: 9), at(day: 13, hour: 11)),
            event("later", at(day: 13, hour: 15), at(day: 13, hour: 16)),
            event("soon", at(day: 13, hour: 11), at(day: 13, hour: 12)),
        ]
        XCTAssertEqual(Agenda.nextEvent(events, after: now)?.title, "soon")
    }

    func testMeetingLinksAreFound() {
        XCTAssertEqual(
            MeetingLink.find(in: [nil, "Room 4", "Join: https://us02web.zoom.us/j/123456?pwd=abc thanks"])?.host,
            "us02web.zoom.us"
        )
        XCTAssertEqual(MeetingLink.find(in: ["https://meet.google.com/abc-defg-hij"])?.host, "meet.google.com")
        XCTAssertNil(MeetingLink.find(in: ["https://example.com/agenda", "no links here"]))
        XCTAssertFalse(MeetingLink.isMeeting(URL(string: "https://notzoom.us.evil.com/j/1")!))
    }

    // MARK: Reminders

    func testReminderBuckets() {
        let overdueDay = ReminderItem(id: "a", title: "a", dueDate: at(day: 12, hour: 0))
        let overdueTime = ReminderItem(id: "b", title: "b", dueDate: at(day: 13, hour: 9), dueHasTime: true)
        let todayLater = ReminderItem(id: "c", title: "c", dueDate: at(day: 13, hour: 18), dueHasTime: true)
        let todayAllDay = ReminderItem(id: "d", title: "d", dueDate: at(day: 13, hour: 0))
        let future = ReminderItem(id: "e", title: "e", dueDate: at(day: 15, hour: 0))
        let someday = ReminderItem(id: "f", title: "f")

        XCTAssertEqual(ReminderOrder.bucket(overdueDay, now: now, calendar: calendar), .overdue)
        XCTAssertEqual(ReminderOrder.bucket(overdueTime, now: now, calendar: calendar), .overdue)
        XCTAssertEqual(ReminderOrder.bucket(todayLater, now: now, calendar: calendar), .today)
        XCTAssertEqual(ReminderOrder.bucket(todayAllDay, now: now, calendar: calendar), .today)
        XCTAssertEqual(ReminderOrder.bucket(future, now: now, calendar: calendar), .upcoming)
        XCTAssertEqual(ReminderOrder.bucket(someday, now: now, calendar: calendar), .someday)
    }

    func testRemindersAreSortedByUrgency() {
        let items = [
            ReminderItem(id: "someday-1", title: "s1"),
            ReminderItem(id: "future", title: "f", dueDate: at(day: 15, hour: 0)),
            ReminderItem(id: "today", title: "t", dueDate: at(day: 13, hour: 18), dueHasTime: true),
            ReminderItem(id: "someday-2", title: "s2"),
            ReminderItem(id: "overdue", title: "o", dueDate: at(day: 12, hour: 0)),
        ]
        XCTAssertEqual(
            ReminderOrder.sorted(items, now: now, calendar: calendar).map(\.id),
            ["overdue", "today", "future", "someday-1", "someday-2"]
        )
    }
}

final class WeatherTests: XCTestCase {
    private let pune = WeatherLocation(name: "Pune", region: "Maharashtra", country: "India", latitude: 18.5196, longitude: 73.8553)

    func testForecastURL() throws {
        let url = try XCTUnwrap(OpenMeteo.forecastURL(for: pune, unit: .fahrenheit))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(url.host, "api.open-meteo.com")
        XCTAssertEqual(values["latitude"], "18.5196")
        XCTAssertEqual(values["longitude"], "73.8553")
        XCTAssertEqual(values["temperature_unit"], "fahrenheit")
        XCTAssertEqual(values["timezone"], "auto")
    }

    func testSearchURLNeedsTwoCharacters() {
        XCTAssertNil(OpenMeteo.searchURL(for: " p "))
        XCTAssertEqual(OpenMeteo.searchURL(for: "Pune")?.host, "geocoding-api.open-meteo.com")
    }

    func testDecodesAForecast() throws {
        let json = """
        {"latitude":18.5,"longitude":73.875,"timezone":"Asia/Kolkata",
         "current":{"time":"2026-10-13T15:30","interval":900,"temperature_2m":29.4,"apparent_temperature":31.2,
                    "weather_code":2,"is_day":1,"wind_speed_10m":9.7},
         "daily":{"time":["2026-10-13","2026-10-14"],"weather_code":[2,61],
                  "temperature_2m_max":[31.0,28.5],"temperature_2m_min":[21.2,null]}}
        """
        let fetched = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let snapshot = try OpenMeteo.decodeForecast(Data(json.utf8), locationName: "Pune", unit: .celsius, fetchedAt: fetched)
        XCTAssertEqual(snapshot.temperature, 29.4)
        XCTAssertEqual(snapshot.apparentTemperature, 31.2)
        XCTAssertEqual(snapshot.condition.text, "Partly cloudy")
        XCTAssertTrue(snapshot.isDay)
        XCTAssertEqual(snapshot.days.count, 2)
        XCTAssertEqual(snapshot.days[1].code, 61)
        XCTAssertNil(snapshot.days[1].low)
        XCTAssertFalse(snapshot.isStale(at: fetched.addingTimeInterval(60), maxAge: 1_800))
        XCTAssertTrue(snapshot.isStale(at: fetched.addingTimeInterval(1_801), maxAge: 1_800))
    }

    func testDecodesSearchResultsAndNoResults() throws {
        let json = """
        {"results":[{"id":1259229,"name":"Pune","latitude":18.51957,"longitude":73.85535,
                     "country":"India","admin1":"Maharashtra","timezone":"Asia/Kolkata"}],
         "generationtime_ms":0.5}
        """
        let results = try OpenMeteo.decodeSearch(Data(json.utf8))
        XCTAssertEqual(results.first?.fullName, "Pune, Maharashtra, India")
        XCTAssertEqual(try OpenMeteo.decodeSearch(Data(#"{"generationtime_ms":0.3}"#.utf8)), [])
    }

    func testConditionsCoverTheCommonCodes() {
        XCTAssertEqual(WeatherCondition(code: 0).symbolName(isDay: true), "sun.max.fill")
        XCTAssertEqual(WeatherCondition(code: 0).symbolName(isDay: false), "moon.stars.fill")
        XCTAssertEqual(WeatherCondition(code: 63).text, "Rain")
        XCTAssertEqual(WeatherCondition(code: 95).symbolName(isDay: true), "cloud.bolt.rain.fill")
        XCTAssertEqual(WeatherCondition(code: 1234).text, "Unknown")
    }

    func testTemperatureFormatting() {
        XCTAssertEqual(TemperatureFormat.short(21.4), "21°")
        XCTAssertEqual(TemperatureFormat.short(-0.6), "-1°")
        XCTAssertEqual(TemperatureFormat.short(nil), "–")
        XCTAssertEqual(TemperatureUnit.preferred(usesMetric: false), .fahrenheit)
    }
}
