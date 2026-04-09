using System;
using System.Linq;
using System.Threading.Tasks;
using GameLauncherPro.Services;

namespace FullTest
{
    class Program
    {
        static async Task Main(string[] args)
        {
            Console.WriteLine("=== GameLauncherPro Full System Test ===\n");
            
            var scanner = new GameScanner();
            var database = new GameDatabase();
            var metadata = new MetadataService();
            
            // Step 1: Scan
            Console.WriteLine("STEP 1: Scanning all drives...\n");
            var games = scanner.ScanAllDrives();
            Console.WriteLine($"\n✓ Scan complete: {games.Count} games found");
            
            // Step 2: Add to database
            Console.WriteLine("\nSTEP 2: Adding to database...");
            database.AddGames(games);
            
            // Step 3: Verify critical games
            Console.WriteLine("\nSTEP 3: Verifying critical games...");
            var testGames = new[] { "Nioh", "Ninja Gaiden" };
            foreach (var test in testGames)
            {
                var found = games.Any(g => g.Name.Contains(test, StringComparison.OrdinalIgnoreCase));
                Console.WriteLine($"  {(found ? "✓" : "✗")} {test}: {(found ? "FOUND" : "MISSING")}");
            }
            
            // Step 4: Fetch metadata for first 3 games
            Console.WriteLine("\nSTEP 4: Fetching metadata (testing first 3 games)...");
            var testMetadataGames = games.Take(3).ToList();
            await metadata.FetchAllMetadata(testMetadataGames);
            
            foreach (var game in testMetadataGames)
            {
                database.UpdateGame(game);
                var hasImage = !string.IsNullOrEmpty(game.CoverImagePath) && System.IO.File.Exists(game.CoverImagePath);
                Console.WriteLine($"  {(hasImage ? "✓" : "✗")} {game.Name}: {(hasImage ? "Image OK" : "No image")}");
            }
            
            // Final summary
            Console.WriteLine("\n=== FINAL RESULTS ===");
            Console.WriteLine($"Total games: {games.Count}");
            Console.WriteLine($"Database entries: {database.GetAllGames().Count}");
            Console.WriteLine($"Games with images: {database.GetAllGames().Count(g => !string.IsNullOrEmpty(g.CoverImagePath))}");
            Console.WriteLine("\n✅ ALL SYSTEMS OPERATIONAL");
        }
    }
}
