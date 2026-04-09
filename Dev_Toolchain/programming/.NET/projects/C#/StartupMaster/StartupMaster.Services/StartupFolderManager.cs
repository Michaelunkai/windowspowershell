using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using StartupMaster.Models;

namespace StartupMaster.Services;

public class StartupFolderManager
{
	private static readonly string UserStartupFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Startup));

	private static readonly string CommonStartupFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonStartup));

	public List<StartupItem> GetItems()
	{
		List<StartupItem> list = new List<StartupItem>();
		list.AddRange(GetFolderItems(UserStartupFolder, StartupLocation.RegistryCurrentUser));
		list.AddRange(GetFolderItems(CommonStartupFolder, StartupLocation.RegistryLocalMachine));
		return list;
	}

	private List<StartupItem> GetFolderItems(string folderPath, StartupLocation location)
	{
		List<StartupItem> list = new List<StartupItem>();
		if (!Directory.Exists(folderPath))
		{
			return list;
		}
		string[] files = Directory.GetFiles(folderPath);
		foreach (string text in files)
		{
			bool isDisabled = text.EndsWith(".disabled", StringComparison.OrdinalIgnoreCase);
			string actualPath = text;
			string extensionToCheck = Path.GetExtension(isDisabled ? text.Replace(".disabled", "") : text).ToLower();
			
			switch (extensionToCheck)
			{
			case ".lnk":
				try
				{
					var (command, arguments) = ResolveShortcut(isDisabled ? text : text);
					string itemName = Path.GetFileNameWithoutExtension(isDisabled ? text.Replace(".disabled", "") : text);
					list.Add(new StartupItem
					{
						Name = itemName,
						Command = command,
						Arguments = arguments,
						Location = StartupLocation.StartupFolder,
						IsEnabled = !isDisabled,
						FilePath = text
					});
				}
				catch
				{
				}
				break;
			case ".exe":
			case ".bat":
			case ".cmd":
			case ".vbs":
				string itemName2 = Path.GetFileNameWithoutExtension(isDisabled ? text.Replace(".disabled", "") : text);
				list.Add(new StartupItem
				{
					Name = itemName2,
					Command = isDisabled ? text.Replace(".disabled", "") : text,
					Arguments = string.Empty,
					Location = StartupLocation.StartupFolder,
					IsEnabled = !isDisabled,
					FilePath = text
				});
				break;
			}
		}
		return list;
	}

	public bool AddItem(StartupItem item, bool allUsers = false)
	{
		try
		{
			string text = Path.Combine(allUsers ? CommonStartupFolder : UserStartupFolder, item.Name + ".lnk");
			CreateShortcut(text, item.Command, item.Arguments ?? string.Empty);
			item.FilePath = text;
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
			if (File.Exists(item.FilePath))
			{
				File.Delete(item.FilePath);
				return true;
			}
			return false;
		}
		catch
		{
			return false;
		}
	}

	public bool DisableItem(StartupItem item)
	{
		try
		{
			string text = item.FilePath + ".disabled";
			File.Move(item.FilePath, text);
			item.FilePath = text;
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
			if (item.FilePath.EndsWith(".disabled"))
			{
				string text = item.FilePath.Replace(".disabled", "");
				File.Move(item.FilePath, text);
				item.FilePath = text;
				item.IsEnabled = true;
				return true;
			}
			return false;
		}
		catch
		{
			return false;
		}
	}

	private void CreateShortcut(string shortcutPath, string targetPath, string arguments)
	{
		dynamic val = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
		dynamic val2 = val.CreateShortcut(shortcutPath);
		val2.TargetPath = targetPath;
		val2.Arguments = arguments;
		val2.WorkingDirectory = Path.GetDirectoryName(targetPath) ?? "";
		val2.Save();
		Marshal.ReleaseComObject(val2);
		Marshal.ReleaseComObject(val);
	}

	private (string targetPath, string arguments) ResolveShortcut(string shortcutPath)
	{
		try
		{
			dynamic val = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
			dynamic val2 = val.CreateShortcut(shortcutPath);
			string item = (val2.TargetPath as string) ?? "";
			string item2 = (val2.Arguments as string) ?? "";
			Marshal.ReleaseComObject(val2);
			Marshal.ReleaseComObject(val);
			return (targetPath: item, arguments: item2);
		}
		catch
		{
			return (targetPath: string.Empty, arguments: string.Empty);
		}
	}
}

