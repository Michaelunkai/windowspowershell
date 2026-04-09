using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using GameLauncherPro.Services;

namespace FixNamesAndImages
{
    class Program
    {
        static async Task Main(string[] args)
        {
            Console.WriteLine("=== Fix Names and Refetch Images ===\n");
            
            var database = new GameDatabase();
            var metadata = new MetadataService();
            
            var games = database.GetAllGames();
            
            // Fix game names
            var nioh = games.FirstOrDefault(g => g.Name.Contains("Nioh3"));
            if (nioh != null)
            {
                Console.WriteLine($"Fixing: {nioh.Name} -> Nioh 3");
                nioh.Name = "Nioh 3";
                // Delete old PNG image
                if (File.Exists(nioh.CoverImagePath))
                    File.Delete(nioh.CoverImagePath);
                nioh.CoverImagePath = "";
                nioh.BackgroundImagePath = "";
                database.UpdateGame(nioh);
            }
            
            var ninjaGaiden = games.FirstOrDefault(g => g.Name.Contains("Ninjagaidenragebound"));
            if (ninjaGaiden != null)
            {
                Console.WriteLine($"Fixing: {ninjaGaiden.Name} -> Ninja Gaiden Ragebound");
                ninjaGaiden.Name = "Ninja Gaiden Ragebound";
                // Delete old PNG image
                if (File.Exists(ninjaGaiden.CoverImagePath))
                    File.Delete(ninjaGaiden.CoverImagePath);
                ninjaGaiden.CoverImagePath = "";
                ninjaGaiden.BackgroundImagePath = "";
                database.UpdateGame(ninjaGaiden);
            }
            
            // Refetch metadata for games without images
            Console.WriteLine("\nRefetching images...");
            var needImages = database.GetAllGames().Where(g => string.IsNullOrEmpty(g.CoverImagePath)).ToList();
            
            if (needImages.Any())
            {
                await metadata.FetchAllMetadata(needImages);
                
                // Update database
                foreach (var game in needImages)
                {
                    database.UpdateGame(game);
                }
            }
            
            Console.WriteLine("\n✓ Complete!");
        }
    }
}
