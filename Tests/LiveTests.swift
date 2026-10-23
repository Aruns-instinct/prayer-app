import XCTest
import MapKit
@testable import PrayerTracker

/// These hit the real network. They report whether live Aladhan fetch and MapKit city search work from the CI simulator.
final class LiveTests: XCTestCase {
    func testLiveAladhanFetchForCoimbatore() throws {
        UserDefaults.standard.removeObject(forKey: "prayer.state.v1")
        UserDefaults.standard.removeObject(forKey: "prayer.caches.v1")
        let s = Store()
        s.settings = Settings(place: Place(name: "Coimbatore", latitude: 11.0168, longitude: 76.9558, timeZoneID: "Asia/Kolkata"),
                              method: .muslimWorldLeague, asr: .standard)
        s.refreshTimes(force: true)
        let deadline = Date().addingTimeInterval(40)
        while s.caches.isEmpty && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.5)) }
        XCTAssertFalse(s.caches.isEmpty, "no data fetched. status: \(s.fetchStatus)")
        let today = Date()
        let fajr = try XCTUnwrap(s.time(for: .fajr, on: today), "no fajr for today")
        let order = PrayerName.allCases.compactMap { s.time(for: $0, on: today) }
        XCTAssertEqual(order.count, 5)
        XCTAssertEqual(order, order.sorted(), "times not in order")
        print("LIVE_ALADHAN fajr=\(fajr) all=\(order) status='\(s.fetchStatus)'")
    }

    func testLiveCitySearchCoimbatore() throws {
        let exp = expectation(description: "search")
        var items: [MKMapItem] = []
        let r = MKLocalSearch.Request(); r.naturalLanguageQuery = "Coimbatore"; r.resultTypes = .address
        MKLocalSearch(request: r).start { resp, err in
            print("LIVE_SEARCH error=\(String(describing: err))")
            items = resp?.mapItems ?? []; exp.fulfill()
        }
        wait(for: [exp], timeout: 40)
        XCTAssertFalse(items.isEmpty, "MapKit returned no results")
        for i in items.prefix(3) {
            print("LIVE_SEARCH item=\(i.name ?? "?") locality=\(i.placemark.locality ?? "nil") tz=\(i.placemark.timeZone?.identifier ?? "NIL") coord=\(i.placemark.coordinate)")
        }
        // MapKit gave no time zone for this result (see the LIVE_SEARCH log); the app resolves it via Aladhan instead. See next test.
    }

    func testLiveTimeZoneResolutionWhenMapKitHasNone() throws {
        UserDefaults.standard.removeObject(forKey: "prayer.state.v1")
        UserDefaults.standard.removeObject(forKey: "prayer.caches.v1")
        let s = Store()
        s.settings = Settings(place: Place(name: "Coimbatore", latitude: 11.0167202, longitude: 76.9773787, timeZoneID: ""),
                              method: .muslimWorldLeague, asr: .standard)
        XCTAssertFalse(s.settings.isReady, "must not be ready without a time zone")
        let deadline = Date().addingTimeInterval(40)
        while s.settings.place?.timeZoneID.isEmpty ?? true, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.5)) }
        print("LIVE_TZ resolved=\(s.settings.place?.timeZoneID ?? "nil") status='\(s.fetchStatus)'")
        XCTAssertEqual(s.settings.place?.timeZoneID, "Asia/Kolkata")
    }
}
