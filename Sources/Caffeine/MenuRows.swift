import AppKit

final class ToggleSwitch: NSView {
    var onToggle: ((Bool) -> Void)?

    private(set) var isOn = false

    private let track = NSView()
    private let knob = NSView()

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 38, height: 22))
        wantsLayer = true

        track.wantsLayer = true
        track.layer?.cornerRadius = 11
        knob.wantsLayer = true
        knob.layer?.cornerRadius = 9
        knob.layer?.backgroundColor = NSColor.white.cgColor
        knob.layer?.shadowColor = NSColor.black.cgColor
        knob.layer?.shadowOpacity = 0.25
        knob.layer?.shadowRadius = 1.5
        knob.layer?.shadowOffset = NSSize(width: 0, height: 1)
        knob.layer?.masksToBounds = false

        addSubview(track)
        addSubview(knob)
        track.frame = bounds

        applyState(animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 38, height: 22)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func setState(_ on: Bool, animated: Bool = true) {
        guard on != isOn else { return }
        isOn = on
        applyState(animated: animated)
    }

    override func mouseDown(with event: NSEvent) {
        setState(!isOn)
        onToggle?(isOn)
    }

    private func applyState(animated: Bool) {
        let fillColor = NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            if isDark {
                return self.isOn ? NSColor.controlAccentColor : NSColor(white: 1, alpha: 0.24)
            }
            return self.isOn ? NSColor.controlAccentColor : NSColor(white: 0, alpha: 0.18)
        }
        track.layer?.backgroundColor = resolve(fillColor)

        let target = NSRect(x: isOn ? bounds.width - 20 : 2, y: 2, width: 18, height: 18)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                knob.animator().frame = target
            }
        } else {
            knob.frame = target
        }
    }

    private func resolve(_ color: NSColor) -> CGColor {
        var resolved = color
        effectiveAppearance.performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.sRGB) ?? color
        }
        return resolved.cgColor
    }
}

final class ToggleRowView: NSView {
    var onToggle: ((Bool) -> Void)?

    private let switchControl = ToggleSwitch()

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 30))

        switchControl.onToggle = { [weak self] on in
            self?.onToggle?(on)
        }
        switchControl.translatesAutoresizingMaskIntoConstraints = false

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
        switchControl.setState(on, animated: false)
    }
}

final class DurationRowView: NSView {
    var onSelect: (() -> Void)?

    var isSelectedRow = false {
        didSet {
            checkLabel.isHidden = !isSelectedRow
        }
    }

    var showsChevron = false {
        didSet {
            chevronLabel.isHidden = !showsChevron
        }
    }

    private let titleLabel: NSTextField
    private let checkLabel = NSTextField(labelWithString: "✓")
    private let chevronLabel = NSTextField(labelWithString: "▾")
    private var hovering = false

    init(title: String) {
        titleLabel = NSTextField(labelWithString: title)
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 24))

        for label in [titleLabel, checkLabel, chevronLabel] {
            label.font = .menuFont(ofSize: 0)
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }

        checkLabel.isHidden = true
        chevronLabel.isHidden = true

        NSLayoutConstraint.activate([
            checkLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            checkLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            chevronLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

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

    private func updateTextColors() {
        titleLabel.textColor = hovering ? .alternateSelectedControlTextColor : .labelColor
        checkLabel.textColor = hovering ? .alternateSelectedControlTextColor : .controlAccentColor
        chevronLabel.textColor = hovering ? .alternateSelectedControlTextColor : .secondaryLabelColor
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
        slider.allowsTickMarkValuesOnly = false
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
        guard let index = closestIndex(for: minutes) else { return }
        slider.doubleValue = Double(index)
        valueLabel.stringValue = DurationFormat.short(minutes: ladder[index])
    }

    private func closestIndex(for minutes: Int) -> Int? {
        var bestIndex: Int?
        var bestDistance = Int.max
        for (index, value) in ladder.enumerated() {
            let distance = abs(value - minutes)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    @objc private func sliderMoved(_ sender: NSSlider) {
        let index = min(max(0, Int(sender.doubleValue.rounded())), ladder.count - 1)
        let minutes = ladder[index]
        valueLabel.stringValue = DurationFormat.short(minutes: minutes)
        onValueChanged?(minutes)
    }
}
