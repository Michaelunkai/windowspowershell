using System;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;

namespace game_launcher_winforms.Services
{
    public class CoverImageDownloader
    {
        private readonly string _cacheDir;
        private readonly HttpClient _httpClient;

        public CoverImageDownloader()
        {
            _cacheDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "GameLauncherPro", "cache", "images"
            );
            Directory.CreateDirectory(_cacheDir);

            _httpClient = new HttpClient();
            _httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36");
            _httpClient.Timeout = TimeSpan.FromSeconds(15);
        }

        public async Task<string> DownloadCoverAsync(string gameId, string gameName)
        {
            var imagePath = Path.Combine(_cacheDir, $"{gameId}_cover.jpg");

            // Try multiple sources in order
            var sources = new[]
            {
                () => TryDownloadFromSteamSearch(gameName, imagePath),
                () => TryDownloadFromSteamGridDB(gameName, imagePath),
                () => TryDownloadGenericSearch(gameName, imagePath)
            };

            foreach (var tryDownload in sources)
            {
                try
                {
                    if (await tryDownload())
                    {
                        Console.WriteLine($"[Cover] Downloaded: {gameName}");
                        return imagePath;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[Cover] Failed source for {gameName}: {ex.Message}");
                }
            }

            Console.WriteLine($"[Cover] No image found for {gameName}");
            return string.Empty;
        }

        private async Task<bool> TryDownloadFromSteamSearch(string gameName, string imagePath)
        {
            try
            {
                // Try to find Steam App ID by searching
                var searchUrl = $"https://steamcommunity.com/actions/SearchApps/{Uri.EscapeDataString(gameName)}";
                var searchResponse = await _httpClient.GetStringAsync(searchUrl);

                Console.WriteLine($"[Cover] Steam search for '{gameName}': {searchResponse.Substring(0, Math.Min(200, searchResponse.Length))}");

                // Parse JSON manually (response is like: [{"appid":"1145360","name":"Hades","logo":"..."}])
                var appidMatch = System.Text.RegularExpressions.Regex.Match(searchResponse, "\"appid\"\\s*:\\s*\"?(\\d+)\"?");
                if (!appidMatch.Success)
                {
                    Console.WriteLine($"[Cover] No appid found in response");
                    return false;
                }

                var appid = appidMatch.Groups[1].Value;
                Console.WriteLine($"[Cover] Found Steam ID: {appid}");

                // Download header image
                var imageUrl = $"https://cdn.cloudflare.steamstatic.com/steam/apps/{appid}/header.jpg";
                return await DownloadImageAsync(imageUrl, imagePath);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Cover] Steam search error: {ex.Message}");
                return false;
            }
        }

        private async Task<bool> TryDownloadFromSteamGridDB(string gameName, string imagePath)
        {
            // SteamGridDB free API (no key needed for search)
            // This is a fallback - may not work without API key
            var searchUrl = $"https://www.steamgriddb.com/search/autocomplete/{Uri.EscapeDataString(gameName)}";
            
            try
            {
                var response = await _httpClient.GetStringAsync(searchUrl);
                // Try to extract image URL from response
                var imgIndex = response.IndexOf("\"thumb\":");
                if (imgIndex == -1) return false;

                var urlStart = response.IndexOf("http", imgIndex);
                if (urlStart == -1) return false;

                var urlEnd = response.IndexOf("\"", urlStart);
                if (urlEnd == -1) return false;

                var imageUrl = response.Substring(urlStart, urlEnd - urlStart);
                return await DownloadImageAsync(imageUrl, imagePath);
            }
            catch
            {
                return false;
            }
        }

        private async Task<bool> TryDownloadGenericSearch(string gameName, string imagePath)
        {
            // Fallback: Try direct game folder images first
            var gameExePath = gameName; // This would need the actual exe path
            // Look for common image files in game directory
            // This is a placeholder - would need actual implementation
            return false;
        }

        private async Task<bool> DownloadImageAsync(string url, string savePath)
        {
            try
            {
                Console.WriteLine($"[Cover] Downloading from: {url}");
                var response = await _httpClient.GetAsync(url);
                if (!response.IsSuccessStatusCode)
                {
                    Console.WriteLine($"[Cover] HTTP {response.StatusCode}");
                    return false;
                }

                var imageBytes = await response.Content.ReadAsByteArrayAsync();
                Console.WriteLine($"[Cover] Downloaded {imageBytes.Length} bytes");
                
                if (imageBytes.Length < 1000)
                {
                    Console.WriteLine($"[Cover] Image too small, probably error page");
                    return false;
                }

                await File.WriteAllBytesAsync(savePath, imageBytes);
                var success = File.Exists(savePath);
                Console.WriteLine($"[Cover] Saved to: {savePath} [Success: {success}]");
                return success;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Cover] Download error: {ex.Message}");
                return false;
            }
        }

        public void Dispose()
        {
            _httpClient?.Dispose();
        }
    }
}
