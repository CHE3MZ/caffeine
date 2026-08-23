import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    enum Mode: Equatable {
        case infinite
        case preset(minutes: Int)
        case custom
    }

    private static let presetDurations: [(title: String, minutes: Int)] = [
        ("15 Minutes", 15),
        ("30 Minutes", 30),
        ("45 Minutes", 45),
        ("1 Hour", 60),
        ("4 Hours", 240),
        ("8 Hours", 480),
    ]

    private static let customLadder = [1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 360, 480, 720, 1440]
    private static let lowBatteryThresholdPercent = 20.0

    private(set) var isActive = false
    private(set) var mode: Mode = .infinite
    private(set) var customMinutes = 60
    private(set) var disableWhenBelow20 = true

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    private var expirationDate: Date?
    private var expirationTimer: Timer?
    private var countdownTimer: Timer?
    private var pendingCustomRenewal: DispatchWorkItem?
    private var customExpanded = false

    private lazy var activeIcon = Self.statusBarIcon(resourceBase: "coffee-enabled", symbolFallback: "cup.and.saucer.fill")
    private lazy var inactiveIcon = Self.statusBarIcon(resourceBase: "coffee-disabled", symbolFallback: "cup.and.saucer")

    private let batteryMonitor = BatteryMonitor()

    private let toggleRow = ToggleRowView()
    private let toggleItem = NSMenuItem()
    private let remainingRow = LabelRowView()
    private let remainingItem = NSMenuItem()
    private var durationEntries: [(mode: Mode, row: DurationRowView)] = []
    private let sliderRow = CustomDurationView(ladder: StatusBarController.customLadder)
    private let sliderItem = NSMenuItem()
    private let lowBatteryItem = NSMenuItem(
        title: "Turn Off Below 20% Battery",
        action: #selector(toggleLowBatterySetting(_:)),
        keyEquivalent: ""
    )

    override init() {
        super.init()
        buildMenu()

        menu.delegate = self
        menu.autoenablesItems = false

        statusItem.menu = menu
        refreshIcon()

        batteryMonitor.onChange = { [weak self] in self?.evaluateLowBatteryCutoff() }
        batteryMonitor.start()
    }

    func shutdown() {
        deactivate()
        batteryMonitor.stop()
    }

    // MARK: - Menu construction

    private func buildMenu() {
        toggleItem.view = toggleRow
        toggleRow.onToggle = { [weak self] turnOn in
            turnOn ? self?.activate() : self?.deactivate()
        }
        menu.addItem(toggleItem)

        remainingItem.view = remainingRow
        remainingItem.isEnabled = false
        remainingItem.isHidden = true
        menu.addItem(remainingItem)

        menu.addItem(.separator())

        addDurationRow(title: "Infinite", mode: .infinite)
        for (title, minutes) in Self.presetDurations {
            addDurationRow(title: title, mode: .preset(minutes: minutes))
        }
        addDurationRow(title: "Custom…", mode: .custom)

        sliderItem.view = sliderRow
        sliderItem.isHidden = true
        sliderRow.onValueChanged = { [weak self] minutes in
            self?.customValueChanged(minutes)
        }
        menu.addItem(sliderItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let settingsSubmenu = NSMenu()
        settingsSubmenu.autoenablesItems = false
        lowBatteryItem.target = self
        settingsSubmenu.addItem(lowBatteryItem)
        settingsItem.submenu = settingsSubmenu
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Caffeine", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    private func addDurationRow(title: String, mode newMode: Mode) {
        let row = DurationRowView(title: title)
        row.onSelect = { [weak self] in
            self?.durationSelected(newMode)
        }
        let item = NSMenuItem()
        item.view = row
        item.isEnabled = false
        durationEntries.append((newMode, row))
        menu.addItem(item)
    }

    // MARK: - Activation

    func activate() {
        cancelPendingCustomRenewal()

        let seconds = currentSeconds()
        guard SleepManager.shared.preventSleep(timeoutSeconds: seconds) else {
            deactivate()
            return
        }
        scheduleExpiration(seconds: seconds)
        isActive = true
        startCountdownIfNeeded()

        refreshIcon()
        refreshMenuState()
    }

    func deactivate() {
        cancelPendingCustomRenewal()
        expirationTimer?.invalidate()
        expirationTimer = nil
        stopCountdown()
        expirationDate = nil
        SleepManager.shared.releaseAssertion()
        isActive = false

        refreshIcon()
        refreshMenuState()
    }

    private func currentSeconds() -> TimeInterval {
        switch mode {
        case .infinite:
            return 0
        case .preset(let minutes):
            return TimeInterval(minutes) * 60
        case .custom:
            return TimeInterval(customMinutes) * 60
        }
    }

    private func scheduleExpiration(seconds: TimeInterval) {
        expirationTimer?.invalidate()
        expirationTimer = nil

        if seconds > 0 {
            expirationDate = Date().addingTimeInterval(seconds)
            let timer = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in
                self?.caffeinationExpired()
            }
            timer.tolerance = 5
            RunLoop.main.add(timer, forMode: .common)
            expirationTimer = timer
        } else {
            expirationDate = nil
        }
    }

    private func caffeinationExpired() {
        expirationTimer = nil
        deactivate()
    }

    // MARK: - Live countdown

    private func startCountdownIfNeeded() {
        guard isActive, expirationDate != nil, countdownTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickCountdown()
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
        refreshRemainingLabel()
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func tickCountdown() {
        guard let date = expirationDate else {
            stopCountdown()
            return
        }
        refreshRemainingLabel()
        if date.timeIntervalSinceNow <= 0 {
            deactivate()
        }
    }

    private func refreshRemainingLabel() {
        guard let date = expirationDate else { return }
        remainingRow.setText("Time Remaining: \(DurationFormat.countdown(secondsRemaining: date.timeIntervalSinceNow))")
    }

    // MARK: - Selections

    private func durationSelected(_ newMode: Mode) {
        if case .custom = newMode {
            mode = .custom
            customExpanded = true
        } else {
            mode = newMode
            customExpanded = false
        }

        if isActive {
            applyDurationToActiveSession()
        }
        refreshMenuState()
    }

    private func applyDurationToActiveSession() {
        cancelPendingCustomRenewal()
        guard SleepManager.shared.preventSleep(timeoutSeconds: currentSeconds()) else {
            deactivate()
            return
        }
        scheduleExpiration(seconds: currentSeconds())
    }

    private func customValueChanged(_ minutes: Int) {
        customMinutes = minutes

        guard isActive else {
            refreshMenuState()
            return
        }

        pendingCustomRenewal?.cancel()
        let renewal = DispatchWorkItem { [weak self] in
            guard let self, self.isActive, Self.isCustom(self.mode) else { return }
            self.applyDurationToActiveSession()
            self.refreshMenuState()
        }
        pendingCustomRenewal = renewal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: renewal)

        refreshMenuState()
    }

    private func cancelPendingCustomRenewal() {
        pendingCustomRenewal?.cancel()
        pendingCustomRenewal = nil
    }

    private func evaluateLowBatteryCutoff() {
        guard isActive, disableWhenBelow20,
              let status = BatteryStatus.current(),
              status.hasBattery,
              !status.onACPower,
              status.percent < Self.lowBatteryThresholdPercent
        else { return }

        deactivate()
    }

    // MARK: - Actions

    @objc private func toggleLowBatterySetting(_ sender: NSMenuItem) {
        disableWhenBelow20.toggle()
        if disableWhenBelow20 {
            evaluateLowBatteryCutoff()
        }
        refreshMenuState()
    }

    private static func isCustom(_ candidate: Mode) -> Bool {
        if case .custom = candidate { return true }
        return false
    }

    // MARK: - UI state

    private func refreshIcon() {
        statusItem.button?.image = isActive ? activeIcon : inactiveIcon
        statusItem.button?.toolTip = isActive ? "Caffeine — keeping your Mac awake" : "Caffeine"
    }

    private func refreshMenuState() {
        toggleRow.setSwitchOn(isActive)

        if expirationDate != nil {
            remainingItem.isHidden = false
            refreshRemainingLabel()
        } else {
            remainingItem.isHidden = true
        }
        for entry in durationEntries {
            entry.row.isSelectedRow = entry.mode == mode
            entry.row.showsChevron = Self.isCustom(entry.mode)
            entry.row.isExpanded = Self.isCustom(entry.mode) && customExpanded
        }

        if Self.isCustom(mode), customExpanded {
            sliderItem.isHidden = false
            sliderRow.setMinutes(customMinutes)
        } else {
            sliderItem.isHidden = true
        }

        lowBatteryItem.state = disableWhenBelow20 ? .on : .off
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshMenuState()
    }

    func menuWillOpen(_ menu: NSMenu) {
        startCountdownIfNeeded()
    }

    func menuDidClose(_ menu: NSMenu) {
        stopCountdown()
    }

    // MARK: - Icons

    private static func statusBarIcon(resourceBase: String, symbolFallback: String) -> NSImage {
        let composite = NSImage()
        var addedRepresentation = false

        for (suffix, scale) in [("", CGFloat(1)), ("@2x", CGFloat(2)), ("@3x", CGFloat(3))] {
            guard let url = Bundle.main.url(forResource: resourceBase + suffix, withExtension: "png"),
                  let representation = NSImageRep(contentsOf: url)
            else { continue }
            representation.size = NSSize(width: CGFloat(representation.pixelsWide) / scale,
                                         height: CGFloat(representation.pixelsHigh) / scale)
            composite.addRepresentation(representation)
            addedRepresentation = true
        }

        if addedRepresentation {
            composite.isTemplate = true
            return composite
        }

        let fallback = NSImage(systemSymbolName: symbolFallback, accessibilityDescription: "Caffeine") ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }
}
