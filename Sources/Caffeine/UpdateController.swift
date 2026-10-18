import AppKit

final class UpdateController: NSObject {
    enum State {
        case idle
        case checking
        case downloading
    }

    let menuItem = NSMenuItem(title: "Check for Updates…", action: nil, keyEquivalent: "")

    private var state: State = .idle

    override init() {
        super.init()
        menuItem.target = self
        menuItem.action = #selector(checkForUpdates(_:))
        if isAutomatic {
            checkForUpdates(menuItem)
        }
    }

    @objc private func checkForUpdates(_ sender: NSMenuItem) {
        guard state == .idle else { return }
        setState(.checking)

        Task { @MainActor in
            do {
                let release = try await UpdateChecker.availableRelease()
                setState(.idle)
                guard let release else {
                    if !isAutomatic {
                        presentUpToDateAlert()
                    }
                    return
                }
                if isAutomatic {
                    install(release)
                } else {
                    promptForInstall(release)
                }
            } catch {
                setState(.idle)
                report(error)
            }
        }
    }

    private func promptForInstall(_ release: UpdateRelease) {
        let alert = NSAlert()
        alert.messageText = "Caffeine \(release.version) is available"
        alert.informativeText =
            "You're running \(UpdateChecker.currentVersion). The update will download, install, and relaunch Caffeine."
        alert.addButton(withTitle: "Install and Relaunch")
        alert.addButton(withTitle: "Later")

        guard runAlert(alert) == .alertFirstButtonReturn else { return }
        install(release)
    }

    private func install(_ release: UpdateRelease) {
        setState(.downloading)

        Task { @MainActor in
            do {
                let update = try await UpdateChecker.download(release)
                try UpdateInstaller.installAndRelaunch(replacing: Bundle.main.bundleURL, update: update)
                NSApp.terminate(nil)
            } catch {
                setState(.idle)
                report(error)
            }
        }
    }

    private func setState(_ newState: State) {
        state = newState

        switch newState {
        case .idle:
            menuItem.title = "Check for Updates…"
            menuItem.isEnabled = true
        case .checking:
            menuItem.title = "Checking for Updates…"
            menuItem.isEnabled = false
        case .downloading:
            menuItem.title = "Downloading Update…"
            menuItem.isEnabled = false
        }
    }

    private func presentUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "Caffeine \(UpdateChecker.currentVersion) is the latest version."
        alert.addButton(withTitle: "OK")
        runAlert(alert)
    }

    private func report(_ error: Error) {
        if isAutomatic {
            FileHandle.standardError.write(Data("update failed: \(error.localizedDescription)\n".utf8))
            return
        }

        let alert = NSAlert()
        alert.messageText = "Update check failed"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        runAlert(alert)
    }

    private func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        return alert.runModal()
    }

    private var isAutomatic: Bool {
        ProcessInfo.processInfo.environment["CAFFEINE_AUTOUPDATE"] == "1"
    }
}
