using System;
using System.Linq;
using System.Threading.Tasks;
using GameLauncherPro.Services;

namespace MetadataTest
{
    class Program
    {
        static async Task Main(string[] args)
        {
            Console.WriteLine("=== Metadata Service Test ===\n");
            
            var database = new GameDatabase();
            var metadata = new MetadataService();
            
            var games = database.GetAllGames();
            var gamesWithoutImages = games.Where(g => string.IsNullOrEmpty(g.CoverImagePath) || !System.IO.File.Exists(g.CoverImagePath)).ToList();
            
            Console.WriteLine($"Found {gamesWithoutImages.Count} games without images\n");
            
            if (gamesWithoutImages.Count > 0)
            {
                await metadata.FetchAllMetadata(gamesWithoutImages);
                
                // Save updated games
                foreach (var game in gamesWithoutImages)
                {
                    database.UpdateGame(game);
                }
                
                Console.WriteLine("\n=== Results ===");
                foreach (var game in gamesWithoutImages)
                {
                    var hasImage = !string.IsNullOrEmpty(game.CoverImagePath) && System.IO.File.Exists(game.CoverImagePath);
                    Console.WriteLine($"{(hasImage ? "✓" : "✗")} {game.Name}: {(hasImage ? "Has image" : "No image")}");
                }
            }
            else
            {
                Console.WriteLine("All games already have images!");
            }
            
            Console.WriteLine("\n=== Test Complete ===");
        }
    }
}
