using Microsoft.Win32;
using System.Diagnostics;
using System.Text.RegularExpressions;

namespace UninstallPro;

// ─── Data Models ───────────────────────────────────────────────
public sealed class AppInfo
{
    public string Name { get; set; } = "";
    public string Version { get; set; } = "";
    public string Publisher { get; set; } = "";
    public string InstallDate { get; set; } = "";
    public string InstallLocation { get; set; } = "";
    public string UninstallCmd { get; set; } = "";
    public string QuietUninstallCmd { get; set; } = "";
    public long SizeBytes { get; set; }
    public string RegKey { get; set; } = "";
    public string IconPath { get; set; } = "";
    public bool IsUpdate { get; set; }
    public bool IsStoreApp { get; set; }
    public string StorePackageName { get; set; } = "";

    public string SizeText => SizeBytes switch
    {
        <= 0 => "",
        < 1024 => $"{SizeBytes} B",
        < 1048576 => $"{SizeBytes / 1024.0:F1} KB",
        < 1073741824 => $"{SizeBytes / 1048576.0:F1} MB",
        _ => $"{SizeBytes / 1073741824.0:F2} GB"
    };

    public string DateText
    {
        get
        {
            if (string.IsNullOrWhiteSpace(InstallDate) || InstallDate.Length != 8) return "";
            try { return $"{InstallDate[..4]}-{InstallDate[4..6]}-{InstallDate[6..8]}"; }
            catch { return InstallDate; }
        }
    }
}

public sealed class CleanupResult
{
    public bool Success { get; set; }
    public int FilesRemoved { get; set; }
    public int FoldersRemoved { get; set; }
    public int RegKeysRemoved { get; set; }
    public long BytesFreed { get; set; }
    public List<string> Errors { get; set; } = [];
    public TimeSpan Duration { get; set; }
}

public sealed class JunkItem
{
    public string Path { get; set; } = "";
    public long Size { get; set; }
    public string Category { get; set; } = "";
    public DateTime LastAccess { get; set; }
}

public sealed class StartupEntry
{
    public string Name { get; set; } = "";
    public string Command { get; set; } = "";
    public string Location { get; set; } = "";
    public bool Enabled { get; set; } = true;
    public string Source { get; set; } = "";
}

// ─── Engine ────────────────────────────────────────────────────
public sealed class Engine
{
    private static readonly string[] UninstallPaths =
    [
        @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    ];

    // ── Installed Programs ─────────────────────────────────────
    public List<AppInfo> GetInstalledPrograms(bool includeUpdates = false)
    {
        var result = new List<AppInfo>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var path in UninstallPaths)
        {
            Scan(Registry.LocalMachine, path, result, seen, includeUpdates);
            Scan(Registry.CurrentUser, path, result, seen, includeUpdates);
        }

