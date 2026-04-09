using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using GameLauncherPro.Models;

namespace GameLauncherPro.Services
{
    public class GameDatabase
    {
        private readonly string _dbPath;
        private List<Game> _games;

        public GameDatabase()
        {
            _dbPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "GameLauncherPro", "games.json"
            );

            Directory.CreateDirectory(Path.GetDirectoryName(_dbPath)!);
            _games = LoadGames();
        }

        public List<Game> GetAllGames() => _games.ToList();

        public Game? GetGame(string id) => _games.FirstOrDefault(g => g.Id == id);

        public void AddGame(Game game)
        {
            if (!_games.Any(g => g.ExecutablePath.Equals(game.ExecutablePath, StringComparison.OrdinalIgnoreCase)))
            {
                _games.Add(game);
                Save();
                Console.WriteLine($"Added game: {game.Name}");
            }
            else
            {
                Console.WriteLine($"Game already exists: {game.Name}");
            }
        }

        public void AddGames(List<Game> games)
        {
            int added = 0;
            foreach (var game in games)
            {
                if (!_games.Any(g => g.ExecutablePath.Equals(game.ExecutablePath, StringComparison.OrdinalIgnoreCase) ||
                                    g.InstallDirectory.Equals(game.InstallDirectory, StringComparison.OrdinalIgnoreCase)))
                {
                    _games.Add(game);
                    added++;
                }
            }
            
            if (added > 0)
            {
                Save();
                Console.WriteLine($"Added {added} new games to database");
            }
            else
            {
                Console.WriteLine($"No new games found (all already in database)");
            }
        }

        public void UpdateGame(Game game)
        {
            var existing = _games.FirstOrDefault(g => g.Id == game.Id);
            if (existing != null)
            {
                _games.Remove(existing);
                _games.Add(game);
                Save();
            }
        }

        public void RemoveGame(string id)
        {
            var game = _games.FirstOrDefault(g => g.Id == id);
            if (game != null)
            {
                _games.Remove(game);
                Save();
            }
        }

        public void Save()
        {
            try
            {
                var json = JsonConvert.SerializeObject(_games, Formatting.Indented);
                File.WriteAllText(_dbPath, json);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error saving database: {ex.Message}");
            }
        }

        private List<Game> LoadGames()
        {
            try
            {
                if (File.Exists(_dbPath))
                {
                    var json = File.ReadAllText(_dbPath);
                    return JsonConvert.DeserializeObject<List<Game>>(json) ?? new List<Game>();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error loading database: {ex.Message}");
            }

            return new List<Game>();
        }

        public void Clear()
        {
            _games.Clear();
            Save();
        }
    }
}
