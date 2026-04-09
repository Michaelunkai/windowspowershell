using System;
using System.Collections.Specialized;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Management;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace TgTray
{
    enum IconState { Running, Connecting, Stopped }

    // =====================================================================
    //  tg.exe — Claude Telegram Channel Manager
    //
    //  tg              → show status; if tray not running, launch it
    //  tg status       → print status to console, exit
    //  tg start        → start channel, exit
    //  tg stop         → stop channel, exit
    //  tg restart      → clean restart, exit
    //  tg tray         → force-launch system tray (even if already running)
    //  tg tui          → open live TUI terminal
    // =====================================================================

    static class Program
    {
        [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")]   static extern bool ShowWindow(IntPtr hWnd, int nCmd);
        [DllImport("kernel32.dll")] static extern bool AttachConsole(int pid);
        [DllImport("kernel32.dll")] static extern bool AllocConsole();
        [DllImport("kernel32.dll")] static extern bool FreeConsole();
        const int SW_HIDE = 0;
        const int SW_MINIMIZE = 6;
        const int ATTACH_PARENT_PROCESS = -1;

        public static readonly string ChannelDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".claude", "channels");
        static readonly string Ps5 = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System),
            "WindowsPowerShell", "v1.0", "powershell.exe");

        [STAThread]
        static void Main(string[] args)
        {
            // Force TLS 1.2 - Telegram API rejects TLS 1.0/1.1
            // Use numeric cast for .NET 4.0 compiler compatibility (3072 = Tls12, 12288 = Tls13)
            ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072 | (SecurityProtocolType)12288;
            try { _Main(args); }
            catch (Exception ex)
            {
                try { File.WriteAllText(@"C:\temp\tg-crash.txt", ex.ToString()); } catch {}
                Console.Error.WriteLine("CRASH: " + ex.Message);
                Console.Error.WriteLine(ex.StackTrace);
            }
        }

        static void _Main(string[] args)
        {
            string cmd = args.Length > 0 ? args[0].ToLower() : "";

            // For CLI commands (status/start/stop/etc.) attach to the calling console
            // so output appears there. For "tray" we run purely as a GUI app — no console.
            if (cmd != "tray")
            {
                if (!AttachConsole(ATTACH_PARENT_PROCESS))
                    AllocConsole();
                // Re-open stdout/stderr so Console.WriteLine works after attach
                Console.SetOut(new System.IO.StreamWriter(Console.OpenStandardOutput()) { AutoFlush = true });
                Console.SetError(new System.IO.StreamWriter(Console.OpenStandardError()) { AutoFlush = true });
            }

            switch (cmd)
            {
                case "status":
                    PrintStatus();
                    return;

                case "start":
                    var st = GetState();
                    if (st.IsRunning)
                    {
                        Console.WriteLine("Channel already RUNNING (Runner PID " + st.RunnerPid + ", Claude PID " + st.ClaudePid + ")");
                    }
                    else
                    {
                        RunPs("-File \"" + Path.Combine(ChannelDir, "launch-channel.ps1") + "\"", hidden: true);
                        Console.WriteLine("Channel starting... allow 15-20s. Run 'tg status' to check.");
                    }
                    return;

                case "stop":
                    StopChannel();
                    Console.WriteLine("Channel stopped.");
                    return;

                case "restart":
                    RestartChannel();
                    Console.WriteLine("Channel restarting (clean)... allow ~30s.");
                    return;

                case "tray":
                    LaunchTray(mustBeNew: false);
                    return;

                case "tui":
                    OpenTui();
                    return;

                default:
                    // No args: launch tray silently (no console output)
                    LaunchTray(mustBeNew: false);
                    return;
            }
        }

        // ─── Tray launcher ────────────────────────────────────────────────────
        static void LaunchTray(bool mustBeNew)
        {
            bool created;
            var mutex = new Mutex(true, "TgTrayApp_Claude_2025", out created);

            if (!created)
            {
                if (mustBeNew)
                    Console.WriteLine("System tray already running.");
                else
                    Console.WriteLine("System tray: already in tray. Right-click the TG icon in your taskbar.");
                mutex.Dispose();
                return;
            }

            // Hide console window immediately (minimize then hide to reduce flicker)
            IntPtr con = GetConsoleWindow();
            ShowWindow(con, SW_MINIMIZE);
            ShowWindow(con, SW_HIDE);

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new TrayApp(mutex));
            mutex.Dispose();
        }

        // ─── TUI launcher ─────────────────────────────────────────────────────
        public static void OpenTui()
        {
            string tuiScript = Path.Combine(ChannelDir, "tui.ps1");
            if (!File.Exists(tuiScript))
            {
                Console.WriteLine("TUI script not found: " + tuiScript);
                return;
            }
            var psi = new ProcessStartInfo
            {
                FileName         = Ps5,
                Arguments        = "-NoProfile -ExecutionPolicy Bypass -File \"" + tuiScript + "\"",
                WindowStyle      = ProcessWindowStyle.Normal,
                CreateNoWindow   = false,
                UseShellExecute  = true,
            };
            Process.Start(psi);
        }

        // ─── Channel process detection ─────────────────────────────────────────
        public struct State
        {
            public bool HasRunner, HasClaude;
            public int BunCount, RunnerPid, ClaudePid;
            // Channel is TRULY running only when claude + bun (telegram plugin) are both alive
            public bool IsRunning { get { return HasClaude && BunCount > 0; } }
            // Claude alive but plugin dead = zombie session that needs restart
            public bool IsZombie  { get { return HasClaude && BunCount == 0; } }
        }

        public static State GetState()
        {
            var s = new State();
            try
            {
                // Fast pre-check using Process API (kernel call, no WMI overhead).
                // Claude CLI runs as node.exe, so scan node too.
                var claudeProcs = Process.GetProcessesByName("claude");
                var nodeProcs   = Process.GetProcessesByName("node");
                var cmdProcs    = Process.GetProcessesByName("cmd");
                var psProcs     = Process.GetProcessesByName("powershell");
                var bunProcs    = Process.GetProcessesByName("bun");

                s.BunCount = bunProcs.Length;

                // If no candidate processes exist, nothing more to do.
                if (claudeProcs.Length == 0 && nodeProcs.Length == 0 && cmdProcs.Length == 0 && psProcs.Length == 0)
                    return s;

                // Build a targeted WMI query using only the PIDs we already found.
                var pids = new System.Collections.Generic.List<int>();
                foreach (var p in claudeProcs) pids.Add(p.Id);
                foreach (var p in nodeProcs)   pids.Add(p.Id);
                foreach (var p in cmdProcs)    pids.Add(p.Id);
                foreach (var p in psProcs)     pids.Add(p.Id);

                string pidFilter = string.Join(" OR ",
                    System.Linq.Enumerable.Select(pids, id => "ProcessId=" + id));

                var q = new ManagementObjectSearcher(
                    "SELECT ProcessId, Name, CommandLine FROM Win32_Process " +
                    "WHERE " + pidFilter);
                foreach (ManagementObject o in q.Get())
                {
                    string name = (o["Name"] ?? "").ToString();
                    string cmd  = (o["CommandLine"] ?? "").ToString();
                    int    pid  = Convert.ToInt32(o["ProcessId"]);

                    if ((name == "cmd.exe" && cmd.Contains("run-channel")) ||
                        (name == "powershell.exe" && cmd.Contains("run-channel")))
                    { s.HasRunner = true;  s.RunnerPid = pid; }
                    else if ((name == "claude.exe" || name == "node.exe") &&
                             (cmd.Contains("--channels") || cmd.Contains("telegram-channel")))
                    { s.HasClaude = true; s.ClaudePid = pid; }
                }
            }
            catch { }
            return s;
        }

        // ─── Console status print ──────────────────────────────────────────────
        static void PrintStatus()
        {
            var s = GetState();
            Console.WriteLine("=== Claude Telegram Channel ===");
            Console.WriteLine("Status:  " + (s.IsRunning ? "RUNNING" : "STOPPED"));
            if (s.IsRunning)
            {
                Console.WriteLine("Runner:  PID " + s.RunnerPid);
                Console.WriteLine("Claude:  PID " + s.ClaudePid);
                Console.WriteLine("Bun:     " + s.BunCount + " process(es)");
            }
            Console.WriteLine("Bot:     @michaelovsky5c3344545laud5e5_bot");

            // Last 3 debug log lines
            string logPath = Path.Combine(ChannelDir, "tg-debug.log");
            if (File.Exists(logPath))
            {
                try
                {
                    string[] lines = File.ReadAllLines(logPath);
                    int start = Math.Max(0, lines.Length - 3);
                    Console.WriteLine("--- last activity ---");
                    for (int i = start; i < lines.Length; i++)
                        Console.WriteLine(lines[i]);
                }
                catch { }
            }
        }

        // ─── Channel control ───────────────────────────────────────────────────
        public static void StartChannel()
        {
            // Use VBS wrapper for guaranteed zero-popup on Win11
            // VBS oShell.Run style=0 (SW_HIDE) is the ONLY reliable hidden method
            string vbs = Path.Combine(ChannelDir, "tg-channel-startup.vbs");
            if (File.Exists(vbs))
            {
                var psi = new ProcessStartInfo
                {
                    FileName        = "wscript.exe",
                    Arguments       = "//B \"" + vbs + "\"",
                    CreateNoWindow  = true,
                    UseShellExecute = false,
                };
                Process.Start(psi);
            }
            else
            {
                RunPs("-File \"" + Path.Combine(ChannelDir, "launch-channel.ps1") + "\"", hidden: true);
            }
        }

        public static void StopChannel()
        {
            string script =
                "taskkill /F /IM bun.exe 2>$null; " +
                "Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'claude.exe' -or $_.Name -eq 'node.exe') -and ($_.CommandLine -like '*--channels*' -or $_.CommandLine -like '*telegram-channel*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; " +
                "Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'cmd.exe' -or $_.Name -eq 'powershell.exe') -and $_.CommandLine -like '*run-channel*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }";
            RunPs("-Command \"" + script + "\"", hidden: true);
        }

        public static void RestartChannel()
        {
            RunPs("-File \"" + Path.Combine(ChannelDir, "clean-restart.ps1") + "\"", hidden: true);
        }

        public static void RunPs(string psArgs, bool hidden)
        {
            var psi = new ProcessStartInfo
            {
                FileName        = Ps5,
                Arguments       = "-NoProfile -ExecutionPolicy Bypass " + psArgs,
                WindowStyle     = hidden ? ProcessWindowStyle.Hidden : ProcessWindowStyle.Normal,
                CreateNoWindow  = hidden,
                UseShellExecute = true,
            };
            Process.Start(psi);
        }
    }

    // =========================================================================
    //  System Tray Application
    // =========================================================================
    class TrayApp : ApplicationContext
    {
        private readonly NotifyIcon trayIcon;
        private readonly System.Windows.Forms.Timer timer;
        private readonly Mutex ownerMutex;
        private bool wasRunning = false;
        private bool notifiedReady = false;
        private int readyConfirmTicks = 0;         // count consecutive "running" ticks before sending ready
        private const int READY_CONFIRM_THRESHOLD = 5; // 5 consecutive seconds of running before "ready"
        private int zombieTicks = 0;
        private int zombieCooldown = 0;
        private int gatPollTicks = 0;
        private int gatPollInterval = 5;           // starts at 5s, backs off on errors
        // gatLastUpdateId removed — no longer tracking offset to avoid consuming bun's messages
        private int transientErrorCount = 0;
        private int consecutiveGatErrors = 0;      // for exponential backoff
        private int launchCooldown = 0;              // suppress /gat polling after channel start
        private int mcpCheckTicks = 0;               // ticks since ready, to detect dead MCP plugin
        private bool mcpCheckDone = false;            // only check once per session
        private int autoStartTicks = 0;              // ticks channel has been stopped — auto-start after 15s
        private bool autoStartDone = false;           // only auto-start once per tray session
        private DateTime lastInboundTime = DateTime.MinValue;
        private DateTime lastReplyTime = DateTime.MinValue;
        private bool watchdogTriggered = false;
        private DateTime startupTime = DateTime.Now; // track when tray started for startup grace

        private ToolStripMenuItem headerItem, startItem, stopItem, restartItem;

        public TrayApp(Mutex mutex)
        {
            ownerMutex = mutex;

            var menu = new ContextMenuStrip();

            headerItem = new ToolStripMenuItem("Claude Telegram");
            headerItem.Enabled = false;
            headerItem.Font = new Font(headerItem.Font.FontFamily, headerItem.Font.Size, FontStyle.Bold);
            menu.Items.Add(headerItem);
            menu.Items.Add(new ToolStripSeparator());

            startItem   = new ToolStripMenuItem("▶  Start Channel",   null, OnStart);
            stopItem    = new ToolStripMenuItem("■  Stop Channel",    null, OnStop);
            restartItem = new ToolStripMenuItem("↺  Restart Channel", null, OnRestart);
            var tuiItem      = new ToolStripMenuItem("📺  TUI — Live Terminal",  null, OnTui);
            var logDebugItem = new ToolStripMenuItem("📋  Debug Log",            null, OnDebugLog);
            var logChanItem  = new ToolStripMenuItem("📄  Channel Log",          null, OnChannelLog);
            var exitItem     = new ToolStripMenuItem("✖  Exit Tray",             null, OnExit);

            menu.Items.Add(startItem);
            menu.Items.Add(stopItem);
            menu.Items.Add(restartItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(tuiItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(logDebugItem);
            menu.Items.Add(logChanItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(exitItem);

            trayIcon = new NotifyIcon
            {
                ContextMenuStrip = menu,
                Visible          = true,
                Icon             = MakeIcon(IconState.Stopped),
                Text             = "Claude Telegram Channel"
            };
            trayIcon.DoubleClick += OnTui;

            timer = new System.Windows.Forms.Timer { Interval = 1000 };
            timer.Tick += OnTick;
            timer.Start();

            // Capture current state BEFORE first Tick so startup balloon only fires
            // when channel transitions from stopped → running (not if already running)
            // Channel auto-start is handled by TgChannel Task Scheduler task — not here.
            wasRunning = Program.GetState().IsRunning;

            Tick(); // immediate first update
        }

        // ─── Icon ─────────────────────────────────────────────────────────────
        static Icon MakeIcon(IconState state)
        {
            var bmp = new Bitmap(32, 32, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.Clear(Color.Transparent);

                Color bg = state == IconState.Running   ? Color.FromArgb(39, 174, 96)   // green
                         : state == IconState.Connecting ? Color.FromArgb(230, 168, 0)   // yellow
                                                         : Color.FromArgb(192, 57,  43); // red
                using (var b = new SolidBrush(bg))
                    g.FillEllipse(b, 1, 1, 29, 29);
                using (var p = new Pen(Color.FromArgb(210, 210, 210), 1.5f))
                    g.DrawEllipse(p, 1, 1, 29, 29);

                var sf = new StringFormat
                {
                    Alignment     = StringAlignment.Center,
                    LineAlignment = StringAlignment.Center
                };
                using (var f  = new Font("Arial", 10.5f, FontStyle.Bold))
                using (var tb = new SolidBrush(Color.White))
                    g.DrawString("TG", f, tb, new RectangleF(1, 1, 29, 29), sf);
            }
            return Icon.FromHandle(bmp.GetHicon());
        }

        // ─── Polling ──────────────────────────────────────────────────────────
        void OnTick(object sender, EventArgs e) { Tick(); }

        void Tick()
        {
            var s = Program.GetState();

            // Auto-recover zombie: claude alive but plugin dead → kill & restart
            // Only attempt once per cooldown period to avoid restart loops
            // Skip zombie detection during first 60s after tray startup (channel needs time to init)
            bool inStartupGrace = (DateTime.Now - startupTime).TotalSeconds < 30;
            if (s.IsZombie && zombieCooldown <= 0 && !inStartupGrace)
            {
                zombieTicks++;
                // Give plugin 45 seconds to start (increased from 30), then force restart ONCE
                if (zombieTicks > 45)
                {
                    zombieTicks = 0;
                    zombieCooldown = 180; // Don't retry for 3 minutes (increased from 2)
                    DebugLog("ZOMBIE detected: Claude alive (PID " + s.ClaudePid + ") but plugin dead — killing and restarting");
                    SendTelegramAsync("Zombie detected: Claude alive but Telegram plugin dead. Auto-restarting...");
                    try
                    {
                        if (s.ClaudePid > 0)
                            Process.GetProcessById(s.ClaudePid).Kill();
                    }
                    catch { }
                    launchCooldown = 45;
                    Program.RestartChannel();
                }
            }
            else if (!s.IsZombie)
            {
                zombieTicks = 0;
            }
            if (zombieCooldown > 0) zombieCooldown--;
            if (launchCooldown > 0) launchCooldown--;

            // Determine 3-state icon: green=running, yellow=connecting, red=stopped
            IconState iconState = s.IsRunning    ? IconState.Running
                                : (s.HasRunner || s.HasClaude) ? IconState.Connecting
                                                : IconState.Stopped;

            trayIcon.Icon = MakeIcon(iconState);

            string header = iconState == IconState.Running    ? "Claude Telegram  [RUNNING]"
                          : iconState == IconState.Connecting ? "Claude Telegram  [CONNECTING]"
                                                              : "Claude Telegram  [STOPPED]";
            headerItem.Text = header;

            trayIcon.Text = iconState == IconState.Running
                ? "Claude Telegram: RUNNING"
                : iconState == IconState.Connecting
                    ? "Claude Telegram: CONNECTING..."
                    : "Claude Telegram: STOPPED";

            startItem.Enabled   = !s.IsRunning;
            stopItem.Enabled    =  s.IsRunning;
            restartItem.Enabled =  true;

            // Track consecutive running ticks for confirmed readiness
            if (s.IsRunning)
                readyConfirmTicks++;
            else
                readyConfirmTicks = 0;

            if (s.IsRunning && !wasRunning)
            {
                Balloon("Telegram Connecting", "Claude Telegram channel detected, confirming...", ToolTipIcon.Info);
            }
            else if (!s.IsRunning && wasRunning)
            {
                Balloon("Channel Offline", "Claude Telegram went offline.", ToolTipIcon.Warning);
            }

            // Only send "ready" after READY_CONFIRM_THRESHOLD consecutive seconds of running
            // This ensures bun plugin is actually stable and responding, not just briefly alive
            if (!notifiedReady && readyConfirmTicks >= READY_CONFIRM_THRESHOLD)
            {
                notifiedReady = true;
                mcpCheckTicks = 0;
                mcpCheckDone = false;
                Balloon("Telegram Ready", "Claude Telegram is connected and ready.", ToolTipIcon.Info);
                SendTelegramAsync("Claude channel is ready. Send me a message!");
            }

            // MCP dead-plugin detection: 45s after "ready", check debug log for MCP timeout
            // If MCP telegram timed out, claude is running but can't receive messages → restart
            if (notifiedReady && !mcpCheckDone && s.IsRunning)
            {
                mcpCheckTicks++;
                if (mcpCheckTicks >= 45)
                {
                    mcpCheckDone = true;
                    ThreadPool.QueueUserWorkItem(delegate
                    {
                        try
                        {
                            string debugLog = Path.Combine(Program.ChannelDir, "claude-full-debug.log");
                            if (File.Exists(debugLog))
                            {
                                string[] lines = File.ReadAllLines(debugLog);
                                bool connected = false;
                                bool timedOut = false;
                                // Check last 100 lines for MCP telegram status
                                int start = Math.Max(0, lines.Length - 100);
                                for (int i = start; i < lines.Length; i++)
                                {
                                    if (lines[i].Contains("plugin:telegram:telegram") && lines[i].Contains("Channel notifications registered"))
                                        connected = true;
                                    if (lines[i].Contains("plugin:telegram:telegram") && lines[i].Contains("Connection failed"))
                                    { timedOut = true; connected = false; }
                                }
                                if (timedOut && !connected)
                                {
                                    DebugLog("MCP DEAD: telegram plugin connection failed but claude still running — restarting");
                                    SendTelegramAsync("MCP telegram plugin timed out on startup. Auto-restarting...");
                                    Thread.Sleep(500);
                                    launchCooldown = 45;
                                    Program.RestartChannel();
                                }
                            }
                        }
                        catch { }
                    });
                }
            }

            // NOTE: wasRunning is set at the END of Tick() so transition
            // detection (autoStartDone reset, balloon logic) sees the OLD value.

            // ─── Response watchdog ──────────────────────────────────────────
            // If channel is running, scan tg-debug.log for INBOUND without REPLY within 90s
            if (s.IsRunning)
            {
                try
                {
                    string logPath = Path.Combine(Program.ChannelDir, "tg-debug.log");
                    if (File.Exists(logPath))
                    {
                        string[] lines = File.ReadAllLines(logPath);
                        DateTime newestInbound = DateTime.MinValue;
                        DateTime newestReply   = DateTime.MinValue;

                        // Scan last 50 lines for efficiency
                        int start = Math.Max(0, lines.Length - 50);
                        for (int i = start; i < lines.Length; i++)
                        {
                            string line = lines[i];
                            if (line.Length < 21) continue;
                            // Parse timestamp from "[yyyy-MM-dd HH:mm:ss]"
                            DateTime ts;
                            if (!DateTime.TryParse(line.Substring(1, 19), out ts)) continue;

                            if (line.Contains("INBOUND"))
                                newestInbound = ts;
                            else if (line.Contains("REPLY"))
                                newestReply = ts;
                        }

                        lastInboundTime = newestInbound;
                        lastReplyTime   = newestReply;

                        if (lastInboundTime > DateTime.MinValue &&
                            lastInboundTime > lastReplyTime &&
                            (DateTime.Now - lastInboundTime).TotalSeconds > 60)
                        {
                            if (!watchdogTriggered)
                            {
                                watchdogTriggered = true;
                                DebugLog("WATCHDOG: INBOUND at " + lastInboundTime.ToString("HH:mm:ss") + " with no REPLY after 60s — restarting channel");
                                SendTelegramAsync("Watchdog: no response after 60s, restarting channel...");
                                Thread.Sleep(500);
                                launchCooldown = 45;
                                Program.RestartChannel();
                            }
                        }
                        else
                        {
                            watchdogTriggered = false;
                        }
                    }
                }
                catch (Exception ex)
                {
                    DebugLog("Watchdog scan error: " + ex.Message);
                }
            }
            else
            {
                watchdogTriggered = false;
            }

            // ─── Auto-start: if channel is fully stopped for 15s, start it ─────
            // This is the PRIMARY startup mechanism. TgChannel Task Scheduler is backup.
            if (!s.IsRunning && !s.HasClaude && !s.HasRunner && launchCooldown <= 0)
            {
                autoStartTicks++;
                if (!autoStartDone && autoStartTicks >= 15)
                {
                    autoStartDone = true;
                    autoStartTicks = 0;
                    DebugLog("AUTO-START: Channel stopped for 15s — starting channel");
                    launchCooldown = 60; // prevent rapid restart loops
                    Program.StartChannel();
                }
            }
            else if (s.IsRunning)
            {
                autoStartTicks = 0;
                // Reset autoStartDone when channel goes offline (to allow re-auto-start)
                // But NOT here — only reset when it transitions to stopped (handled below)
            }

            // Reset auto-start flag when channel transitions from running to stopped
            // This allows auto-start to fire again if channel dies later
            if (!s.IsRunning && wasRunning)
            {
                autoStartDone = false;
                autoStartTicks = 0;
            }

            // Poll for /gat command ONLY when channel is stopped (bun not long-polling)
            if (!s.IsRunning && !s.HasClaude)
            {
                gatPollTicks++;
                if (gatPollTicks >= gatPollInterval)
                {
                    gatPollTicks = 0;
                    PollForGatCommand();
                }
            }
            else
            {
                gatPollTicks = 0;
                gatPollInterval = 5; // reset backoff when channel is running
                consecutiveGatErrors = 0;
            }

            // Update wasRunning LAST so all transition detection above sees the OLD value
            wasRunning = s.IsRunning;
        }

        void PollForGatCommand()
        {
            // Skip polling during startup grace period (first 10s) — network often not ready
            if ((DateTime.Now - startupTime).TotalSeconds < 10) return;
            // Skip polling during launch cooldown (prevents 409 Conflict race with bun)
            if (launchCooldown > 0) return;

            ThreadPool.QueueUserWorkItem(delegate
            {
                try
                {
                    // Quick network check: skip if no network interface is up
                    if (!System.Net.NetworkInformation.NetworkInterface.GetIsNetworkAvailable())
                    {
                        consecutiveGatErrors++;
                        gatPollInterval = Math.Min(60, 5 * (1 + consecutiveGatErrors)); // backoff up to 60s
                        return;
                    }

                    using (var wc = new WebClient())
                    {
                        // NEVER send offset= here — that would acknowledge (consume) messages
                        // meant for bun. Only peek at the latest 5 updates without consuming them.
                        string url = "https://api.telegram.org/bot8689142235:AAFSkrKNpFlRJXqYa8PC-4tdK1CFsnQKawA/getUpdates?limit=5&timeout=0";
                        string json = wc.DownloadString(url);

                        // Success — reset backoff
                        consecutiveGatErrors = 0;
                        gatPollInterval = 5;

                        // Look for /gat command from our user — don't track offset for non-/gat messages
                        bool foundGat = false;
                        long maxUpdateId = 0;

                        int idx = 0;
                        while ((idx = json.IndexOf("\"update_id\":", idx)) >= 0)
                        {
                            idx += 12;
                            int end = idx;
                            while (end < json.Length && char.IsDigit(json[end])) end++;
                            long uid;
                            if (long.TryParse(json.Substring(idx, end - idx), out uid))
                            {
                                if (uid > maxUpdateId)
                                    maxUpdateId = uid;
                            }
                        }

                        if (json.Contains("\"text\":\"/gat\"") || json.Contains("\"text\":\"/gat@"))
                        {
                            if (json.Contains("\"id\":716239770"))
                                foundGat = true;
                        }

                        if (foundGat && maxUpdateId > 0)
                        {
                            // Only NOW acknowledge updates — drain up to and including the /gat message
                            try { wc.DownloadString("https://api.telegram.org/bot8689142235:AAFSkrKNpFlRJXqYa8PC-4tdK1CFsnQKawA/getUpdates?offset=" + (maxUpdateId + 1) + "&limit=1&timeout=0"); } catch {}
                            SendTelegramAsync("Reconnecting... (force restart via /gat)");
                            Thread.Sleep(500);
                            Program.RestartChannel();
                        }
                    }
                }
                catch (Exception ex)
                {
                    consecutiveGatErrors++;
                    // Exponential backoff: 5s → 10s → 20s → 40s → 60s max
                    gatPollInterval = Math.Min(60, 5 * (1 << Math.Min(consecutiveGatErrors, 4)));

                    var wex = ex as WebException;
                    if (wex != null && IsTransientWebError(wex))
                    {
                        transientErrorCount++;
                        // Log less frequently as errors pile up (every 10th instead of 5th)
                        if (transientErrorCount <= 3 || transientErrorCount % 10 == 0)
                            DebugLog("PollForGatCommand transient error (#" + transientErrorCount + ", backoff=" + gatPollInterval + "s): " + wex.Status);
                    }
                    else
                    {
                        // Only log fatal errors occasionally (not every 5s flooding the log)
                        if (consecutiveGatErrors <= 3 || consecutiveGatErrors % 10 == 0)
                            DebugLog("PollForGatCommand error (#" + consecutiveGatErrors + ", backoff=" + gatPollInterval + "s): " + ex.GetType().Name + " - " + ex.Message);
                    }
                }
            });
        }

        static void SendTelegramAsync(string text)
        {
            ThreadPool.QueueUserWorkItem(delegate
            {
                for (int attempt = 0; attempt < 2; attempt++)
                {
                    try
                    {
                        using (var wc = new WebClient())
                        {
                            var nv = new NameValueCollection();
                            nv["chat_id"]    = "716239770";
                            nv["text"]       = text;
                            nv["parse_mode"] = "HTML";
                            wc.UploadValues(
                                "https://api.telegram.org/bot8689142235:AAFSkrKNpFlRJXqYa8PC-4tdK1CFsnQKawA/sendMessage",
                                nv);
                        }
                        return; // success — exit
                    }
                    catch (Exception ex)
                    {
                        var wex = ex as WebException;
                        bool transient = wex != null && IsTransientWebError(wex);
                        if (transient && attempt == 0)
                        {
                            DebugLog("SendTelegram transient error, retrying in 2s: " + ex.Message);
                            Thread.Sleep(2000);
                            continue; // retry once
                        }
                        DebugLog("SendTelegram " + (transient ? "transient" : "FATAL") + " error: " + ex.GetType().Name + " - " + ex.Message);
                    }
                }
            });
        }

        // ─── Debug logging helper ────────────────────────────────────────────
        static void DebugLog(string msg)
        {
            try
            {
                string path = Path.Combine(Program.ChannelDir, "tg-debug.log");
                File.AppendAllText(path, "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] [TRAY] " + msg + Environment.NewLine);
            }
            catch { }
        }

        static bool IsTransientWebError(WebException wex)
        {
            if (wex.Status == WebExceptionStatus.Timeout ||
                wex.Status == WebExceptionStatus.ConnectFailure ||
                wex.Status == WebExceptionStatus.NameResolutionFailure ||
                wex.Status == WebExceptionStatus.SecureChannelFailure ||   // SSL/TLS handshake failure
                wex.Status == WebExceptionStatus.SendFailure ||            // network send failure
                wex.Status == WebExceptionStatus.ReceiveFailure ||         // network receive failure
                wex.Status == WebExceptionStatus.RequestCanceled)          // aborted request
                return true;
            var resp = wex.Response as HttpWebResponse;
            if (resp != null)
            {
                int code = (int)resp.StatusCode;
                return code == 409 || code == 503 || code == 502 || code == 429 || code >= 500;
            }
            // If the exception message or inner exception mentions SSL/TLS, treat as transient
            // "Could not create SSL/TLS secure channel" often shows as SendFailure or UnknownError
            if (wex.Message.Contains("SSL") || wex.Message.Contains("TLS") || wex.Message.Contains("secure channel"))
                return true;
            if (wex.InnerException != null &&
                (wex.InnerException.Message.Contains("SSL") || wex.InnerException.Message.Contains("TLS") || wex.InnerException.Message.Contains("secure channel")))
                return true;
            return false;
        }

        void Balloon(string title, string text, ToolTipIcon icon)
        {
            trayIcon.BalloonTipTitle = title;
            trayIcon.BalloonTipText  = text;
            trayIcon.BalloonTipIcon  = icon;
            trayIcon.ShowBalloonTip(4000);
        }

        // ─── Menu handlers ────────────────────────────────────────────────────
        void OnStart(object sender, EventArgs e)
        {
            Program.StartChannel();
            launchCooldown = 45; // suppress /gat polling for 45s to avoid 409 race with bun
            Balloon("Starting", "Channel starting up... ~5-10s.", ToolTipIcon.Info);
        }

        void OnStop(object sender, EventArgs e)
        {
            Program.StopChannel();
            Balloon("Stopping", "Sending stop signal...", ToolTipIcon.Info);
        }

        void OnRestart(object sender, EventArgs e)
        {
            Program.RestartChannel();
            launchCooldown = 45;
            Balloon("Restarting", "Clean restart initiated... allow ~15s.", ToolTipIcon.Info);
        }

        void OnTui(object sender, EventArgs e)
        {
            Program.OpenTui();
        }

        void OnDebugLog(object sender, EventArgs e)
        {
            OpenFile(Path.Combine(Program.ChannelDir, "tg-debug.log"));
        }

        void OnChannelLog(object sender, EventArgs e)
        {
            OpenFile(Path.Combine(Program.ChannelDir, "channel.log"));
        }

        static void OpenFile(string path)
        {
            if (File.Exists(path))
                Process.Start("notepad.exe", path);
            // File not found: silently ignore — no popup
        }

        void OnExit(object sender, EventArgs e)
        {
            trayIcon.Visible = false;
            Application.Exit();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                if (timer != null) timer.Dispose();
                if (trayIcon != null) trayIcon.Dispose();
                if (ownerMutex != null) ownerMutex.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
