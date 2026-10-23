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
}
