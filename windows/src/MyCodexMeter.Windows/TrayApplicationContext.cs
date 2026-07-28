using System.Diagnostics;
using System.Runtime.Versioning;
using MyCodexMeter.Core;
using MyCodexMeter.Core.Models;

namespace MyCodexMeter.Windows;

[SupportedOSPlatform("windows")]
internal sealed class TrayApplicationContext : ApplicationContext
{
    private readonly CodexAppServerClient _client = new();
    private readonly NotifyIcon _notifyIcon;
    private readonly ContextMenuStrip _menu;
    private readonly ToolStripMenuItem _summaryItem;
    private readonly ToolStripMenuItem _detailsItem;
    private readonly ToolStripMenuItem _refreshItem;
    private readonly ToolStripMenuItem _launchAtStartupItem;
    private readonly System.Windows.Forms.Timer _refreshTimer;
    private readonly CancellationTokenSource _lifetime = new();
    private Icon? _currentIcon;
    private bool _isRefreshing;

    public TrayApplicationContext()
    {
        _summaryItem = new ToolStripMenuItem("กำลังอ่านข้อมูลจาก Codex…")
        {
            Enabled = false,
        };

        _detailsItem = new ToolStripMenuItem("รายละเอียดโควตา")
        {
            Enabled = false,
        };

        _refreshItem = new ToolStripMenuItem(
            "รีเฟรชตอนนี้",
            image: null,
            async (_, _) => await RefreshUsageAsync());

        _launchAtStartupItem = new ToolStripMenuItem(
            "เปิดพร้อม Windows",
            image: null,
            (_, _) => ToggleLaunchAtStartup())
        {
            Checked = StartupManager.IsEnabled,
            CheckOnClick = false,
        };

        _menu = new ContextMenuStrip();
        _menu.Items.Add(new ToolStripMenuItem("myCodex Meter") { Enabled = false });
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add(_summaryItem);
        _menu.Items.Add(_detailsItem);
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add(_refreshItem);
        _menu.Items.Add(new ToolStripMenuItem(
            "เปิด Usage Dashboard",
            image: null,
            (_, _) => OpenUsageDashboard()));
        _menu.Items.Add(_launchAtStartupItem);
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add(new ToolStripMenuItem(
            "ออกจาก myCodex Meter",
            image: null,
            (_, _) => Exit()));

        _currentIcon = DynamicTrayIconRenderer.Create(100);
        _notifyIcon = new NotifyIcon
        {
            Icon = _currentIcon,
            Text = "myCodex Meter • กำลังอ่าน Codex Usage",
            ContextMenuStrip = _menu,
            Visible = true,
        };

        _notifyIcon.MouseClick += (_, eventArgs) =>
        {
            if (eventArgs.Button == MouseButtons.Left)
            {
                _menu.Show(Cursor.Position);
            }
        };

        _refreshTimer = new System.Windows.Forms.Timer
        {
            Interval = 60_000,
            Enabled = true,
        };
        _refreshTimer.Tick += async (_, _) => await RefreshUsageAsync();

        _ = RefreshUsageAsync();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _lifetime.Cancel();
            _refreshTimer.Dispose();
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
            _currentIcon?.Dispose();
            _menu.Dispose();
            _lifetime.Dispose();
        }

        base.Dispose(disposing);
    }

    private async Task RefreshUsageAsync()
    {
        if (_isRefreshing)
        {
            return;
        }

        _isRefreshing = true;
        _refreshItem.Enabled = false;
        _refreshItem.Text = "กำลังรีเฟรช…";

        try
        {
            var snapshot = await _client.FetchRateLimitsAsync(_lifetime.Token);
            UpdateFromSnapshot(snapshot);
        }
        catch (OperationCanceledException) when (_lifetime.IsCancellationRequested)
        {
        }
        catch (Exception exception)
        {
            UpdateForError(exception);
        }
        finally
        {
            _isRefreshing = false;
            _refreshItem.Enabled = true;
            _refreshItem.Text = "รีเฟรชตอนนี้";
        }
    }

    private void UpdateFromSnapshot(UsageSnapshot snapshot)
    {
        var headline = snapshot.HeadlineWindow;
        if (headline is null)
        {
            return;
        }

        SetIcon(headline.RemainingPercent);
        _notifyIcon.Text = UsageFormatting.Tooltip(snapshot);
        _summaryItem.Text =
            $"Codex คงเหลือ {UsageFormatting.Percent(headline.RemainingPercent)}";
        _detailsItem.Enabled = true;
        _detailsItem.DropDownItems.Clear();

        foreach (var group in snapshot.GroupedWindows)
        {
            var groupName = group.FirstOrDefault()?.LimitName ??
                (group.Key == "codex" ? "Codex" : group.Key);

            var groupItem = new ToolStripMenuItem(groupName) { Enabled = false };
            _detailsItem.DropDownItems.Add(groupItem);

            foreach (var window in group.OrderBy(item => item.WindowDurationMinutes))
            {
                _detailsItem.DropDownItems.Add(
                    new ToolStripMenuItem(
                        $"รอบ {UsageFormatting.Duration(window.WindowDurationMinutes)} — " +
                        $"เหลือ {UsageFormatting.Percent(window.RemainingPercent)}")
                    {
                        Enabled = false,
                    });
                _detailsItem.DropDownItems.Add(
                    new ToolStripMenuItem(
                        $"รีเซ็ต {UsageFormatting.ResetDate(window.ResetsAt)}")
                    {
                        Enabled = false,
                    });
            }
        }

        _detailsItem.DropDownItems.Add(new ToolStripSeparator());
        _detailsItem.DropDownItems.Add(
            new ToolStripMenuItem(
                $"อัปเดตล่าสุด {UsageFormatting.FetchedTime(snapshot.FetchedAt)}")
            {
                Enabled = false,
            });
    }

    private void UpdateForError(Exception exception)
    {
        SetIcon(null);
        var message = string.IsNullOrWhiteSpace(exception.Message)
            ? "อ่าน Codex Usage ไม่สำเร็จ"
            : exception.Message;
        _notifyIcon.Text = TruncateTooltip($"myCodex Meter • {message}");
        _summaryItem.Text = $"อ่านข้อมูลไม่สำเร็จ: {message}";
        _detailsItem.Enabled = false;
        _detailsItem.DropDownItems.Clear();
    }

    private void SetIcon(double? remainingPercent)
    {
        var nextIcon = DynamicTrayIconRenderer.Create(remainingPercent);
        var previousIcon = _currentIcon;
        _currentIcon = nextIcon;
        _notifyIcon.Icon = nextIcon;
        previousIcon?.Dispose();
    }

    private void ToggleLaunchAtStartup()
    {
        try
        {
            StartupManager.SetEnabled(!StartupManager.IsEnabled);
            _launchAtStartupItem.Checked = StartupManager.IsEnabled;
        }
        catch (Exception exception)
        {
            MessageBox.Show(
                exception.Message,
                "ตั้งค่าเปิดพร้อม Windows ไม่สำเร็จ",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning);
        }
    }

    private static void OpenUsageDashboard()
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = "https://chatgpt.com/codex/settings/usage",
            UseShellExecute = true,
        });
    }

    private static string TruncateTooltip(string value) =>
        value.Length <= 63 ? value : value[..63];

    private void Exit()
    {
        _notifyIcon.Visible = false;
        ExitThread();
    }
}
