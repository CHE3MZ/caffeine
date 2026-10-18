import Foundation
import IOKit.ps

struct BatteryStatus {
    let hasBattery: Bool
    let onACPower: Bool
    let percent: Double

    static func current() -> BatteryStatus? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        var hasBattery = false
        var onACPower = false
        var percent = 100.0

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                    as NSDictionary?
            else { continue }

            if let type = description[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType {
                hasBattery = true
                if let state = description[kIOPSPowerSourceStateKey] as? String, state == kIOPSACPowerValue {
                    onACPower = true
                }
                let current = description[kIOPSCurrentCapacityKey] as? Int ?? 100
                let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 0
                if maximum > 0 {
                    percent = Double(current) / Double(maximum) * 100
                }
            } else if let state = description[kIOPSPowerSourceStateKey] as? String, state == kIOPSACPowerValue {
                onACPower = true
            }
        }

        return BatteryStatus(hasBattery: hasBattery, onACPower: onACPower, percent: percent)
    }
}

final class BatteryMonitor {
    var onChange: (() -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var monitorContext: UnsafeMutableRawPointer?

    func start() {
        guard runLoopSource == nil, monitorContext == nil else { return }

        let context = Unmanaged.passRetained(self).toOpaque()
        let callback: @convention(c) (UnsafeMutableRawPointer?) -> Void = { rawContext in
            guard let rawContext else { return }
            Unmanaged<BatteryMonitor>.fromOpaque(rawContext).takeUnretainedValue().onChange?()
        }

        guard let created = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else {
            Unmanaged<BatteryMonitor>.fromOpaque(context).release()
            return
        }
        monitorContext = context
        CFRunLoopAddSource(CFRunLoopGetMain(), created, .commonModes)
        runLoopSource = created
    }

    func stop() {
        guard let source = runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        if let context = monitorContext {
            Unmanaged<BatteryMonitor>.fromOpaque(context).release()
            monitorContext = nil
        }
        runLoopSource = nil
    }
}
