using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using game_launcher_winforms.Models;

namespace game_launcher_winforms.Services
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

        public void Reload()
        {
            _games = LoadGames();
            Console.WriteLine($"[DB] Reloaded {_games.Count} games from disk");
        }

        public Game? GetGame(string id) => _games.FirstOrDefault(g => g.Id == id);

        public void AddGame(Game game)
        {
            if (!_games.Any(g => g.ExecutablePath == game.ExecutablePath))
            {
                _games.Add(game);
                Save();
                Console.WriteLine($"Added game: {game.Name}");
            }
        }

        public void AddGames(List<Game> games)
        {
            foreach (var game in games)
            {
                if (!_games.Any(g => g.ExecutablePath == game.ExecutablePath))
                {
                    _games.Add(game);
                }
            }
            Save();
            Console.WriteLine($"Added {games.Count} games to database");
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
