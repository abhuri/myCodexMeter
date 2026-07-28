namespace MyCodexMeter.Core.Models;

public enum UsageWindowKind
{
    Primary,
    Secondary,
}

public sealed record UsageWindow(
    string LimitId,
    string? LimitName,
    UsageWindowKind Kind,
    double UsedPercent,
    int WindowDurationMinutes,
    DateTimeOffset ResetsAt)
{
    public double RemainingPercent => Math.Clamp(100 - UsedPercent, 0, 100);
}
