using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;

namespace MyCodexMeter.Windows;

[SupportedOSPlatform("windows")]
internal static class DynamicTrayIconRenderer
{
    private const int CanvasSize = 32;

    public static Icon Create(double? remainingPercent)
    {
        using var bitmap = new Bitmap(
            CanvasSize,
            CanvasSize,
            PixelFormat.Format32bppArgb);
        using var graphics = Graphics.FromImage(bitmap);

        graphics.Clear(Color.Transparent);
        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        graphics.TextRenderingHint =
            System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;

        var color = remainingPercent switch
        {
            null => Color.FromArgb(220, 209, 52, 56),
            >= 50 => Color.FromArgb(230, 40, 167, 69),
            >= 20 => Color.FromArgb(235, 245, 143, 35),
            _ => Color.FromArgb(230, 220, 53, 69),
        };

        using var logoBrush = new SolidBrush(color);
        DrawCodexMark(graphics, logoBrush);

        var label = remainingPercent is null
            ? "!"
            : Math.Round(Math.Clamp(remainingPercent.Value, 0, 100))
                .ToString("0", System.Globalization.CultureInfo.InvariantCulture);
        var fontSize = label.Length >= 3 ? 8.2f : 10.5f;

        using var font = new Font(
            "Segoe UI",
            fontSize,
            FontStyle.Bold,
            GraphicsUnit.Pixel);
        using var textBrush = new SolidBrush(Color.White);
        using var format = new StringFormat
        {
            Alignment = StringAlignment.Center,
            LineAlignment = StringAlignment.Center,
        };

        graphics.DrawString(
            label,
            font,
            textBrush,
            new RectangleF(3, 3, 26, 26),
            format);

        var iconHandle = bitmap.GetHicon();
        try
        {
            using var borrowedIcon = Icon.FromHandle(iconHandle);
            return (Icon)borrowedIcon.Clone();
        }
        finally
        {
            DestroyIcon(iconHandle);
        }
    }

    private static void DrawCodexMark(Graphics graphics, Brush brush)
    {
        const float center = CanvasSize / 2f;
        const float lobeRadius = 6.1f;
        const float orbitRadius = 6.6f;

        for (var index = 0; index < 7; index++)
        {
            var angle = index * Math.PI * 2 / 7 - Math.PI / 2;
            var x = center + (float)Math.Cos(angle) * orbitRadius;
            var y = center + (float)Math.Sin(angle) * orbitRadius;
            graphics.FillEllipse(
                brush,
                x - lobeRadius,
                y - lobeRadius,
                lobeRadius * 2,
                lobeRadius * 2);
        }

        graphics.FillEllipse(brush, 8.2f, 8.2f, 15.6f, 15.6f);
    }

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DestroyIcon(IntPtr handle);
}
