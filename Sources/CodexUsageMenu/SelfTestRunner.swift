import AppKit
import Foundation

enum SelfTestRunner {
    static func run() -> Bool {
        var failures: [String] = []

        do {
            let response: [String: Any] = [
                "result": [
                    "rateLimits": [
                        "limitId": "codex",
                        "limitName": NSNull(),
                        "primary": [
                            "usedPercent": 25,
                            "windowDurationMins": 300,
                            "resetsAt": 1_730_947_200,
                        ],
                        "secondary": [
                            "usedPercent": 70,
                            "windowDurationMins": 10_080,
                            "resetsAt": 1_731_206_400,
                        ],
                    ],
                ],
            ]

            let snapshot = try UsageParser.parse(
                response: response,
                now: Date(timeIntervalSince1970: 100)
            )

            expect(snapshot.windows.count == 2, "parse primary and secondary", into: &failures)
            expect(snapshot.headlineWindow?.remainingPercent == 30, "choose most constrained window", into: &failures)
            expect(snapshot.defaultLimitID == "codex", "preserve default limit ID", into: &failures)
        } catch {
            failures.append("parse fixture: \(error.localizedDescription)")
        }

        do {
            let limit: [String: Any] = [
                "limitId": "codex",
                "primary": [
                    "usedPercent": 1,
                    "windowDurationMins": 10_080,
                    "resetsAt": 1_785_814_584,
                ],
            ]

            let response: [String: Any] = [
                "result": [
                    "rateLimits": limit,
                    "rateLimitsByLimitId": [
                        "codex": limit,
                    ],
                ],
            ]

            let snapshot = try UsageParser.parse(response: response)
            expect(snapshot.windows.count == 1, "deduplicate compatibility view", into: &failures)
            expect(snapshot.headlineWindow?.remainingPercent == 99, "calculate remaining percent", into: &failures)
        } catch {
            failures.append("deduplication fixture: \(error.localizedDescription)")
        }

        let epochInBangkok = UsageFormatting.resetDate(Date(timeIntervalSince1970: 0))
        expect(epochInBangkok.contains("07:00"), "format Asia/Bangkok time", into: &failures)
        expect(epochInBangkok.contains("2513"), "format Thai Buddhist year", into: &failures)
        expect(UsageFormatting.duration(minutes: 300) == "5 ชั่วโมง", "format five-hour duration", into: &failures)
        expect(UsageFormatting.duration(minutes: 10_080) == "1 สัปดาห์", "format weekly duration", into: &failures)

        let icon = CodexMenuIcon.make()
        expect(icon.isTemplate, "render Codex icon as a macOS template image", into: &failures)
        expect(icon.size == NSSize(width: 18, height: 18), "render Codex icon at menu-bar size", into: &failures)

        if failures.isEmpty {
            print("Self-test passed")
            return true
        }

        for failure in failures {
            fputs("Self-test failed: \(failure)\n", stderr)
        }
        return false
    }

    static func checkLiveUsage() -> Bool {
        let client = CodexAppServerClient()
        let semaphore = DispatchSemaphore(value: 0)
        var succeeded = false

        client.fetchRateLimits { result in
            switch result {
            case let .success(snapshot):
                if let headline = snapshot.headlineWindow {
                    print("Codex remaining: \(UsageFormatting.percent(headline.remainingPercent))")
                    print("Reset: \(UsageFormatting.resetDate(headline.resetsAt))")
                    print("Windows: \(snapshot.windows.count)")
                    succeeded = true
                } else {
                    fputs("Live check failed: no usage window\n", stderr)
                }
            case let .failure(error):
                fputs("Live check failed: \(error.localizedDescription)\n", stderr)
            }

            semaphore.signal()
        }

        let result = semaphore.wait(timeout: .now() + 20)
        client.stop()

        if result == .timedOut {
            fputs("Live check failed: timed out\n", stderr)
            return false
        }

        return succeeded
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String,
        into failures: inout [String]
    ) {
        if !condition() {
            failures.append(message)
        }
    }
}
