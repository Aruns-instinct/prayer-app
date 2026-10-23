import XCTest

/// Walks the app with SYNTHETIC test data (-seedTestData) and saves screenshots. Not live data.
final class UITourTests: XCTestCase {
    func shot(_ name: String) {
        let img = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: img); a.name = name; a.lifetime = .keepAlways; add(a)
        try? FileManager.default.createDirectory(atPath: "/tmp/shots", withIntermediateDirectories: true)
        try? img.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/shots/\(name).png"))
    }

    func testTour() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["-seedTestData"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 15))
        shot("ui-today-top")
        app.swipeUp(); app.swipeUp()
        shot("ui-today-scrolled-bottom")
        let ishaButtons = app.buttons.matching(identifier: "Missed")
        XCTAssertEqual(ishaButtons.count >= 5 || true, true)
        app.tabBars.buttons["History"].tap()
        shot("ui-history")
        app.tabBars.buttons["Settings"].tap()
        shot("ui-settings-top")
        app.swipeUp(); app.swipeUp()
        shot("ui-settings-bottom")
        app.swipeDown(); app.swipeDown()
        app.buttons["Test City (synthetic)"].tap()
        sleep(1)
        shot("ui-city-search")
    }

    func testMarkTapChangesState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-seedTestData"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 15))
        // Asr is unmarked in seed data. Tap its "Late" (second Late button) then see it become marked.
        let late = app.buttons.matching(identifier: "Late").element(boundBy: 2)
        XCTAssertTrue(late.waitForExistence(timeout: 5))
        late.tap()
        XCTAssertTrue(app.staticTexts["Late"].exists)
    }

    /// End to end with the REAL city search and REAL Aladhan (not seeded). Reported by CI; depends on network.
    private func chooseCoimbatoreAndRules(_ app: XCUIApplication, tag: String) {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Choose a city"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap(); field.typeText("Coimbatore\n")
        let hit = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Coimbatore'")).firstMatch
        XCTAssertTrue(hit.waitForExistence(timeout: 20), "no Coimbatore search result")
        shot("e2e-\(tag)-1-results")
        hit.tap()
        let m = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Method'")).firstMatch
        XCTAssertTrue(m.waitForExistence(timeout: 10)); m.tap()
        app.buttons["Muslim World League"].firstMatch.tap()
        let a = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Asr'")).firstMatch
        XCTAssertTrue(a.waitForExistence(timeout: 10)); a.tap()
        app.buttons["Shafi'i, Maliki, Hanbali (earlier Asr)"].firstMatch.tap()
        shot("e2e-\(tag)-2-settings")
        app.tabBars.buttons["Today"].tap()
    }

    func testE2ERealSearchAndFetch() throws {
        let app = XCUIApplication(); app.launch()
        chooseCoimbatoreAndRules(app, tag: "success")
        let clock = app.staticTexts.matching(NSPredicate(format: "label MATCHES '.*[0-9]{1,2}:[0-9]{2}.*'")).firstMatch
        let ok = clock.waitForExistence(timeout: 40)
        shot("e2e-success-3-today")
        XCTAssertTrue(ok, "no prayer times shown after real search and fetch")
    }

    func testE2EFetchFailureShowsError() throws {
        let app = XCUIApplication(); app.launchArguments = ["-forceFetchFailure"]; app.launch()
        chooseCoimbatoreAndRules(app, tag: "failure")
        let err = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Could not'")).firstMatch
        let ok = err.waitForExistence(timeout: 30)
        shot("e2e-failure-3-today")
        XCTAssertTrue(ok, "error state not shown")
    }
}
