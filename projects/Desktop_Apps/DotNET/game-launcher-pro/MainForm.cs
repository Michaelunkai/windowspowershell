using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using game_launcher_winforms.Models;
using game_launcher_winforms.Services;

namespace game_launcher_winforms
{
    public partial class MainForm : Form
    {
        private GameDatabase _database;
        private GameLauncher _launcher;
        private GameScanner _scanner;
        private FlowLayoutPanel _gamesPanel;
        private TextBox _searchBox;
        private Label _statusLabel;
        private Label _countLabel;

        public MainForm()
        {
            InitializeComponent();
            InitializeCustomComponents();
            LoadGames();
        }

        private void InitializeCustomComponents()
        {
            this.Text = "🎮 Game Launcher Pro";
            this.WindowState = FormWindowState.Maximized;
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Color.FromArgb(18, 18, 20);
            this.DoubleBuffered = true;
            
            // Icon is now embedded in the exe via project settings

            // Top panel - Header
            var topPanel = new Panel
            {
                Dock = DockStyle.Top,
                Height = 80,
                BackColor = Color.FromArgb(25, 25, 28),
                Padding = new Padding(20, 0, 20, 0)
            };

            var titleLabel = new Label
            {
                Text = "🎮 GAME LAUNCHER PRO",
                Font = new Font("Segoe UI", 24, FontStyle.Bold),
                ForeColor = Color.FromArgb(0, 200, 255),
                Location = new Point(20, 20),
                AutoSize = true
            };

            _countLabel = new Label
            {
                Text = "(0 games)",
                Font = new Font("Segoe UI", 14),
                ForeColor = Color.FromArgb(120, 120, 130),
                Location = new Point(380, 28),
                AutoSize = true
            };

            // Search box
            _searchBox = new TextBox
            {
                Location = new Point(600, 25),
                Width = 300,
                Height = 30,
                Font = new Font("Segoe UI", 12),
                BackColor = Color.FromArgb(35, 35, 40),
                ForeColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle
            };
            _searchBox.TextChanged += SearchBox_TextChanged;

            // Buttons
            var scanButton = CreateButton("🔍 Scan", new Point(920, 22), Color.FromArgb(0, 120, 200));
            scanButton.Click += ScanButton_Click;

            var refreshButton = CreateButton("🔄 Refresh", new Point(1020, 22), Color.FromArgb(60, 60, 70));
            refreshButton.Click += RefreshButton_Click;

            topPanel.Controls.Add(titleLabel);
            topPanel.Controls.Add(_countLabel);
            topPanel.Controls.Add(_searchBox);
            topPanel.Controls.Add(scanButton);
            topPanel.Controls.Add(refreshButton);

            // Games panel with scroll
            _gamesPanel = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                AutoScroll = true,
                BackColor = Color.FromArgb(18, 18, 20),
                Padding = new Padding(30, 20, 30, 20),
                WrapContents = true
            };

            // Status bar
            var statusPanel = new Panel
            {
                Dock = DockStyle.Bottom,
                Height = 35,
                BackColor = Color.FromArgb(25, 25, 28)
            };

            _statusLabel = new Label
            {
                Text = "Ready",
                Font = new Font("Segoe UI", 10),
                ForeColor = Color.FromArgb(100, 100, 110),
                Location = new Point(20, 8),
                AutoSize = true
            };

            statusPanel.Controls.Add(_statusLabel);

            this.Controls.Add(_gamesPanel);
            this.Controls.Add(topPanel);
            this.Controls.Add(statusPanel);

            _database = new GameDatabase();
            _launcher = new GameLauncher(_database);
            _scanner = new GameScanner();
        }

