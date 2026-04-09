using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using GameLauncherPro.Models;

namespace GameLauncherPro.Services
{
    public class GameScanner
    {
        private readonly string[] _excludedPaths = new[]
        {
            "Windows", "WinSxS", "WindowsApps", "$Recycle.Bin", 
            "System Volume Information", "ProgramData", "Recovery",
            "AppData", "Temp", "node_modules", ".git", ".vs",
            "obj", "bin\\Debug", "bin\\Release", "packages",
            "_CommonRedist", "_Redist", "Redist", "DirectX",
            "vcredist", "dotnet", "steamapps\\common\\Proton"
        };

        private readonly string[] _commonGameFolders = new[]
        {
            "games", "Steam", "steamapps\\common",
            "Epic Games", "GOG Games", "GOG Galaxy\\Games",
            "Program Files\\Steam\\steamapps\\common",
            "Program Files (x86)\\Steam\\steamapps\\common",
            "Xbox Games", "EA Games"
        };

        // Executables that START with these prefixes (case-insensitive)
        private readonly string[] _excludedPrefixes = new[]
        {
            "unins", "setup", "install", "crashreport", "crashhandler",
            "unitycrash", "vcredist", "directx", "physx", "dotnet",
            "configurator", "updater", "patcher",
            "keygen", "quicksfv", "quickbms", "regrouplog", "easyanticheat",
            "vtoyjump", "imdisk", "bugreport", "dxwebsetup",
            "vc_redist", "dotnetfx", "redprelauncher", "ue4prereq",
            "ue5prereq", "battleye", "7z"
        };

        // Executables that CONTAIN these substrings (case-insensitive)
        private readonly string[] _excludedSubstrings = new[]
        {
            "redist", "crack", "cheat", "crashclient", "crashreporter",
            "prereq", "crashdump", "trainer", "fling", "scriptmerger",
            "kdiff", "mods_tool", "modmerger", "launcher_update"
        };

