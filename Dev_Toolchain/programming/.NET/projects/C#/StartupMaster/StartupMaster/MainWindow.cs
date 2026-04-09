using System;
using System.CodeDom.Compiler;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Markup;
using System.Windows.Media;
using Microsoft.Win32;
using StartupMaster.Models;
using StartupMaster.Services;
using StartupMaster.Utils;
using StartupMaster.Views;

namespace StartupMaster;

public partial class MainWindow : Window
{
	private readonly StartupManager _startupManager;

	private readonly BackupManager _backupManager;

	private readonly PerformanceAnalyzer _analyzer;

	private ObservableCollection<StartupItem> _allItems;

	private ObservableCollection<StartupItem> _filteredItems;

	private bool _hasUnsavedChanges;

	private bool _isLoading;

	public MainWindow()
	{
		InitializeComponent();
		_startupManager = new StartupManager();
		_backupManager = new BackupManager();
		_analyzer = new PerformanceAnalyzer();
		_allItems = new ObservableCollection<StartupItem>();
		_filteredItems = new ObservableCollection<StartupItem>();
		StartupItemsGrid.ItemsSource = _filteredItems;
		base.Loaded += MainWindow_Loaded;
		base.Closing += MainWindow_Closing;
		base.KeyDown += MainWindow_KeyDown;
	}

	private void MainWindow_KeyDown(object sender, KeyEventArgs e)
	{
		if ((int)e.Key == 94)
		{
			LoadStartupItemsAsync();
			e.Handled = true;
		}
		if ((int)e.KeyboardDevice.Modifiers != 2)
		{
			return;
		}
		Key key = e.Key;
		if ((int)key <= 52)
		{
			switch ((int)key - 45)
			{
			case 3:
				ExportButton_Click(null, null);
				e.Handled = true;
				return;
			case 4:
				SearchBox.Focus();
				e.Handled = true;
				return;
			case 0:
				BatchButton_Click(null, null);
				e.Handled = true;
				return;
			case 1:
			case 2:
				return;
			}
			if ((int)key == 52)
			{
				ImportButton_Click(null, null);
				e.Handled = true;
			}
		}
		else if ((int)key != 57)
		{
			if ((int)key == 63)
			{
				StatisticsButton_Click(null, null);
				e.Handled = true;
			}
		}
		else
		{
			AddButton_Click(null, null);
			e.Handled = true;
		}
	}

	private void MainWindow_Loaded(object sender, RoutedEventArgs e)
	{
		LoadStartupItemsAsync();
		CreateInitialBackup();
	}

	private void MainWindow_Closing(object sender, CancelEventArgs e)
	{
		// Always hide to tray instead of closing - only Exit from tray menu kills the app
		e.Cancel = true;
		if (_hasUnsavedChanges)
		{
			_backupManager.CreateAutoBackup(_allItems.ToList(), "OnClose");
		}
		Hide();
	}

	private void Window_StateChanged(object sender, EventArgs e)
	{
		if (WindowState == WindowState.Minimized)
		{
			Hide();
		}
	}

	private void CreateInitialBackup()
	{
		try
		{
			_backupManager.CreateAutoBackup(_allItems.ToList(), "OnLoad");
		}
		catch
		{
		}
	}

	private async void LoadStartupItemsAsync()
	{
		if (_isLoading) return;
		_isLoading = true;

		try
		{
			StatusText.Text = "Loading startup items...";

			List<StartupItem> allItems = await Task.Run(() => _startupManager.GetAllItems());

			await Task.Run(() => BootImpactEstimator.EstimateAll(allItems));

			_allItems.Clear();
			foreach (StartupItem item in allItems)
			{
				_allItems.Add(item);
			}
			ApplyFilters();
			UpdateItemCount();
			StatusText.Text = "Ready";
		}
		catch (Exception ex)
		{
			MessageBox.Show("Error loading startup items: " + ex.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Hand);
			StatusText.Text = "Error loading items";
		}
		finally
		{
			_isLoading = false;
		}
	}

