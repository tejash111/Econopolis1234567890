import XCTest

@MainActor
final class MobileNavigationTests: XCTestCase {
  func testCityControlsTabsAndInspectors() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["-econopolis-ui-testing"]
    app.launch()
    XCTAssertTrue(app.staticTexts["simulationDay"].waitForExistence(timeout: 30))
    XCTAssertTrue(app.staticTexts["DAY 0"].exists)
    app.buttons["stepDay"].tap()
    XCTAssertTrue(app.staticTexts["DAY 1"].waitForExistence(timeout: 10))
    app.buttons["playPause"].tap()
    XCTAssertTrue(app.staticTexts["DAY 2"].waitForExistence(timeout: 10))
    app.buttons["playPause"].tap()
    selectNativeTab("Economy", in: app)
    XCTAssertTrue(app.staticTexts["The pulse of your city"].waitForExistence(timeout: 10))
    app.swipeUp()
    selectNativeTab("Citizens", in: app)
    XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10))
    app.searchFields.firstMatch.tap()
    app.searchFields.firstMatch.typeText("Alex\n")
    let firstCitizen = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Alex'")).firstMatch
    XCTAssertTrue(firstCitizen.waitForExistence(timeout: 10))
    firstCitizen.tap()
    XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 10))
    app.buttons["Done"].tap()
    if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
    selectNativeTab("AI Economist", in: app)
    app.swipeUp()
    app.buttons["Show me businesses at risk"].tap()
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'cash-flow measure'")).firstMatch
        .waitForExistence(timeout: 10))
    selectNativeTab("Crisis Lab", in: app)
    let policy = app.buttons["Policy Rate"]
    for _ in 0..<5 where !policy.isHittable { app.swipeUp() }
    XCTAssertTrue(policy.waitForExistence(timeout: 10))
    policy.tap()
    XCTAssertTrue(app.staticTexts["Preview intervention"].waitForExistence(timeout: 10))
    app.buttons["Cancel"].tap()

  }
  func testCityTouchAndFallback() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["-econopolis-ui-testing"]
    app.launch()
    XCTAssertTrue(app.staticTexts["simulationDay"].waitForExistence(timeout: 30))
    let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
    center.press(
      forDuration: 0.1,
      thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.55)))
    app.pinch(withScale: 1.2, velocity: 0.5)
    XCTAssertTrue(app.buttons["stepDay"].exists)
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = "RealityKit iPhone city"
    image.lifetime = .keepAlways
    add(image)
    app.buttons["City options"].tap()
    app.descendants(matching: .any).matching(
      NSPredicate(format: "label BEGINSWITH 'Isometric fallback'")
    ).firstMatch.tap()
    XCTAssertTrue(app.buttons["stepDay"].exists)
    let fallback = XCTAttachment(screenshot: app.screenshot())
    fallback.name = "Isometric fallback"
    fallback.lifetime = .keepAlways
    add(fallback)
    selectNativeTab("Economy", in: app)
    XCUIDevice.shared.orientation = .landscapeLeft
    let landscapeReady = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [landscapeReady], timeout: 10), .completed)
    app.swipeUp()
    XCTAssertTrue(app.tabBars.buttons["Economy"].exists)
    let landscape = XCTAttachment(screenshot: app.screenshot())
    landscape.name = "Landscape economy"
    landscape.lifetime = .keepAlways
    add(landscape)
    XCUIDevice.shared.orientation = .portrait
  }
}
