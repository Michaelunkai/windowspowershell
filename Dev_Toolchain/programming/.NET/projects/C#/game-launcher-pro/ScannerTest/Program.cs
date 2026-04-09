using System;
using System.Linq;
using GameLauncherPro.Services;

namespace ScannerTest
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("=== GameLauncherPro Scanner Test ===\n");
            
            var scanner = new GameScanner();
            var database = new GameDatabase();
            
            Console.WriteLine("Starting scan...\n");
            var games = scanner.ScanAllDrives();
            
            Console.WriteLine($"\n=== Scan Results ===" );
            Console.WriteLine($"Found {games.Count} games total\n");
            
            // Test for specific games
            var testGames = new[] { "Nioh3", "ninjagaidenragebound", "Ninja Gaiden Ragebound" };
            
            foreach (var testName in testGames)
            {
                var found = games.FirstOrDefault(g => 
                    g.Name.Contains(testName, StringComparison.OrdinalIgnoreCase) ||
                    g.InstallDirectory.Contains(testName, StringComparison.OrdinalIgnoreCase));
                
                if (found != null)
                {
                    Console.WriteLine($"✓ FOUND: {found.Name}");
                    Console.WriteLine($"  Exe: {found.ExecutablePath}");
                    Console.WriteLine($"  Dir: {found.InstallDirectory}\n");
                }
                else
                {
                    Console.WriteLine($"✗ NOT FOUND: {testName}\n");
                }
            }
            
            // Add games to database
            Console.WriteLine("\nAdding games to database...");
            database.AddGames(games);
            
            Console.WriteLine("\n=== Test Complete ===");
            Console.WriteLine("Press any key to exit...");
            Console.ReadKey();
        }
    }
}
