import XCTest

@MainActor final class CombinedDemoUITests: XCTestCase {
  private func open() -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["-econopolis-ui-testing"]
    app.launch()
    XCTAssertTrue(app.staticTexts["simulationDay"].waitForExistence(timeout: 30))
    return app
  }
  private func tap(_ title: String, app: XCUIApplication, timeout: TimeInterval = 30) {
    let button = app.buttons[title]
    for _ in 0..<4 where !button.exists { app.swipeUp() }
    XCTAssertTrue(button.waitForExistence(timeout: timeout))
    let enabled = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "enabled == true"), object: button)
    XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: timeout), .completed)
    for _ in 0..<5 where !button.isHittable { app.swipeUp() }
    button.tap()
  }
  private func capture(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  func testGreatBankRunEndToEnd() throws {
    let app = open()
    app.tabBars.buttons["Crisis Lab"].tap()
    tap("START LIVE DEMO", app: app)
    tap("Trigger The Great Bank Run", app: app, timeout: 60)
    XCTAssertTrue(app.buttons["Rewind World B"].waitForExistence(timeout: 60))
    app.tabBars.buttons["City"].tap()
    XCTAssertTrue(app.staticTexts["DAY 35"].waitForExistence(timeout: 20))
    capture("Bank run city - real state", app: app)
    app.buttons["Financial heatmap"].tap()
    app.descendants(matching: .any).matching(
      NSPredicate(format: "label BEGINSWITH 'Banking stress'")
    ).firstMatch.tap()
    capture("Banking heatmap", app: app)
    app.tabBars.buttons["Crisis Lab"].tap()
    tap("Rewind World B", app: app)
    app.tabBars.buttons["City"].tap()
    XCTAssertTrue(app.staticTexts["DAY 7"].waitForExistence(timeout: 20))
    app.tabBars.buttons["Crisis Lab"].tap()
    tap("Apply liquidity & replay", app: app, timeout: 60)
    XCTAssertTrue(app.buttons["Restart live demo"].waitForExistence(timeout: 60))
    let comparison = app.staticTexts["Computed futures"]
    for _ in 0..<4 where !comparison.isHittable { app.swipeUp() }
    XCTAssertTrue(comparison.waitForExistence(timeout: 10))
    capture("Computed comparison", app: app)

    app.tabBars.buttons["Citizens"].tap()
    let first = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Riley 1'")).firstMatch
    XCTAssertTrue(first.waitForExistence(timeout: 15))
    first.tap()
    XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 15))
    capture("Citizen financial consequences", app: app)
    app.buttons["Done"].tap()
    app.tabBars.buttons["AI Economist"].tap()
    tap("Explain the impact of the bank run", app: app)
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Depositors requested'"))
        .firstMatch.waitForExistence(timeout: 20))
    capture("Grounded offline economist", app: app)
  }
  func testPhase2CityFiltersAndCommandPreview() throws {
    let app = open()
    app.buttons["Reset camera"].tap()
    let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
    origin.press(
      forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
    )
    app.pinch(withScale: 1.2, velocity: 0.5)
    capture("Procedural city", app: app)
    app.tabBars.buttons["Citizens"].tap()
    app.buttons["Citizen filters"].tap()
    XCTAssertTrue(app.staticTexts["Filter citizens"].waitForExistence(timeout: 10))
    app.buttons["Done"].tap()
    app.searchFields.firstMatch.tap()
    app.searchFields.firstMatch.typeText("no_such_citizen\n")
    XCTAssertTrue(app.staticTexts["No matching citizens"].waitForExistence(timeout: 10))
    if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
    app.tabBars.buttons["AI Economist"].tap()
    tap("Increase interest rates by 2 percentage points", app: app)
    XCTAssertTrue(app.staticTexts["Preview intervention"].waitForExistence(timeout: 10))
    app.buttons["Cancel"].tap()
    app.tabBars.buttons["City"].tap()
    XCTAssertTrue(app.staticTexts["DAY 0"].waitForExistence(timeout: 10))
  }
}
