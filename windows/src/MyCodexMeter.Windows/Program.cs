using System.Runtime.Versioning;

namespace MyCodexMeter.Windows;

[SupportedOSPlatform("windows")]
internal static class Program
{
    [STAThread]
    private static void Main()
    {
        using var singleInstance = new Mutex(
            initiallyOwned: true,
            "Local\\com.sunday.mycodex-meter",
            out var isFirstInstance);

        if (!isFirstInstance)
        {
            return;
        }

        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        Application.ThreadException += (_, eventArgs) =>
        {
            MessageBox.Show(
                eventArgs.Exception.Message,
                "myCodex Meter",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        };

        using var context = new TrayApplicationContext();
        Application.Run(context);
    }
}