        public List<Game> ScanAllDrives()
        {
            var games = new Dictionary<string, Game>(); // Use dict to prevent duplicates
            var drives = DriveInfo.GetDrives()
                .Where(d => d.IsReady && d.DriveType == DriveType.Fixed)
                .ToList();

            Console.WriteLine($"Found {drives.Count} fixed drives");

            foreach (var drive in drives)
            {
                Console.WriteLine($"\n=== Scanning {drive.Name} ===");
                
                // Scan common game folders first (faster)
                foreach (var gameFolder in _commonGameFolders)
                {
                    var fullPath = Path.Combine(drive.RootDirectory.FullName, gameFolder);
                    if (Directory.Exists(fullPath))
                    {
                        Console.WriteLine($"Scanning: {fullPath}");
                        var folderGames = ScanGameFolder(fullPath);
                        foreach (var game in folderGames)
                        {
                            var key = game.ExecutablePath.ToLowerInvariant();
                            if (!games.ContainsKey(key))
                            {
                                games[key] = game;
                            }
                        }
                    }
                }

                // Scan root for any additional "game" folders not in common list
                try
                {
                    var rootDirs = Directory.GetDirectories(drive.RootDirectory.FullName)
                        .Where(d => !_excludedPaths.Any(ex => 
                            d.Contains(ex, StringComparison.OrdinalIgnoreCase)))
                        .Where(d => {
                            var dirName = new DirectoryInfo(d).Name.ToLower();
                            return dirName.Contains("game") && !_commonGameFolders.Any(cf => 
                                d.EndsWith(cf, StringComparison.OrdinalIgnoreCase));
                        })
                        .ToList();

                    foreach (var dir in rootDirs)
                    {
                        Console.WriteLine($"Scanning additional: {dir}");
                        var folderGames = ScanGameFolder(dir);
                        foreach (var game in folderGames)
                        {
                            var key = game.ExecutablePath.ToLowerInvariant();
                            if (!games.ContainsKey(key))
                            {
                                games[key] = game;
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error scanning root of {drive.Name}: {ex.Message}");
                }
            }

            Console.WriteLine($"\n=== Scan complete: Found {games.Count} games ===");
            return games.Values.ToList();
        }

        private List<Game> ScanGameFolder(string gameFolder)
        {
            var games = new List<Game>();

            try
            {
                if (!Directory.Exists(gameFolder))
                    return games;

                // Get all subdirectories (potential game installations)
                var gameDirs = Directory.GetDirectories(gameFolder)
                    .Where(d => !_excludedPaths.Any(ex => 
                        d.Contains(ex, StringComparison.OrdinalIgnoreCase)))
                    .ToList();

                foreach (var gameDir in gameDirs)
                {
                    try
                    {
                        var dirInfo = new DirectoryInfo(gameDir);
                        
                        // Skip empty directories
                        if (!Directory.EnumerateFileSystemEntries(gameDir).Any())
                        {
                            Console.WriteLine($"  Skipping empty: {dirInfo.Name}");
                            continue;
                        }

                        var mainExe = FindMainExecutable(gameDir, dirInfo.Name);
                        if (mainExe != null && File.Exists(mainExe))
                        {
                            var game = CreateGameFromExecutable(mainExe, gameDir);
                            games.Add(game);
                            Console.WriteLine($"  ✓ Found: {game.Name} -> {Path.GetFileName(mainExe)}");
                        }
                        else
                        {
                            Console.WriteLine($"  ✗ No valid exe: {dirInfo.Name}");
                        }
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"  Error in {gameDir}: {ex.Message}");
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error scanning {gameFolder}: {ex.Message}");
            }

            return games;
        }

        private string? FindMainExecutable(string directory, string folderName)
        {
            try
            {
                // Get all exe files recursively (but limit depth to 3 levels)
                var exeFiles = GetExecutablesRecursive(directory, 0, 3)
                    .Where(f => !IsExcludedExecutable(Path.GetFileNameWithoutExtension(f)))
                    .Where(f => new FileInfo(f).Length > 10 * 1024) // Must be >10KB
                    .ToList();

                if (exeFiles.Count == 0) return null;

                // PRIORITY 1: Exe that matches folder name
                var matchingName = exeFiles.FirstOrDefault(f => 
                    Path.GetFileNameWithoutExtension(f).Equals(folderName, StringComparison.OrdinalIgnoreCase));
                if (matchingName != null) return matchingName;

                // PRIORITY 2: Exe in root directory (not subdirectory)
                var rootExes = exeFiles
                    .Where(f => Path.GetDirectoryName(f)?.Equals(directory, StringComparison.OrdinalIgnoreCase) == true)
                    .OrderByDescending(f => new FileInfo(f).Length)
                    .ToList();
                if (rootExes.Any()) return rootExes.First();

                // PRIORITY 3: Exe in Binaries or Bin folder (largest)
                var binExes = exeFiles
                    .Where(f => f.Contains("\\bin\\", StringComparison.OrdinalIgnoreCase) ||
                               f.Contains("\\binaries\\", StringComparison.OrdinalIgnoreCase))
                    .OrderByDescending(f => new FileInfo(f).Length)
                    .ToList();
                if (binExes.Any()) return binExes.First();

                // PRIORITY 4: Largest exe overall (likely the main game)
                return exeFiles
                    .OrderByDescending(f => new FileInfo(f).Length)
                    .First();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error finding exe in {directory}: {ex.Message}");
                return null;
            }
        }

        private bool IsExcludedExecutable(string fileName)
        {
            var lower = fileName.ToLowerInvariant();
            
            // Check prefix matches
            if (_excludedPrefixes.Any(prefix => lower.StartsWith(prefix)))
                return true;
            
            // Check substring matches
            if (_excludedSubstrings.Any(sub => lower.Contains(sub)))
                return true;
            
            return false;
        }

        private List<string> GetExecutablesRecursive(string directory, int currentDepth, int maxDepth)
        {
            var exes = new List<string>();

            if (currentDepth > maxDepth)
                return exes;

            try
            {
                // Add exes from current directory
                exes.AddRange(Directory.GetFiles(directory, "*.exe", SearchOption.TopDirectoryOnly));

                // Recursively scan subdirectories
                var subDirs = Directory.GetDirectories(directory)
                    .Where(d => !_excludedPaths.Any(ex => 
                        d.Contains(ex, StringComparison.OrdinalIgnoreCase)));

                foreach (var subDir in subDirs)
                {
                    exes.AddRange(GetExecutablesRecursive(subDir, currentDepth + 1, maxDepth));
                }
            }
            catch (UnauthorizedAccessException)
            {
                // Skip restricted directories
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error reading {directory}: {ex.Message}");
            }

            return exes;
        }

        private Game CreateGameFromExecutable(string exePath, string installDir)
        {
            var fileName = Path.GetFileNameWithoutExtension(exePath);
            var dirName = new DirectoryInfo(installDir).Name;

            // Use ORIGINAL names (before cleaning) to judge quality
            bool fileHasOriginalSpaces = fileName.Contains(' ');
            bool dirHasOriginalSpaces = dirName.Contains(' ');
            
            var dirGameName = CleanGameName(dirName);
            var fileGameName = CleanGameName(fileName);

            string gameName;
            
            // If the original exe filename has spaces, it's properly named by developers
            if (fileHasOriginalSpaces && !dirHasOriginalSpaces)
            {
                gameName = fileGameName;
            }
            // If the original dir name has spaces, prefer it
            else if (dirHasOriginalSpaces && !fileHasOriginalSpaces)
            {
                gameName = dirGameName;
            }
            // Both have spaces - prefer whichever has more words (richer name)
            else if (fileHasOriginalSpaces && dirHasOriginalSpaces)
            {
                gameName = fileGameName.Count(c => c == ' ') >= dirGameName.Count(c => c == ' ')
                    ? fileGameName : dirGameName;
            }
            // Neither has spaces - prefer directory name if it's long enough
            else if (!string.IsNullOrWhiteSpace(dirGameName) && dirGameName.Length >= 3)
            {
                gameName = dirGameName;
            }
            else
            {
                gameName = fileGameName;
            }
            
            // Final cleanup - if name still has no spaces and is long, try the other source
            if (!gameName.Contains(' ') && gameName.Length > 15)
            {
                var altName = fileGameName.Contains(' ') ? fileGameName : dirGameName;
                if (altName.Contains(' '))
                    gameName = altName;
            }

            return new Game
            {
                Name = gameName,
                ExecutablePath = exePath,
                InstallDirectory = installDir,
                DateAdded = DateTime.Now
            };
        }

        private string CleanGameName(string name)
        {
            if (string.IsNullOrWhiteSpace(name))
                return "Unknown Game";

            // Replace separators with spaces
            name = name.Replace("_", " ").Replace("-", " ");
            
            // Insert spaces before capital letters in camelCase/PascalCase
            name = System.Text.RegularExpressions.Regex.Replace(name, @"([a-z])([A-Z])", "$1 $2");
            name = System.Text.RegularExpressions.Regex.Replace(name, @"([A-Z]+)([A-Z][a-z])", "$1 $2");
            
            // Insert spaces before numbers
            name = System.Text.RegularExpressions.Regex.Replace(name, @"([a-zA-Z])(\d)", "$1 $2");
            name = System.Text.RegularExpressions.Regex.Replace(name, @"(\d)([a-zA-Z])", "$1 $2");
            
            // Remove version numbers and years (but keep game titles with numbers like "Nioh 3")
            name = System.Text.RegularExpressions.Regex.Replace(name, @"v\d+(\.\d+)*", "", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            name = System.Text.RegularExpressions.Regex.Replace(name, @"\b(19|20)\d{2}\b", "");
            
            // Remove common suffixes
            var suffixes = new[] { 
                "Master Collection", "Definitive Edition", "Game of the Year",
                "Complete Edition", "Remastered", "Enhanced Edition", "GOTY",
                "Directors Cut", "Ultimate Edition", "Gold Edition", "Digital Deluxe"
            };
            
            foreach (var suffix in suffixes)
            {
                name = name.Replace(suffix, "", StringComparison.OrdinalIgnoreCase);
            }
            
            // Collapse multiple spaces
            name = System.Text.RegularExpressions.Regex.Replace(name, @"\s+", " ").Trim();

            // Capitalize properly (Title Case)
            // Known acronyms/roman numerals to keep as-is
            var keepAsIs = new[] { "II", "III", "IV", "VI", "VII", "VIII", "IX", "XI", "XII", "XIII", "XIV", "XV", "XVI", "DLC", "RPG", "HD", "VR", "XL" };
            
            var words = name.Split(' ');
            for (int i = 0; i < words.Length; i++)
            {
                if (words[i].Length > 0)
                {
                    var upper = words[i].ToUpperInvariant();
                    
                    // Keep known acronyms/roman numerals
                    if (keepAsIs.Contains(upper))
                    {
                        words[i] = upper;
                    }
                    // Lowercase articles/prepositions (except first word)
                    else if (i > 0 && new[] { "and", "of", "the", "a", "an", "in", "on", "at", "to", "for" }.Contains(words[i].ToLower()))
                    {
                        words[i] = words[i].ToLower();
                    }
                    // Pure numbers - keep as-is
                    else if (words[i].All(char.IsDigit))
                    {
                        words[i] = words[i];
                    }
                    // Title case everything else
                    else
                    {
                        words[i] = char.ToUpper(words[i][0]) + words[i].Substring(1).ToLower();
                    }
                }
            }

            name = string.Join(" ", words).Trim();
            
            return string.IsNullOrWhiteSpace(name) ? "Unknown Game" : name;
        }
    }
}
