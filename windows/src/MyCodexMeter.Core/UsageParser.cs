using System.Text.Json;
using MyCodexMeter.Core.Models;

namespace MyCodexMeter.Core;

public static class UsageParser
{
    public static UsageSnapshot Parse(JsonElement response, DateTimeOffset? now = null)
    {
        if (!response.TryGetProperty("result", out var result) ||
            result.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidDataException("Codex ไม่ได้ส่งข้อมูลผลลัพธ์กลับมา");
        }

        var windows = new Dictionary<(string LimitId, UsageWindowKind Kind), UsageWindow>();
        string? defaultLimitId = null;

        if (result.TryGetProperty("rateLimits", out var defaultLimit) &&
            defaultLimit.ValueKind == JsonValueKind.Object)
        {
            defaultLimitId = ReadOptionalString(defaultLimit, "limitId");
            AddLimit(defaultLimit, windows);
        }

        if (result.TryGetProperty("rateLimitsByLimitId", out var limitsById) &&
            limitsById.ValueKind == JsonValueKind.Object)
        {
            foreach (var property in limitsById.EnumerateObject())
            {
                if (property.Value.ValueKind == JsonValueKind.Object)
                {
                    AddLimit(property.Value, windows);
                }
            }
        }

        if (windows.Count == 0)
        {
            throw new InvalidDataException("ไม่พบข้อมูลโควตา Codex ในบัญชีนี้");
        }

        return new UsageSnapshot(
            windows.Values
                .OrderBy(window => window.LimitId)
                .ThenBy(window => window.WindowDurationMinutes)
                .ToArray(),
            defaultLimitId,
            now ?? DateTimeOffset.UtcNow);
    }

    private static void AddLimit(
        JsonElement limit,
        IDictionary<(string LimitId, UsageWindowKind Kind), UsageWindow> windows)
    {
        var limitId = ReadOptionalString(limit, "limitId");
        if (string.IsNullOrWhiteSpace(limitId))
        {
            return;
        }

        var limitName = ReadOptionalString(limit, "limitName");
        AddWindow(limit, "primary", UsageWindowKind.Primary, limitId, limitName, windows);
        AddWindow(limit, "secondary", UsageWindowKind.Secondary, limitId, limitName, windows);
    }

    private static void AddWindow(
        JsonElement limit,
        string propertyName,
        UsageWindowKind kind,
        string limitId,
        string? limitName,
        IDictionary<(string LimitId, UsageWindowKind Kind), UsageWindow> windows)
    {
        if (!limit.TryGetProperty(propertyName, out var rawWindow) ||
            rawWindow.ValueKind != JsonValueKind.Object ||
            !TryReadDouble(rawWindow, "usedPercent", out var usedPercent) ||
            !TryReadInt32(rawWindow, "windowDurationMins", out var durationMinutes) ||
            !TryReadInt64(rawWindow, "resetsAt", out var resetsAt))
        {
            return;
        }

        windows[(limitId, kind)] = new UsageWindow(
            limitId,
            limitName,
            kind,
            usedPercent,
            durationMinutes,
            DateTimeOffset.FromUnixTimeSeconds(resetsAt));
    }

    private static string? ReadOptionalString(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var property) ||
            property.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
        {
            return null;
        }

        return property.ValueKind == JsonValueKind.String
            ? property.GetString()
            : null;
    }

    private static bool TryReadDouble(
        JsonElement element,
        string propertyName,
        out double value)
    {
        value = default;
        if (!element.TryGetProperty(propertyName, out var property))
        {
            return false;
        }

        return property.ValueKind switch
        {
            JsonValueKind.Number => property.TryGetDouble(out value),
            JsonValueKind.String => double.TryParse(
                property.GetString(),
                System.Globalization.CultureInfo.InvariantCulture,
                out value),
            _ => false,
        };
    }

    private static bool TryReadInt32(
        JsonElement element,
        string propertyName,
        out int value)
    {
        value = default;
        if (!element.TryGetProperty(propertyName, out var property))
        {
            return false;
        }

        return property.ValueKind switch
        {
            JsonValueKind.Number => property.TryGetInt32(out value),
            JsonValueKind.String => int.TryParse(
                property.GetString(),
                System.Globalization.CultureInfo.InvariantCulture,
                out value),
            _ => false,
        };
    }

    private static bool TryReadInt64(
        JsonElement element,
        string propertyName,
        out long value)
    {
        value = default;
        if (!element.TryGetProperty(propertyName, out var property))
        {
            return false;
        }

        return property.ValueKind switch
        {
            JsonValueKind.Number => property.TryGetInt64(out value),
            JsonValueKind.String => long.TryParse(
                property.GetString(),
                System.Globalization.CultureInfo.InvariantCulture,
                out value),
            _ => false,
        };
    }
}
