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
    let demoTitles = [
      "START LIVE DEMO", "Trigger The Great Bank Run", "Rewind World B", "Apply liquidity & replay",
      "Restart live demo",
    ]
    if demoTitles.contains(title) {
      XCTAssertTrue(button.waitForExistence(timeout: timeout))
    } else {
      for _ in 0..<4 where !button.exists { app.swipeUp() }
    }

    XCTAssertTrue(button.waitForExistence(timeout: timeout))
    let enabled = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "enabled == true"), object: button)
    XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: timeout), .completed)
    for _ in 0..<5 where !button.isHittable { app.swipeUp() }
    tapNativeElement(button, in: app)
  }
  private func capture(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  func testGreatBankRunEndToEnd() throws {
    let app = open()
    selectNativeTab("Crisis Lab", in: app)
    tap("START LIVE DEMO", app: app)
    selectNativeTab("City", in: app)
    XCTAssertTrue(app.staticTexts["DAY 7"].waitForExistence(timeout: 30))
    selectNativeTab("Crisis Lab", in: app)
    tap("Trigger The Great Bank Run", app: app, timeout: 60)
    XCTAssertTrue(app.buttons["Rewind World B"].waitForExistence(timeout: 60))
    selectNativeTab("City", in: app)
    XCTAssertTrue(app.staticTexts["DAY 35"].waitForExistence(timeout: 20))
    capture("Bank run city - real state", app: app)
    app.buttons["Financial heatmap"].tap()
    app.descendants(matching: .any).matching(
      NSPredicate(format: "label BEGINSWITH 'Banking stress'")
    ).firstMatch.tap()
    capture("Banking heatmap", app: app)
    selectNativeTab("Crisis Lab", in: app)
    tap("Rewind World B", app: app)
    selectNativeTab("City", in: app)
    XCTAssertTrue(app.staticTexts["DAY 7"].waitForExistence(timeout: 20))
    selectNativeTab("Crisis Lab", in: app)
    tap("Apply liquidity & replay", app: app, timeout: 60)
    XCTAssertTrue(app.buttons["Restart live demo"].waitForExistence(timeout: 60))
    let comparison = app.staticTexts["Computed futures"]
    for _ in 0..<4 where !comparison.isHittable { app.swipeUp() }
    XCTAssertTrue(comparison.waitForExistence(timeout: 10))
    capture("Computed comparison", app: app)

    selectNativeTab("Citizens", in: app)
    let first = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Riley 1'")).firstMatch
    XCTAssertTrue(first.waitForExistence(timeout: 15))
    first.tap()
    XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 15))
    capture("Citizen financial consequences", app: app)
    app.buttons["Done"].tap()
    selectNativeTab("AI Economist", in: app)
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
    selectNativeTab("Citizens", in: app)
    app.buttons["Citizen filters"].tap()
    XCTAssertTrue(app.staticTexts["Filter citizens"].waitForExistence(timeout: 10))
    app.buttons["Done"].tap()
    app.searchFields.firstMatch.tap()
    app.searchFields.firstMatch.typeText("no_such_citizen\n")
    XCTAssertTrue(app.staticTexts["No matching citizens"].waitForExistence(timeout: 10))
    if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
    selectNativeTab("AI Economist", in: app)
    tap("Increase interest rates by 2 percentage points", app: app)
    XCTAssertTrue(app.staticTexts["Preview intervention"].waitForExistence(timeout: 10))
    app.buttons["Cancel"].tap()
    selectNativeTab("City", in: app)
    XCTAssertTrue(app.staticTexts["DAY 0"].waitForExistence(timeout: 10))
  }
  func testNativeLightAndDarkScreens() throws {
    continueAfterFailure = false
    for appearance in ["Light", "Dark"] {
      let app = XCUIApplication()
      app.launchArguments = ["-econopolis-ui-testing", "-appearance", appearance]
      app.launch()
      XCTAssertTrue(app.staticTexts["simulationDay"].waitForExistence(timeout: 30))
      XCTAssertTrue(app.buttons["Reset camera"].exists)
      capture("Native \(appearance) - City", app: app)
      selectNativeTab("Economy", in: app)
      XCTAssertTrue(app.staticTexts["The pulse of your city"].waitForExistence(timeout: 10))
      capture("Native \(appearance) - Economy", app: app)
      selectNativeTab("Crisis Lab", in: app)
      XCTAssertTrue(app.buttons["START LIVE DEMO"].waitForExistence(timeout: 10))
      capture("Native \(appearance) - Crisis Lab", app: app)
      selectNativeTab("Citizens", in: app)
      XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10))
      capture("Native \(appearance) - Citizens", app: app)
      selectNativeTab("AI Economist", in: app)
      XCTAssertTrue(app.staticTexts["Offline Economist"].waitForExistence(timeout: 10))
      capture("Native \(appearance) - Economist", app: app)
      app.terminate()
    }
  }

  func testLiveStocksConnectionPreviewDoesNotChangeCity() throws {
    let app = open()
    selectNativeTab("Economy", in: app)
    tap("liveStocks", app: app)
    XCTAssertTrue(app.staticTexts["Connect market data"].waitForExistence(timeout: 15))
    capture("Live Stocks - no credentials", app: app)
    tap("addStocksKey", app: app)
    XCTAssertTrue(app.secureTextFields["stocksAPIKey"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["Save key and connect"].isEnabled)
    capture("Live Stocks - secure connection form", app: app)
    tap("Cancel", app: app)
    XCTAssertTrue(app.staticTexts["Connect market data"].waitForExistence(timeout: 10))
    selectNativeTab("City", in: app)
    XCTAssertTrue(app.staticTexts["DAY 0"].waitForExistence(timeout: 10))
  }

}

/// Use the native control's visible bounds when Simulator AX hit-point lookup is unreliable.
@MainActor func tapNativeElement(_ element: XCUIElement, in app: XCUIApplication) {
  let frame = element.frame
  if !frame.isEmpty && frame.midX.isFinite && frame.midY.isFinite {
    app.coordinate(withNormalizedOffset: .zero).withOffset(
      CGVector(dx: frame.midX - app.frame.minX, dy: frame.midY - app.frame.minY)
    ).tap()
  } else {
    element.tap()
  }
}
@MainActor func selectNativeTab(_ title: String, in app: XCUIApplication) {
  let tab = app.tabBars.buttons[title]
  XCTAssertTrue(tab.waitForExistence(timeout: 10))
  tapNativeElement(tab, in: app)
}
