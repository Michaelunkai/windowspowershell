using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32;

class UltimateUninstallerNuclear
{
    private static long totalItems = 0;
    private static long processedItems = 0;
    private static object lockObj = new object();
    private static List<string> deleteQueue = new List<string>();
    private static Stopwatch stopwatch = new Stopwatch();
    
    [DllImport("kernel32.dll")]
    static extern bool GetDiskFreeSpaceEx(string lpDirectoryName, out ulong lpFreeBytesAvailable, out ulong lpTotalNumberOfBytes, out ulong lpTotalNumberOfFreeBytes);

    static void UpdateProgress(string action, bool force = false)
    {
        lock (lockObj)
        {
            processedItems++;
            if (force || processedItems % 10 == 0 || totalItems > 0 && processedItems % Math.Max(1, totalItems / 100) == 0)
            {
                long elapsed = stopwatch.ElapsedMilliseconds / 1000;
                double itemsPerSec = elapsed > 0 ? (double)processedItems / elapsed : 0;
                string speed = itemsPerSec > 1 ? itemsPerSec.ToString("F1") + " items/sec" : "";
                
                Console.Write("\r[" + elapsed + "s] [" + processedItems + " items] " + speed.PadRight(20) + " | " + action.PadRight(60));
            }
        }
    }

    static void Main(string[] args)
    {
        if (args.Length == 0)
        {
            Console.WriteLine("Usage: ultimate_uninstaller_NUCLEAR.exe <pattern1> [pattern2] [...] [/y]");
            Console.WriteLine("Example: ultimate_uninstaller_NUCLEAR.exe driverbooster ccleaner iobit /y");
            Console.WriteLine("  /y = Auto-confirm (skip prompt)");
            Console.WriteLine("\nNUCLEAR MODE:");
            Console.WriteLine("  - Kills ALL matching processes instantly");
            Console.WriteLine("  - Scans ENTIRE C: drive recursively");
            Console.WriteLine("  - Deletes EVERYTHING matching patterns");
            Console.WriteLine("  - Multithreaded for maximum speed");
            return;
        }

        stopwatch.Start();
        
        bool autoConfirm = args.Any(a => a.Equals("/y", StringComparison.OrdinalIgnoreCase));
        var patterns = args.Where(a => !a.StartsWith("/")).Select(p => p.ToLower()).ToList();
        
        Console.WriteLine("[NUCLEAR MODE] Targeting: " + string.Join(", ", patterns));
        Console.WriteLine("This will OBLITERATE ALL TRACES from C: drive (processes, files, registry)");
        Console.WriteLine("Scanning ENTIRE C: drive tree recursively...\n");

        if (!autoConfirm)
        {
            bool isInteractive = true;
            try { isInteractive = !Console.IsInputRedirected; } catch { isInteractive = false; }

            if (!isInteractive)
            {
                Console.WriteLine("[AUTO-CONFIRM] Non-interactive mode, proceeding...\n");
            }
            else
            {
                Console.Write("Press 'y' to START NUCLEAR DESTRUCTION: ");
                try
                {
                    var key = Console.ReadKey();
                    Console.WriteLine();
                    if (key.KeyChar != 'y' && key.KeyChar != 'Y')
                    {
                        Console.WriteLine("Cancelled.");
                        return;
                    }
                }
                catch
                {
                    Console.WriteLine("\n[AUTO-CONFIRM] Cannot read input, proceeding...\n");
                }
            }
        }
        else
        {
            Console.WriteLine("[AUTO-CONFIRM] Proceeding...\n");
        }

        // PHASE 0: EMERGENCY FORCE KILL (taskkill /F /IM)
        Console.WriteLine("[0/8] EMERGENCY FORCE KILL...");
        EmergencyForceKill(patterns);
        Thread.Sleep(1000);
        
        // PHASE 1: KILL ALL MATCHING PROCESSES (INSTANT)
        Console.WriteLine("[1/8] KILLING ALL MATCHING PROCESSES...");
        KillAllMatchingProcesses(patterns);
        Thread.Sleep(500);
        
        // PHASE 2: NUKE WINDOWS STORE APPS (AppX/UWP)
        Console.WriteLine("\n[2/8] NUKING WINDOWS STORE APPS (AppX/UWP)...");
        NukeWindowsStoreApps(patterns);
        Thread.Sleep(500);
        
        // PHASE 3: STOP/DELETE SERVICES
        Console.WriteLine("\n[3/8] NUKING SERVICES...");
        NukeServices(patterns);
        
        // PHASE 4: OFFICIAL UNINSTALL
        Console.WriteLine("\n[4/8] RUNNING OFFICIAL UNINSTALLERS...");
        var programs = FindInstalledPrograms(patterns);
        if (programs.Count > 0)
        {
            Console.WriteLine("Found " + programs.Count + " installed program(s):");
            foreach (var prog in programs)
            {
                Console.WriteLine("  - " + prog.Name + " (" + prog.Version + ")");
                NuclearUninstall(prog);
            }
        }
        else
        {
            Console.WriteLine("No installed programs found in registry.");
        }
        
        // Kill processes again (in case uninstaller spawned something)
        EmergencyForceKill(patterns);
        KillAllMatchingProcesses(patterns);
        
        // PHASE 5: FULL C: DRIVE RECURSIVE SCAN
        Console.WriteLine("\n[5/8] SCANNING ENTIRE C: DRIVE (RECURSIVE, MULTITHREADED)...");
        Console.WriteLine("This may take a while depending on drive size...\n");
        ScanAndDestroyFullDrive(patterns);
        
        // PHASE 6: REGISTRY NUCLEAR SWEEP
        Console.WriteLine("\n\n[6/8] NUKING REGISTRY...");
        NukeRegistry(patterns);
        
        // PHASE 7: ULTRA CLEANUP - EVERY POSSIBLE LOCATION
        Console.WriteLine("\n[7/8] NUKING SHORTCUTS & ICONS...");
        NukeShortcuts(patterns);
        NukeDesktopIcons(patterns);
        
        Console.WriteLine("\n[8/8] NUKING TASKS, STARTUP, PREFETCH...");
        NukeScheduledTasks(patterns);
        NukeStartupEntries(patterns);
        NukePrefetch(patterns);
        NukeTempFolders(patterns);
        NukeRecentFiles(patterns);
        NukeEnvironmentVariables(patterns);
        NukeQuickLaunch(patterns);
        
        // Final kill sweep
        Console.WriteLine("\n[FINAL] Process kill sweep...");
        EmergencyForceKill(patterns);
        KillAllMatchingProcesses(patterns);
        
        long totalSeconds = stopwatch.ElapsedMilliseconds / 1000;
        Console.WriteLine("\n\n[COMPLETE] Nuclear destruction finished in " + totalSeconds + "s");
        Console.WriteLine("Processed " + processedItems + " items, deleted " + deleteQueue.Count + " objects");
    }

