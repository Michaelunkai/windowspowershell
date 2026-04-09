using System.ComponentModel;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace UninstallPro;

// ═══════════════════════════════════════════════════════════════
// MODERN BUTTON - Animated, gradient, beautiful
// ═══════════════════════════════════════════════════════════════
public sealed class FlatBtn : Control
{
    private float _anim;
    private bool _hover, _press;
    private readonly System.Windows.Forms.Timer _timer = new() { Interval = 16 };

    public FlatBtn()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                 ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        Size = new Size(140, 42);
        Cursor = Cursors.Hand;
        Font = Theme.FontBtn;
        _timer.Tick += (_, _) =>
        {
            _anim += _hover ? 0.12f : -0.12f;
            _anim = Math.Clamp(_anim, 0, 1);
            Invalidate();
            if ((_hover && _anim >= 1) || (!_hover && _anim <= 0)) _timer.Stop();
        };
    }

    [DefaultValue(typeof(Color), "99, 102, 241")]
    public Color Accent { get; set; } = Theme.Accent;

    [DefaultValue(false)]
    public bool Filled { get; set; }

    [DefaultValue("")]
    public string Icon { get; set; } = "";

    [DefaultValue(10)]
    public int Radius { get; set; } = 10;

    protected override void OnMouseEnter(EventArgs e) { _hover = true; _timer.Start(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { _hover = false; _press = false; _timer.Start(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) { _press = true; Invalidate(); base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { _press = false; Invalidate(); base.OnMouseUp(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;

        var rect = new RectangleF(1, 1, Width - 2, Height - 2);

        // Background
        Color bgColor;
        if (Filled)
        {
            bgColor = _press ? Theme.Darken(Accent, 0.15f) : Theme.Lerp(Accent, Theme.Lighten(Accent, 0.15f), _anim);
        }
        else
        {
            bgColor = _press ? Theme.BgSelected : Theme.Lerp(Theme.BgCard, Theme.BgHover, _anim);
        }

        using (var brush = new SolidBrush(bgColor))
            Theme.FillRoundRect(g, brush, rect, Radius);

        // Border for non-filled
        if (!Filled)
        {
            var borderColor = Theme.Lerp(Theme.Border, Theme.Lerp(Accent, Theme.AccentLight, _anim), _anim * 0.7f);
            using var pen = new Pen(borderColor, 1.2f);
            Theme.DrawRoundRect(g, pen, rect, Radius);
        }

        // Glow effect when hovering filled button
        if (Filled && _anim > 0.3f)
        {
            var glowRect = new RectangleF(-2, -2, Width + 4, Height + 4);
            using var glowPath = Theme.RoundRect(glowRect, Radius + 2);
            using var glowBrush = new SolidBrush(Color.FromArgb((int)(30 * _anim), Accent));
            g.FillPath(glowBrush, glowPath);
        }

        // Text
        var fgColor = Filled ? Color.White : Theme.Lerp(Theme.TextPrimary, Accent, _anim * 0.5f);
        var label = string.IsNullOrEmpty(Icon) ? Text : $"{Icon}  {Text}";
        var sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
        using (var brush = new SolidBrush(fgColor))
            g.DrawString(label, Font, brush, rect, sf);
    }
}

// ═══════════════════════════════════════════════════════════════
// SEARCH BOX - Modern input with placeholder
// ═══════════════════════════════════════════════════════════════
public sealed class SearchBox : Panel
{
    private readonly TextBox _tb;
    private readonly Label _placeholder;
    private readonly Label _icon;
    private bool _focused;

    public SearchBox()
    {
        Height = 44;
        BackColor = Theme.BgInput;
        Padding = new Padding(40, 10, 14, 10);

        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.OptimizedDoubleBuffer, true);

        _icon = new Label
        {
            Text = "🔍",
            ForeColor = Theme.TextMuted,
            Font = new Font("Segoe UI Emoji", 12F),
            Size = new Size(30, 30),
            Location = new Point(10, 7),
            TextAlign = ContentAlignment.MiddleCenter
        };

        _tb = new TextBox
        {
            BorderStyle = BorderStyle.None,
            BackColor = Theme.BgInput,
            ForeColor = Theme.TextPrimary,
            Font = Theme.FontBody,
            Dock = DockStyle.Fill
        };

        _placeholder = new Label
        {
            Text = "Search programs by name, publisher or version...",
            ForeColor = Theme.TextMuted,
            BackColor = Color.Transparent,
            Font = Theme.FontBody,
            Dock = DockStyle.Fill,
            AutoSize = false,
            TextAlign = ContentAlignment.MiddleLeft
        };
        _placeholder.Click += (_, _) => _tb.Focus();

        _tb.TextChanged += (_, _) =>
        {
            _placeholder.Visible = string.IsNullOrEmpty(_tb.Text);
            OnTextChanged(EventArgs.Empty);
        };
        _tb.GotFocus += (_, _) => { _focused = true; _icon.ForeColor = Theme.Accent; Invalidate(); };
        _tb.LostFocus += (_, _) => { _focused = false; _icon.ForeColor = Theme.TextMuted; Invalidate(); };

        Controls.Add(_tb);
        Controls.Add(_placeholder);
        Controls.Add(_icon);
        _placeholder.BringToFront();
    }

    [Browsable(false)]
    public override string Text { get => _tb.Text; set => _tb.Text = value; }

    public void FocusInput() => _tb.Focus();

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;

        var rect = new RectangleF(0, 0, Width - 1, Height - 1);
        using var brush = new SolidBrush(Theme.BgInput);
        Theme.FillRoundRect(e.Graphics, brush, rect, 12);

        var c = _focused ? Theme.Accent : Theme.Border;
        using var pen = new Pen(c, _focused ? 2f : 1f);
        Theme.DrawRoundRect(e.Graphics, pen, rect, 12);
    }
}

// ═══════════════════════════════════════════════════════════════
// PROGRAM LIST - Dark themed ListView
// ═══════════════════════════════════════════════════════════════
public sealed class ProgramList : ListView
{
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)]
    private static extern int SetWindowTheme(IntPtr hWnd, string sub, string? id);

    public ProgramList()
    {
        DoubleBuffered = true;
        View = View.Details;
        FullRowSelect = true;
        MultiSelect = true;
        BorderStyle = BorderStyle.None;
        BackColor = Theme.BgDark;
        ForeColor = Theme.TextPrimary;
        Font = Theme.FontBody;
        OwnerDraw = true;
        HeaderStyle = ColumnHeaderStyle.Clickable;
        GridLines = false;

        DrawColumnHeader += OnDrawHeader;
        DrawItem += OnDrawItem;
        DrawSubItem += OnDrawSubItem;
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        try { SetWindowTheme(Handle, "Explorer", null); } catch { }
    }

    private void OnDrawHeader(object? s, DrawListViewColumnHeaderEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;

        // Header background
        using var bg = new LinearGradientBrush(e.Bounds, Theme.BgPanel, Theme.Darken(Theme.BgPanel, 0.1f), 90);
        g.FillRectangle(bg, e.Bounds);

        // Bottom border
        using var line = new Pen(Theme.Border, 2);
        g.DrawLine(line, e.Bounds.Left, e.Bounds.Bottom - 1, e.Bounds.Right, e.Bounds.Bottom - 1);

        // Header text
        var r = new Rectangle(e.Bounds.X + 12, e.Bounds.Y, e.Bounds.Width - 12, e.Bounds.Height);
        TextRenderer.DrawText(g, e.Header?.Text ?? "", Theme.FontBold, r, Theme.TextSecondary,
            TextFormatFlags.Left | TextFormatFlags.VerticalCenter);
    }

    private void OnDrawItem(object? s, DrawListViewItemEventArgs e) { /* handled in sub-item */ }

    private void OnDrawSubItem(object? s, DrawListViewSubItemEventArgs e)
    {
        if (e.Item == null || e.SubItem == null) return;

        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;

        // Row background with zebra striping
        Color bg;
        if (e.Item.Selected && ContainsFocus)
            bg = Theme.Accent;
        else if (e.Item.Selected)
            bg = Theme.BgSelected;
        else
            bg = e.ItemIndex % 2 == 0 ? Theme.BgDark : Color.FromArgb(20, 20, 26);

        using (var brush = new SolidBrush(bg))
            g.FillRectangle(brush, e.Bounds);

        // Text
        var textColor = e.Item.Selected && ContainsFocus ? Color.White :
                        e.ColumnIndex == 0 ? Theme.TextPrimary : Theme.TextSecondary;

        var textFont = e.ColumnIndex == 0 ? Theme.FontBold : Theme.FontBody;
        var r = new Rectangle(e.Bounds.X + 12, e.Bounds.Y, e.Bounds.Width - 12, e.Bounds.Height);
        TextRenderer.DrawText(g, e.SubItem.Text, textFont, r, textColor,
            TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
    }
}

// ═══════════════════════════════════════════════════════════════
// STAT CARD - Dashboard style metric card
// ═══════════════════════════════════════════════════════════════
public sealed class StatCard : Panel
{
    public StatCard()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.OptimizedDoubleBuffer, true);
        Size = new Size(180, 90);
        BackColor = Theme.BgCard;
    }

    [DefaultValue("0")]
    public string Value { get; set; } = "0";

    [DefaultValue("Label")]
    public string Label { get; set; } = "Label";

    [DefaultValue(typeof(Color), "99, 102, 241")]
    public Color AccentColor { get; set; } = Theme.Accent;

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;

        var rect = new RectangleF(0, 0, Width, Height);

        // Card background with gradient
        using (var brush = new LinearGradientBrush(ClientRectangle, Theme.BgCard, Theme.Darken(Theme.BgCard, 0.05f), 90))
            Theme.FillRoundRect(g, brush, rect, 12);

        // Border
        using (var pen = new Pen(Theme.Border, 1))
            Theme.DrawRoundRect(g, pen, new RectangleF(0.5f, 0.5f, Width - 1, Height - 1), 12);

        // Accent dot
        using (var brush = new SolidBrush(AccentColor))
            g.FillEllipse(brush, 16, 16, 10, 10);

        // Value
        using (var brush = new SolidBrush(Theme.TextPrimary))
            g.DrawString(Value, Theme.FontStatValue, brush, 16, 38);

        // Label
        using (var brush = new SolidBrush(Theme.TextMuted))
            g.DrawString(Label, Theme.FontStatLabel, brush, 16, 66);
    }

    public void SetValue(string value)
    {
        Value = value;
        Invalidate();
    }
}

