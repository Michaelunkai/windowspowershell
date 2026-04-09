using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using StartupMaster.Models;

namespace StartupMaster.Utils;

public class BackupManager
{
	private static readonly string BackupDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "StartupMaster", "Backups");

	public BackupManager()
	{
		if (!Directory.Exists(BackupDirectory))
		{
			Directory.CreateDirectory(BackupDirectory);
		}
	}

	public string CreateAutoBackup(List<StartupItem> items, string reason = "Auto")
	{
		string value = DateTime.Now.ToString("yyyyMMdd_HHmmss");
		string path = $"Backup_{reason}_{value}.json";
		string text = Path.Combine(BackupDirectory, path);
		string contents = JsonSerializer.Serialize(new BackupData
		{
			Timestamp = DateTime.Now,
			Reason = reason,
			ItemCount = items.Count,
			Items = items
		}, new JsonSerializerOptions
		{
			WriteIndented = true
		});
		File.WriteAllText(text, contents);
		CleanOldBackups();
		return text;
	}

	public List<BackupInfo> GetBackups()
	{
		List<BackupInfo> list = new List<BackupInfo>();
		if (!Directory.Exists(BackupDirectory))
		{
			return list;
		}
		string[] files = Directory.GetFiles(BackupDirectory, "*.json");
		foreach (string text in files)
		{
			try
			{
				BackupData backupData = JsonSerializer.Deserialize<BackupData>(File.ReadAllText(text));
				if (backupData != null)
				{
					list.Add(new BackupInfo
					{
						FilePath = text,
						FileName = Path.GetFileName(text),
						Timestamp = backupData.Timestamp,
						Reason = backupData.Reason,
						ItemCount = backupData.ItemCount,
						FileSize = new FileInfo(text).Length
					});
				}
			}
			catch
			{
			}
		}
		list.Sort((BackupInfo a, BackupInfo b) => b.Timestamp.CompareTo(a.Timestamp));
		return list;
	}

	public BackupData RestoreBackup(string filePath)
	{
		return JsonSerializer.Deserialize<BackupData>(File.ReadAllText(filePath));
	}

	public void DeleteBackup(string filePath)
	{
		if (File.Exists(filePath))
		{
			File.Delete(filePath);
		}
	}

	private void CleanOldBackups()
	{
		List<BackupInfo> backups = GetBackups();
		if (backups.Count <= 50)
		{
			return;
		}
		for (int i = 50; i < backups.Count; i++)
		{
			try
			{
				File.Delete(backups[i].FilePath);
			}
			catch
			{
			}
		}
	}

	public long GetTotalBackupSize()
	{
		long num = 0L;
		if (Directory.Exists(BackupDirectory))
		{
			string[] files = Directory.GetFiles(BackupDirectory, "*.json");
			foreach (string fileName in files)
			{
				num += new FileInfo(fileName).Length;
			}
		}
		return num;
	}
}

