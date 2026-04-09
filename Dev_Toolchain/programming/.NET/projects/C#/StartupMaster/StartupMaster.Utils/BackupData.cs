using System;
using System.Collections.Generic;
using StartupMaster.Models;

namespace StartupMaster.Utils;

public class BackupData
{
	public DateTime Timestamp { get; set; }

	public string Reason { get; set; }

	public int ItemCount { get; set; }

	public List<StartupItem> Items { get; set; }
}

