using System.Drawing;
using System.Drawing.Drawing2D;

namespace UninstallPro;

public static class Theme
{
    // Backgrounds - Rich dark gradients
    public static readonly Color BgDark       = Color.FromArgb(15, 15, 18);
    public static readonly Color BgPanel      = Color.FromArgb(22, 22, 28);
    public static readonly Color BgCard       = Color.FromArgb(32, 32, 40);
    public static readonly Color BgHover      = Color.FromArgb(42, 42, 52);
    public static readonly Color BgSelected   = Color.FromArgb(50, 50, 62);
    public static readonly Color BgInput      = Color.FromArgb(25, 25, 32);

    // Beautiful accent colors
    public static readonly Color Accent       = Color.FromArgb(99, 102, 241);  // Indigo
    public static readonly Color AccentLight  = Color.FromArgb(129, 140, 248);
    public static readonly Color AccentDim    = Color.FromArgb(67, 56, 202);

    // Semantic colors
    public static readonly Color Danger       = Color.FromArgb(239, 68, 68);   // Red
    public static readonly Color DangerDim    = Color.FromArgb(185, 28, 28);
    public static readonly Color Warning      = Color.FromArgb(245, 158, 11);  // Amber
    public static readonly Color WarningDim   = Color.FromArgb(180, 83, 9);
    public static readonly Color Success      = Color.FromArgb(34, 197, 94);   // Emerald
    public static readonly Color SuccessDim   = Color.FromArgb(21, 128, 61);
    public static readonly Color Info         = Color.FromArgb(59, 130, 246);  // Blue

    // Text colors
    public static readonly Color TextPrimary  = Color.FromArgb(248, 250, 252);
    public static readonly Color TextSecondary = Color.FromArgb(148, 163, 184);
    public static readonly Color TextMuted    = Color.FromArgb(100, 116, 139);
    public static readonly Color TextDim      = Color.FromArgb(71, 85, 105);

    // Borders
    public static readonly Color Border       = Color.FromArgb(51, 65, 85);
    public static readonly Color BorderLight  = Color.FromArgb(71, 85, 105);
    public static readonly Color BorderFocus  = Accent;

    // Fonts - System fonts with fallbacks
    public static readonly Font FontTitle     = new("Segoe UI", 22F, FontStyle.Bold);
    public static readonly Font FontSubtitle  = new("Segoe UI", 11F, FontStyle.Regular);
    public static readonly Font FontHeading   = new("Segoe UI Semibold", 13F);
    public static readonly Font FontBody      = new("Segoe UI", 10F);
    public static readonly Font FontSmall     = new("Segoe UI", 9F);
    public static readonly Font FontBold      = new("Segoe UI Semibold", 10F);
    public static readonly Font FontBtn       = new("Segoe UI Semibold", 9.5F);
    public static readonly Font FontMono      = new("Cascadia Mono", 9.5F);
    public static readonly Font FontNavItem   = new("Segoe UI Semibold", 10.5F);
    public static readonly Font FontStatValue = new("Segoe UI", 18F, FontStyle.Bold);
    public static readonly Font FontStatLabel = new("Segoe UI", 9F);

    // Shadows
    public static void DrawShadow(Graphics g, Rectangle rect, int depth = 3)
    {
        for (int i = depth; i > 0; i--)
        {
            var alpha = (int)(20f / i);
            using var brush = new SolidBrush(Color.FromArgb(alpha, 0, 0, 0));
            var r = new Rectangle(rect.X + i, rect.Y + i, rect.Width, rect.Height);
            FillRoundRect(g, brush, r, 10);
        }
    }

    // Rounded rectangles
    public static GraphicsPath RoundRect(RectangleF r, float rad)
    {
        var p = new GraphicsPath();
        if (rad < 1) { p.AddRectangle(r); return p; }
        var d = rad * 2;
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    public static void FillRoundRect(Graphics g, Brush b, RectangleF r, float rad)
    {
        using var path = RoundRect(r, rad);
        g.FillPath(b, path);
    }

    public static void DrawRoundRect(Graphics g, Pen p, RectangleF r, float rad)
    {
        using var path = RoundRect(r, rad);
        g.DrawPath(p, path);
    }

    public static Color Lerp(Color a, Color b, float t)
    {
        t = Math.Clamp(t, 0, 1);
        return Color.FromArgb(
            (int)(a.A + (b.A - a.A) * t),
            (int)(a.R + (b.R - a.R) * t),
            (int)(a.G + (b.G - a.G) * t),
            (int)(a.B + (b.B - a.B) * t));
    }

    public static Color Darken(Color c, float amount = 0.2f)
    {
        return Color.FromArgb(c.A,
            Math.Max(0, (int)(c.R * (1 - amount))),
            Math.Max(0, (int)(c.G * (1 - amount))),
            Math.Max(0, (int)(c.B * (1 - amount))));
    }

    public static Color Lighten(Color c, float amount = 0.2f)
    {
        return Color.FromArgb(c.A,
            Math.Min(255, (int)(c.R + (255 - c.R) * amount)),
            Math.Min(255, (int)(c.G + (255 - c.G) * amount)),
            Math.Min(255, (int)(c.B + (255 - c.B) * amount)));
    }

    // Gradient helpers
    public static LinearGradientBrush GradientBrush(Rectangle r, Color c1, Color c2, float angle = 90)
    {
        return new LinearGradientBrush(r, c1, c2, angle);
    }
}