	private void ApplyFilters()
	{
		_filteredItems.Clear();
		string searchText = SearchBox.Text?.ToLower() ?? "";
		int selectedIndex = FilterComboBox.SelectedIndex;
		IEnumerable<StartupItem> allItems = _allItems;
		allItems = selectedIndex switch
		{
			1 => allItems.Where((StartupItem i) => i.IsEnabled),
			2 => allItems.Where((StartupItem i) => !i.IsEnabled),
			3 => allItems.Where((StartupItem i) => i.Location == StartupLocation.RegistryCurrentUser || i.Location == StartupLocation.RegistryLocalMachine),
			4 => allItems.Where((StartupItem i) => i.Location == StartupLocation.StartupFolder),
			5 => allItems.Where((StartupItem i) => i.Location == StartupLocation.TaskScheduler),
			6 => allItems.Where((StartupItem i) => i.Location == StartupLocation.Service),
			_ => allItems,
		};
		if (!string.IsNullOrWhiteSpace(searchText))
		{
			allItems = allItems.Where((StartupItem i) => i.Name.ToLower().Contains(searchText) || i.Command.ToLower().Contains(searchText));
		}
		foreach (StartupItem item in allItems)
		{
			_filteredItems.Add(item);
		}
	}

	private void UpdateItemCount()
	{
		ItemCountText.Text = $"{_filteredItems.Count} of {_allItems.Count} items";
	}

	private void RefreshButton_Click(object sender, RoutedEventArgs e)
	{
		LoadStartupItemsAsync();
	}

	private void AddButton_Click(object sender, RoutedEventArgs e)
	{
		AddEditDialog addEditDialog = new AddEditDialog();
		if (addEditDialog.ShowDialog() == true)
		{
			StartupItem startupItem = addEditDialog.StartupItem;
			if (_startupManager.AddItem(startupItem))
			{
				MessageBox.Show("Successfully added '" + startupItem.Name + "' to startup.", "Success", MessageBoxButton.OK, MessageBoxImage.Asterisk);
				LoadStartupItemsAsync();
			}
			else
			{
				MessageBox.Show("Failed to add '" + startupItem.Name + "' to startup.", "Error", MessageBoxButton.OK, MessageBoxImage.Hand);
			}
		}
	}

	private void EditButton_Click(object sender, RoutedEventArgs e)
	{
		StartupItem dataContext = null;
		if (sender is Button btn)
		{
			dataContext = btn.DataContext as StartupItem;
		}
		if (dataContext == null || new AddEditDialog(dataContext).ShowDialog() != true)
		{
			return;
		}
		if (dataContext.Location == StartupLocation.TaskScheduler)
		{
			if (_startupManager.UpdateDelay(dataContext))
			{
				MessageBox.Show("Delay updated successfully.", "Success", MessageBoxButton.OK, MessageBoxImage.Asterisk);
			}
			else
			{
				MessageBox.Show("Failed to update delay.", "Error", MessageBoxButton.OK, MessageBoxImage.Hand);
			}
		}
		LoadStartupItemsAsync();
	}

	private void EnableButton_Click(object sender, RoutedEventArgs e)
	{
		StartupItem dataContext = null;
		if (sender is Button btn)
		{
			dataContext = btn.DataContext as StartupItem;
		}
		if (dataContext != null)
		{
			if (_startupManager.EnableItem(dataContext))
			{
				StatusText.Text = "Enabled '" + dataContext.Name + "'";
				_hasUnsavedChanges = true;
				LoadStartupItemsAsync();
			}
			else
			{
				MessageBox.Show("Failed to enable '" + dataContext.Name + "'.", "Error", MessageBoxButton.OK, MessageBoxImage.Hand);
			}
		}
	}

	private void DisableButton_Click(object sender, RoutedEventArgs e)
	{
		StartupItem dataContext = null;
		if (sender is Button btn)
		{
			dataContext = btn.DataContext as StartupItem;
		}
		if (dataContext == null)
		{
			return;
		}
		if (dataContext.IsCritical)
		{
			MessageBox.Show($"Cannot disable '{dataContext.Name}'.\n\nReason: {dataContext.CriticalReason}\n\nThis item is essential for Windows to function properly.", "Critical System Component", MessageBoxButton.OK, MessageBoxImage.Exclamation);
		}
		else
		{
			_backupManager.CreateAutoBackup(_allItems.ToList(), "BeforeDisable_" + dataContext.Name);
			if (_startupManager.DisableItem(dataContext))
			{
				StatusText.Text = "Disabled '" + dataContext.Name + "'";
				_hasUnsavedChanges = true;
				LoadStartupItemsAsync();
			}
			else
			{
				MessageBox.Show("Failed to disable '" + dataContext.Name + "'.", "Error", MessageBoxButton.OK, MessageBoxImage.Hand);
			}
		}
	}

