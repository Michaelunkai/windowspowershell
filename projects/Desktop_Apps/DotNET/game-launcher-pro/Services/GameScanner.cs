using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using game_launcher_winforms.Models;

namespace game_launcher_winforms.Services
{
    public class GameScanner
    {
        private readonly string[] _scanPaths = new[] 
        { 
            @"E:\games",
            @"F:\games"
        };

        private readonly CoverImageDownloader _coverDownloader;

        public GameScanner()
        {
            _coverDownloader = new CoverImageDownloader();
        }

        // Common game launcher exe names to skip
        private readonly HashSet<string> _blacklist = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "unins000.exe",
            "uninstall.exe",
            "setup.exe",
            "launcher.exe",
            "updater.exe",
            "crash.exe",
            "crashreport.exe",
            "crashhandler.exe",
            "ue4prereqsetup_x64.exe",
            "unity.exe",
            "unitycrashhandler64.exe",
            "unitycrashhandler32.exe",
            "benchmark.exe",
            "config.exe",
            "settings.exe",
            "vc_redist.x64.exe",
            "vc_redist.x86.exe",
            "vcredist_x64.exe",
            "vcredist_x86.exe",
            "dxsetup.exe",
            "directx.exe",
            "dotnetfx.exe",
            "setup_redlauncher.exe",
            "redlauncher.exe",
            "calleditor.exe",
            "editor.exe",
            "ghost.exe",
            "redprelauncher.exe",
            "quicksfv.exe",
            "dxwebsetup.exe"
        };

        public async Task<List<Game>> ScanForNewGamesAsync(List<Game> existingGames)
        {
            var newGames = new List<Game>();
            var existingPaths = new HashSet<string>(
                existingGames.Select(g => g.ExecutablePath), 
                StringComparer.OrdinalIgnoreCase
            );

            Console.WriteLine($"[Scanner] Starting scan of {_scanPaths.Length} directories...");

            foreach (var basePath in _scanPaths)
            {
                if (!Directory.Exists(basePath))
                {
                    Console.WriteLine($"[Scanner] SKIP: {basePath} does not exist");
                    continue;
                }

                Console.WriteLine($"[Scanner] Scanning: {basePath}");

                try
                {
                    // Get all subdirectories (each game folder)
                    var gameDirs = Directory.GetDirectories(basePath);
                    Console.WriteLine($"[Scanner] Found {gameDirs.Length} subdirectories");

                    foreach (var gameDir in gameDirs)
                    {
                        var gameName = Path.GetFileName(gameDir);
                        
                        // Find the main executable
                        var mainExe = FindMainExecutable(gameDir);
                        
                        if (mainExe != null && !existingPaths.Contains(mainExe))
                        {
                            // Check if we already have a game from this install directory
                            var existingGameInDir = existingGames.FirstOrDefault(g => 
                                g.InstallDirectory.Equals(gameDir, StringComparison.OrdinalIgnoreCase));
                            
                            if (existingGameInDir != null)
                            {
                                Console.WriteLine($"[Scanner] SKIP: {gameName} - already have game from this directory ({existingGameInDir.Name})");
                                continue;
                            }

                            var gameId = Guid.NewGuid().ToString();
                            var cleanName = CleanGameName(gameName);

                            // Download cover image
                            var coverPath = await _coverDownloader.DownloadCoverAsync(gameId, cleanName);

                            var game = new Game
                            {
                                Id = gameId,
                                Name = cleanName,
                                ExecutablePath = mainExe,
                                InstallDirectory = gameDir,
                                CoverImagePath = coverPath,
                                BackgroundImagePath = "",
                                Description = "",
                                DateAdded = DateTime.Now,
                                LastPlayed = null,
                                PlayCount = 0,
                                PlaytimeMinutes = 0,
                                IsFavorite = false,
                                Tags = Array.Empty<string>()
                            };

                            newGames.Add(game);
                            existingPaths.Add(mainExe);
                            Console.WriteLine($"[Scanner] NEW: {game.Name} -> {Path.GetFileName(mainExe)} [Image: {(!string.IsNullOrEmpty(coverPath) ? "✓" : "✗")}]");
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[Scanner] ERROR scanning {basePath}: {ex.Message}");
                }
            }

            Console.WriteLine($"[Scanner] Scan complete. Found {newGames.Count} new games");
            return newGames;
        }

        private string? FindMainExecutable(string gameDir)
        {
            try
            {
                // Get all .exe files in the game directory and subdirectories (up to 3 levels)
                var exeFiles = Directory.GetFiles(gameDir, "*.exe", SearchOption.AllDirectories)
                    .Where(f =>
                    {
                        var relativePath = Path.GetRelativePath(gameDir, f);
                        var depth = relativePath.Split(Path.DirectorySeparatorChar).Length - 1;
                        return depth <= 3; // Max 3 levels deep
                    })
                    .Where(f => !_blacklist.Contains(Path.GetFileName(f)))
                    .ToList();

                if (exeFiles.Count == 0)
                    return null;

                // Priority 1: exe in root with same name as folder
                var gameName = Path.GetFileName(gameDir);
                var rootExes = exeFiles.Where(f => Path.GetDirectoryName(f) == gameDir).ToList();
                var matchingName = rootExes.FirstOrDefault(f =>
                    Path.GetFileNameWithoutExtension(f).Equals(gameName, StringComparison.OrdinalIgnoreCase));
                if (matchingName != null)
                    return matchingName;

                // Priority 2: any exe in root
                if (rootExes.Any())
                    return rootExes.OrderByDescending(f => new FileInfo(f).Length).First();

                // Priority 3: exe in bin folder
                var binExe = exeFiles.FirstOrDefault(f =>
                    f.Contains(@"\bin\", StringComparison.OrdinalIgnoreCase) ||
                    f.Contains(@"\Binaries\", StringComparison.OrdinalIgnoreCase));
                if (binExe != null)
                    return binExe;

                // Priority 4: largest exe file (likely the main game)
                return exeFiles.OrderByDescending(f => new FileInfo(f).Length).First();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Scanner] ERROR finding exe in {gameDir}: {ex.Message}");
                return null;
            }
        }

        private string CleanGameName(string rawName)
        {
            // Remove common version numbers and cleanup
            var cleaned = rawName
                .Replace("_", " ")
                .Replace("-", " ");

            // Capitalize each word
            var words = cleaned.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            return string.Join(" ", words.Select(w =>
                char.ToUpper(w[0]) + (w.Length > 1 ? w.Substring(1) : "")));
        }

        public List<Game> RemoveDeletedGames(List<Game> games)
        {
            var validGames = new List<Game>();
            var removedCount = 0;

            foreach (var game in games)
            {
                if (File.Exists(game.ExecutablePath))
                {
                    validGames.Add(game);
                }
                else
                {
                    Console.WriteLine($"[Scanner] REMOVED: {game.Name} (exe not found)");
                    removedCount++;
                }
            }

            if (removedCount > 0)
            {
                Console.WriteLine($"[Scanner] Removed {removedCount} deleted games");
            }

            return validGames;
        }
    }
}
