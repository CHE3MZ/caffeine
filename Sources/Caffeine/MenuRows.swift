import AppKit

final class ToggleRowView: NSView {
    var onToggle: ((Bool) -> Void)?

    private let switchControl = NSSwitch()

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 30))

        switchControl.target = self
        switchControl.action = #selector(switchChanged(_:))
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
        let newState: NSControl.StateValue = on ? .on : .off
        if switchControl.state != newState {
            switchControl.state = newState
        }
    }

    @objc private func switchChanged(_ sender: NSSwitch) {
        onToggle?(sender.state == .on)
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
