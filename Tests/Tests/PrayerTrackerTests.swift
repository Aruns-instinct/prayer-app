import XCTest
@testable import PrayerTracker

final class PrayerTrackerTests: XCTestCase {
    // Shape follows the Aladhan calendar response (checked against the live API on 23 Oct 2026 for Coimbatore, method 3, school 0).
    let sample = """
    {"code":200,"data":[{"timings":{"Fajr":"05:01 (IST)","Sunrise":"06:10 (IST)","Dhuhr":"12:07 (IST)","Asr":"15:28 (IST)","Maghrib":"18:01 (IST)","Isha":"19:08 (IST)"},
    "date":{"gregorian":{"date":"23-10-2026"},"hijri":{"date":"12-05-1448"}}}]}
    """

    func testParseDecodesAladhanShape() throws {
        let days = try XCTUnwrap(Store.parse(Data(sample.utf8), tz: "Asia/Kolkata"))
        XCTAssertEqual(days["2026-10-23"]?["fajr"], "05:01")
        XCTAssertEqual(days["2026-10-23"]?["asr"], "15:28")
        XCTAssertEqual(days["2026-10-23"]?["isha"], "19:08")
    }

    func testParseRejectsGarbage() {
        XCTAssertNil(Store.parse(Data("{}".utf8), tz: "Asia/Kolkata"))
        XCTAssertNil(Store.parse(Data("not json".utf8), tz: "Asia/Kolkata"))
    }

    private func storeWithTimes(tz: String) throws -> Store {
        UserDefaults.standard.removeObject(forKey: "prayer.state.v1")
        UserDefaults.standard.removeObject(forKey: "prayer.caches.v1")
        let s = Store()
        s.settings = Settings(place: Place(name: "T", latitude: 11, longitude: 77, timeZoneID: tz), method: .muslimWorldLeague, asr: .standard)
        let days = try XCTUnwrap(Store.parse(Data(sample.utf8), tz: tz))
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: tz)!
        let noon = cal.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 12))!
        let k = try XCTUnwrap(s.cachedMonthKeyForTest(noon))
        s.caches[k] = Store.MonthCache(key: k, fetchedAt: Date(), days: days)
        return s
    }

    func testTimeIsInPlaceTimezoneNotDeviceTimezone() throws {
        let s = try storeWithTimes(tz: "Asia/Kolkata")
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let day = cal.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9))!
        let t = try XCTUnwrap(s.time(for: .fajr, on: day))
        let c = cal.dateComponents([.hour, .minute], from: t)
        XCTAssertEqual(c.hour, 5); XCTAssertEqual(c.minute, 1)
        XCTAssertEqual(t.timeIntervalSince1970, 1792711860, accuracy: 1) // 2026-10-23 05:01 IST = 2026-10-22 23:31 UTC
    }

    func testDayKeyUsesPlaceTimezone() throws {
        let s = try storeWithTimes(tz: "Asia/Kolkata")
        // 2026-10-22 20:00 UTC is 2026-10-23 01:30 in Kolkata
        let d = Date(timeIntervalSince1970: 1792699200)
        XCTAssertEqual(s.dayKey(d), "2026-10-23")
    }

    func testManualTimeOverridesCalculated() throws {
        let s = try storeWithTimes(tz: "Asia/Kolkata")
        s.settings.manualTimes["fajr"] = "05:25"
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let day = cal.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9))!
        let c = cal.dateComponents([.hour, .minute], from: try XCTUnwrap(s.time(for: .fajr, on: day)))
        XCTAssertEqual(c.hour, 5); XCTAssertEqual(c.minute, 25)
    }

    func testMarksAndUnconfirmed() throws {
        let s = try storeWithTimes(tz: "Asia/Kolkata")
        let d = Date()
        XCTAssertNil(s.log[s.dayKey(d)]?["fajr"], "unmarked prayers must stay unconfirmed")
        s.setMark(.late, prayer: .fajr, date: d)
        XCTAssertEqual(s.log[s.dayKey(d)]?["fajr"], .late)
        s.setMark(nil, prayer: .fajr, date: d)
        XCTAssertNil(s.log[s.dayKey(d)]?["fajr"])
        XCTAssertNil(s.log[s.dayKey(d)]?["dhuhr"])
    }

    func testReminderPlanOnlyFutureAndCapped() throws {
        let s = try storeWithTimes(tz: "Asia/Kolkata")
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 13))!
        let plan = s.plannedReminders(now: now)
        // Only 23 Oct is cached in this test, so after 13:00 IST only Asr, Maghrib, Isha remain.
        XCTAssertEqual(plan.map { $0.prayer.rawValue }, ["asr", "maghrib", "isha"])
        XCTAssertTrue(plan.allSatisfy { $0.at > now })
        XCTAssertEqual(plan.first?.id, "2026-10-23-asr")
        XCTAssertLessThanOrEqual(plan.count, 35)
    }

    func testNoPlanWithoutChoices() {
        UserDefaults.standard.removeObject(forKey: "prayer.state.v1")
        let s = Store()
        s.settings = Settings()
        XCTAssertTrue(s.plannedReminders(now: Date()).isEmpty)
    }
}
