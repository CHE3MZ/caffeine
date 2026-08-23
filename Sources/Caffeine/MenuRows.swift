import AppKit

final class ToggleRowView: NSView {
    var onToggle: ((Bool) -> Void)?

    private let switchControl = NSSwitch()

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 30))

        switchControl.controlSize = .small
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.target = self
        switchControl.action = #selector(switchFlipped(_:))
        switchControl.setAccessibilityLabel("Enable Caffeine")

        let label = NSTextField(labelWithString: "Enable Caffeine")
        label.font = .menuFont(ofSize: 0)
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        addSubview(switchControl)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            switchControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            switchControl.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setSwitchOn(_ on: Bool) {
        switchControl.state = on ? .on : .off
    }

    @objc private func switchFlipped(_ sender: NSSwitch) {
        onToggle?(sender.state == .on)
    }
}

final class DurationRowView: NSView {
    var onSelect: (() -> Void)?

    var isSelectedRow = false {
        didSet {
            checkLabel.isHidden = !isSelectedRow
            setAccessibilityValue(isSelectedRow ? "selected" : nil)
        }
    }

    var showsChevron = false {
        didSet {
            chevronView.isHidden = !showsChevron
            refreshChevron()
        }
    }

    var isExpanded = false {
        didSet {
            if isExpanded != oldValue {
                refreshChevron()
            }
        }
    }

    private let titleLabel: NSTextField
    private let checkLabel = NSTextField(labelWithString: "✓")
    private let chevronView = NSImageView()
    private static let chevronConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
    private var hovering = false

    init(title: String) {
        titleLabel = NSTextField(labelWithString: title)
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 24))

        for label in [titleLabel, checkLabel] {
            label.font = .menuFont(ofSize: 0)
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chevronView)
        refreshChevron()
        chevronView.isHidden = true

        checkLabel.isHidden = true

        NSLayoutConstraint.activate([
            checkLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            checkLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            chevronView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(title)

        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        ))

        updateTextColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard hovering else { return }
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 2), xRadius: 5, yRadius: 5).fill()
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
        updateTextColors()
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
        updateTextColors()
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?()
    }

    override func accessibilityPerformPress() -> Bool {
        onSelect?()
        return true
    }

    private func updateTextColors() {
        titleLabel.textColor = hovering ? .alternateSelectedControlTextColor : .labelColor
        checkLabel.textColor = hovering ? .alternateSelectedControlTextColor : .labelColor
        chevronView.contentTintColor = hovering ? .alternateSelectedControlTextColor : .secondaryLabelColor
    }

    private func refreshChevron() {
        let symbolName = isExpanded ? "chevron.down" : "chevron.right"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(Self.chevronConfiguration)
        chevronView.image = image
    }
}

final class LabelRowView: NSView {
    private let label = NSTextField(labelWithString: "")

    init(title: String = "") {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 22))

        label.font = .menuFont(ofSize: 0)
        label.textColor = .secondaryLabelColor
        label.stringValue = title
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setText(_ text: String) {
        label.stringValue = text
    }
}

final class CustomDurationView: NSView {
    var onValueChanged: ((Int) -> Void)?

    private let ladder: [Int]
    private let slider: NSSlider
    private let valueLabel = NSTextField(labelWithString: "")

    init(ladder: [Int]) {
        self.ladder = ladder
        self.slider = NSSlider(value: 0, minValue: 0, maxValue: 0, target: nil, action: nil)
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 30))

        slider.minValue = 0
        slider.maxValue = Double(max(0, ladder.count - 1))
        slider.isContinuous = true
        slider.controlSize = .small
        slider.target = self
        slider.action = #selector(sliderMoved(_:))
        slider.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        valueLabel.alignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(slider)
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            valueLabel.widthAnchor.constraint(equalToConstant: 76),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -8),
        ])

        setMinutes(ladder.count >= 2 ? ladder[ladder.count / 2] : (ladder.first ?? 1))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setMinutes(_ minutes: Int) {
        let index = DurationFormat.closestLadderIndex(ladder: ladder, minutes: minutes)
        slider.doubleValue = Double(index)
        valueLabel.stringValue = DurationFormat.short(minutes: ladder[index])
    }

    @objc private func sliderMoved(_ sender: NSSlider) {
        let index = min(max(0, Int(sender.doubleValue.rounded())), ladder.count - 1)
        let minutes = ladder[index]
        valueLabel.stringValue = DurationFormat.short(minutes: minutes)
        onValueChanged?(minutes)
    }
}
