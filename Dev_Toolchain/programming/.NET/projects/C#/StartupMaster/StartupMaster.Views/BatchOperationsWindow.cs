using System;
using System.CodeDom.Compiler;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;
using StartupMaster.Models;
using StartupMaster.Services;
using StartupMaster.Utils;

namespace StartupMaster.Views;

public partial class BatchOperationsWindow : Window
{
	private readonly List<StartupItem> _items;

	private readonly StartupManager _manager;

	private readonly StartupImpactCalculator _calculator;

	private bool _changesMade;

	
	
	
	
	
	
	public BatchOperationsWindow(List<StartupItem> items, StartupManager manager)
	{
		InitializeComponent();
		_items = items;
		_manager = manager;
		_calculator = new StartupImpactCalculator();
		LoadData();
	}

	private void LoadData()
	{
		List<string> itemsSource = (from i in _items
			where i.IsEnabled && _calculator.CalculateImpact(i) >= 7
			select $"{i.Name} - Impact: {_calculator.CalculateImpact(i)}/10").ToList();
		HighImpactList.ItemsSource = itemsSource;
		List<string> itemsSource2 = (from i in _items
			where i.IsEnabled && i.DelaySeconds == 0
			select $"{i.Name} - Suggested delay: {GetSuggestedDelay(i)}s").ToList();
		DelayList.ItemsSource = itemsSource2;
		List<string> itemsSource3 = (from i in _items
			group i by i.Command.ToLower() into g
			where g.Count() > 1
			select g).SelectMany((IGrouping<string, StartupItem> g) => g.Select((StartupItem i) => i.Name + " (" + i.LocationDisplay + ")")).ToList();
		DuplicatesList.ItemsSource = itemsSource3;
	}

	private int GetSuggestedDelay(StartupItem item)
	{
		int num = _calculator.CalculateImpact(item);
		if (num < 9)
		{
			if (num < 7)
			{
				return 15;
			}
			return 30;
		}
		return 60;
	}

	private void DisableHighImpactButton_Click(object sender, RoutedEventArgs e)
	{
		List<string> list = HighImpactList.SelectedItems.Cast<string>().ToList();
		if (list.Count == 0)
		{
			MessageBox.Show("Please select items to disable.", "No Selection", MessageBoxButton.OK, MessageBoxImage.Asterisk);
		}
		else
		{
			if (MessageBox.Show($"Disable {list.Count} high-impact items?", "Confirm", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
			{
				return;
			}
			foreach (string item in list)
			{
				string name = item.Split(" - ")[0];
				StartupItem startupItem = _items.FirstOrDefault((StartupItem i) => i.Name == name);
				if (startupItem != null)
				{
					_manager.DisableItem(startupItem);
				}
			}
			_changesMade = true;
			MessageBox.Show($"Disabled {list.Count} items.", "Success", MessageBoxButton.OK, MessageBoxImage.Asterisk);
		}
	}

	private void ApplyDelaysButton_Click(object sender, RoutedEventArgs e)
	{
		MessageBox.Show("Delay application requires Task Scheduler migration.\nThis feature will be fully functional in v1.1.", "Feature Preview", MessageBoxButton.OK, MessageBoxImage.Asterisk);
	}

	private void RemoveDuplicatesButton_Click(object sender, RoutedEventArgs e)
	{
		List<string> list = DuplicatesList.SelectedItems.Cast<string>().ToList();
		if (list.Count == 0)
		{
			MessageBox.Show("Please select duplicates to remove.", "No Selection", MessageBoxButton.OK, MessageBoxImage.Asterisk);
			return;
		}
		MessageBox.Show($"Would remove {list.Count} duplicate entries.\nFull duplicate detection in v1.1.", "Feature Preview", MessageBoxButton.OK, MessageBoxImage.Asterisk);
	}

	private void DisableAllButton_Click(object sender, RoutedEventArgs e)
	{
		if (MessageBox.Show("⚠\ufe0f This will disable ALL startup items!\n\nOnly use this in emergency situations.\n\nContinue?", "Emergency Action", MessageBoxButton.YesNo, MessageBoxImage.Exclamation) != MessageBoxResult.Yes)
		{
			return;
		}
		int num = 0;
		foreach (StartupItem item in _items.Where((StartupItem i) => i.IsEnabled))
		{
			if (_manager.DisableItem(item))
			{
				num++;
			}
		}
		_changesMade = true;
		MessageBox.Show($"Disabled {num} items.", "Complete", MessageBoxButton.OK, MessageBoxImage.Asterisk);
	}

	private void EnableAllButton_Click(object sender, RoutedEventArgs e)
	{
		int num = 0;
		foreach (StartupItem item in _items.Where((StartupItem i) => !i.IsEnabled))
		{
			if (_manager.EnableItem(item))
			{
				num++;
			}
		}
		_changesMade = true;
		MessageBox.Show($"Enabled {num} items.", "Complete", MessageBoxButton.OK, MessageBoxImage.Asterisk);
	}

	private void RemoveDisabledButton_Click(object sender, RoutedEventArgs e)
	{
		List<StartupItem> list = _items.Where((StartupItem i) => !i.IsEnabled).ToList();
		if (MessageBox.Show($"Permanently remove {list.Count} disabled items?", "Confirm Removal", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
		{
			return;
		}
		int num = 0;
		foreach (StartupItem item in list)
		{
			if (_manager.RemoveItem(item))
			{
				num++;
			}
		}
		_changesMade = true;
		MessageBox.Show($"Removed {num} items.", "Complete", MessageBoxButton.OK, MessageBoxImage.Asterisk);
	}

	private void CancelButton_Click(object sender, RoutedEventArgs e)
	{
		base.DialogResult = _changesMade;
		Close();
	}

}