    static void EmergencyForceKill(List<string> patterns)
    {
        // ULTRA AGGRESSIVE: Use taskkill /F /IM for ALL matching process names
        try
        {
            var allProcesses = Process.GetProcesses();
            var processNames = new HashSet<string>();
            
            foreach (var proc in allProcesses)
            {
                try
                {
                    string procName = proc.ProcessName.ToLower();
                    if (IsExactMatch(procName, patterns))
                    {
                        processNames.Add(proc.ProcessName + ".exe");
                    }
                }
                catch { }
            }
            
            foreach (var procName in processNames)
            {
                Console.WriteLine("  [FORCE KILL] taskkill /F /IM " + procName);
                RunCmd("taskkill.exe", "/F /IM \"" + procName + "\"", 3000);
            }
            
            if (processNames.Count == 0)
                Console.WriteLine("  No matching processes found for emergency kill.");
        }
        catch { }
    }

    static void KillAllMatchingProcesses(List<string> patterns)
    {
        try
        {
            var currentPid = Process.GetCurrentProcess().Id;
            var allProcesses = Process.GetProcesses();
            int killed = 0;
            
            Parallel.ForEach(allProcesses, proc =>
            {
                try
                {
                    // Skip ourselves!
                    if (proc.Id == currentPid) return;
                    
                    string procName = proc.ProcessName.ToLower();
                    string mainModule = "";
                    string cmdLine = "";
                    
                    try 
                    { 
                        if (proc.MainModule != null && proc.MainModule.FileName != null) 
                            mainModule = proc.MainModule.FileName.ToLower(); 
                    } 
                    catch { }
                    
                    // Get command line
                    try
                    {
                        using (var searcher = new ManagementObjectSearcher("SELECT CommandLine FROM Win32_Process WHERE ProcessId = " + proc.Id))
                        {
                            foreach (ManagementObject obj in searcher.Get())
                            {
                                var cmdObj = obj["CommandLine"];
                                if (cmdObj != null) cmdLine = cmdObj.ToString().ToLower();
                            }
                        }
                    }
                    catch { }

                    // Use exact matching for process names
                    bool matches = IsExactMatch(procName, patterns) || 
                                   IsExactMatch(mainModule, patterns) || 
                                   IsExactMatch(cmdLine, patterns);

                    if (matches)
                    {
                        lock (lockObj)
                        {
                            Console.WriteLine("  [KILL] " + proc.ProcessName + " (PID " + proc.Id + ")");
                            killed++;
                        }
                        
                        try
                        {
                            proc.Kill();
                            proc.WaitForExit(3000);
                        }
                        catch { }
                    }
                }
                catch { }
            });
            
            if (killed == 0)
                Console.WriteLine("  No matching processes found.");
            else
                Console.WriteLine("  Killed " + killed + " process(es).");
        }
        catch { }
    }

