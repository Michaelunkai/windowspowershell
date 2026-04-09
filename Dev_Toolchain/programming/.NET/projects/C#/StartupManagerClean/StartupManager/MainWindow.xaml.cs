using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using System.Windows.Data;
using Button = System.Windows.Controls.Button;
using MessageBox = System.Windows.MessageBox;

namespace StartupManager;

public partial class MainWindow : Window
{
    private readonly StartupService _service;
    private readonly TrayIconService _trayIcon;
    private ObservableCollection<StartupItem> _items;
    private ICollectionView _itemsView;

    public MainWindow()
    {
        InitializeComponent();
        _service = new StartupService();
        _trayIcon = new TrayIconService(this);
        _items = new ObservableCollection<StartupItem>();
        
        _itemsView = CollectionViewSource.GetDefaultView(_items);
        _itemsView.SortDescriptions.Add(new SortDescription("IsEnabled", ListSortDirection.Descending));
        
        ItemsGrid.ItemsSource = _itemsView;
        
        Loaded += (s, e) => LoadItems();
        Closing += (s, e) =>
        {
            e.Cancel = true;
            Hide();
        };
    }

    private void LoadItems()
    {
        try
        {
            StatusText.Text = "Loading...";
            _items.Clear();
            
            var items = _service.GetAllItems();
            foreach (var item in items)
            {
                _items.Add(item);
            }
            
            StatusText.Text = $"✅ {_items.Count} startup items loaded - All are modifiable with ADMIN permissions";
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Error loading items: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            StatusText.Text = "Error loading items";
        }
    }

    private void Refresh_Click(object sender, RoutedEventArgs e)
    {
        LoadItems();
    }

    private void AddNew_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new AddItemDialog { Owner = this };
        if (dialog.ShowDialog() == true)
        {
            if (_service.AddItem(dialog.ItemName, dialog.ItemCommand))
            {
                MessageBox.Show($"Successfully added '{dialog.ItemName}' to startup!", "Success", MessageBoxButton.OK, MessageBoxImage.Information);
                LoadItems();
            }
            else
            {
                MessageBox.Show($"Failed to add '{dialog.ItemName}' to startup.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }

    private void Enable_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button button && button.DataContext is StartupItem item)
        {
            if (_service.EnableItem(item.Name))
            {
                StatusText.Text = $"✅ Enabled '{item.Name}'";
                LoadItems();
            }
            else
            {
                MessageBox.Show($"Failed to enable '{item.Name}'.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }

    private void Disable_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button button && button.DataContext is StartupItem item)
        {
            if (_service.DisableItem(item.Name))
            {
                StatusText.Text = $"❌ Disabled '{item.Name}'";
                LoadItems();
            }
            else
            {
                MessageBox.Show($"Failed to disable '{item.Name}'.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }

    private void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button button && button.DataContext is StartupItem item)
        {
            if (MessageBox.Show($"Are you sure you want to remove '{item.Name}' from startup?", 
                "Confirm Delete", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
            {
                if (_service.DeleteItem(item.Name))
                {
                    StatusText.Text = $"🗑️ Removed '{item.Name}'";
                    LoadItems();
                }
                else
                {
                    MessageBox.Show($"Failed to remove '{item.Name}'.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }
    }
}
