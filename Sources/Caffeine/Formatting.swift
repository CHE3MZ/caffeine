import Foundation

enum DurationFormat {
    static func short(minutes: Int) -> String {
        if minutes < 60 {
            return minutes == 1 ? "1 min" : "\(minutes) min"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return hours == 1 ? "1 hr" : "\(hours) hrs"
        }
        return "\(hours) hr \(remainder) min"
    }

    static func countdown(secondsRemaining: TimeInterval) -> String {
        let total = max(0, Int(secondsRemaining.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension DurationFormat {
    static func closestLadderIndex(ladder: [Int], minutes: Int) -> Int {
        precondition(!ladder.isEmpty, "ladder must not be empty")
        var bestIndex = 0
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
}
