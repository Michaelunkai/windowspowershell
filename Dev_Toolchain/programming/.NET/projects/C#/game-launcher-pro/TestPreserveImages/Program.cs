using System;
using System.Linq;
using System.Threading.Tasks;
using GameLauncherPro.Services;

namespace TestPreserveImages
{
    class Program
    {
        static async Task Main(string[] args)
        {
            Console.WriteLine("=== Test: Preserve Existing Images ===\n");
            
            var database = new GameDatabase();
            var scanner = new GameScanner();
            var metadata = new MetadataService();
            
            // Load existing games
            var existingGames = database.GetAllGames();
            Console.WriteLine($"Existing games in database: {existingGames.Count}");
            
            var withImages = existingGames.Where(g => !string.IsNullOrEmpty(g.CoverImagePath) && System.IO.File.Exists(g.CoverImagePath)).Count();
            Console.WriteLine($"Games with existing images: {withImages}\n");
            
            // Scan for new games
            Console.WriteLine("Scanning for games...");
            var scannedGames = scanner.ScanAllDrives();
            Console.WriteLine($"Found {scannedGames.Count} games\n");
            
            // Add to database (will skip duplicates)
            database.AddGames(scannedGames);
            
            // Fetch metadata (should skip games with good images)
            var allGames = database.GetAllGames();
            await metadata.FetchAllMetadata(allGames);
            
            // Verify old images preserved
            Console.WriteLine("\n=== Verification ===");
            var finalGames = database.GetAllGames();
            
            foreach (var game in finalGames.OrderBy(g => g.Name))
            {
                var hasImage = !string.IsNullOrEmpty(game.CoverImagePath) && System.IO.File.Exists(game.CoverImagePath);
                var imageType = hasImage ? (game.CoverImagePath.EndsWith(".jpg") ? "JPG" : "PNG") : "NONE";
                Console.WriteLine($"{(hasImage ? "✓" : "✗")} {game.Name,-35} [{imageType}]");
            }
            
            var finalWithJpg = finalGames.Count(g => !string.IsNullOrEmpty(g.CoverImagePath) && g.CoverImagePath.EndsWith(".jpg", StringComparison.OrdinalIgnoreCase));
            Console.WriteLine($"\n✓ Games with high-quality JPG images: {finalWithJpg}");
        }
    }
}
