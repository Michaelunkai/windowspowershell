using System;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using GameLauncherPro.Models;

namespace GameLauncherPro.Services
{
    public class ImprovedMetadataService
    {
        private readonly HttpClient _httpClient;
        private readonly string _imageCache;

        public ImprovedMetadataService()
        {
            _httpClient = new HttpClient();
            _httpClient.DefaultRequestHeaders.Add("User-Agent", "GameLauncherPro/1.0");
            _httpClient.Timeout = TimeSpan.FromSeconds(15);
            
            _imageCache = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "GameLauncherPro", "cache", "images"
            );
            Directory.CreateDirectory(_imageCache);
        }

        public async Task<bool> FetchMetadataFromGoogle(Game game)
        {
            try
            {
                // Use Google Images search (scraping approach)
                var searchTerm = Uri.EscapeDataString($"{game.Name} game cover");
                var url = $"https://www.google.com/search?q={searchTerm}&tbm=isch";

                var response = await _httpClient.GetStringAsync(url);
                
                // Extract first image URL from HTML
                var imgStartIndex = response.IndexOf("https://", response.IndexOf("\"ou\":\""));
                if (imgStartIndex > 0)
                {
                    var imgEndIndex = response.IndexOf("\"", imgStartIndex);
                    if (imgEndIndex > imgStartIndex)
                    {
                        var imageUrl = response.Substring(imgStartIndex, imgEndIndex - imgStartIndex);
                        game.CoverImagePath = await DownloadImage(imageUrl, game.Id, "cover");
                        game.BackgroundImagePath = game.CoverImagePath;
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Google search error for {game.Name}: {ex.Message}");
            }

            return false;
        }

        public async Task<bool> FetchMetadataManual(Game game)
        {
            // Generate placeholder images with game name
            try
            {
                var placeholderPath = Path.Combine(_imageCache, $"{game.Id}_placeholder.png");
                
                // Create simple colored placeholder (would need System.Drawing in real impl)
                // For now, just mark as attempted
                game.CoverImagePath = "placeholder";
                return true;
            }
            catch
            {
                return false;
            }
        }

        private async Task<string> DownloadImage(string url, string gameId, string type)
        {
            try
            {
                var extension = ".jpg";
                var fileName = $"{gameId}_{type}{extension}";
                var filePath = Path.Combine(_imageCache, fileName);

                if (File.Exists(filePath))
                {
                    return filePath;
                }

                var imageData = await _httpClient.GetByteArrayAsync(url);
                await File.WriteAllBytesAsync(filePath, imageData);

                Console.WriteLine($"Downloaded {type} for {gameId}");
                return filePath;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Download error: {ex.Message}");
                return string.Empty;
            }
        }

        public async Task FetchAllMetadata(List<Game> games)
        {
            Console.WriteLine($"Attempting metadata fetch for {games.Count} games...");
            
            foreach (var game in games)
            {
                try
                {
                    var success = await FetchMetadataFromGoogle(game);
                    if (!success)
                    {
                        await FetchMetadataManual(game);
                    }
                    await Task.Delay(2000); // Rate limiting
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error for {game.Name}: {ex.Message}");
                }
            }
        }
    }
}