    static void NukeWindowsStoreApps(List<string> patterns)
    {
        // Remove Windows Store Apps (AppX/UWP packages) using PowerShell
        try
        {
            Console.WriteLine("  Scanning for AppX packages...");
            
            // Get all AppX packages for ALL users
            var psi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = "-NoProfile -Command \"Get-AppxPackage -AllUsers | Select-Object Name,PackageFullName | ConvertTo-Json\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                CreateNoWindow = true
            };
            
            var proc = Process.Start(psi);
            if (proc == null) return;
            
            var output = proc.StandardOutput.ReadToEnd();
            proc.WaitForExit(30000);
            
            if (string.IsNullOrWhiteSpace(output)) return;
            
            // Parse JSON manually (simple approach)
            var lines = output.Split('\n');
            var packagesToRemove = new List<string>();
            
            foreach (var line in lines)
            {
                if (line.Contains("\"Name\""))
                {
                    var namePart = line.Split(':');
                    if (namePart.Length > 1)
                    {
                        var name = namePart[1].Trim().Trim('"', ',').ToLower();
                        if (IsExactMatch(name, patterns))
                        {
                            // Find the PackageFullName in the next few lines
                            var lineIndex = Array.IndexOf(lines, line);
                            for (int i = lineIndex; i < Math.Min(lineIndex + 5, lines.Length); i++)
                            {
                                if (lines[i].Contains("\"PackageFullName\""))
                                {
                                    var pkgPart = lines[i].Split(':');
                                    if (pkgPart.Length > 1)
                                    {
                                        var pkgName = pkgPart[1].Trim().Trim('"', ',');
                                        packagesToRemove.Add(pkgName);
                                    }
                                    break;
                                }
                            }
                        }
                    }
                }
            }
            
            // Remove each matching package
            foreach (var pkg in packagesToRemove)
            {
                Console.WriteLine("  [APPX] Removing: " + pkg);
                
                // Remove for all users
                var removePsi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -Command \"Get-AppxPackage -AllUsers | Where-Object {$_.PackageFullName -eq '" + pkg + "'} | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue\"",
                    UseShellExecute = false,
                    CreateNoWindow = true
                };
                
                var removeProc = Process.Start(removePsi);
                if (removeProc != null) removeProc.WaitForExit(20000);
            }
            
            if (packagesToRemove.Count == 0)
                Console.WriteLine("  No matching AppX packages found.");
            else
                Console.WriteLine("  Removed " + packagesToRemove.Count + " AppX package(s).");
            