// ═══════════════════════════════════════════════════════════════
// NAV ITEM - Sidebar navigation button
// ═══════════════════════════════════════════════════════════════
public sealed class NavItem : Control
{
    private float _anim;
    private bool _hover;
    private bool _active;
    private readonly System.Windows.Forms.Timer _timer = new() { Interval = 16 };

    public NavItem()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                 ControlStyles.OptimizedDoubleBuffer, true);
        Size = new Size(160, 48);
        Cursor = Cursors.Hand;
        Font = Theme.FontNavItem;
        _timer.Tick += (_, _) =>
        {
            _anim += (_hover || _active) ? 0.12f : -0.12f;
            _anim = Math.Clamp(_anim, 0, 1);
            Invalidate();
            if (((_hover || _active) && _anim >= 1) || (!_hover && !_active && _anim <= 0)) _timer.Stop();
        };
    }

    [DefaultValue("")]
    public string Icon { get; set; } = "";

    [DefaultValue(false)]
    public bool Active
    {
        get => _active;
        set { _active = value; _timer.Start(); }
    }

    protected override void OnMouseEnter(EventArgs e) { _hover = true; _timer.Start(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { _hover = false; _timer.Start(); base.OnMouseLeave(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;

        var rect = new RectangleF(4, 4, Width - 8, Height - 8);

        // Background
        var bgColor = _active
            ? Theme.Lerp(Theme.AccentDim, Theme.Accent, _anim * 0.3f)
            : Theme.Lerp(Color.Transparent, Theme.BgHover, _anim);

        if (_active || _anim > 0)
        {
            using var brush = new SolidBrush(bgColor);
            Theme.FillRoundRect(g, brush, rect, 10);
        }

        // Active indicator
        if (_active)
        {
            using var brush = new SolidBrush(Theme.Accent);
            Theme.FillRoundRect(g, brush, new RectangleF(0, 12, 4, Height - 24), 2);
        }

        // Icon + Text
        var fgColor = _active ? Color.White : Theme.Lerp(Theme.TextSecondary, Theme.TextPrimary, _anim);
        var label = string.IsNullOrEmpty(Icon) ? Text : $"{Icon}  {Text}";
        using (var brush = new SolidBrush(fgColor))
            g.DrawString(label, Font, brush, 20, (Height - Font.Height) / 2f);
    }
}
