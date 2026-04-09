using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using Microsoft.Win32;
using StartupMaster.Models;

namespace StartupMaster.Services;

public class RegistryStartupManager
{
	private static readonly string[] RegistryPaths = new string[6] { "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce", "SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Run", "SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\RunOnce", "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunServices", "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunServicesOnce" };

	private static readonly string StartupApprovedRun = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run";

	private static readonly string StartupApprovedRun32 = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run32";

	public List<StartupItem> GetItems()
	{
		List<StartupItem> list = new List<StartupItem>();
		HashSet<string> disabledItemNames = GetDisabledItemNames();
		string[] registryPaths = RegistryPaths;
		foreach (string text in registryPaths)
		{
			try
			{
				using RegistryKey registryKey = Registry.CurrentUser.OpenSubKey(text);
				if (registryKey != null)
				{
					list.AddRange(ReadRegistryKey(registryKey, text, StartupLocation.RegistryCurrentUser, disabledItemNames));
				}
			}
			catch
			{
			}
		}
		registryPaths = RegistryPaths;
		foreach (string text2 in registryPaths)
		{
			try
			{
				using RegistryKey registryKey2 = Registry.LocalMachine.OpenSubKey(text2);
				if (registryKey2 != null)
				{
					list.AddRange(ReadRegistryKey(registryKey2, text2, StartupLocation.RegistryLocalMachine, disabledItemNames));
				}
			}
			catch
			{
			}
		}
		list.AddRange(GetDisabledOnlyItems(disabledItemNames));
		return list;
	}

	private HashSet<string> GetDisabledItemNames()
	{
		HashSet<string> hashSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
		try
		{
			using RegistryKey registryKey = Registry.CurrentUser.OpenSubKey(StartupApprovedRun);
			if (registryKey != null)
			{
				string[] valueNames = registryKey.GetValueNames();
				foreach (string text in valueNames)
				{
					if (registryKey.GetValue(text) is byte[] array && array.Length >= 12 && array[0] == 3)
					{
						hashSet.Add(text);
					}
				}
			}
		}
		catch
		{
		}
		try
		{
			using RegistryKey registryKey2 = Registry.LocalMachine.OpenSubKey(StartupApprovedRun);
			if (registryKey2 != null)
			{
				string[] valueNames = registryKey2.GetValueNames();
				foreach (string text2 in valueNames)
				{
					if (registryKey2.GetValue(text2) is byte[] array2 && array2.Length >= 12 && array2[0] == 3)
					{
						hashSet.Add(text2);
					}
				}
			}
		}
		catch
		{
		}
		try
		{
			using RegistryKey registryKey3 = Registry.CurrentUser.OpenSubKey(StartupApprovedRun32);
			if (registryKey3 != null)
			{
				string[] valueNames = registryKey3.GetValueNames();
				foreach (string text3 in valueNames)
				{
					if (registryKey3.GetValue(text3) is byte[] array3 && array3.Length >= 12 && array3[0] == 3)
					{
						hashSet.Add(text3);
					}
				}
			}
		}
		catch
		{
		}
		return hashSet;
	}

	private List<StartupItem> GetDisabledOnlyItems(HashSet<string> disabledItems)
	{
		return new List<StartupItem>();
	}

	private List<StartupItem> ReadRegistryKey(RegistryKey key, string path, StartupLocation location, HashSet<string> disabledItems)
	{
		List<StartupItem> list = new List<StartupItem>();
		string[] valueNames = key.GetValueNames();
		foreach (string text in valueNames)
		{
			try
			{
				string text2 = key.GetValue(text)?.ToString();
				if (!string.IsNullOrEmpty(text2))
				{
					(string, string) tuple = SplitCommandLine(text2);
					bool flag = disabledItems.Contains(text);
					StartupItem item = new StartupItem
					{
						Name = text,
						Command = tuple.Item1,
						Arguments = tuple.Item2,
						Location = location,
						IsEnabled = !flag,
						RegistryKey = path,
						RegistryValueName = text,
						Publisher = GetPublisher(tuple.Item1)
					};
					list.Add(item);
				}
			}
			catch
			{
			}
		}
		return list;
	}

