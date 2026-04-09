using System;
using System.IO;
using System.Linq;
using GameLauncherPro.Models;
using GameLauncherPro.Services;

namespace GameLauncherPro.CLI
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("=== Game Launcher Pro CLI ===\n");

            if (args.Length == 0)
            {
                ShowHelp();
                return;
            }

            var command = args[0].ToLower();
            var database = new GameDatabase();
            var scanner = new GameScanner();
            var metadata = new MetadataService();

            switch (command)
            {
                case "scan":
                    ScanGames(scanner, database);
                    break;

                case "add":
                    if (args.Length < 3)
                    {
                        Console.WriteLine("Usage: GameLauncherPro.CLI.exe add \"Game Name\" \"path\\to\\game.exe\"");
                        return;
                    }
                    AddGame(args[1], args[2], database);
                    break;

                case "list":
                    ListGames(database);
                    break;

                case "fetch":
                    FetchMetadata(database, metadata);
                    break;

                case "remove":
                    if (args.Length < 2)
                    {
                        Console.WriteLine("Usage: GameLauncherPro.CLI.exe remove <game_id>");
                        return;
                    }
                    RemoveGame(args[1], database);
                    break;

                case "launch":
                    if (args.Length < 2)
                    {
                        Console.WriteLine("Usage: GameLauncherPro.CLI.exe launch \"Game Name\"");
                        return;
                    }
                    LaunchGame(args[1], database);
                    break;

                default:
                    ShowHelp();
                    break;
            }
        }

        static void ShowHelp()
        {
            Console.WriteLine("Commands:");
            Console.WriteLine("  scan                          - Scan all drives for games");
            Console.WriteLine("  add <name> <exe_path>         - Add a game manually");
            Console.WriteLine("  list                          - List all games");
            Console.WriteLine("  fetch                         - Fetch metadata for all games");
            Console.WriteLine("  remove <game_id>              - Remove a game");
            Console.WriteLine("  launch <game_name>            - Launch a game");
        }

        static void ScanGames(GameScanner scanner, GameDatabase database)
        {
            Console.WriteLine("Scanning for games...\n");
            var games = scanner.ScanAllDrives();
            
            Console.WriteLine($"\nFound {games.Count} games:");
            foreach (var game in games)
            {
                Console.WriteLine($"  - {game.Name} ({game.ExecutablePath})");
            }

            database.AddGames(games);
            Console.WriteLine($"\nAdded {games.Count} games to database!");
        }

        static void AddGame(string name, string exePath, GameDatabase database)
        {
            if (!File.Exists(exePath))
            {
                Console.WriteLine($"Error: Executable not found: {exePath}");
                return;
            }

            var game = new Game
            {
                Name = name,
                ExecutablePath = exePath,
                InstallDirectory = Path.GetDirectoryName(exePath) ?? string.Empty
            };

            database.AddGame(game);
            Console.WriteLine($"Added: {game.Name} (ID: {game.Id})");
        }

        static void ListGames(GameDatabase database)
        {
            var games = database.GetAllGames();
            
            if (games.Count == 0)
            {
                Console.WriteLine("No games in database.");
                return;
            }

            Console.WriteLine($"Total games: {games.Count}\n");
            foreach (var game in games)
            {
                Console.WriteLine($"[{game.Id}]");
                Console.WriteLine($"  Name: {game.Name}");
                Console.WriteLine($"  Path: {game.ExecutablePath}");
                Console.WriteLine($"  Play Count: {game.PlayCount}");
                Console.WriteLine($"  Last Played: {game.LastPlayed?.ToString("yyyy-MM-dd HH:mm") ?? "Never"}");
                Console.WriteLine($"  Has Cover: {!string.IsNullOrEmpty(game.CoverImagePath)}");
                Console.WriteLine();
            }
        }

        static void FetchMetadata(GameDatabase database, MetadataService metadata)
        {
            var games = database.GetAllGames()
                .Where(g => string.IsNullOrEmpty(g.CoverImagePath))
                .ToList();

            if (games.Count == 0)
            {
                Console.WriteLine("All games already have metadata!");
                return;
            }

            Console.WriteLine($"Fetching metadata for {games.Count} games...\n");
            metadata.FetchAllMetadata(games).Wait();

            foreach (var game in games)
            {
                database.UpdateGame(game);
            }

            Console.WriteLine("\nMetadata fetch complete!");
        }

        static void RemoveGame(string id, GameDatabase database)
        {
            var game = database.GetGame(id);
            if (game == null)
            {
                Console.WriteLine($"Game not found: {id}");
                return;
            }

            database.RemoveGame(id);
            Console.WriteLine($"Removed: {game.Name}");
        }

        static void LaunchGame(string name, GameDatabase database)
        {
            var games = database.GetAllGames();
            var game = games.FirstOrDefault(g => g.Name.Equals(name, StringComparison.OrdinalIgnoreCase));

            if (game == null)
            {
                Console.WriteLine($"Game not found: {name}");
                Console.WriteLine("\nAvailable games:");
                foreach (var g in games)
                {
                    Console.WriteLine($"  - {g.Name}");
                }
                return;
            }

            var launcher = new GameLauncher(database);
            if (launcher.LaunchGame(game))
            {
                Console.WriteLine($"Launched: {game.Name}");
            }
            else
            {
                Console.WriteLine($"Failed to launch: {game.Name}");
            }
        }
    }
}
