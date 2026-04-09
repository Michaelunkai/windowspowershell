using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace GitDesk
{
    /// <summary>
    /// Manages repository persistence and recent repositories list.
    /// Automatically saves last opened repo and provides enterprise-grade state management.
    /// </summary>
    public static class RepoManager
    {
        private static readonly string ConfigPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "GitDesk", "repos.json");

        public static RepoConfig Load()
        {
            try
            {
                if (!File.Exists(ConfigPath))
                    return new RepoConfig();

                string json = File.ReadAllText(ConfigPath);
                return JsonSerializer.Deserialize<RepoConfig>(json) ?? new RepoConfig();
            }
            catch
            {
                return new RepoConfig();
            }
        }

        public static void Save(RepoConfig config)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(ConfigPath)!);
                string json = JsonSerializer.Serialize(config, new JsonSerializerOptions
                {
                    WriteIndented = true
                });
                File.WriteAllText(ConfigPath, json);
            }
            catch { }
        }

        public static void AddRecent(string path)
        {
            var config = Load();
            
            // Normalize path
            path = Path.GetFullPath(path).TrimEnd('\\', '/');
            
            // Remove if already exists
            config.RecentRepos.RemoveAll(r => string.Equals(r.Path, path, StringComparison.OrdinalIgnoreCase));
            
            // Add to front
            config.RecentRepos.Insert(0, new RepoEntry
            {
                Path = path,
                Name = Path.GetFileName(path),
                LastOpened = DateTime.Now
            });
            
            // Keep only last 20
            if (config.RecentRepos.Count > 20)
                config.RecentRepos = config.RecentRepos.Take(20).ToList();
            
            config.LastOpenedRepo = path;
            Save(config);
        }

        public static void RemoveRecent(string path)
        {
            var config = Load();
            config.RecentRepos.RemoveAll(r => string.Equals(r.Path, path, StringComparison.OrdinalIgnoreCase));
            Save(config);
        }

        public static void SetLastRepo(string path)
        {
            var config = Load();
            config.LastOpenedRepo = path;
            Save(config);
        }

        public static string? GetLastRepo()
        {
            var config = Load();
            return config.LastOpenedRepo;
        }

        public static List<RepoEntry> GetRecentRepos()
        {
            var config = Load();
            return config.RecentRepos.Where(r => Directory.Exists(r.Path)).ToList();
        }

        public static void SaveWindowState(double width, double height, bool maximized)
        {
            var config = Load();
            config.WindowWidth = width;
            config.WindowHeight = height;
            config.WindowMaximized = maximized;
            Save(config);
        }

        public static (double Width, double Height, bool Maximized) GetWindowState()
        {
            var config = Load();
            return (config.WindowWidth, config.WindowHeight, config.WindowMaximized);
        }
    }

    public class RepoConfig
    {
        public string? LastOpenedRepo { get; set; }
        public List<RepoEntry> RecentRepos { get; set; } = new();
        public double WindowWidth { get; set; } = 1400;
        public double WindowHeight { get; set; } = 900;
        public bool WindowMaximized { get; set; } = false;
    }

    public class RepoEntry
    {
        public string Path { get; set; } = "";
        public string Name { get; set; } = "";
        public DateTime LastOpened { get; set; }
    }
}
