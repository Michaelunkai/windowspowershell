using System.Drawing.Drawing2D;
using System.Diagnostics;

namespace UninstallPro;

public sealed class MainForm : Form
{
    private readonly Engine _engine = new();
    private List<AppInfo> _allApps = [];
    private List<AppInfo> _displayedApps = [];
    private readonly ColumnSorter _sorter = new();

    // ── Controls ───────────────────────────────────────────────
    private ProgramList _list = null!;
    private SearchBox _search = null!;
    private Panel _sidebar = null!;
    private Label _statusText = null!;
    private Label _countText = null!;
    private ProgressBar _progress = null!;

    // Sidebar detail labels
    private Label _detailName = null!, _detailPub = null!, _detailVer = null!;
    private Label _detailSize = null!, _detailDate = null!, _detailPath = null!;

    // Stat cards
    private StatCard _statTotal = null!, _statSize = null!, _statSelected = null!;

    // Navbar buttons
    private Panel _navbar = null!;
    private readonly Dictionary<string, NavItem> _navItems = new();
    private string _currentTab = "programs";

    // Tab panels
    private Panel _programsPanel = null!, _startupPanel = null!, _junkPanel = null!;

    // Startup tab
    private ProgramList _startupList = null!;

    // Junk tab
    private ProgramList _junkList = null!;
    private Label _junkSummary = null!;
    private List<JunkItem> _junkItems = [];

    // Checkbox
    private CheckBox _chkUpdates = null!;

    public MainForm()
    {
        Text = "UninstallPro";
        Size = new Size(1500, 900);
        MinimumSize = new Size(1100, 650);
        BackColor = Theme.BgDark;
        StartPosition = FormStartPosition.CenterScreen;
        DoubleBuffered = true;
        KeyPreview = true;
        WindowState = FormWindowState.Maximized;

        BuildUI();

        Load += MainForm_Load;
        KeyDown += OnKeyDown;
    }

