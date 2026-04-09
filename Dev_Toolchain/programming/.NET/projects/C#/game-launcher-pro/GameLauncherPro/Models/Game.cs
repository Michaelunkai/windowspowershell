using System;

namespace GameLauncherPro.Models
{
    public class Game
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public string Name { get; set; } = string.Empty;
        public string ExecutablePath { get; set; } = string.Empty;
        public string InstallDirectory { get; set; } = string.Empty;
        public string CoverImagePath { get; set; } = string.Empty;
        public string BackgroundImagePath { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public DateTime DateAdded { get; set; } = DateTime.Now;
        public DateTime? LastPlayed { get; set; }
        public int PlayCount { get; set; } = 0;
        public long PlaytimeMinutes { get; set; } = 0;
        public bool IsFavorite { get; set; } = false;
        public string[] Tags { get; set; } = Array.Empty<string>();
    }
}
