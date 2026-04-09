using System;
using System.Diagnostics;
using System.IO;
using GameLauncherPro.Models;

namespace GameLauncherPro.Services
{
    public class GameLauncher
    {
        private readonly GameDatabase _database;

        public GameLauncher(GameDatabase database)
        {
            _database = database;
        }

        public bool LaunchGame(Game game)
        {
            try
            {
                if (!File.Exists(game.ExecutablePath))
                {
                    Console.WriteLine($"Executable not found: {game.ExecutablePath}");
                    return false;
                }

                var startInfo = new ProcessStartInfo
                {
                    FileName = game.ExecutablePath,
                    WorkingDirectory = Path.GetDirectoryName(game.ExecutablePath),
                    UseShellExecute = true
                };

                Process.Start(startInfo);

                // Update stats
                game.LastPlayed = DateTime.Now;
                game.PlayCount++;
                _database.UpdateGame(game);

                Console.WriteLine($"Launched: {game.Name}");
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error launching {game.Name}: {ex.Message}");
                return false;
            }
        }
    }
}
