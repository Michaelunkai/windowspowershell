using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using GameLauncherPro.Models;
using GameLauncherPro.Services;
using GameLauncherPro.Views;

namespace GameLauncherPro
{
    public partial class MainWindow : Window
    {
        private readonly GameDatabase _database;
        private readonly GameScanner _scanner;
        private readonly MetadataService _metadata;
        private readonly GameLauncher _launcher;
        private List<Game> _allGames;
        private List<Game> _filteredGames;

        public MainWindow()
        {
            InitializeComponent();
            
            _database = new GameDatabase();
            _scanner = new GameScanner();
            _metadata = new MetadataService();
            _launcher = new GameLauncher(_database);
            
            _allGames = new List<Game>();
            _filteredGames = new List<Game>();

            Loaded += MainWindow_Loaded;
        }

        private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
        {
            try
            {
                await LoadGames();
            }
            catch (Exception ex)
            {
                StatusText.Text = $"Error loading: {ex.Message}";
                MessageBox.Show($"Failed to load games: {ex.Message}\n\nPlease try scanning for games.", 
                    "Load Error", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        private async Task LoadGames()
        {
            try
            {
                StatusText.Text = "Loading games...";
                _allGames = _database.GetAllGames();
                _filteredGames = _allGames;
                UpdateGameCount();
                DisplayGames(_filteredGames);
                StatusText.Text = $"Loaded {_allGames.Count} games";
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error loading games: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void DisplayGames(List<Game> games)
        {
            GamesPanel.Children.Clear();

            foreach (var game in games)
            {
                var tile = CreateGameTile(game);
                GamesPanel.Children.Add(tile);
            }
        }

        private Border CreateGameTile(Game game)
        {
            var border = new Border
            {
                Width = 200,
                Height = 280,
                Margin = new Thickness(10),
                CornerRadius = new CornerRadius(8),
                Background = new SolidColorBrush(Color.FromRgb(45, 45, 48)),
                Cursor = Cursors.Hand
            };

            var grid = new Grid();
            grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(200) });
            grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

            // Cover Image
            var image = new Image
            {
                Stretch = Stretch.UniformToFill
            };

            if (!string.IsNullOrEmpty(game.CoverImagePath) && System.IO.File.Exists(game.CoverImagePath))
            {
                try
                {
                    image.Source = new BitmapImage(new Uri(game.CoverImagePath));
                }
                catch
                {
                    image.Source = CreatePlaceholderImage();
                }
            }
            else
            {
                image.Source = CreatePlaceholderImage();
            }

            Grid.SetRow(image, 0);
            grid.Children.Add(image);

            // Game Info
            var infoPanel = new StackPanel
            {
                Margin = new Thickness(10),
                VerticalAlignment = VerticalAlignment.Center
            };

            var nameText = new TextBlock
            {
                Text = game.Name,
                FontSize = 14,
                FontWeight = FontWeights.Bold,
                Foreground = Brushes.White,
                TextWrapping = TextWrapping.Wrap,
                TextAlignment = TextAlignment.Center
            };

            var playButton = new Button
            {
                Content = "▶ PLAY",
                Margin = new Thickness(0, 8, 0, 0),
                Background = new SolidColorBrush(Color.FromRgb(0, 120, 215)),
                Width = 120,
                Height = 35
            };

            playButton.Click += (s, e) => LaunchGame(game);

            infoPanel.Children.Add(nameText);
            infoPanel.Children.Add(playButton);

            Grid.SetRow(infoPanel, 1);
            grid.Children.Add(infoPanel);

            border.Child = grid;

            // Hover effect
            border.MouseEnter += (s, e) => border.Background = new SolidColorBrush(Color.FromRgb(62, 62, 66));
            border.MouseLeave += (s, e) => border.Background = new SolidColorBrush(Color.FromRgb(45, 45, 48));

            return border;
        }

        private ImageSource CreatePlaceholderImage()
        {
            var drawingVisual = new DrawingVisual();
            using (var dc = drawingVisual.RenderOpen())
            {
                dc.DrawRectangle(new SolidColorBrush(Color.FromRgb(30, 30, 30)), null, new Rect(0, 0, 200, 200));
                var formattedText = new FormattedText(
                    "🎮",
                    System.Globalization.CultureInfo.InvariantCulture,
                    FlowDirection.LeftToRight,
                    new Typeface("Segoe UI"),
                    72,
                    Brushes.Gray,
                    VisualTreeHelper.GetDpi(this).PixelsPerDip
                );
                dc.DrawText(formattedText, new Point(60, 60));
            }

            var renderTargetBitmap = new RenderTargetBitmap(200, 200, 96, 96, PixelFormats.Pbgra32);
            renderTargetBitmap.Render(drawingVisual);
            return renderTargetBitmap;
        }

        private void LaunchGame(Game game)
        {
            StatusText.Text = $"Launching {game.Name}...";
            
            if (_launcher.LaunchGame(game))
            {
                StatusText.Text = $"Launched {game.Name}";
            }
            else
            {
                MessageBox.Show($"Failed to launch {game.Name}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                StatusText.Text = "Ready";
            }
        }

        private async void ScanGames_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                StatusText.Text = "Scanning for games...";
                var button = sender as Button;
                if (button != null) button.IsEnabled = false;

                await Task.Run(() =>
                {
                    var games = _scanner.ScanAllDrives();
                    
                    Dispatcher.Invoke(() =>
                    {
                        _database.AddGames(games);
                        StatusText.Text = $"Found {games.Count} new games!";
                    });
                });

                await LoadGames();
                
                if (button != null) button.IsEnabled = true;
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error scanning games: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                StatusText.Text = "Scan failed";
            }
        }

        private async void FetchMetadata_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                StatusText.Text = "Fetching metadata...";
                var button = sender as Button;
                if (button != null) button.IsEnabled = false;

                var gamesWithoutMetadata = _allGames
                    .Where(g => string.IsNullOrEmpty(g.CoverImagePath))
                    .ToList();

                if (gamesWithoutMetadata.Count == 0)
                {
                    MessageBox.Show("All games already have metadata!", "Info", MessageBoxButton.OK, MessageBoxImage.Information);
                    StatusText.Text = "Ready";
                    if (button != null) button.IsEnabled = true;
                    return;
                }

                await Task.Run(async () =>
                {
                    await _metadata.FetchAllMetadata(gamesWithoutMetadata);
                    
                    Dispatcher.Invoke(() =>
                    {
                        foreach (var game in gamesWithoutMetadata)
                        {
                            _database.UpdateGame(game);
                        }
                    });
                });

                await LoadGames();
                StatusText.Text = $"Metadata fetched for {gamesWithoutMetadata.Count} games!";
                
                if (button != null) button.IsEnabled = true;
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error fetching metadata: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                StatusText.Text = "Metadata fetch failed";
            }
        }

