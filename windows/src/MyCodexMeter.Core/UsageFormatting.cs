using System.Globalization;
using MyCodexMeter.Core.Models;

namespace MyCodexMeter.Core;

public static class UsageFormatting
{
    private static readonly CultureInfo ThaiCulture = CultureInfo.GetCultureInfo("th-TH");

    public static TimeZoneInfo BangkokTimeZone { get; } = ResolveBangkokTimeZone();

    public static string Percent(double value) => $"{Math.Round(value):0}%";

    public static string Duration(int minutes)
    {
        if (minutes % 10_080 == 0)
        {
            return $"{minutes / 10_080} สัปดาห์";
        }

        if (minutes % 1_440 == 0)
        {
            return $"{minutes / 1_440} วัน";
        }

        if (minutes % 60 == 0)
        {
            return $"{minutes / 60} ชั่วโมง";
        }

        return $"{minutes} นาที";
    }

    public static string ResetDate(DateTimeOffset date)
    {
        var bangkokDate = TimeZoneInfo.ConvertTime(date, BangkokTimeZone);
        return bangkokDate.ToString("d MMM yyyy เวลา HH:mm น.", ThaiCulture);
    }

    public static string ResetDateShort(DateTimeOffset date)
    {
        var bangkokDate = TimeZoneInfo.ConvertTime(date, BangkokTimeZone);
        return bangkokDate.ToString("d MMM HH:mm น.", ThaiCulture);
    }

    public static string FetchedTime(DateTimeOffset date)
    {
        var bangkokDate = TimeZoneInfo.ConvertTime(date, BangkokTimeZone);
        return bangkokDate.ToString("HH:mm:ss น.", ThaiCulture);
    }

    public static string Tooltip(UsageSnapshot snapshot)
    {
        var headline = snapshot.HeadlineWindow;
        if (headline is null)
        {
            return "myCodex Meter • ยังไม่มีข้อมูล";
        }

        var tooltip = $"Codex เหลือ {Percent(headline.RemainingPercent)} • รีเซ็ต {ResetDateShort(headline.ResetsAt)}";
        return tooltip.Length <= 63 ? tooltip : tooltip[..63];
    }

    private static TimeZoneInfo ResolveBangkokTimeZone()
    {
        foreach (var id in new[] { "Asia/Bangkok", "SE Asia Standard Time" })
        {
            try
            {
                return TimeZoneInfo.FindSystemTimeZoneById(id);
            }
            catch (TimeZoneNotFoundException)
            {
            }
            catch (InvalidTimeZoneException)
            {
            }
        }

        return TimeZoneInfo.CreateCustomTimeZone(
            "Asia/Bangkok",
            TimeSpan.FromHours(7),
            "Asia/Bangkok",
            "Asia/Bangkok");
    }
}