        return result.OrderBy(a => a.Name, StringComparer.OrdinalIgnoreCase).ToList();
    }

    private static void Scan(RegistryKey root, string path, List<AppInfo> list, HashSet<string> seen, bool includeUpdates)
    {
        try
        {
            using var key = root.OpenSubKey(path);
            if (key == null) return;

            foreach (var sub in key.GetSubKeyNames())
            {
                try
                {
                    using var sk = key.OpenSubKey(sub);
                    if (sk == null) continue;

                    var name = sk.GetValue("DisplayName")?.ToString();
                    if (string.IsNullOrWhiteSpace(name) || !seen.Add(name)) continue;

                    if (sk.GetValue("SystemComponent") is int sc && sc == 1) continue;

                    var isUpd = IsUpdateEntry(name);
                    if (!includeUpdates && isUpd) continue;

                    var app = new AppInfo
                    {
                        Name = name,
                        Version = sk.GetValue("DisplayVersion")?.ToString() ?? "",
                        Publisher = sk.GetValue("Publisher")?.ToString() ?? "",
                        InstallDate = sk.GetValue("InstallDate")?.ToString() ?? "",
                        InstallLocation = sk.GetValue("InstallLocation")?.ToString() ?? "",
                        UninstallCmd = sk.GetValue("UninstallString")?.ToString() ?? "",
                        QuietUninstallCmd = sk.GetValue("QuietUninstallString")?.ToString() ?? "",
                        IconPath = sk.GetValue("DisplayIcon")?.ToString() ?? "",
                        RegKey = $"{root.Name}\\{path}\\{sub}",
                        IsUpdate = isUpd,
                        SizeBytes = TryGetSize(sk)
                    };

                    list.Add(app);
                }
                catch { }
            }
        }
        catch { }
    }

    private static long TryGetSize(RegistryKey k)
    {
        var v = k.GetValue("EstimatedSize");
        return v != null ? Convert.ToInt64(v) * 1024 : 0;
    }

    private static bool IsUpdateEntry(string name) =>
        Regex.IsMatch(name, @"(update for|hotfix|security update|kb\d{6,}|service pack)", RegexOptions.IgnoreCase);

    // ── Store Apps ─────────────────────────────────────────────
    public async Task<List<AppInfo>> GetStoreApps()
    {
        var apps = new List<AppInfo>();
        try
        {
            var psi = new ProcessStartInfo("powershell.exe",
                "-NoProfile -Command \"Get-AppxPackage | Where-Object {$_.IsFramework -eq $false} | Select-Object Name, PackageFullName, Version, Publisher, InstallLocation | ConvertTo-Csv -NoTypeInformation\"")
            {
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using var proc = Process.Start(psi);
            if (proc == null) return apps;

            var output = await proc.StandardOutput.ReadToEndAsync();
            await proc.WaitForExitAsync();

            foreach (var line in output.Split('\n').Skip(1))
            {
                var cols = ParseCsvLine(line);
                if (cols.Length < 5 || string.IsNullOrWhiteSpace(cols[0])) continue;

                var friendlyName = cols[0].Trim('"').Split('.').Last();
                if (friendlyName.Length < 2) friendlyName = cols[0].Trim('"');

                long size = 0;
                try
                {
                    var loc = cols[4].Trim('"', '\r');
                    if (Directory.Exists(loc))
                        size = new DirectoryInfo(loc).EnumerateFiles("*", SearchOption.AllDirectories)
                            .Sum(f => { try { return f.Length; } catch { return 0L; } });
                }
                catch { }

                apps.Add(new AppInfo
                {
                    Name = friendlyName,
                    Version = cols[2].Trim('"'),
                    Publisher = cols[3].Trim('"'),
                    InstallLocation = cols[4].Trim('"', '\r'),
                    IsStoreApp = true,
                    StorePackageName = cols[1].Trim('"'),
                    SizeBytes = size
                });
            }
        }
        catch { }

        return apps.OrderBy(a => a.Name).ToList();
    }

    private static string[] ParseCsvLine(string line)
    {
        var parts = new List<string>();
        bool inQuotes = false;
        var current = new System.Text.StringBuilder();

        foreach (char c in line)
        {
            if (c == '"') { inQuotes = !inQuotes; current.Append(c); }
            else if (c == ',' && !inQuotes) { parts.Add(current.ToString()); current.Clear(); }
            else current.Append(c);
        }
        parts.Add(current.ToString());
        return parts.ToArray();
    }

    // ── Uninstall ──────────────────────────────────────────────
    public async Task<CleanupResult> Uninstall(AppInfo app, bool deep, IProgress<string>? progress = null)
    {
        var sw = Stopwatch.StartNew();
        var result = new CleanupResult();

        try
        {
            // Store app
            if (app.IsStoreApp)
            {
                progress?.Report($"Removing Store app: {app.Name}...");
                var ok = await RunPowerShell($"Remove-AppxPackage -Package '{app.StorePackageName}'");
                result.Success = ok;
                if (!ok) result.Errors.Add("Store app removal failed");
                result.Duration = sw.Elapsed;
                return result;
            }

            // Create restore point (async, don't wait too long)
            progress?.Report("Creating system restore point...");
            _ = Task.Run(() => CreateRestorePoint(app.Name));

            // Run native uninstaller
            progress?.Report($"Running uninstaller for {app.Name}...");
            var uninstallOk = await RunNativeUninstaller(app);

            // Deep scan for leftovers
            if (deep)
            {
                progress?.Report("Scanning for leftover files...");
                await Task.Delay(1500);

                var leftovers = FindLeftovers(app);

                // Clean leftover files
                foreach (var file in leftovers.files)
                {
                    try { File.Delete(file); result.FilesRemoved++; result.BytesFreed += new FileInfo(file).Length; }
                    catch (Exception ex) { result.Errors.Add($"File: {file} - {ex.Message}"); }
                }

                progress?.Report("Cleaning leftover folders...");
                foreach (var dir in leftovers.dirs.OrderByDescending(d => d.Length))
                {
                    try
                    {
                        if (Directory.Exists(dir) && !Directory.EnumerateFileSystemEntries(dir).Any())
                        {
                            Directory.Delete(dir);
                            result.FoldersRemoved++;
                        }
                    }
                    catch (Exception ex) { result.Errors.Add($"Dir: {dir} - {ex.Message}"); }
                }

                progress?.Report("Cleaning leftover registry entries...");
                foreach (var rk in leftovers.regKeys)
                {
                    try { DeleteRegKey(rk); result.RegKeysRemoved++; }
                    catch (Exception ex) { result.Errors.Add($"Reg: {rk} - {ex.Message}"); }
                }
            }

            // Remove main reg entry
            try { DeleteRegKey(app.RegKey); result.RegKeysRemoved++; } catch { }

            result.Success = uninstallOk || result.FilesRemoved > 0;
        }
        catch (Exception ex) { result.Errors.Add(ex.Message); }

        result.Duration = sw.Elapsed;
        return result;
    }

    public async Task<CleanupResult> ForceRemove(AppInfo app, IProgress<string>? progress = null)
    {
        var sw = Stopwatch.StartNew();
        var result = new CleanupResult();

        try
        {
            if (app.IsStoreApp)
                return await Uninstall(app, false, progress);

            _ = Task.Run(() => CreateRestorePoint($"Force: {app.Name}"));

            if (!string.IsNullOrWhiteSpace(app.InstallLocation) && Directory.Exists(app.InstallLocation))
            {
                progress?.Report($"Deleting: {app.InstallLocation}...");
                var files = Directory.GetFiles(app.InstallLocation, "*", SearchOption.AllDirectories);
                foreach (var f in files)
                {
                    try { var len = new FileInfo(f).Length; File.Delete(f); result.FilesRemoved++; result.BytesFreed += len; }
                    catch (Exception ex) { result.Errors.Add($"{f}: {ex.Message}"); }
                }

                try { Directory.Delete(app.InstallLocation, true); result.FoldersRemoved++; } catch { }
            }

            progress?.Report("Removing registry entries...");
            try { DeleteRegKey(app.RegKey); result.RegKeysRemoved++; } catch { }

            result.Success = true;
        }
        catch (Exception ex) { result.Errors.Add(ex.Message); }

        result.Duration = sw.Elapsed;
        return result;
    }

    // ── Junk Files ─────────────────────────────────────────────
    public List<JunkItem> ScanJunk()
    {
        var items = new List<JunkItem>();
        var paths = new (string path, string category)[]
        {
            (Path.GetTempPath(), "Windows Temp"),
            (Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Temp"), "User Temp"),
            (Environment.GetFolderPath(Environment.SpecialFolder.InternetCache), "Browser Cache"),
            (Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "CrashDumps"), "Crash Dumps"),
            (@"C:\Windows\Prefetch", "Prefetch"),
            (Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Microsoft", "Windows", "Explorer"), "Thumbnail Cache"),
        };

        foreach (var (path, category) in paths)
        {
            if (!Directory.Exists(path)) continue;
            try
            {
                foreach (var file in Directory.EnumerateFiles(path, "*", SearchOption.AllDirectories))
                {
                    try
                    {
                        var fi = new FileInfo(file);
                        if ((DateTime.Now - fi.LastAccessTime).TotalDays > 7)
                        {
                            items.Add(new JunkItem { Path = file, Size = fi.Length, Category = category, LastAccess = fi.LastAccessTime });
                        }
                    }
                    catch { }
                }
            }
            catch { }
        }

        return items;
    }

    public (int deleted, long bytesFreed) CleanJunk(List<JunkItem> items)
    {
        int deleted = 0; long freed = 0;
        foreach (var item in items)
        {
            try { File.Delete(item.Path); deleted++; freed += item.Size; }
            catch { }
        }
        return (deleted, freed);
    }

    // ── Startup Programs ───────────────────────────────────────
    public List<StartupEntry> GetStartupEntries()
    {
        var entries = new List<StartupEntry>();
        var regPaths = new[]
        {
            (Registry.CurrentUser, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKCU Run"),
            (Registry.LocalMachine, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKLM Run"),
            (Registry.LocalMachine, @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run", "HKLM Run (x86)"),
        };

        foreach (var (root, path, source) in regPaths)
        {
            try
            {
                using var key = root.OpenSubKey(path);
                if (key == null) continue;
                foreach (var name in key.GetValueNames())
                {
                    var val = key.GetValue(name)?.ToString() ?? "";
                    entries.Add(new StartupEntry { Name = name, Command = val, Location = $"{root.Name}\\{path}", Source = source, Enabled = true });
                }
            }
            catch { }
        }

        // Startup folders
        foreach (var folder in new[] { Environment.GetFolderPath(Environment.SpecialFolder.Startup),
                                       Environment.GetFolderPath(Environment.SpecialFolder.CommonStartup) })
        {
            if (!Directory.Exists(folder)) continue;
            try
            {
                foreach (var file in Directory.GetFiles(folder))
                    entries.Add(new StartupEntry { Name = Path.GetFileName(file), Command = file, Location = folder, Source = "Startup Folder", Enabled = true });
            }
            catch { }
        }

        return entries.OrderBy(e => e.Name).ToList();
    }

    public bool DeleteStartupEntry(StartupEntry entry)
    {
        try
        {
            if (entry.Source == "Startup Folder")
            {
                if (File.Exists(entry.Command)) { File.Delete(entry.Command); return true; }
                return false;
            }

            // Registry
            var parts = entry.Location.Split('\\', 2);
            if (parts.Length != 2) return false;
            var root = parts[0].Contains("LOCAL_MACHINE") ? Registry.LocalMachine : Registry.CurrentUser;
            using var key = root.OpenSubKey(parts[1], writable: true);
            key?.DeleteValue(entry.Name, throwOnMissingValue: false);
            return true;
        }
        catch { return false; }
    }

    // ── Helpers ─────────────────────────────────────────────────
    private async Task<bool> RunNativeUninstaller(AppInfo app)
    {
        var cmd = !string.IsNullOrWhiteSpace(app.QuietUninstallCmd) ? app.QuietUninstallCmd : app.UninstallCmd;
        if (string.IsNullOrWhiteSpace(cmd)) return false;

        try
        {
            var (exe, args) = ParseCommand(cmd);
            if (string.IsNullOrWhiteSpace(app.QuietUninstallCmd))
                args = AddSilentFlags(exe, args);

            var psi = new ProcessStartInfo(exe, args) { UseShellExecute = false, CreateNoWindow = true };
            using var proc = Process.Start(psi);
            if (proc == null) return false;

            await proc.WaitForExitAsync().WaitAsync(TimeSpan.FromMinutes(5));
            return proc.ExitCode == 0;
        }
        catch { return false; }
    }

    private static (string exe, string args) ParseCommand(string cmd)
    {
        cmd = cmd.Trim();
        if (cmd.StartsWith('"'))
        {
            var end = cmd.IndexOf('"', 1);
            if (end > 0) return (cmd[1..end], cmd[(end + 1)..].Trim());
        }
        var space = cmd.IndexOf(' ');
        return space > 0 ? (cmd[..space], cmd[(space + 1)..]) : (cmd, "");
    }

    private static string AddSilentFlags(string exe, string args)
    {
        var lower = Path.GetFileName(exe).ToLower();
        if (lower.Contains("msiexec") && !args.Contains("/qn")) args += " /qn /norestart";
        else if (!args.Contains("/S") && !args.Contains("/silent")) args += " /S";
        return args;
    }

    private static (List<string> files, List<string> dirs, List<string> regKeys) FindLeftovers(AppInfo app)
    {
        var files = new List<string>();
        var dirs = new List<string>();
        var regKeys = new List<string>();

        var searchName = Regex.Replace(app.Name, @"[\d\.\s]+(x64|x86|32|64)?", "", RegexOptions.IgnoreCase).Trim();
        if (searchName.Length < 3) searchName = app.Name.Split(' ')[0];

        var searchDirs = new[]
        {
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData)
        };

        foreach (var baseDir in searchDirs.Where(Directory.Exists))
        {
            try
            {
                foreach (var dir in Directory.GetDirectories(baseDir))
                {
                    var dn = Path.GetFileName(dir).ToLower();
                    if (dn.Contains(searchName.ToLower()) ||
                        (!string.IsNullOrWhiteSpace(app.Publisher) && dn.Contains(app.Publisher.ToLower())))
                    {
                        dirs.Add(dir);
                        try { files.AddRange(Directory.GetFiles(dir, "*", SearchOption.AllDirectories)); } catch { }
                    }
                }
            }
            catch { }
        }

        // Registry leftovers
        foreach (var (root, basePath) in new[] { (Registry.LocalMachine, "SOFTWARE"), (Registry.CurrentUser, "SOFTWARE") })
        {
            try
            {
                using var key = root.OpenSubKey(basePath);
                if (key == null) continue;
                foreach (var sub in key.GetSubKeyNames())
                {
                    if (sub.ToLower().Contains(searchName.ToLower()))
                        regKeys.Add($"{root.Name}\\{basePath}\\{sub}");
                }
            }
            catch { }
        }

        return (files, dirs, regKeys);
    }

    private static void DeleteRegKey(string fullPath)
    {
        var parts = fullPath.Split('\\', 2);
        if (parts.Length < 2) return;
        var root = parts[0] switch
        {
            "HKEY_LOCAL_MACHINE" => Registry.LocalMachine,
            "HKEY_CURRENT_USER" => Registry.CurrentUser,
            "HKEY_CLASSES_ROOT" => Registry.ClassesRoot,
            _ => (RegistryKey?)null
        };
        if (root == null) return;
        var last = parts[1].LastIndexOf('\\');
        if (last <= 0) return;
        using var parent = root.OpenSubKey(parts[1][..last], writable: true);
        parent?.DeleteSubKeyTree(parts[1][(last + 1)..], throwOnMissingSubKey: false);
    }

    private static void CreateRestorePoint(string desc)
    {
        try
        {
            var psi = new ProcessStartInfo("powershell.exe",
                $"-NoProfile -Command \"Checkpoint-Computer -Description 'UninstallPro: {desc}' -RestorePointType APPLICATION_UNINSTALL\"")
            { CreateNoWindow = true, UseShellExecute = false };
            using var p = Process.Start(psi);
            p?.WaitForExit(15000);
        }
        catch { }
    }

    private static async Task<bool> RunPowerShell(string command)
    {
        try
        {
            var psi = new ProcessStartInfo("powershell.exe", $"-NoProfile -Command \"{command}\"")
            {
                RedirectStandardOutput = true, RedirectStandardError = true,
                UseShellExecute = false, CreateNoWindow = true
            };
            using var proc = Process.Start(psi);
            if (proc == null) return false;
            await proc.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(60));
            return proc.ExitCode == 0;
        }
        catch { return false; }
    }
}