	private string? GetPublisher(string? command)
	{
		if (string.IsNullOrEmpty(command))
		{
			return null;
		}
		try
		{
			string text = command;
			if (text.StartsWith("\""))
			{
				int num = text.IndexOf('"', 1);
				if (num > 0)
				{
					text = text.Substring(1, num - 1);
				}
			}
			text = Environment.ExpandEnvironmentVariables(text);
			if (File.Exists(text))
			{
				return FileVersionInfo.GetVersionInfo(text).CompanyName;
			}
		}
		catch
		{
		}
		return null;
	}

	public bool AddItem(StartupItem item)
	{
		try
		{
			using RegistryKey registryKey = ((item.Location == StartupLocation.RegistryCurrentUser) ? Registry.CurrentUser : Registry.LocalMachine).OpenSubKey(item.RegistryKey ?? "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", writable: true);
			if (registryKey == null)
			{
				return false;
			}
			string value = (string.IsNullOrEmpty(item.Arguments) ? item.Command : ("\"" + item.Command + "\" " + item.Arguments));
			registryKey.SetValue(item.RegistryValueName ?? item.Name, value);
			return true;
		}
		catch
		{
			return false;
		}
	}

	public bool RemoveItem(StartupItem item)
	{
		try
		{
			using RegistryKey registryKey = ((item.Location == StartupLocation.RegistryCurrentUser) ? Registry.CurrentUser : Registry.LocalMachine).OpenSubKey(item.RegistryKey ?? "", writable: true);
			registryKey?.DeleteValue(item.RegistryValueName ?? "", throwOnMissingValue: false);
			RemoveFromStartupApproved(item);
			return true;
		}
		catch
		{
			return false;
		}
	}

	public bool DisableItem(StartupItem item)
	{
		if (item.IsCritical)
		{
			return false;
		}
		try
		{
			using RegistryKey registryKey = ((item.Location == StartupLocation.RegistryCurrentUser) ? Registry.CurrentUser : Registry.LocalMachine).CreateSubKey(StartupApprovedRun);
			if (registryKey != null)
			{
				registryKey.SetValue(value: new byte[12]
				{
					3, 0, 0, 0, 0, 0, 0, 0, 0, 0,
					0, 0
				}, name: item.RegistryValueName ?? item.Name, valueKind: RegistryValueKind.Binary);
			}
			item.IsEnabled = false;
			return true;
		}
		catch
		{
			return false;
		}
	}

	public bool EnableItem(StartupItem item)
	{
		try
		{
			using RegistryKey registryKey = ((item.Location == StartupLocation.RegistryCurrentUser) ? Registry.CurrentUser : Registry.LocalMachine).CreateSubKey(StartupApprovedRun);
			if (registryKey != null)
			{
				registryKey.SetValue(value: new byte[12]
				{
					2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
					0, 0
				}, name: item.RegistryValueName ?? item.Name, valueKind: RegistryValueKind.Binary);
			}
			item.IsEnabled = true;
			return true;
		}
		catch
		{
			return false;
		}
	}

	private void RemoveFromStartupApproved(StartupItem item)
	{
		try
		{
			using RegistryKey registryKey = ((item.Location == StartupLocation.RegistryCurrentUser) ? Registry.CurrentUser : Registry.LocalMachine).OpenSubKey(StartupApprovedRun, writable: true);
			registryKey?.DeleteValue(item.RegistryValueName ?? item.Name, throwOnMissingValue: false);
		}
		catch
		{
		}
	}

	private (string command, string arguments) SplitCommandLine(string commandLine)
	{
		if (string.IsNullOrWhiteSpace(commandLine))
		{
			return (command: string.Empty, arguments: string.Empty);
		}
		commandLine = commandLine.Trim();
		if (commandLine.StartsWith("\""))
		{
			int num = commandLine.IndexOf('"', 1);
			if (num > 0)
			{
				string item = commandLine.Substring(1, num - 1);
				string item2 = commandLine.Substring(num + 1).Trim();
				return (command: item, arguments: item2);
			}
		}
		int num2 = commandLine.IndexOf(' ');
		if (num2 > 0)
		{
			return (command: commandLine.Substring(0, num2), arguments: commandLine.Substring(num2 + 1).Trim());
		}
		return (command: commandLine, arguments: string.Empty);
	}
}