	private void DeleteButton_Click(object sender, RoutedEventArgs e)
	{
		StartupItem dataContext = null;
		if (sender is Button btn)
		{
			dataContext = btn.DataContext as StartupItem;
		}
		if (dataContext != null && MessageBox.Show("Are you sure you want to remove '" + dataContext.Name + "' from startup?\n\nA backup will be created automatically.", "Confirm Delete", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
		{
			_backupManager.CreateAutoBackup(_allItems.ToList(), "BeforeDelete_" + dataContext.Name);
			if (_startupManager.RemoveItem(dataContext))
			{
				StatusText.Text = "Removed '" + dataContext.Name + "'";
				_hasUnsavedChanges = true;
				LoadStartupItemsAsync();
			}
			else
			{
				MessageBox.Show("Failed to remove '" + dataContext.Name + "'.", "Error", MessageBoxButton.OK, MessageBoxImage.Hand);
			}
		}
	}

	private void AnalyzeButton_Click(object sender, RoutedEventArgs e)
	{
		try
		{
			AnalysisReport report = _analyzer.AnalyzeStartupItems(_allItems.ToList());
			string text = _analyzer.GenerateTextReport(report);
			Window window = new Window();
			window.Title = "Startup Performance Analysis";
			window.Width = 700.0;
			window.Height = 600.0;
			window.WindowStartupLocation = WindowStartupLocation.CenterOwner;
			window.Owner = this;
			window.Content = new ScrollViewer
			{
				Content = new TextBox
				{
					Text = text,
					IsReadOnly = true,
					FontFamily = new FontFamily("Consolas"),
					Padding = new Thickness(10.0),
					VerticalScrollBarVisibility = ScrollBarVisibility.Auto
				}
			};
			window.ShowDialog();
		}
		catch (Exception ex)
		{
			MessageBox.Show("Analysis failed: " + ex.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Hand);
		}
	}

	private void FilterComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
	{
		if (_allItems != null)
		{
			ApplyFilters();
			UpdateItemCount();
		}
	}

	private void StatisticsButton_Click(object sender, RoutedEventArgs e)
	{
		StatisticsWindow statisticsWindow = new StatisticsWindow(_allItems.ToList());
		statisticsWindow.Owner = this;
		statisticsWindow.ShowDialog();
	}

	private void BatchButton_Click(object sender, RoutedEventArgs e)
	{
		if (new BatchOperationsWindow(_allItems.ToList(), _startupManager)
		{
			Owner = this
		}.ShowDialog() == true)
		{
			_hasUnsavedChanges = true;
			LoadStartupItemsAsync();
		}
	}

	private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
	{
		if (_allItems != null)
		{
			ApplyFilters();
			UpdateItemCount();
		}
	}

	private void ExportButton_Click(object sender, RoutedEventArgs e)
	{
		SaveFileDialog saveFileDialog = new SaveFileDialog
		{
			Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*",
			DefaultExt = "json",
			FileName = $"StartupItems_{DateTime.Now:yyyyMMdd_HHmmss}.json"
		};
		if (saveFileDialog.ShowDialog() == true)
		{
			try
			{
				string contents = JsonSerializer.Serialize(_allItems, new JsonSerializerOptions
				{
					WriteIndented = true
				});
				File.WriteAllText(saveFileDialog.FileName, contents);
				MessageBox.Show("Export successful!", "Success", MessageBoxButton.OK, MessageBoxImage.Asterisk);
			}
			catch (Exception ex)
			{
				MessageBox.Show("Export failed: " + ex.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Hand);
			}
		}
	}

	private void ImportButton_Click(object sender, RoutedEventArgs e)
	{
		OpenFileDialog openFileDialog = new OpenFileDialog
		{
			Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*",
			DefaultExt = "json"
		};
		if (openFileDialog.ShowDialog() != true)
		{
			return;
		}
		try
		{
			List<StartupItem> list = JsonSerializer.Deserialize<List<StartupItem>>(File.ReadAllText(openFileDialog.FileName));
			if (list == null || list.Count <= 0 || MessageBox.Show($"Import {list.Count} items?", "Confirm Import", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
			{
				return;
			}
			int num = 0;
			foreach (StartupItem item in list)
			{
				if (_startupManager.AddItem(item))
				{
					num++;
				}
			}
			MessageBox.Show($"Imported {num} of {list.Count} items.", "Import Complete", MessageBoxButton.OK, MessageBoxImage.Asterisk);
			LoadStartupItemsAsync();
		}
		catch (Exception ex)
		{
			MessageBox.Show("Import failed: " + ex.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Hand);
		}
	}

}