            // Also nuke Windows Store app data folders
            NukeWindowsStoreAppFolders(patterns);
        }
        catch (Exception ex)
        {
            Console.WriteLine("  AppX removal error: " + ex.Message);
        }
    }

    static void NukeWindowsStoreAppFolders(List<string> patterns)
    {
        // Nuke WindowsApps, Packages, and related folders
        var appPaths = new List<string>();
        
        // WindowsApps (requires ownership changes)
        appPaths.Add(@"C:\Program Files\WindowsApps");
        
        // All users' app data
        var usersPath = @"C:\Users";
        if (Directory.Exists(usersPath))
        {
            foreach (var userDir in Directory.GetDirectories(usersPath))
            {
                appPaths.Add(Path.Combine(userDir, "AppData", "Local", "Packages"));
                appPaths.Add(Path.Combine(userDir, "AppData", "Local", "Microsoft", "Windows", "Application Shortcuts"));
            }
        }
        
        foreach (var basePath in appPaths)
        {
            if (!Directory.Exists(basePath)) continue;
            
            try
            {
                foreach (var dir in Directory.GetDirectories(basePath))
                {
                    string dirName = Path.GetFileName(dir).ToLower();
                    if (IsExactMatch(dirName, patterns))
                    {
                        Console.WriteLine("  [APPX FOLDER] " + dir);
                        
                        // Take ownership first (for WindowsApps)
                        if (basePath.Contains("WindowsApps"))
                        {
                            RunCmd("takeown.exe", "/f \"" + dir + "\" /r /d y", 10000);
                            RunCmd("icacls.exe", "\"" + dir + "\" /grant *S-1-1-0:F /t /c /q", 10000);
                        }
                        
                        ForceDeleteDirectory(dir);
                    }
                }
            }
            catch { }
        }
    }

    static void ScanAndDestroyFullDrive(List<string> patterns)
    {
        // Start from C: root
        var rootDirs = new List<string>();
        
        try
        {
            // Get all top-level directories
            var allDirs = Directory.GetDirectories(@"C:\");
            
            // Prioritize common locations first for faster results
            var priorityDirs = new[] { "Program Files", "Program Files (x86)", "ProgramData", "Users" };
            var priority = allDirs.Where(d => priorityDirs.Any(p => d.EndsWith(p, StringComparison.OrdinalIgnoreCase))).ToList();
            var rest = allDirs.Except(priority).ToList();
            
            rootDirs.AddRange(priority);
            rootDirs.AddRange(rest);
        }
        catch { }

        // Scan each root directory in parallel
        Parallel.ForEach(rootDirs, new ParallelOptions { MaxDegreeOfParallelism = 8 }, rootDir =>
        {
            try
            {
                ScanDirectoryRecursive(rootDir, patterns, 0);
            }
            catch { }
        });

        // Execute all deletions
        if (deleteQueue.Count > 0)
        {
            Console.WriteLine("\n\nDeleting " + deleteQueue.Count + " items...");
            Parallel.ForEach(deleteQueue, new ParallelOptions { MaxDegreeOfParallelism = 16 }, path =>
            {
                try
                {
                    if (Directory.Exists(path))
                    {
                        UpdateProgress("DEL: " + Path.GetFileName(path));
                        ForceDeleteDirectory(path);
                    }
                    else if (File.Exists(path))
                    {
                        UpdateProgress("DEL: " + Path.GetFileName(path));
                        ForceDeleteFile(path);
                    }
                }
                catch { }
            });
        }
    }

    static bool IsSafePath(string path)
    {
        string lowerPath = path.ToLower();
        
        // NEVER touch these locations (safety whitelist)
        var safePaths = new[]
        {
            "\\python",
            "\\node_modules",
            "\\npm",
            "\\site-packages",
            "\\dotnet",
            "\\microsoft.net",
            "\\windows\\system32",
            "\\windows\\syswow64",
            "\\windows\\winsxs",
            "$recycle.bin",
            "\\windowsapps",
            "\\windowspowershell",
            "\\git"
        };
        
        return safePaths.Any(s => lowerPath.Contains(s));
    }

    static bool IsExactMatch(string name, List<string> patterns)
    {
        // Require EXACT match or very specific context
        // "driver booster" should match "Driver Booster 12.lnk" but NOT "webdriver"
        foreach (var pattern in patterns)
        {
            // Check for exact product names
            if (pattern == "driverbooster" || pattern == "driver booster")
            {
                // Must contain "driver" AND "boost" together
                if (name.Contains("driver") && name.Contains("boost"))
                    return true;
            }
            else if (pattern == "ccleaner")
            {
                // Must be exactly ccleaner (not "cleaner")
                if (name.Contains("ccleaner"))
                    return true;
            }
            else if (pattern == "iobit")
            {
                // Must be exactly iobit
                if (name.Contains("iobit"))
                    return true;
            }
            else if (pattern == "phonelink" || pattern == "phone link" || pattern == "phone-link")
            {
                // Phone Link (also known as "Your Phone")
                // Match: phonelink, phone link, yourphone, microsoft.yourphone
                if (name.Contains("phonelink") || 
                    name.Contains("phone-link") ||
                    (name.Contains("phone") && name.Contains("link")) ||
                    name.Contains("yourphone") ||
                    name.Contains("your phone") ||
                    name.Contains("microsoft.yourphone"))
                    return true;
            }
            else
            {
                // For other patterns, require exact substring match
                if (name.Contains(pattern))
                    return true;
            }
        }
        return false;
    }

    static void ScanDirectoryRecursive(string path, List<string> patterns, int depth)
    {
        // Safety check - never scan protected paths
        if (IsSafePath(path))
            return;
        
        string dirName = "";
        try { var fn = Path.GetFileName(path); if (fn != null) dirName = fn.ToLower(); } catch { }

        try
        {
            UpdateProgress("Scan: " + path);
            
            // Check if current directory matches (using smart matching)
            if (IsExactMatch(dirName, patterns))
            {
                lock (lockObj)
                {
                    deleteQueue.Add(path);
                    Console.WriteLine("\n  [FOUND] " + path);
                }
                return; // Don't recurse into directory we're deleting
            }

            // Check files in current directory (including hidden/system files)
            try
            {
                var files = Directory.GetFiles(path, "*", SearchOption.TopDirectoryOnly);
                foreach (var file in files)
                {
                    if (IsSafePath(file))
                        continue;
                    
                    string fileName = "";
                    try 
                    { 
                        var fn = Path.GetFileName(file); 
                        if (fn != null) fileName = fn.ToLower(); 
                    } 
                    catch { }
                    
                    // Use smart matching
                    if (IsExactMatch(fileName, patterns))
                    {
                        lock (lockObj)
                        {
                            deleteQueue.Add(file);
                            Console.WriteLine("\n  [FOUND FILE] " + file);
                        }
                    }
                }
            }
            catch { }

            // Recurse into subdirectories
            try
            {
                var subDirs = Directory.GetDirectories(path);
                
                if (depth < 3) // Parallelize first few levels
                {
                    Parallel.ForEach(subDirs, new ParallelOptions { MaxDegreeOfParallelism = 4 }, subDir =>
                    {
                        ScanDirectoryRecursive(subDir, patterns, depth + 1);
                    });
                }
                else // Serial for deep levels
                {
                    foreach (var subDir in subDirs)
                    {
                        ScanDirectoryRecursive(subDir, patterns, depth + 1);
                    }
                }
            }
            catch { }
        }
        catch { }
    }

    static void NukeRegistry(List<string> patterns)
    {
        var registryRoots = new[]
        {
            Tuple.Create(Registry.LocalMachine, @"SOFTWARE"),
            Tuple.Create(Registry.LocalMachine, @"SOFTWARE\WOW6432Node"),
            Tuple.Create(Registry.CurrentUser, @"SOFTWARE"),
            Tuple.Create(Registry.LocalMachine, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
            Tuple.Create(Registry.LocalMachine, @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
            Tuple.Create(Registry.CurrentUser, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")
        };

        foreach (var root in registryRoots)
        {
            try
            {
                UpdateProgress("Registry: " + root.Item2, true);
                DeleteRegistryKeysRecursive(root.Item1, root.Item2, patterns);
            }
            catch { }
        }
    }

    static void DeleteRegistryKeysRecursive(RegistryKey root, string path, List<string> patterns)
    {
        try
        {
            using (var key = root.OpenSubKey(path, true))
            {
                if (key == null) return;

                var subKeyNames = key.GetSubKeyNames().ToList();
                foreach (var subKeyName in subKeyNames)
                {
                    bool matches = IsExactMatch(subKeyName.ToLower(), patterns);
                    
                    if (matches)
                    {
                        try
                        {
                            UpdateProgress("REG DEL: " + subKeyName, true);
                            Console.WriteLine("\n  [REG] " + path + "\\" + subKeyName);
                            key.DeleteSubKeyTree(subKeyName);
                        }
                        catch { }
                    }
                    else
                    {
                        // Recurse
                        try
                        {
                            DeleteRegistryKeysRecursive(root, path + "\\" + subKeyName, patterns);
                        }
                        catch { }
                    }
                }
            }
        }
        catch { }
    }

    static List<ProgramInfo> FindInstalledPrograms(List<string> patterns)
    {
        var programs = new List<ProgramInfo>();
        var seen = new HashSet<string>();

        string[] registryKeys = new[]
        {
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        };

        foreach (var keyPath in registryKeys)
        {
            try
            {
                using (var key = Registry.LocalMachine.OpenSubKey(keyPath))
                {
                    if (key == null) continue;
                    
                    foreach (var subKeyName in key.GetSubKeyNames())
                    {
                        using (var subKey = key.OpenSubKey(subKeyName))
                        {
                            if (subKey == null) continue;
                            
                            var displayNameObj = subKey.GetValue("DisplayName");
                            var displayName = displayNameObj != null ? displayNameObj.ToString() : null;
                            if (string.IsNullOrEmpty(displayName)) continue;
                            
                            bool matches = IsExactMatch(displayName.ToLower(), patterns);
                            if (matches)
                            {
                                var versionObj = subKey.GetValue("DisplayVersion");
                                var identifier = displayName + "_" + (versionObj != null ? versionObj.ToString() : "");
                                if (seen.Contains(identifier)) continue;
                                seen.Add(identifier);

                                var uninstallObj = subKey.GetValue("UninstallString");
                                var publisherObj = subKey.GetValue("Publisher");
                                
                                programs.Add(new ProgramInfo
                                {
                                    Name = displayName,
                                    Version = versionObj != null ? versionObj.ToString() : "Unknown",
                                    UninstallString = uninstallObj != null ? uninstallObj.ToString() : null,
                                    RegistryPath = keyPath + "\\" + subKeyName,
                                    Publisher = publisherObj != null ? publisherObj.ToString() : null
                                });
                            }
                        }
                    }
                }
            }
            catch { }
        }

        return programs;
    }

    static void NuclearUninstall(ProgramInfo program)
    {
        Console.WriteLine("  Uninstalling: " + program.Name);
        
        try
        {
            if (!string.IsNullOrEmpty(program.UninstallString))
            {
                var uninstallCmd = program.UninstallString;
                
                // Make it silent
                if (uninstallCmd.ToLower().Contains("msiexec"))
                {
                    uninstallCmd = uninstallCmd.Replace("/I", "/X").Replace("/i", "/x");
                    if (!uninstallCmd.Contains("/qn"))
                        uninstallCmd += " /qn /norestart";
                }

                var psi = new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = "/c " + uninstallCmd,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };
                var proc = Process.Start(psi);
                if (proc != null) proc.WaitForExit(30000);
            }
        }
        catch { }
    }

    static void NukeServices(List<string> patterns)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "sc.exe",
                Arguments = "query type= service state= all",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                CreateNoWindow = true
            };
            var proc = Process.Start(psi);
            if (proc == null) return;
            var output = proc.StandardOutput.ReadToEnd();
            proc.WaitForExit(10000);

            var lines = output.Split('\n');
            foreach (var line in lines)
            {
                if (line.Trim().StartsWith("SERVICE_NAME:"))
                {
                    var serviceName = line.Trim().Substring("SERVICE_NAME:".Length).Trim();
                    bool matches = IsExactMatch(serviceName.ToLower(), patterns);
                    
                    if (matches)
                    {
                        Console.WriteLine("  [SERVICE] " + serviceName);
                        RunCmd("sc.exe", "stop \"" + serviceName + "\"", 5000);
                        Thread.Sleep(500);
                        RunCmd("sc.exe", "delete \"" + serviceName + "\"", 5000);
                    }
                }
            }
        }
        catch { }
    }

    static void NukeShortcuts(List<string> patterns)
    {
        // Scan ALL start menus and shortcuts for ALL users
        var usersPath = @"C:\Users";
        if (Directory.Exists(usersPath))
        {
            foreach (var userDir in Directory.GetDirectories(usersPath))
            {
                var userPaths = new[]
                {
                    Path.Combine(userDir, "AppData", "Roaming", "Microsoft", "Windows", "Start Menu"),
                    Path.Combine(userDir, "Desktop")
                };

                foreach (var basePath in userPaths)
                {
                    if (!Directory.Exists(basePath)) continue;
                    
                    try
                    {
                        foreach (var file in Directory.GetFiles(basePath, "*", SearchOption.AllDirectories))
                        {
                            if (IsSafePath(file)) continue;
                            
                            string fileName = Path.GetFileNameWithoutExtension(file).ToLower();
                            if (IsExactMatch(fileName, patterns))
                            {
                                Console.WriteLine("  [SHORTCUT] " + file);
                                ForceDeleteFile(file);
                            }
                        }
                        
                        foreach (var dir in Directory.GetDirectories(basePath, "*", SearchOption.AllDirectories))
                        {
                            if (IsSafePath(dir)) continue;
                            
                            string dirName = Path.GetFileName(dir).ToLower();
                            if (IsExactMatch(dirName, patterns))
                            {
                                Console.WriteLine("  [SHORTCUT DIR] " + dir);
                                ForceDeleteDirectory(dir);
                            }
                        }
                    }
                    catch { }
                }
            }
        }
        
        // Common/Public locations
        var commonPaths = new[]
        {
            @"C:\ProgramData\Microsoft\Windows\Start Menu",
            @"C:\Users\Public\Desktop"
        };

        foreach (var basePath in commonPaths)
        {
            if (!Directory.Exists(basePath)) continue;
            
            try
            {
                foreach (var file in Directory.GetFiles(basePath, "*", SearchOption.AllDirectories))
                {
                    if (IsSafePath(file)) continue;
                    
                    string fileName = Path.GetFileNameWithoutExtension(file).ToLower();
                    if (IsExactMatch(fileName, patterns))
                    {
                        Console.WriteLine("  [COMMON SHORTCUT] " + file);
                        ForceDeleteFile(file);
                    }
                }
                
                foreach (var dir in Directory.GetDirectories(basePath, "*", SearchOption.AllDirectories))
                {
                    if (IsSafePath(dir)) continue;
                    
                    string dirName = Path.GetFileName(dir).ToLower();
                    if (IsExactMatch(dirName, patterns))
                    {
                        Console.WriteLine("  [COMMON SHORTCUT DIR] " + dir);
                        ForceDeleteDirectory(dir);
                    }
                }
            }
            catch { }
        }
    }

    static void NukeScheduledTasks(List<string> patterns)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "schtasks.exe",
                Arguments = "/query /fo CSV /nh",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                CreateNoWindow = true
            };
            var proc = Process.Start(psi);
            if (proc == null) return;
            var output = proc.StandardOutput.ReadToEnd();
            proc.WaitForExit(10000);

            foreach (var line in output.Split('\n'))
            {
                var parts = line.Split(',');
                if (parts.Length > 0)
                {
                    var taskName = parts[0].Trim('"', ' ');
                    if (IsExactMatch(taskName.ToLower(), patterns))
                    {
                        Console.WriteLine("  [TASK] " + taskName);
                        RunCmd("schtasks.exe", "/delete /tn \"" + taskName + "\" /f", 5000);
                    }
                }
            }
        }
        catch { }
    }

    static void NukeStartupEntries(List<string> patterns)
    {
        var startupKeys = new[]
        {
            Tuple.Create(Registry.CurrentUser, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run"),
            Tuple.Create(Registry.CurrentUser, @"SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"),
            Tuple.Create(Registry.LocalMachine, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run"),
            Tuple.Create(Registry.LocalMachine, @"SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"),
            Tuple.Create(Registry.LocalMachine, @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run")
        };

        foreach (var entry in startupKeys)
        {
            try
            {
                using (var key = entry.Item1.OpenSubKey(entry.Item2, true))
                {
                    if (key == null) continue;
                    foreach (var valueName in key.GetValueNames())
                    {
                        var value = (key.GetValue(valueName) ?? "").ToString().ToLower();
                        bool matches = IsExactMatch(valueName.ToLower(), patterns) || IsExactMatch(value, patterns);
                        
                        if (matches)
                        {
                            Console.WriteLine("  [STARTUP] " + valueName);
                            key.DeleteValue(valueName);
                        }
                    }
                }
            }
            catch { }
        }
    }

    static void ForceDeleteDirectory(string path)
    {
        try
        {
            var dirInfo = new DirectoryInfo(path);
            if (dirInfo.Exists)
            {
                try
                {
                    foreach (var file in dirInfo.GetFiles("*", SearchOption.AllDirectories))
                        file.Attributes = FileAttributes.Normal;
                    foreach (var dir in dirInfo.GetDirectories("*", SearchOption.AllDirectories))
                        dir.Attributes = FileAttributes.Normal;
                }
                catch { }
                
                dirInfo.Attributes = FileAttributes.Normal;
                dirInfo.Delete(true);
            }
        }
        catch
        {
            try
            {
                RunCmd("cmd.exe", "/c rmdir /s /q \"" + path + "\"", 5000);
            }
            catch { }
        }
    }

    static void ForceDeleteFile(string path)
    {
        try
        {
            var fileInfo = new FileInfo(path);
            if (fileInfo.Exists)
            {
                fileInfo.Attributes = FileAttributes.Normal;
                fileInfo.Delete();
            }
        }
        catch
        {
            try
            {
                RunCmd("cmd.exe", "/c del /f /q \"" + path + "\"", 3000);
            }
            catch { }
        }
    }

    static void NukeDesktopIcons(List<string> patterns)
    {
        // Scan ALL user desktops (not just current user)
        var usersPath = @"C:\Users";
        if (!Directory.Exists(usersPath)) return;

        try
        {
            foreach (var userDir in Directory.GetDirectories(usersPath))
            {
                var desktops = new[]
                {
                    Path.Combine(userDir, "Desktop"),
                    Path.Combine(userDir, "OneDrive", "Desktop"),
                    Path.Combine(userDir, "OneDrive - Personal", "Desktop")
                };

                foreach (var desktop in desktops)
                {
                    if (!Directory.Exists(desktop)) continue;
                    
                    try
                    {
                        // Delete matching files
                        foreach (var file in Directory.GetFiles(desktop, "*", SearchOption.AllDirectories))
                        {
                            if (IsSafePath(file)) continue;
                            
                            string fileName = Path.GetFileNameWithoutExtension(file).ToLower();
                            if (IsExactMatch(fileName, patterns))
                            {
                                Console.WriteLine("  [DESKTOP ICON] " + file);
                                ForceDeleteFile(file);
                            }
                        }
                        
                        // Delete matching folders
                        foreach (var dir in Directory.GetDirectories(desktop, "*", SearchOption.AllDirectories))
                        {
                            if (IsSafePath(dir)) continue;
                            
                            string dirName = Path.GetFileName(dir).ToLower();
                            if (IsExactMatch(dirName, patterns))
                            {
                                Console.WriteLine("  [DESKTOP FOLDER] " + dir);
                                ForceDeleteDirectory(dir);
                            }
                        }
                    }
                    catch { }
                }
            }
            
            // Also check Public desktop
            var publicDesktop = @"C:\Users\Public\Desktop";
            if (Directory.Exists(publicDesktop))
            {
                try
                {
                    foreach (var file in Directory.GetFiles(publicDesktop, "*", SearchOption.AllDirectories))
                    {
                        if (IsSafePath(file)) continue;
                        
                        string fileName = Path.GetFileNameWithoutExtension(file).ToLower();
                        if (IsExactMatch(fileName, patterns))
                        {
                            Console.WriteLine("  [PUBLIC DESKTOP] " + file);
                            ForceDeleteFile(file);
                        }
                    }
                }
                catch { }
            }
        }
        catch { }
    }

    static void NukePrefetch(List<string> patterns)
    {
        var prefetchPath = @"C:\Windows\Prefetch";
        if (!Directory.Exists(prefetchPath)) return;

        try
        {
            foreach (var file in Directory.GetFiles(prefetchPath, "*.pf"))
            {
                string fileName = Path.GetFileNameWithoutExtension(file).ToLower();
                if (IsExactMatch(fileName, patterns))
                {
                    Console.WriteLine("  [PREFETCH] " + file);
                    ForceDeleteFile(file);
                }
            }
        }
        catch { }
    }

    static void NukeTempFolders(List<string> patterns)
    {
        var tempPaths = new List<string>();
        
        // Windows temp
        tempPaths.Add(@"C:\Windows\Temp");
        tempPaths.Add(Path.GetTempPath());
        
        // All user temps
        var usersPath = @"C:\Users";
        if (Directory.Exists(usersPath))
        {
            foreach (var userDir in Directory.GetDirectories(usersPath))
            {
                tempPaths.Add(Path.Combine(userDir, "AppData", "Local", "Temp"));
                tempPaths.Add(Path.Combine(userDir, "AppData", "Local", "Microsoft", "Windows", "INetCache"));
                tempPaths.Add(Path.Combine(userDir, "AppData", "Local", "Microsoft", "Windows", "Temporary Internet Files"));
            }
        }

        foreach (var tempPath in tempPaths)
        {
            if (!Directory.Exists(tempPath)) continue;
            
            try
            {
                // Files
                foreach (var file in Directory.GetFiles(tempPath, "*", SearchOption.TopDirectoryOnly))
                {
                    try
                    {
                        if (IsSafePath(file)) continue;
                        
                        string fileName = Path.GetFileName(file).ToLower();
                        if (IsExactMatch(fileName, patterns))
                        {
                            ForceDeleteFile(file);
                        }
                    }
                    catch { }
                }
                
                // Directories
                foreach (var dir in Directory.GetDirectories(tempPath, "*", SearchOption.TopDirectoryOnly))
                {
                    try
                    {
                        if (IsSafePath(dir)) continue;
                        
                        string dirName = Path.GetFileName(dir).ToLower();
                        if (IsExactMatch(dirName, patterns))
                        {
                            Console.WriteLine("  [TEMP] " + dir);
                            ForceDeleteDirectory(dir);
                        }
                    }
                    catch { }
                }
            }
            catch { }
        }
    }

    static void NukeRecentFiles(List<string> patterns)
    {
        var usersPath = @"C:\Users";
        if (!Directory.Exists(usersPath)) return;

        foreach (var userDir in Directory.GetDirectories(usersPath))
        {
            var recentPath = Path.Combine(userDir, "AppData", "Roaming", "Microsoft", "Windows", "Recent");
            if (!Directory.Exists(recentPath)) continue;
            
            try
            {
                foreach (var file in Directory.GetFiles(recentPath, "*", SearchOption.AllDirectories))
                {
                    string fileName = Path.GetFileNameWithoutExtension(file).ToLower();
                    if (IsExactMatch(fileName, patterns))
                    {
                        Console.WriteLine("  [RECENT] " + file);
                        ForceDeleteFile(file);
                    }
                }
            }
            catch { }
        }
    }

    static void NukeEnvironmentVariables(List<string> patterns)
    {
        // Check PATH and other env vars for matching entries
        try
        {
            var targets = new[] { EnvironmentVariableTarget.User, EnvironmentVariableTarget.Machine };
            
            foreach (var target in targets)
            {
                try
                {
                    var path = Environment.GetEnvironmentVariable("PATH", target);
                    if (path != null)
                    {
                        var entries = path.Split(';');
                        var cleaned = new List<string>();
                        bool modified = false;
                        
                        foreach (var entry in entries)
                        {
                            bool matches = IsExactMatch(entry.ToLower(), patterns);
                            if (matches)
                            {
                                Console.WriteLine("  [ENV PATH] Removing: " + entry);
                                modified = true;
                            }
                            else
                            {
                                cleaned.Add(entry);
                            }
                        }
                        
                        if (modified)
                        {
                            Environment.SetEnvironmentVariable("PATH", string.Join(";", cleaned), target);
                        }
                    }
                }
                catch { }
            }
        }
        catch { }
    }

    static void NukeQuickLaunch(List<string> patterns)
    {
        var usersPath = @"C:\Users";
        if (!Directory.Exists(usersPath)) return;

        foreach (var userDir in Directory.GetDirectories(usersPath))
        {
            var quickLaunchPaths = new[]
            {
                Path.Combine(userDir, "AppData", "Roaming", "Microsoft", "Internet Explorer", "Quick Launch"),
                Path.Combine(userDir, "AppData", "Roaming", "Microsoft", "Internet Explorer", "Quick Launch", "User Pinned", "TaskBar"),
                Path.Combine(userDir, "AppData", "Roaming", "Microsoft", "Internet Explorer", "Quick Launch", "User Pinned", "StartMenu")
            };

            foreach (var qlPath in quickLaunchPaths)
            {
                if (!Directory.Exists(qlPath)) continue;
                
                try
                {
                    foreach (var file in Directory.GetFiles(qlPath, "*", SearchOption.AllDirectories))
                    {
                        string fileName = Path.GetFileNameWithoutExtension(file).ToLower();
                        if (IsExactMatch(fileName, patterns))
                        {
                            Console.WriteLine("  [QUICKLAUNCH] " + file);
                            ForceDeleteFile(file);
                        }
                    }
                }
                catch { }
            }
        }
    }

    static void RunCmd(string fileName, string arguments, int timeoutMs)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = arguments,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            var proc = Process.Start(psi);
            if (proc != null) proc.WaitForExit(timeoutMs);
        }
        catch { }
    }

    class ProgramInfo
    {
        public string Name { get; set; }
        public string Version { get; set; }
        public string UninstallString { get; set; }
        public string RegistryPath { get; set; }
        public string ProductCode { get; set; }
        public string Publisher { get; set; }
    }
}
