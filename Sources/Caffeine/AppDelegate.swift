import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()

        if ProcessInfo.processInfo.environment["CAFFEINE_AUTOSTART"] == "1" {
            statusBar?.activate()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBar?.shutdown()
    }
}
