using System.Runtime.Versioning;
using Microsoft.Win32;

namespace MyCodexMeter.Windows;

[SupportedOSPlatform("windows")]
internal static class StartupManager
{
    private const string RunKeyPath =
        @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "myCodex Meter";

    public static bool IsEnabled
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath);
            return key?.GetValue(ValueName) is string value &&
                !string.IsNullOrWhiteSpace(value);
        }
    }

    public static void SetEnabled(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(
            RunKeyPath,
            writable: true) ?? throw new InvalidOperationException(
                "เปิด Registry สำหรับ Startup ไม่สำเร็จ");

        if (enabled)
        {
            key.SetValue(
                ValueName,
                $"\"{Application.ExecutablePath}\"",
                RegistryValueKind.String);
        }
        else
        {
            key.DeleteValue(ValueName, throwOnMissingValue: false);
        }
    }
}
