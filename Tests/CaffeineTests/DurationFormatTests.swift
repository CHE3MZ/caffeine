import XCTest

@testable import Caffeine

final class DurationFormatTests: XCTestCase {
    func testShortOneMinute() {
        XCTAssertEqual(DurationFormat.short(minutes: 1), "1 min")
    }

    func testShortFifteenMinutes() {
        XCTAssertEqual(DurationFormat.short(minutes: 15), "15 min")
    }

    func testShortFiftyNineMinutes() {
        XCTAssertEqual(DurationFormat.short(minutes: 59), "59 min")
    }

    func testShortOneHour() {
        XCTAssertEqual(DurationFormat.short(minutes: 60), "1 hr")
    }

    func testShortOneHourOneMinute() {
        XCTAssertEqual(DurationFormat.short(minutes: 61), "1 hr 1 min")
    }

    func testShortNinetyMinutes() {
        XCTAssertEqual(DurationFormat.short(minutes: 90), "1 hr 30 min")
    }

    func testShortTwoHours() {
        XCTAssertEqual(DurationFormat.short(minutes: 120), "2 hrs")
    }

    func testShortTwentyFourHours() {
        XCTAssertEqual(DurationFormat.short(minutes: 1440), "24 hrs")
    }

    func testCountdownJustOverAnHour() {
        XCTAssertEqual(DurationFormat.countdown(secondsRemaining: 3661), "1:01:01")
    }

    func testCountdownJustUnderAnHour() {
        XCTAssertEqual(DurationFormat.countdown(secondsRemaining: 3599), "59:59")
    }

    func testCountdownSixtyOneSeconds() {
        XCTAssertEqual(DurationFormat.countdown(secondsRemaining: 61), "01:01")
    }

    func testCountdownFiveSeconds() {
        XCTAssertEqual(DurationFormat.countdown(secondsRemaining: 5), "00:05")
    }

    func testCountdownNegativeClampsToZero() {
        XCTAssertEqual(DurationFormat.countdown(secondsRemaining: -10), "00:00")
    }

    func testClosestLadderIndexExactHit() {
        XCTAssertEqual(DurationFormat.closestLadderIndex(ladder: [1, 2, 3], minutes: 2), 1)
    }

    func testClosestLadderIndexNearest() {
        XCTAssertEqual(DurationFormat.closestLadderIndex(ladder: [10, 20, 30], minutes: 24), 1)
    }

    func testClosestLadderIndexTieKeepsEarlier() {
        XCTAssertEqual(DurationFormat.closestLadderIndex(ladder: [3, 5], minutes: 4), 0)
    }

    func testClosestLadderIndexBelowFirst() {
        XCTAssertEqual(DurationFormat.closestLadderIndex(ladder: [10, 20], minutes: 0), 0)
    }

    func testClosestLadderIndexAboveLast() {
        XCTAssertEqual(DurationFormat.closestLadderIndex(ladder: [10, 20], minutes: 9999), 1)
    }

    func testCustomLadderStrictlyIncreasingFromOneToOneDay() {
        let ladder = StatusBarController.customLadder
        XCTAssertGreaterThan(ladder.count, 0)
        XCTAssertEqual(ladder.first, 1)
        XCTAssertEqual(ladder.last, 1440)
        for (index, value) in ladder.enumerated() where index > 0 {
            XCTAssertGreaterThan(value, ladder[index - 1])
        }
    }

    func testPresetDurationsStrictlyAscending() {
        var previous = Int.min
        for (_, minutes) in StatusBarController.presetDurations {
            XCTAssertGreaterThan(minutes, previous)
            previous = minutes
        }
    }
}
