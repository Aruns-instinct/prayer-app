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
        XCTAssertNotNil(items.first?.placemark.timeZone, "placemark has no time zone; app would fall back to device time zone")
    }
}
