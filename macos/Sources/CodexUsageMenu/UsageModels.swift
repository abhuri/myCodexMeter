import Foundation

struct UsageWindow: Equatable {
    enum Kind: String {
        case primary
        case secondary
    }

    let limitID: String
    let limitName: String?
    let kind: Kind
    let usedPercent: Double
    let windowDurationMinutes: Int
    let resetsAt: Date

    var remainingPercent: Double {
        min(100, max(0, 100 - usedPercent))
    }
}

struct UsageSnapshot: Equatable {
    let windows: [UsageWindow]
    let defaultLimitID: String?
    let fetchedAt: Date

    var headlineWindow: UsageWindow? {
        let defaultWindows = windows.filter { window in
            guard let defaultLimitID else { return false }
            return window.limitID == defaultLimitID
        }

        return (defaultWindows.isEmpty ? windows : defaultWindows)
            .min { $0.remainingPercent < $1.remainingPercent }
    }

    var groupedWindows: [(limitID: String, name: String?, windows: [UsageWindow])] {
        let grouped = Dictionary(grouping: windows, by: \.limitID)

        return grouped
            .map { limitID, windows in
                (
                    limitID: limitID,
                    name: windows.compactMap(\.limitName).first,
                    windows: windows.sorted {
                        $0.windowDurationMinutes < $1.windowDurationMinutes
                    }
                )
            }
            .sorted { lhs, rhs in
                if lhs.limitID == defaultLimitID { return true }
                if rhs.limitID == defaultLimitID { return false }
                return (lhs.name ?? lhs.limitID)
                    .localizedCaseInsensitiveCompare(rhs.name ?? rhs.limitID) == .orderedAscending
            }
    }
}

enum UsageParser {
    enum ParseError: LocalizedError {
        case missingResult
        case missingRateLimits

        var errorDescription: String? {
            switch self {
            case .missingResult:
                return "Codex ไม่ได้ส่งข้อมูลผลลัพธ์กลับมา"
            case .missingRateLimits:
                return "ไม่พบข้อมูลโควตา Codex ในบัญชีนี้"
            }
        }
    }

    static func parse(response: [String: Any], now: Date = Date()) throws -> UsageSnapshot {
        guard let result = response["result"] as? [String: Any] else {
            throw ParseError.missingResult
        }

        var windows: [UsageWindow] = []
        var defaultLimitID: String?

        if let defaultLimit = result["rateLimits"] as? [String: Any] {
            defaultLimitID = defaultLimit["limitId"] as? String
            windows.append(contentsOf: parseLimit(defaultLimit))
        }

        if let limitsByID = result["rateLimitsByLimitId"] as? [String: Any] {
            for value in limitsByID.values {
                guard let limit = value as? [String: Any] else { continue }
                let parsed = parseLimit(limit)

                for window in parsed where !windows.contains(where: { existing in
                    existing.limitID == window.limitID && existing.kind == window.kind
                }) {
                    windows.append(window)
                }
            }
        }

        guard !windows.isEmpty else {
            throw ParseError.missingRateLimits
        }

        return UsageSnapshot(
            windows: windows,
            defaultLimitID: defaultLimitID,
            fetchedAt: now
        )
    }

    private static func parseLimit(_ limit: [String: Any]) -> [UsageWindow] {
        guard let limitID = limit["limitId"] as? String else { return [] }
        let limitName = limit["limitName"] as? String

        return [UsageWindow.Kind.primary, .secondary].compactMap { kind in
            guard let rawWindow = limit[kind.rawValue] as? [String: Any],
                  let usedPercent = number(rawWindow["usedPercent"]),
                  let duration = integer(rawWindow["windowDurationMins"]),
                  let resetTimestamp = number(rawWindow["resetsAt"])
            else {
                return nil
            }

            return UsageWindow(
                limitID: limitID,
                limitName: limitName,
                kind: kind,
                usedPercent: usedPercent,
                windowDurationMinutes: duration,
                resetsAt: Date(timeIntervalSince1970: resetTimestamp)
            )
        }
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let string = value as? String {
            return Double(string)
        }

        return nil
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = number(value) else { return nil }
        return Int(number)
    }
}

enum UsageFormatting {
    static let bangkokTimeZone = TimeZone(identifier: "Asia/Bangkok")!

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func resetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "th_TH")
        formatter.calendar = Calendar(identifier: .buddhist)
        formatter.timeZone = bangkokTimeZone
        formatter.dateFormat = "d MMM yyyy เวลา HH:mm น."
        return formatter.string(from: date)
    }

    static func fetchedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "th_TH")
        formatter.calendar = Calendar(identifier: .buddhist)
        formatter.timeZone = bangkokTimeZone
        formatter.dateFormat = "HH:mm:ss น."
        return formatter.string(from: date)
    }

    static func duration(minutes: Int) -> String {
        if minutes % 10_080 == 0 {
            return "\(minutes / 10_080) สัปดาห์"
        }

        if minutes % 1_440 == 0 {
            return "\(minutes / 1_440) วัน"
        }

        if minutes % 60 == 0 {
            return "\(minutes / 60) ชั่วโมง"
        }

        return "\(minutes) นาที"
    }

    static func tooltip(for snapshot: UsageSnapshot) -> String {
        guard let headline = snapshot.headlineWindow else {
            return "Codex Usage ยังไม่มีข้อมูล"
        }

        var lines = [
            "Codex คงเหลือ \(percent(headline.remainingPercent))",
        ]

        let defaultWindows = snapshot.windows
            .filter { $0.limitID == (snapshot.defaultLimitID ?? headline.limitID) }
            .sorted { $0.windowDurationMinutes < $1.windowDurationMinutes }

        for window in defaultWindows {
            lines.append(
                "รอบ \(duration(minutes: window.windowDurationMinutes)): "
                    + "คงเหลือ \(percent(window.remainingPercent)) • "
                    + "รีเซ็ต \(resetDate(window.resetsAt))"
            )
        }

        return lines.joined(separator: "\n")
    }
}