    private async void MainForm_Load(object? sender, EventArgs e)
    {
        try
        {
            await LoadPrograms();
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Error loading programs: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    // ─── Build UI ──────────────────────────────────────────────
    private void BuildUI()
    {
        // Main horizontal split: sidebar-left (nav) | center | sidebar-right (details)
        var mainPanel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 3,
            RowCount = 1,
            BackColor = Theme.BgDark
        };
        mainPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 180));    // nav
        mainPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));     // center
        mainPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 310));    // details

        _navbar = BuildNavbar();
        var center = BuildCenter();
        _sidebar = BuildSidebar();

        mainPanel.Controls.Add(_navbar, 0, 0);
        mainPanel.Controls.Add(center, 1, 0);
        mainPanel.Controls.Add(_sidebar, 2, 0);

        Controls.Add(mainPanel);
    }

    // ── Navbar ──────────────────────────────────────────────────
    private Panel BuildNavbar()
    {
        var nav = new Panel { Dock = DockStyle.Fill, BackColor = Theme.BgPanel, Padding = new Padding(12) };

        var title = new Label
        {
            Text = "UninstallPro",
            Font = Theme.FontTitle,
            ForeColor = Theme.Accent,
            AutoSize = true,
            Location = new Point(14, 18)
        };

        var subtitle = new Label
        {
            Text = "System Cleaner",
            Font = Theme.FontSmall,
            ForeColor = Theme.TextMuted,
            AutoSize = true,
            Location = new Point(16, 52)
        };

        var y = 100;
        var navItems = new (string id, string icon, string label)[]
        {
            ("programs", "📦", "Programs"),
            ("startup", "🚀", "Startup"),
            ("junk", "🧹", "Junk Files"),
        };

        foreach (var (id, icon, label) in navItems)
        {
            var navItem = new NavItem
            {
                Text = label,
                Icon = icon,
                Size = new Size(156, 48),
                Location = new Point(10, y),
                Active = id == "programs"
            };
            navItem.Click += (_, _) => SwitchTab(id);
            _navItems[id] = navItem;
            nav.Controls.Add(navItem);
            y += 54;
        }

        nav.Controls.Add(title);
        nav.Controls.Add(subtitle);
        return nav;
    }

    // ── Center ──────────────────────────────────────────────────
    private Panel BuildCenter()
    {
        var center = new Panel { Dock = DockStyle.Fill, BackColor = Theme.BgDark, Padding = new Padding(16, 12, 16, 8) };

        // ── Programs tab ───────────────────────────────────────
        _programsPanel = new Panel { Dock = DockStyle.Fill, BackColor = Theme.BgDark };

        // Top bar: search + buttons
        var topBar = new Panel { Dock = DockStyle.Top, Height = 55, BackColor = Theme.BgDark };

        _search = new SearchBox { Width = 400, Location = new Point(0, 8) };
        _search.TextChanged += (_, _) => ApplyFilter();

        _chkUpdates = new CheckBox
        {
            Text = "Updates",
            ForeColor = Theme.TextSecondary,
            Font = Theme.FontSmall,
            AutoSize = true,
            Location = new Point(420, 18)
        };
        _chkUpdates.CheckedChanged += async (_, _) => await LoadPrograms();

        topBar.Controls.AddRange([_search, _chkUpdates]);

        // Action bar
        var actionBar = new Panel { Dock = DockStyle.Top, Height = 52, BackColor = Theme.BgDark };

        var actions = new (string text, string icon, Color accent, bool filled, EventHandler click)[]
        {
            ("Uninstall", "🗑", Theme.Danger, true, (_, _) => DoUninstall()),
            ("Force Remove", "⚡", Theme.Warning, false, (_, _) => DoForceRemove()),
            ("Batch", "📦", Theme.Accent, false, (_, _) => DoBatch()),
            ("Export CSV", "💾", Theme.Success, false, (_, _) => DoExport()),
            ("Refresh", "🔄", Theme.TextMuted, false, async (_, _) => await LoadPrograms()),
        };

        int ax = 0;
        foreach (var (text, icon, accent, filled, click) in actions)
        {
            var btn = new FlatBtn { Text = text, Icon = icon, Accent = accent, Filled = filled, Location = new Point(ax, 4), Size = new Size(text.Length < 7 ? 120 : 145, 38) };
            btn.Click += click;
            actionBar.Controls.Add(btn);
            ax += btn.Width + 8;
        }

        // Stats bar
        var statsBar = new FlowLayoutPanel { Dock = DockStyle.Top, Height = 90, BackColor = Theme.BgDark, FlowDirection = FlowDirection.LeftToRight, WrapContents = false };
        _statTotal = new StatCard { Value = "0", Label = "Total Programs", AccentColor = Theme.Accent };
        _statSize = new StatCard { Value = "0", Label = "Total Size", AccentColor = Theme.Success };
        _statSelected = new StatCard { Value = "0", Label = "Selected", AccentColor = Theme.Warning };
        statsBar.Controls.AddRange([_statTotal, new Panel { Width = 12 }, _statSize, new Panel { Width = 12 }, _statSelected]);

        // List
        _list = new ProgramList { Dock = DockStyle.Fill };
        _list.Columns.Add("Name", 300);
        _list.Columns.Add("Publisher", 180);
        _list.Columns.Add("Version", 110);
        _list.Columns.Add("Size", 90);
        _list.Columns.Add("Installed", 100);
        _list.Columns.Add("Location", 250);
        _list.ListViewItemSorter = _sorter;
        _list.ColumnClick += (_, e) => { _sorter.Toggle(e.Column); _list.Sort(); };
        _list.SelectedIndexChanged += (_, _) => OnSelectionChanged();
        _list.DoubleClick += (_, _) => OpenFolder();
        _list.ContextMenuStrip = BuildContextMenu();

        // Status bar
        var statusBar = new Panel { Dock = DockStyle.Bottom, Height = 30, BackColor = Theme.BgPanel };
        _statusText = new Label { Text = "Ready", ForeColor = Theme.TextMuted, Font = Theme.FontSmall, AutoSize = true, Location = new Point(10, 8) };
        _countText = new Label { Text = "", ForeColor = Theme.TextMuted, Font = Theme.FontSmall, AutoSize = true, Location = new Point(200, 8) };
        _progress = new ProgressBar { Size = new Size(180, 14), Location = new Point(380, 8), Visible = false, Style = ProgressBarStyle.Marquee, MarqueeAnimationSpeed = 25 };
        statusBar.Controls.AddRange([_statusText, _countText, _progress]);

        _programsPanel.Controls.Add(_list);
        _programsPanel.Controls.Add(statusBar);
        _programsPanel.Controls.Add(actionBar);
        _programsPanel.Controls.Add(statsBar);
        _programsPanel.Controls.Add(topBar);

        // ── Startup tab ────────────────────────────────────────
        _startupPanel = new Panel { Dock = DockStyle.Fill, BackColor = Theme.BgDark, Visible = false };

        var startupTopBar = new Panel { Dock = DockStyle.Top, Height = 55, BackColor = Theme.BgDark };
        var startupLabel = new Label { Text = "🚀  Startup Programs", Font = Theme.FontHeading, ForeColor = Theme.TextPrimary, AutoSize = true, Location = new Point(0, 14) };
        var btnDelStartup = new FlatBtn { Text = "Remove Selected", Icon = "✕", Accent = Theme.Danger, Size = new Size(160, 36), Location = new Point(300, 10) };
        btnDelStartup.Click += (_, _) => DoDeleteStartup();
        var btnRefreshStartup = new FlatBtn { Text = "Refresh", Icon = "🔄", Size = new Size(110, 36), Location = new Point(470, 10) };
        btnRefreshStartup.Click += (_, _) => LoadStartup();
        startupTopBar.Controls.AddRange([startupLabel, btnDelStartup, btnRefreshStartup]);

        _startupList = new ProgramList { Dock = DockStyle.Fill };
        _startupList.Columns.Add("Name", 250);
        _startupList.Columns.Add("Command", 400);
        _startupList.Columns.Add("Source", 150);
        _startupPanel.Controls.Add(_startupList);
        _startupPanel.Controls.Add(startupTopBar);

        // ── Junk tab ───────────────────────────────────────────
        _junkPanel = new Panel { Dock = DockStyle.Fill, BackColor = Theme.BgDark, Visible = false };

        var junkTopBar = new Panel { Dock = DockStyle.Top, Height = 55, BackColor = Theme.BgDark };
        var junkLabel = new Label { Text = "🧹  Junk Files", Font = Theme.FontHeading, ForeColor = Theme.TextPrimary, AutoSize = true, Location = new Point(0, 14) };
        var btnScanJunk = new FlatBtn { Text = "Scan", Icon = "🔍", Accent = Theme.Accent, Filled = true, Size = new Size(100, 36), Location = new Point(200, 10) };
        btnScanJunk.Click += async (_, _) => await ScanJunk();
        var btnCleanJunk = new FlatBtn { Text = "Clean Selected", Icon = "🧹", Accent = Theme.Danger, Size = new Size(150, 36), Location = new Point(310, 10) };
        btnCleanJunk.Click += (_, _) => DoCleanJunk();
        _junkSummary = new Label { Text = "", Font = Theme.FontBody, ForeColor = Theme.TextSecondary, AutoSize = true, Location = new Point(480, 18) };
        junkTopBar.Controls.AddRange([junkLabel, btnScanJunk, btnCleanJunk, _junkSummary]);

        _junkList = new ProgramList { Dock = DockStyle.Fill, CheckBoxes = true };
        _junkList.Columns.Add("File", 450);
        _junkList.Columns.Add("Size", 100);
        _junkList.Columns.Add("Category", 150);
        _junkList.Columns.Add("Last Access", 150);
        _junkPanel.Controls.Add(_junkList);
        _junkPanel.Controls.Add(junkTopBar);

        // Add all tab panels to center
        center.Controls.Add(_programsPanel);
        center.Controls.Add(_startupPanel);
        center.Controls.Add(_junkPanel);

        return center;
    }

    // ── Sidebar ─────────────────────────────────────────────────
    private Panel BuildSidebar()
    {
        var sb = new Panel { Dock = DockStyle.Fill, BackColor = Theme.BgPanel, Padding = new Padding(16) };

        var title = new Label { Text = "Details", Font = Theme.FontHeading, ForeColor = Theme.Accent, AutoSize = true, Location = new Point(16, 16) };

        int y = 50;
        Label MakeField(string label, int yy)
        {
            var lbl = new Label { Text = label, Font = Theme.FontSmall, ForeColor = Theme.TextMuted, AutoSize = true, Location = new Point(16, yy) };
            var val = new Label { Text = "—", Font = Theme.FontBody, ForeColor = Theme.TextPrimary, AutoSize = false, Size = new Size(270, 22), AutoEllipsis = true, Location = new Point(16, yy + 17) };
            sb.Controls.AddRange([lbl, val]);
            return val;
        }

        _detailName = MakeField("NAME", y); y += 48;
        _detailPub  = MakeField("PUBLISHER", y); y += 48;
        _detailVer  = MakeField("VERSION", y); y += 48;
        _detailSize = MakeField("SIZE", y); y += 48;
        _detailDate = MakeField("INSTALL DATE", y); y += 48;
        _detailPath = MakeField("LOCATION", y); y += 58;

        // Action buttons
        var btnOpen = new FlatBtn { Text = "Open Folder", Icon = "📂", Size = new Size(270, 36), Location = new Point(16, y), Accent = Theme.Accent, Filled = true };
        btnOpen.Click += (_, _) => OpenFolder();
        y += 44;

        var btnReg = new FlatBtn { Text = "Open in Registry", Icon = "🔧", Size = new Size(270, 36), Location = new Point(16, y) };
        btnReg.Click += (_, _) => OpenRegistry();
        y += 44;

        var btnCopy = new FlatBtn { Text = "Copy Info", Icon = "📋", Size = new Size(270, 36), Location = new Point(16, y) };
        btnCopy.Click += (_, _) => CopyInfo();

        sb.Controls.AddRange([title, btnOpen, btnReg, btnCopy]);
        return sb;
    }

    // ── Context Menu ────────────────────────────────────────────
    private ContextMenuStrip BuildContextMenu()
    {
        var menu = new ContextMenuStrip { BackColor = Theme.BgCard, ForeColor = Theme.TextPrimary, Font = Theme.FontBody };
        menu.Items.Add("🗑  Uninstall", null, (_, _) => DoUninstall());
        menu.Items.Add("⚡  Force Remove", null, (_, _) => DoForceRemove());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("📂  Open Folder", null, (_, _) => OpenFolder());
        menu.Items.Add("🔧  Open Registry", null, (_, _) => OpenRegistry());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("📋  Copy Name", null, (_, _) => { if (SelectedApp is { } a) Clipboard.SetText(a.Name); });
        menu.Items.Add("📋  Copy Path", null, (_, _) => { if (SelectedApp is { } a && !string.IsNullOrEmpty(a.InstallLocation)) Clipboard.SetText(a.InstallLocation); });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("ℹ  Properties", null, (_, _) => ShowProperties());
        return menu;
    }

    // ─── Tab Switching ──────────────────────────────────────────
    private void SwitchTab(string tab)
    {
        _currentTab = tab;
        _programsPanel.Visible = tab == "programs";
        _startupPanel.Visible = tab == "startup";
        _junkPanel.Visible = tab == "junk";

        foreach (var (id, navItem) in _navItems)
            navItem.Active = id == tab;

        if (tab == "startup") LoadStartup();
    }

    // ─── Data Loading ───────────────────────────────────────────
    private async Task LoadPrograms()
    {
        SetStatus("Loading programs...", true);
        try
        {
            _allApps = await Task.Run(() => _engine.GetInstalledPrograms(_chkUpdates?.Checked ?? false));
            ApplyFilter();
            UpdateStats();
            SetStatus("Ready", false);
        }
        catch (Exception ex)
        {
            SetStatus($"Error: {ex.Message}", false);
        }
    }

    private void ApplyFilter()
    {
        var q = _search?.Text?.ToLower() ?? "";
        _displayedApps = string.IsNullOrWhiteSpace(q)
            ? [.. _allApps]
            : _allApps.Where(a =>
                a.Name.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                a.Publisher.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                a.Version.Contains(q, StringComparison.OrdinalIgnoreCase)
            ).ToList();

        _list.BeginUpdate();
        _list.Items.Clear();
        foreach (var app in _displayedApps)
        {
            var item = new ListViewItem(app.Name) { Tag = app };
            item.SubItems.Add(app.Publisher);
            item.SubItems.Add(app.Version);
            item.SubItems.Add(app.SizeText);
            item.SubItems.Add(app.DateText);
            item.SubItems.Add(app.InstallLocation);
            _list.Items.Add(item);
        }
        _list.EndUpdate();
        _countText.Text = $"{_displayedApps.Count} programs";
    }

    private void UpdateStats()
    {
        _statTotal.SetValue(_allApps.Count.ToString("N0"));
        var totalBytes = _allApps.Sum(a => a.SizeBytes);
        _statSize.SetValue(totalBytes > 0
            ? totalBytes >= 1073741824 ? $"{totalBytes / 1073741824.0:F1} GB" : $"{totalBytes / 1048576.0:F0} MB"
            : "—");
    }

    private void OnSelectionChanged()
    {
        _statSelected.SetValue(_list.SelectedItems.Count.ToString());

        if (_list.SelectedItems.Count > 0 && _list.SelectedItems[0].Tag is AppInfo app)
        {
            _detailName.Text = app.Name;
            _detailPub.Text = string.IsNullOrEmpty(app.Publisher) ? "—" : app.Publisher;
            _detailVer.Text = string.IsNullOrEmpty(app.Version) ? "—" : app.Version;
            _detailSize.Text = string.IsNullOrEmpty(app.SizeText) ? "—" : app.SizeText;
            _detailDate.Text = string.IsNullOrEmpty(app.DateText) ? "—" : app.DateText;
            _detailPath.Text = string.IsNullOrEmpty(app.InstallLocation) ? "—" : app.InstallLocation;
        }
    }

    private AppInfo? SelectedApp => _list.SelectedItems.Count > 0 ? _list.SelectedItems[0].Tag as AppInfo : null;

    // ─── Actions ────────────────────────────────────────────────
    private async void DoUninstall()
    {
        if (SelectedApp is not { } app) { Msg("Select a program first.", "i"); return; }

        if (MessageBox.Show(
            $"Uninstall {app.Name}?\n\n• Runs native uninstaller\n• Deep scans for leftover files & registry\n• Creates restore point",
            "Confirm", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;

        SetStatus($"Uninstalling {app.Name}...", true);
        var result = await _engine.Uninstall(app, deep: true, new Progress<string>(s => SetStatus(s, true)));
        SetStatus("Ready", false);

        var msg = result.Success ? "✅ Uninstallation complete!" : "⚠ Completed with issues.";
        msg += $"\n\n⏱ {result.Duration.TotalSeconds:F1}s\n📁 {result.FilesRemoved} files removed\n📂 {result.FoldersRemoved} folders\n🔧 {result.RegKeysRemoved} registry keys";
        if (result.BytesFreed > 0) msg += $"\n💾 {result.BytesFreed / 1048576.0:F1} MB freed";
        if (result.Errors.Count > 0) msg += $"\n\n❌ {result.Errors.Count} error(s):\n• {string.Join("\n• ", result.Errors.Take(3))}";
        Msg(msg, result.Success ? "i" : "w");

        await LoadPrograms();
    }

    private async void DoForceRemove()
    {
        if (SelectedApp is not { } app) { Msg("Select a program first.", "i"); return; }

        if (MessageBox.Show(
            $"⚠ FORCE REMOVE {app.Name}?\n\nThis skips the native uninstaller and directly deletes files.\nUse only if normal uninstall fails!",
            "Force Remove", MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes) return;

        SetStatus($"Force removing {app.Name}...", true);
        var result = await _engine.ForceRemove(app, new Progress<string>(s => SetStatus(s, true)));
        SetStatus("Ready", false);

        Msg($"Force removal done.\n📁 {result.FilesRemoved} files, 📂 {result.FoldersRemoved} folders, 🔧 {result.RegKeysRemoved} reg keys removed.\n💾 {result.BytesFreed / 1048576.0:F1} MB freed", "i");
        await LoadPrograms();
    }

    private async void DoBatch()
    {
        if (_list.SelectedItems.Count < 2) { Msg("Select 2+ programs for batch uninstall.", "i"); return; }

        var apps = _list.SelectedItems.Cast<ListViewItem>().Select(i => (AppInfo)i.Tag!).ToList();
        if (MessageBox.Show(
            $"Uninstall {apps.Count} programs?\n\n{string.Join("\n", apps.Take(10).Select(a => $"• {a.Name}"))}",
            "Batch Uninstall", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;

        int ok = 0, fail = 0;
        for (int i = 0; i < apps.Count; i++)
        {
            SetStatus($"[{i + 1}/{apps.Count}] Uninstalling {apps[i].Name}...", true);
            var r = await _engine.Uninstall(apps[i], deep: true, new Progress<string>(s => SetStatus($"[{i + 1}/{apps.Count}] {s}", true)));
            if (r.Success) ok++; else fail++;
        }

        SetStatus("Ready", false);
        Msg($"Batch complete!\n✅ {ok} succeeded\n❌ {fail} failed", "i");
        await LoadPrograms();
    }

    private void DoExport()
    {
        using var dlg = new SaveFileDialog { Filter = "CSV|*.csv", FileName = $"Programs_{DateTime.Now:yyyyMMdd}.csv" };
        if (dlg.ShowDialog() != DialogResult.OK) return;

        var lines = new List<string> { "Name,Publisher,Version,Size,InstallDate,Location" };
        lines.AddRange(_allApps.Select(a => $"\"{a.Name}\",\"{a.Publisher}\",\"{a.Version}\",\"{a.SizeText}\",\"{a.DateText}\",\"{a.InstallLocation}\""));
        File.WriteAllLines(dlg.FileName, lines);
        Msg($"✅ Exported {_allApps.Count} programs to:\n{dlg.FileName}", "i");
    }

    private void OpenFolder()
    {
        if (SelectedApp is { InstallLocation: { Length: > 0 } loc } && Directory.Exists(loc))
            Process.Start("explorer.exe", loc);
        else
            Msg("Install folder not found.", "i");
    }

    private void OpenRegistry()
    {
        if (SelectedApp is not { } app || string.IsNullOrEmpty(app.RegKey)) return;
        try { Process.Start("regedit.exe"); } catch { }
    }

    private void CopyInfo()
    {
        if (SelectedApp is not { } app) return;
        Clipboard.SetText($"Name: {app.Name}\nPublisher: {app.Publisher}\nVersion: {app.Version}\nSize: {app.SizeText}\nDate: {app.DateText}\nPath: {app.InstallLocation}\nRegistry: {app.RegKey}");
    }

    private void ShowProperties()
    {
        if (SelectedApp is not { } app) return;
        Msg($"Name: {app.Name}\nPublisher: {app.Publisher}\nVersion: {app.Version}\nSize: {app.SizeText}\nInstalled: {app.DateText}\nLocation: {app.InstallLocation}\nUninstall: {app.UninstallCmd}\nRegistry: {app.RegKey}", "i");
    }

    // ── Startup tab ─────────────────────────────────────────────
    private void LoadStartup()
    {
        var entries = _engine.GetStartupEntries();
        _startupList.BeginUpdate();
        _startupList.Items.Clear();
        foreach (var e in entries)
        {
            var item = new ListViewItem(e.Name) { Tag = e };
            item.SubItems.Add(e.Command);
            item.SubItems.Add(e.Source);
            _startupList.Items.Add(item);
        }
        _startupList.EndUpdate();
    }

    private void DoDeleteStartup()
    {
        if (_startupList.SelectedItems.Count == 0) { Msg("Select a startup entry first.", "i"); return; }

        var entries = _startupList.SelectedItems.Cast<ListViewItem>().Select(i => (StartupEntry)i.Tag!).ToList();
        if (MessageBox.Show($"Remove {entries.Count} startup entries?", "Confirm", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;

        int ok = 0;
        foreach (var e in entries) { if (_engine.DeleteStartupEntry(e)) ok++; }
        Msg($"Removed {ok}/{entries.Count} startup entries.", "i");
        LoadStartup();
    }

    // ── Junk tab ────────────────────────────────────────────────
    private async Task ScanJunk()
    {
        _junkSummary.Text = "Scanning...";
        _junkItems = await Task.Run(() => _engine.ScanJunk());

        _junkList.BeginUpdate();
        _junkList.Items.Clear();
        foreach (var j in _junkItems)
        {
            var item = new ListViewItem(j.Path) { Tag = j, Checked = true };
            item.SubItems.Add(j.Size < 1048576 ? $"{j.Size / 1024.0:F0} KB" : $"{j.Size / 1048576.0:F1} MB");
            item.SubItems.Add(j.Category);
            item.SubItems.Add(j.LastAccess.ToString("yyyy-MM-dd"));
            _junkList.Items.Add(item);
        }
        _junkList.EndUpdate();

        var totalSize = _junkItems.Sum(j => j.Size);
        _junkSummary.Text = $"Found {_junkItems.Count:N0} files  •  {totalSize / 1048576.0:F1} MB";
    }

    private void DoCleanJunk()
    {
        var selected = _junkList.CheckedItems.Cast<ListViewItem>().Select(i => (JunkItem)i.Tag!).ToList();
        if (selected.Count == 0) { Msg("No files selected.", "i"); return; }

        var totalSize = selected.Sum(j => j.Size);
        if (MessageBox.Show($"Delete {selected.Count:N0} files ({totalSize / 1048576.0:F1} MB)?", "Clean Junk", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;

        var (deleted, freed) = _engine.CleanJunk(selected);
        Msg($"✅ Deleted {deleted:N0} files\n💾 {freed / 1048576.0:F1} MB freed", "i");

        // Refresh
        _ = ScanJunk();
    }

    // ─── Keyboard ───────────────────────────────────────────────
    private async void OnKeyDown(object? s, KeyEventArgs e)
    {
        if (e.KeyCode == Keys.F5) { await LoadPrograms(); e.Handled = true; }
        else if (e.KeyCode == Keys.Delete && !e.Shift) { DoUninstall(); e.Handled = true; }
        else if (e.KeyCode == Keys.Delete && e.Shift) { DoForceRemove(); e.Handled = true; }
        else if (e.Control && e.KeyCode == Keys.F) { _search.FocusInput(); e.Handled = true; }
        else if (e.Control && e.KeyCode == Keys.B) { DoBatch(); e.Handled = true; }
        else if (e.Control && e.KeyCode == Keys.E) { DoExport(); e.Handled = true; }
        else if (e.Control && e.KeyCode == Keys.J) { SwitchTab("junk"); e.Handled = true; }
    }

    // ─── Helpers ────────────────────────────────────────────────
    private void SetStatus(string text, bool busy)
    {
        if (InvokeRequired) { Invoke(() => SetStatus(text, busy)); return; }
        _statusText.Text = text;
        _progress.Visible = busy;
        Cursor = busy ? Cursors.WaitCursor : Cursors.Default;
    }

    private void Msg(string text, string type)
    {
        var icon = type switch { "w" => MessageBoxIcon.Warning, "e" => MessageBoxIcon.Error, _ => MessageBoxIcon.Information };
        MessageBox.Show(this, text, "UninstallPro", MessageBoxButtons.OK, icon);
    }
}

// ─── Column Sorter ──────────────────────────────────────────────
public sealed class ColumnSorter : System.Collections.IComparer
{
    public int Col { get; set; }
    public SortOrder Order { get; set; } = SortOrder.Ascending;

    public void Toggle(int col)
    {
        if (col == Col) Order = Order == SortOrder.Ascending ? SortOrder.Descending : SortOrder.Ascending;
        else { Col = col; Order = SortOrder.Ascending; }
    }

    public int Compare(object? x, object? y)
    {
        if (x is not ListViewItem a || y is not ListViewItem b) return 0;
        var r = string.Compare(a.SubItems[Col].Text, b.SubItems[Col].Text, StringComparison.OrdinalIgnoreCase);
        return Order == SortOrder.Ascending ? r : -r;
    }
}
