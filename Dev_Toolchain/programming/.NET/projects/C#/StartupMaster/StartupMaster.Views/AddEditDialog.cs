using System;
using System.CodeDom.Compiler;
using System.Collections;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;
using Microsoft.Win32;
using StartupMaster.Models;

namespace StartupMaster.Views;

public partial class AddEditDialog : Window
{
	private readonly bool _isEditMode;

	
	
	
	
	
	
	
	
	
	public StartupItem StartupItem { get; private set; }

	public AddEditDialog(StartupItem existingItem = null)
	{
		InitializeComponent();
		_isEditMode = existingItem != null;
		if (_isEditMode)
		{
			base.Title = "Edit Startup Item";
			StartupItem = existingItem;
			LoadItemData();
		}
		else
		{
			base.Title = "Add New Startup Item";
			StartupItem = new StartupItem
			{
				Location = StartupLocation.RegistryCurrentUser,
				IsEnabled = true,
				DelaySeconds = 0
			};
		}
		DelaySlider.ValueChanged += DelaySlider_ValueChanged;
		CommandTextBox.TextChanged += CommandTextBox_TextChanged;
	}

	private void LoadItemData()
	{
		NameTextBox.Text = StartupItem.Name;
		CommandTextBox.Text = StartupItem.Command;
		ArgumentsTextBox.Text = StartupItem.Arguments;
		foreach (ComboBoxItem item in (IEnumerable)LocationComboBox.Items)
		{
			if (item.Tag.ToString() == StartupItem.Location.ToString())
			{
				LocationComboBox.SelectedItem = item;
				break;
			}
		}
		DelaySlider.Value = StartupItem.DelaySeconds;
	}

	private void LocationComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
	{
		if (LocationComboBox.SelectedItem is ComboBoxItem comboBoxItem)
		{
			string text = comboBoxItem.Tag.ToString();
			DelayPanel.Visibility = ((!(text == "TaskScheduler")) ? Visibility.Collapsed : Visibility.Visible);
		}
	}

	private void DelaySlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
	{
		if (DelayValueText != null)
		{
			DelayValueText.Text = $"{(int)DelaySlider.Value}s";
		}
	}

	private void CommandTextBox_TextChanged(object sender, TextChangedEventArgs e)
	{
		// Auto-fill name from file path
		if (!_isEditMode && !string.IsNullOrWhiteSpace(CommandTextBox.Text))
		{
			try
			{
				string fileName = Path.GetFileNameWithoutExtension(CommandTextBox.Text);
				if (!string.IsNullOrEmpty(fileName))
				{
					NameTextBox.Text = fileName;
				}
			}
			catch
			{
				// Ignore invalid paths
			}
		}
	}

	private void BrowseButton_Click(object sender, RoutedEventArgs e)
	{
		OpenFileDialog openFileDialog = new OpenFileDialog
		{
			Filter = "All files (*.*)|*.*|Executable files (*.exe)|*.exe|Batch files (*.bat;*.cmd)|*.bat;*.cmd|PowerShell (*.ps1)|*.ps1|Shortcuts (*.lnk)|*.lnk",
			Title = "Select Any File to Run on Startup"
		};
		if (openFileDialog.ShowDialog() == true)
		{
			CommandTextBox.Text = openFileDialog.FileName;
			if (string.IsNullOrWhiteSpace(NameTextBox.Text))
			{
				NameTextBox.Text = Path.GetFileNameWithoutExtension(openFileDialog.FileName);
			}
		}
	}

	private void SaveButton_Click(object sender, RoutedEventArgs e)
	{
		if (string.IsNullOrWhiteSpace(NameTextBox.Text))
		{
			MessageBox.Show("Please enter a name for the startup item.", "Validation Error", MessageBoxButton.OK, MessageBoxImage.Exclamation);
			NameTextBox.Focus();
			return;
		}
		if (string.IsNullOrWhiteSpace(CommandTextBox.Text))
		{
			MessageBox.Show("Please enter a command/path.", "Validation Error", MessageBoxButton.OK, MessageBoxImage.Exclamation);
			CommandTextBox.Focus();
			return;
		}
		StartupItem.Name = NameTextBox.Text.Trim();
		StartupItem.Command = CommandTextBox.Text.Trim();
		StartupItem.Arguments = ArgumentsTextBox.Text?.Trim() ?? string.Empty;
		if (LocationComboBox.SelectedItem is ComboBoxItem comboBoxItem)
		{
			StartupItem.Location = Enum.Parse<StartupLocation>(comboBoxItem.Tag.ToString());
			if (StartupItem.Location == StartupLocation.RegistryCurrentUser || StartupItem.Location == StartupLocation.RegistryLocalMachine)
			{
				StartupItem.RegistryKey = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run";
				StartupItem.RegistryValueName = StartupItem.Name;
			}
		}
		StartupItem.DelaySeconds = (int)DelaySlider.Value;
		base.DialogResult = true;
		Close();
	}

	private void CancelButton_Click(object sender, RoutedEventArgs e)
	{
		base.DialogResult = false;
		Close();
	}

}


