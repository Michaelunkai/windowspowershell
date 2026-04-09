using System;

namespace StartupMaster.Utils;

public class BackupInfo
{
	public string FilePath { get; set; }

	public string FileName { get; set; }

	public DateTime Timestamp { get; set; }

	public string Reason { get; set; }

	public int ItemCount { get; set; }

	public long FileSize { get; set; }

	public string DisplayName => $"{Timestamp:yyyy-MM-dd HH:mm} - {Reason} ({ItemCount} items)";

	public string FileSizeFormatted => FormatFileSize(FileSize);

	private string FormatFileSize(long bytes)
	{
		if (bytes >= 1024)
		{
			if (bytes >= 1048576)
			{
				return $"{bytes / 1048576} MB";
			}
			return $"{bytes / 1024} KB";
		}
		return $"{bytes} B";
	}
}