        private Button CreateButton(string text, Point location, Color backColor)
        {
            var btn = new Button
            {
                Text = text,
                Location = location,
                Width = 90,
                Height = 35,
                BackColor = backColor,
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 10),
                Cursor = Cursors.Hand
            };
            btn.FlatAppearance.BorderSize = 0;
            return btn;
        }

        private void LoadGames()
        {
            try
            {
                _gamesPanel.Controls.Clear();
                var games = _database.GetAllGames();
                _countLabel.Text = $"({games.Count} games)";

                foreach (var game in games)
                {
                    var gamePanel = CreateGamePanel(game);
                    _gamesPanel.Controls.Add(gamePanel);
                }

                _statusLabel.Text = $"Loaded {games.Count} games";
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error loading games: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private Panel CreateGamePanel(Game game)
        {
            // Beautiful EXTRA LARGE card - twice as big
            var panel = new Panel
            {
                Width = 460,
                Height = 520,
                Margin = new Padding(15),
                BackColor = Color.FromArgb(30, 30, 35),
                Cursor = Cursors.Hand
            };

            // Cover image - TWICE AS BIG
            var pictureBox = new PictureBox
            {
                Location = new Point(0, 0),
                Width = 460,
                Height = 350,
                SizeMode = PictureBoxSizeMode.Zoom,
                BackColor = Color.FromArgb(20, 20, 25)
            };

            if (!string.IsNullOrEmpty(game.CoverImagePath) && System.IO.File.Exists(game.CoverImagePath))
            {
                try
                {
                    using (var fs = new System.IO.FileStream(game.CoverImagePath, System.IO.FileMode.Open, System.IO.FileAccess.Read))
                    {
                        pictureBox.Image = Image.FromStream(fs);
                    }
                }
                catch
                {
                    AddPlaceholder(pictureBox);
                }
            }
            else
            {
                AddPlaceholder(pictureBox);
            }

            // Game name - prominent and bigger
            var nameLabel = new Label
            {
                Text = game.Name,
                Location = new Point(10, 360),
                Width = 440,
                Height = 50,
                Font = new Font("Segoe UI", 14, FontStyle.Bold),
                ForeColor = Color.White,
                TextAlign = ContentAlignment.TopCenter
            };

            // Play count
            var statsLabel = new Label
            {
                Text = game.PlayCount > 0 ? $"Played {game.PlayCount} times" : "Never played",
                Location = new Point(10, 410),
                Width = 440,
                Font = new Font("Segoe UI", 10),
                ForeColor = Color.FromArgb(100, 100, 110),
                TextAlign = ContentAlignment.MiddleCenter
            };

            // Beautiful PLAY button - bigger
            var playButton = new Button
            {
                Text = "▶  PLAY",
                Location = new Point(115, 450),
                Width = 230,
                Height = 55,
                BackColor = Color.FromArgb(0, 150, 220),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 14, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            playButton.FlatAppearance.BorderSize = 0;
            playButton.Click += (s, e) => LaunchGame(game);

            // Hover effects
            playButton.MouseEnter += (s, e) => playButton.BackColor = Color.FromArgb(0, 180, 255);
            playButton.MouseLeave += (s, e) => playButton.BackColor = Color.FromArgb(0, 150, 220);

            panel.Controls.Add(pictureBox);
            panel.Controls.Add(nameLabel);
            panel.Controls.Add(statsLabel);
            panel.Controls.Add(playButton);

            // Panel hover effect
            panel.MouseEnter += (s, e) => panel.BackColor = Color.FromArgb(40, 40, 48);
            panel.MouseLeave += (s, e) => panel.BackColor = Color.FromArgb(30, 30, 35);

            // Make the whole panel clickable
            pictureBox.Click += (s, e) => LaunchGame(game);
            nameLabel.Click += (s, e) => LaunchGame(game);

            return panel;
        }

        private void AddPlaceholder(PictureBox pb)
        {
            var placeholder = new Label
            {
                Text = "🎮",
                Font = new Font("Segoe UI", 60),
                ForeColor = Color.FromArgb(60, 60, 70),
                TextAlign = ContentAlignment.MiddleCenter,
                Dock = DockStyle.Fill
            };
            pb.Controls.Add(placeholder);
        }

        private void LaunchGame(Game game)
        {
            _statusLabel.Text = $"Launching {game.Name}...";
            this.Refresh();
            
            if (_launcher.LaunchGame(game))
            {
                _statusLabel.Text = $"✅ Launched {game.Name}";
                LoadGames(); // Refresh to update play count
            }
            else
            {
                MessageBox.Show($"Failed to launch {game.Name}\n\nPath: {game.ExecutablePath}", "Launch Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                _statusLabel.Text = "❌ Launch failed";
            }
        }

        private async void ScanButton_Click(object sender, EventArgs e)
        {
            _statusLabel.Text = "Scanning for new games...";
            this.Refresh();

            // Step 1: Reload from disk to get latest state
            _database.Reload();
            var currentGames = _database.GetAllGames();
            var beforeCount = currentGames.Count;

            // Step 2: Remove games with deleted executables
            var validGames = _scanner.RemoveDeletedGames(currentGames);
            var removed = beforeCount - validGames.Count;

            // Step 3: Scan for new games (with cover download)
            _statusLabel.Text = "Looking for new games...";
            this.Refresh();
            var newGames = await _scanner.ScanForNewGamesAsync(validGames);
            var added = newGames.Count;

            // Step 4: Save all changes to database
            if (removed > 0 || added > 0)
            {
                _database.Clear();
                _database.AddGames(validGames);
                if (newGames.Count > 0)
                {
                    _database.AddGames(newGames);
                }
            }

            var afterCount = _database.GetAllGames().Count;

            string message;
            if (added > 0 || removed > 0)
            {
                message = $"✅ Scan Complete!\n\n";
                if (added > 0) message += $"Added: {added} new game(s)\n";
                if (removed > 0) message += $"Removed: {removed} deleted game(s)\n";
                message += $"\nTotal: {afterCount} games";
            }
            else
            {
                message = $"✅ No changes detected\n\nTotal: {afterCount} games";
            }

            // Auto-fix missing covers using PowerShell script (always run to catch any missing)
            _statusLabel.Text = "Checking cover images...";
            this.Refresh();
            
            try
            {
                var scriptPath = @"F:\study\projects\Desktop_Apps\DotNET\game-launcher-pro\auto-fix-covers.ps1";
                
                if (System.IO.File.Exists(scriptPath))
                {
                    var psi = new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = "powershell.exe",
                        Arguments = $"-ExecutionPolicy Bypass -NoProfile -File \"{scriptPath}\"",
                        UseShellExecute = false,
                        CreateNoWindow = true,
                        RedirectStandardOutput = true
                    };
                    
                    var process = System.Diagnostics.Process.Start(psi);
                    process?.WaitForExit(30000); // Wait max 30 seconds for cover downloads
                    
                    // Reload database to get updated cover paths
                    _database.Reload();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Cover fix error: {ex.Message}");
            }

            MessageBox.Show(message, "Scan Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
            LoadGames();
            _statusLabel.Text = $"Scan complete: {added} added, {removed} removed";
        }

        private void RefreshButton_Click(object sender, EventArgs e)
        {
            _statusLabel.Text = "Refreshing from disk...";
            this.Refresh();
            
            // Reload database from disk (catches external changes like PowerShell scripts)
            _database.Reload();
            
            LoadGames();
            _statusLabel.Text = $"Refreshed - {_database.GetAllGames().Count} games loaded";
        }

        private void SearchBox_TextChanged(object sender, EventArgs e)
        {
            var searchTerm = _searchBox.Text.ToLower();
            _gamesPanel.Controls.Clear();

            var games = _database.GetAllGames();
            if (!string.IsNullOrWhiteSpace(searchTerm))
            {
                games = games.Where(g => g.Name.ToLower().Contains(searchTerm)).ToList();
            }

            foreach (var game in games)
            {
                var gamePanel = CreateGamePanel(game);
                _gamesPanel.Controls.Add(gamePanel);
            }

            _countLabel.Text = $"({games.Count} games)";
        }
    }
}
