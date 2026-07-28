using System.Diagnostics;
using System.Text.Json;
using MyCodexMeter.Core.Models;

namespace MyCodexMeter.Core;

public sealed class CodexAppServerClient
{
    private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(20);

    public async Task<UsageSnapshot> FetchRateLimitsAsync(
        CancellationToken cancellationToken = default)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(RequestTimeout);

        using var process = StartAppServer();
        var errorOutputTask = process.StandardError.ReadToEndAsync(timeout.Token);

        try
        {
            await SendAsync(
                process,
                new
                {
                    method = "initialize",
                    id = 0,
                    @params = new
                    {
                        clientInfo = new
                        {
                            name = "mycodex_meter_windows",
                            title = "myCodex Meter",
                            version = "1.0.0",
                        },
                    },
                },
                timeout.Token);

            await ReadResponseAsync(process, 0, timeout.Token);

            await SendAsync(
                process,
                new
                {
                    method = "initialized",
                    @params = new { },
                },
                timeout.Token);

            await SendAsync(
                process,
                new
                {
                    method = "account/rateLimits/read",
                    id = 1,
                },
                timeout.Token);

            using var response = await ReadResponseAsync(process, 1, timeout.Token);
            return UsageParser.Parse(response.RootElement);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            throw new TimeoutException("Codex App Server ใช้เวลาตอบกลับนานเกินไป");
        }
        catch (EndOfStreamException)
        {
            var errorOutput = await errorOutputTask;
            throw new InvalidOperationException(
                string.IsNullOrWhiteSpace(errorOutput)
                    ? "Codex App Server ปิดการเชื่อมต่อก่อนส่งข้อมูล"
                    : errorOutput.Trim());
        }
        finally
        {
            try
            {
                if (!process.HasExited)
                {
                    process.Kill(entireProcessTree: true);
                }

                await process.WaitForExitAsync(CancellationToken.None)
                    .WaitAsync(TimeSpan.FromSeconds(2));
            }
            catch (Exception)
            {
                // The response has already been handled; cleanup must not hide it.
            }

            try
            {
                await errorOutputTask.WaitAsync(TimeSpan.FromSeconds(2));
            }
            catch (Exception)
            {
                // Best-effort drain prevents an unobserved stderr task.
            }
        }
    }

    private static Process StartAppServer()
    {
        var codexPath = CodexExecutableResolver.Resolve();
        var extension = Path.GetExtension(codexPath);
        ProcessStartInfo startInfo;

        if (OperatingSystem.IsWindows() &&
            (extension.Equals(".cmd", StringComparison.OrdinalIgnoreCase) ||
             extension.Equals(".bat", StringComparison.OrdinalIgnoreCase)))
        {
            startInfo = CreateBaseStartInfo(
                Environment.GetEnvironmentVariable("ComSpec") ?? "cmd.exe");
            startInfo.ArgumentList.Add("/d");
            startInfo.ArgumentList.Add("/s");
            startInfo.ArgumentList.Add("/c");
            startInfo.ArgumentList.Add($"\"{codexPath}\" app-server --stdio");
        }
        else
        {
            startInfo = CreateBaseStartInfo(codexPath);
            startInfo.ArgumentList.Add("app-server");
            startInfo.ArgumentList.Add("--stdio");
        }

        var process = new Process { StartInfo = startInfo };
        try
        {
            process.Start();
            return process;
        }
        catch
        {
            process.Dispose();
            throw;
        }
    }

    private static ProcessStartInfo CreateBaseStartInfo(string executable) =>
        new()
        {
            FileName = executable,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };

    private static async Task SendAsync(
        Process process,
        object message,
        CancellationToken cancellationToken)
    {
        var json = JsonSerializer.Serialize(message);
        await process.StandardInput.WriteLineAsync(json.AsMemory(), cancellationToken);
        await process.StandardInput.FlushAsync(cancellationToken);
    }

    private static async Task<JsonDocument> ReadResponseAsync(
        Process process,
        int requestId,
        CancellationToken cancellationToken)
    {
        while (true)
        {
            var line = await process.StandardOutput.ReadLineAsync(cancellationToken);
            if (line is null)
            {
                throw new EndOfStreamException();
            }

            JsonDocument message;
            try
            {
                message = JsonDocument.Parse(line);
            }
            catch (JsonException)
            {
                continue;
            }

            var root = message.RootElement;
            if (!root.TryGetProperty("id", out var idElement) ||
                idElement.ValueKind != JsonValueKind.Number ||
                !idElement.TryGetInt32(out var id) ||
                id != requestId)
            {
                message.Dispose();
                continue;
            }

            if (root.TryGetProperty("error", out var error))
            {
                var errorMessage = error.TryGetProperty("message", out var messageElement)
                    ? messageElement.GetString()
                    : null;
                message.Dispose();
                throw new InvalidOperationException(
                    errorMessage ?? "Codex App Server เกิดข้อผิดพลาด");
            }

            return message;
        }
    }
}