        private async void Refresh_Click(object sender, RoutedEventArgs e)
        {
            await LoadGames();
        }

        private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            var searchTerm = SearchBox.Text.ToLower();
            
            if (string.IsNullOrWhiteSpace(searchTerm))
            {
                _filteredGames = _allGames;
            }
            else
            {
                _filteredGames = _allGames
                    .Where(g => g.Name.ToLower().Contains(searchTerm))
                    .ToList();
            }

            DisplayGames(_filteredGames);
            UpdateGameCount();
        }

        private void SortComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (SortComboBox.SelectedIndex == -1) return;

            switch (SortComboBox.SelectedIndex)
            {
                case 0: // Name A-Z
                    _filteredGames = _filteredGames.OrderBy(g => g.Name).ToList();
                    break;
                case 1: // Recently Added
                    _filteredGames = _filteredGames.OrderByDescending(g => g.DateAdded).ToList();
                    break;
                case 2: // Recently Played
                    _filteredGames = _filteredGames.OrderByDescending(g => g.LastPlayed ?? DateTime.MinValue).ToList();
                    break;
                case 3: // Most Played
                    _filteredGames = _filteredGames.OrderByDescending(g => g.PlayCount).ToList();
                    break;
            }

            DisplayGames(_filteredGames);
        }

        private void UpdateGameCount()
        {
            GameCountText.Text = $"({_filteredGames.Count} games)";
        }

        private void About_Click(object sender, RoutedEventArgs e)
        {
            var aboutWindow = new AboutWindow();
            aboutWindow.Owner = this;
            aboutWindow.ShowDialog();
        }
    }
}
