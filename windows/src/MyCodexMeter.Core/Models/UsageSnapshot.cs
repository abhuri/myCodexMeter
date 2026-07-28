namespace MyCodexMeter.Core.Models;

public sealed record UsageSnapshot(
    IReadOnlyList<UsageWindow> Windows,
    string? DefaultLimitId,
    DateTimeOffset FetchedAt)
{
    public UsageWindow? HeadlineWindow
    {
        get
        {
            var defaultWindows = DefaultLimitId is null
                ? []
                : Windows.Where(window => window.LimitId == DefaultLimitId).ToArray();

            return (defaultWindows.Length == 0 ? Windows : defaultWindows)
                .MinBy(window => window.RemainingPercent);
        }
    }

    public IEnumerable<IGrouping<string, UsageWindow>> GroupedWindows =>
        Windows
            .GroupBy(window => window.LimitId)
            .OrderByDescending(group => group.Key == DefaultLimitId)
            .ThenBy(group => group.FirstOrDefault()?.LimitName ?? group.Key);
}
