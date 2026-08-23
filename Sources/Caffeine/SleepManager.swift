import Foundation
import IOKit.pwr_mgt

final class SleepManager {
    static let shared = SleepManager()

    private var assertionID: IOPMAssertionID?

    private init() {}

    func preventSleep(timeoutSeconds: TimeInterval) -> Bool {
        releaseAssertion()

        var newID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithDescription(
            kIOPMAssertPreventUserIdleDisplaySleep as CFString,
            "Caffeine" as CFString,
            "Caffeine is keeping your Mac awake." as CFString,
            nil as CFString?,
            nil as CFString?,
            timeoutSeconds,
            nil as CFString?,
            &newID
        )

        guard result == kIOReturnSuccess else { return false }
        assertionID = newID
        return true
    }

    func releaseAssertion() {
        guard let id = assertionID else { return }
        IOPMAssertionRelease(id)
        assertionID = nil
    }
}
