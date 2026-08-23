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

    private lazy var activeIcon = Self.statusBarIcon(resourceBase: "coffee-enabled", symbolFallback: "cup.and.saucer.fill")
    private lazy var inactiveIcon = Self.statusBarIcon(resourceBase: "coffee-disabled", symbolFallback: "cup.and.saucer")

    private let batteryMonitor = BatteryMonitor()

    private let toggleRow = ToggleRowView()
    private let toggleItem = NSMenuItem()
    private let remainingItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var durationItems: [NSMenuItem] = []
    private let customItem = NSMenuItem(title: "Custom…", action: #selector(selectCustom(_:)), keyEquivalent: "")
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
        statusItem.button?.image = inactiveIcon
        statusItem.button?.toolTip = "Caffeine"

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

        remainingItem.isEnabled = false
        remainingItem.isHidden = true
        menu.addItem(remainingItem)

        menu.addItem(.separator())

        let infiniteItem = NSMenuItem(title: "Infinite", action: #selector(selectInfinite(_:)), keyEquivalent: "")
        infiniteItem.target = self
        infiniteItem.tag = 0
        durationItems.append(infiniteItem)

        for (title, minutes) in Self.presetDurations {
            let item = NSMenuItem(title: title, action: #selector(selectPreset(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            durationItems.append(item)
        }

        customItem.target = self
        durationItems.append(customItem)

        for item in durationItems {
            menu.addItem(item)
        }

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

    // MARK: - Activation

    func activate() {
        cancelPendingCustomRenewal()

        guard SleepManager.shared.preventSleep(timeoutSeconds: currentSeconds()) else {
            deactivate()
            return
        }
        scheduleExpiration(seconds: currentSeconds())
        isActive = true

        refreshIcon()
        refreshMenuState()
    }

    func deactivate() {
        cancelPendingCustomRenewal()
        expirationTimer?.invalidate()
        expirationTimer = nil
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

    private func chooseMode(_ newMode: Mode) {
        mode = newMode
        activate()
    }

    private func customValueChanged(_ minutes: Int) {
        customMinutes = minutes

        guard isActive, mode == .custom else {
            refreshMenuState()
            return
        }

        pendingCustomRenewal?.cancel()
        let renewal = DispatchWorkItem { [weak self] in
            guard let self, self.isActive else { return }
            SleepManager.shared.preventSleep(timeoutSeconds: self.currentSeconds())
            self.scheduleExpiration(seconds: self.currentSeconds())
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

    @objc private func selectInfinite(_ sender: NSMenuItem) {
        chooseMode(.infinite)
    }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        chooseMode(.preset(minutes: sender.tag))
    }

    @objc private func selectCustom(_ sender: NSMenuItem) {
        chooseMode(.custom)
    }

    @objc private func toggleLowBatterySetting(_ sender: NSMenuItem) {
        disableWhenBelow20.toggle()
        if disableWhenBelow20 {
            evaluateLowBatteryCutoff()
        }
        refreshMenuState()
    }

    // MARK: - UI state

    private func refreshIcon() {
        statusItem.button?.image = isActive ? activeIcon : inactiveIcon
        statusItem.button?.toolTip = isActive ? "Caffeine — keeping your Mac awake" : "Caffeine"
    }

    private func refreshMenuState() {
        toggleRow.setSwitchOn(isActive)
        remainingItem.isHidden = !isActive
        remainingItem.title = remainingLine()

        for item in durationItems {
            item.state = isSelected(item) ? .on : .off
        }

        sliderItem.isHidden = mode != .custom
        if mode == .custom {
            sliderRow.setMinutes(customMinutes)
        }

        lowBatteryItem.state = disableWhenBelow20 ? .on : .off
    }

    private func isSelected(_ item: NSMenuItem) -> Bool {
        if item === customItem {
            return mode == .custom
        }
        if item.tag == 0 {
            return mode == .infinite
        }
        if case .preset(let minutes) = mode {
            return minutes == item.tag
        }
        return false
    }

    private func remainingLine() -> String {
        guard let date = expirationDate else {
            return "Keeping Your Mac Awake"
        }
        return "Time Remaining: \(DurationFormat.countdown(secondsRemaining: date.timeIntervalSinceNow))"
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshMenuState()
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard isActive, expirationDate != nil else { return }
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.isActive, let date = self.expirationDate else { return }
            self.remainingItem.title = self.remainingLine()
            if date.timeIntervalSinceNow <= 0 {
                self.deactivate()
            }
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        countdownTimer?.invalidate()
        countdownTimer = nil
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
