using System;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using System.Drawing;
using System.Drawing.Imaging;
using Newtonsoft.Json.Linq;
using GameLauncherPro.Models;

namespace GameLauncherPro.Services
{
    public class MetadataService
    {
        private readonly HttpClient _httpClient;
        private readonly string _imageCache;

        public MetadataService()
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

        public async Task<bool> FetchMetadata(Game game)
        {
            try
            {
                // Skip if already has a good quality image (JPG from API)
                if (!string.IsNullOrEmpty(game.CoverImagePath) && 
                    File.Exists(game.CoverImagePath) &&
                    game.CoverImagePath.EndsWith(".jpg", StringComparison.OrdinalIgnoreCase))
                {
                    Console.WriteLine($"Skipping {game.Name} - already has high-quality image");
                    return true;
                }
                
                Console.WriteLine($"Fetching metadata for: {game.Name}");
                
                // Try multiple sources in order
                if (await FetchFromSteamGridDB(game)) return true;
                Console.WriteLine("  SteamGridDB failed, trying RAWG...");
                
                if (await FetchFromRAWG(game)) return true;
                Console.WriteLine("  RAWG failed, extracting exe icon...");
                
                if (ExtractIconFromExecutable(game)) return true;
                Console.WriteLine("  Icon extraction failed, using placeholder...");
                
                // Always generate placeholder as final fallback
                GeneratePlaceholder(game);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error fetching metadata for {game.Name}: {ex.Message}");
                GeneratePlaceholder(game);
                return false;
            }
        }

