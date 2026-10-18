import XCTest

@testable import Caffeine

final class UpdateCheckerTests: XCTestCase {
    func testNewerPatchVersion() {
        XCTAssertTrue(UpdateChecker.isNewer("1.0.1", than: "1.0.0"))
    }

    func testEqualVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("1.0.0", than: "1.0.0"))
    }

    func testOlderVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("0.9.9", than: "1.0.0"))
    }

    func testLeadingVIsIgnored() {
        XCTAssertTrue(UpdateChecker.isNewer("v1.1.0", than: "1.0.0"))
    }

    func testNumericComparisonAcrossDigitCounts() {
        XCTAssertTrue(UpdateChecker.isNewer("1.10.0", than: "1.9.0"))
    }

    func testMissingComponentsDefaultToZero() {
        XCTAssertTrue(UpdateChecker.isNewer("1.1", than: "1.0.9"))
    }

    func testPrereleaseSuffixIgnored() {
        XCTAssertFalse(UpdateChecker.isNewer("1.0.1-beta.1", than: "1.0.1"))
    }

    func testMajorBumpIsNewer() {
        XCTAssertTrue(UpdateChecker.isNewer("2.0.0", than: "1.99.99"))
    }
}
