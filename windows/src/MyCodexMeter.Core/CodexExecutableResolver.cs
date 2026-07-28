namespace MyCodexMeter.Core;

public static class CodexExecutableResolver
{
    public static string Resolve()
    {
        var overridePath = Environment.GetEnvironmentVariable("CODEX_CLI_PATH");
        if (!string.IsNullOrWhiteSpace(overridePath))
        {
            if (File.Exists(overridePath))
            {
                return Path.GetFullPath(overridePath);
            }

            throw new FileNotFoundException(
                "CODEX_CLI_PATH ชี้ไปยังไฟล์ที่ไม่มีอยู่",
                overridePath);
        }

        var executableNames = OperatingSystem.IsWindows()
            ? new[] { "codex.exe", "codex.cmd", "codex.bat" }
            : new[] { "codex" };

        var pathValue = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        foreach (var directory in pathValue.Split(Path.PathSeparator))
        {
            if (string.IsNullOrWhiteSpace(directory))
            {
                continue;
            }

            foreach (var executableName in executableNames)
            {
                var candidate = Path.Combine(directory.Trim(), executableName);
                if (File.Exists(candidate))
                {
                    return candidate;
                }
            }
        }

        if (OperatingSystem.IsWindows())
        {
            var localAppData = Environment.GetFolderPath(
                Environment.SpecialFolder.LocalApplicationData);
            var candidates = new[]
            {
                Path.Combine(localAppData, "Programs", "Codex", "codex.exe"),
                Path.Combine(localAppData, "Microsoft", "WinGet", "Links", "codex.exe"),
            };

            var installed = candidates.FirstOrDefault(File.Exists);
            if (installed is not null)
            {
                return installed;
            }
        }

        throw new FileNotFoundException(
            "ไม่พบ Codex CLI กรุณาติดตั้ง Codex หรือตั้งค่า CODEX_CLI_PATH");
    }
}