        private async Task<bool> FetchFromSteamGridDB(Game game)
        {
            try
            {
                var searchName = Uri.EscapeDataString(game.Name);
                var url = $"https://www.steamgriddb.com/api/public/search/autocomplete/{searchName}";

                var response = await _httpClient.GetStringAsync(url);
                var json = JObject.Parse(response);

                if (json["success"]?.Value<bool>() == true && json["data"] is JArray games && games.Count > 0)
                {
                    var firstGame = games[0];
                    var gameId = firstGame["id"]?.Value<int>();
                    
                    if (gameId.HasValue)
                    {
                        var gridUrl = $"https://www.steamgriddb.com/api/public/grid/game/{gameId}";
                        var gridResponse = await _httpClient.GetStringAsync(gridUrl);
                        var gridJson = JObject.Parse(gridResponse);

                        if (gridJson["data"] is JArray grids && grids.Count > 0)
                        {
                            var imageUrl = grids[0]["url"]?.Value<string>();
                            if (!string.IsNullOrEmpty(imageUrl))
                            {
                                var coverPath = await DownloadImage(imageUrl, game.Id, "cover");
                                if (!string.IsNullOrEmpty(coverPath))
                                {
                                    game.CoverImagePath = coverPath;
                                    game.BackgroundImagePath = coverPath;
                                    Console.WriteLine($"  ✓ Downloaded from SteamGridDB");
                                    return true;
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  SteamGridDB error: {ex.Message}");
            }

            return false;
        }

        private async Task<bool> FetchFromRAWG(Game game)
        {
            try
            {
                var searchName = Uri.EscapeDataString(game.Name);
                var url = $"https://api.rawg.io/api/games?search={searchName}&page_size=1";

                var response = await _httpClient.GetStringAsync(url);
                var json = JObject.Parse(response);

                if (json["results"] is JArray results && results.Count > 0)
                {
                    var firstGame = results[0];
                    var backgroundImage = firstGame["background_image"]?.Value<string>();
                    
                    if (!string.IsNullOrEmpty(backgroundImage))
                    {
                        var imagePath = await DownloadImage(backgroundImage, game.Id, "cover");
                        if (!string.IsNullOrEmpty(imagePath))
                        {
                            game.CoverImagePath = imagePath;
                            game.BackgroundImagePath = imagePath;
                            Console.WriteLine($"  ✓ Downloaded from RAWG");
                            return true;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  RAWG error: {ex.Message}");
            }

            return false;
        }

        private bool ExtractIconFromExecutable(Game game)
        {
            try
            {
                if (!File.Exists(game.ExecutablePath))
                    return false;

                var icon = Icon.ExtractAssociatedIcon(game.ExecutablePath);
                if (icon == null)
                    return false;

                var outputPath = Path.Combine(_imageCache, $"{game.Id}_icon.png");
                
                // Convert icon to bitmap and save at higher resolution
                using (var bitmap = icon.ToBitmap())
                {
                    // Use original size if it's already large, otherwise upscale to 512x512
                    int targetSize = Math.Max(bitmap.Width, 512);
                    
                    using (var resized = new Bitmap(targetSize, targetSize))
                    using (var graphics = Graphics.FromImage(resized))
                    {
                        // Use high-quality rendering
                        graphics.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                        graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.HighQuality;
                        graphics.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                        graphics.CompositingQuality = System.Drawing.Drawing2D.CompositingQuality.HighQuality;
                        
                        graphics.DrawImage(bitmap, 0, 0, targetSize, targetSize);
                        resized.Save(outputPath, ImageFormat.Png);
                    }
                }

                game.CoverImagePath = outputPath;
                game.BackgroundImagePath = outputPath;
                Console.WriteLine($"  ✓ Extracted exe icon");
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Icon extraction error: {ex.Message}");
                return false;
            }
        }

        private void GeneratePlaceholder(Game game)
        {
            try
            {
                var outputPath = Path.Combine(_imageCache, $"{game.Id}_placeholder.png");

                using (var bitmap = new Bitmap(200, 200))
                using (var graphics = Graphics.FromImage(bitmap))
                {
                    // Create gradient background
                    var random = new Random(game.Name.GetHashCode());
                    var color1 = Color.FromArgb(random.Next(50, 150), random.Next(50, 150), random.Next(50, 150));
                    var color2 = Color.FromArgb(30, 30, 30);
                    
                    using (var brush = new System.Drawing.Drawing2D.LinearGradientBrush(
                        new Rectangle(0, 0, 200, 200), color1, color2, 45f))
                    {
                        graphics.FillRectangle(brush, 0, 0, 200, 200);
                    }

                    // Draw game icon
                    using (var font = new Font("Segoe UI", 48, FontStyle.Bold))
                    using (var textBrush = new SolidBrush(Color.FromArgb(180, 180, 180)))
                    {
                        var iconText = "🎮";
                        var textSize = graphics.MeasureString(iconText, font);
                        graphics.DrawString(iconText, font, textBrush, 
                            (200 - textSize.Width) / 2, (200 - textSize.Height) / 2 - 20);
                    }

                    // Draw game name
                    var gameName = game.Name.Length > 20 ? game.Name.Substring(0, 17) + "..." : game.Name;
                    using (var font = new Font("Segoe UI", 10, FontStyle.Bold))
                    using (var textBrush = new SolidBrush(Color.White))
                    {
                        var format = new StringFormat
                        {
                            Alignment = StringAlignment.Center,
                            LineAlignment = StringAlignment.Center
                        };
                        graphics.DrawString(gameName, font, textBrush, 
                            new RectangleF(5, 150, 190, 45), format);
                    }

                    bitmap.Save(outputPath, ImageFormat.Png);
                }

                game.CoverImagePath = outputPath;
                game.BackgroundImagePath = outputPath;
                Console.WriteLine($"  ✓ Generated placeholder");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Placeholder generation error: {ex.Message}");
            }
        }

        private async Task<string> DownloadImage(string url, string gameId, string type)
        {
            try
            {
                var extension = Path.GetExtension(url).Split('?')[0];
                if (string.IsNullOrEmpty(extension)) extension = ".jpg";

                var fileName = $"{gameId}_{type}{extension}";
                var filePath = Path.Combine(_imageCache, fileName);

                if (File.Exists(filePath))
                    return filePath;

                var imageData = await _httpClient.GetByteArrayAsync(url);
                await File.WriteAllBytesAsync(filePath, imageData);

                return filePath;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Download error: {ex.Message}");
                return string.Empty;
            }
        }

        public async Task FetchAllMetadata(System.Collections.Generic.List<Game> games)
        {
            // Filter to only games needing metadata
            var gamesNeedingMetadata = games.Where(g => 
                string.IsNullOrEmpty(g.CoverImagePath) || 
                !File.Exists(g.CoverImagePath)).ToList();
            
            if (gamesNeedingMetadata.Count == 0)
            {
                Console.WriteLine("All games already have images!");
                return;
            }
            
            Console.WriteLine($"\n=== Fetching metadata for {gamesNeedingMetadata.Count} games ===");
            
            int success = 0;
            for (int i = 0; i < gamesNeedingMetadata.Count; i++)
            {
                var game = gamesNeedingMetadata[i];
                Console.WriteLine($"[{i+1}/{gamesNeedingMetadata.Count}] {game.Name}");
                
                if (await FetchMetadata(game))
                    success++;
                
                await Task.Delay(1000); // Rate limiting
            }

            Console.WriteLine($"=== Metadata complete: {success}/{gamesNeedingMetadata.Count} successful ===");
        }
    }
}
