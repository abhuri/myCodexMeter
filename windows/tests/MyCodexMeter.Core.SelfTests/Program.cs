using System.Text.Json;
using MyCodexMeter.Core;

var failures = new List<string>();

void Expect(bool condition, string message)
{
    if (!condition)
    {
        failures.Add(message);
    }
}

try
{
    using var fixture = JsonDocument.Parse(
        """
        {
          "result": {
            "rateLimits": {
              "limitId": "codex",
              "limitName": null,
              "primary": {
                "usedPercent": 25,
                "windowDurationMins": 300,
                "resetsAt": 1730947200
              },
              "secondary": {
                "usedPercent": 70,
                "windowDurationMins": 10080,
                "resetsAt": 1731206400
              }
            },
            "rateLimitsByLimitId": {
              "codex": {
                "limitId": "codex",
                "limitName": null,
                "primary": {
                  "usedPercent": 25,
                  "windowDurationMins": 300,
                  "resetsAt": 1730947200
                },
                "secondary": {
                  "usedPercent": 70,
                  "windowDurationMins": 10080,
                  "resetsAt": 1731206400
                }
              },
              "codex_other": {
                "limitId": "codex_other",
                "limitName": "Codex Other",
                "primary": {
                  "usedPercent": "42",
                  "windowDurationMins": "60",
                  "resetsAt": "1730950800"
                }
              }
            }
          }
        }
        """);

    var snapshot = UsageParser.Parse(
        fixture.RootElement,
        DateTimeOffset.FromUnixTimeSeconds(100));

    Expect(snapshot.Windows.Count == 3, "parse and deduplicate usage windows");
    Expect(snapshot.DefaultLimitId == "codex", "preserve default limit ID");
    Expect(snapshot.HeadlineWindow?.RemainingPercent == 30, "choose most constrained default window");
    Expect(snapshot.GroupedWindows.Count() == 2, "group multiple Codex buckets");

    var tooltip = UsageFormatting.Tooltip(snapshot);
    Expect(tooltip.Length <= 63, "respect Windows NotifyIcon tooltip length");
    Expect(tooltip.Contains("30%", StringComparison.Ordinal), "show exact remaining percent in tooltip");
}
catch (Exception exception)
{
    failures.Add($"parse fixture: {exception.Message}");
}

var epochInBangkok = UsageFormatting.ResetDate(DateTimeOffset.UnixEpoch);
Expect(epochInBangkok.Contains("07:00", StringComparison.Ordinal), "format Asia/Bangkok time");
Expect(epochInBangkok.Contains("2513", StringComparison.Ordinal), "format Thai Buddhist year");
Expect(UsageFormatting.Duration(300) == "5 ชั่วโมง", "format five-hour duration");
Expect(UsageFormatting.Duration(10_080) == "1 สัปดาห์", "format weekly duration");

if (args.Contains("--live", StringComparer.OrdinalIgnoreCase))
{
    try
    {
        var liveSnapshot = await new CodexAppServerClient().FetchRateLimitsAsync();
        var headline = liveSnapshot.HeadlineWindow ??
            throw new InvalidOperationException("live response has no usage window");

        Console.WriteLine(
            $"Live Codex remaining: {UsageFormatting.Percent(headline.RemainingPercent)}");
        Console.WriteLine(
            $"Live reset: {UsageFormatting.ResetDate(headline.ResetsAt)}");
    }
    catch (Exception exception)
    {
        failures.Add($"live check: {exception.Message}");
    }
}

if (failures.Count == 0)
{
    Console.WriteLine("Windows core self-tests passed");
    return 0;
}

foreach (var failure in failures)
{
    Console.Error.WriteLine($"Self-test failed: {failure}");
}

return 1;
