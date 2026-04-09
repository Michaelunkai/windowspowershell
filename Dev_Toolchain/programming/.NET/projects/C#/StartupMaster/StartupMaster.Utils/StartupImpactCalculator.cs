using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using StartupMaster.Models;

namespace StartupMaster.Utils;

public class StartupImpactCalculator
{
	private static readonly Dictionary<string, int> KnownImpactScores = new Dictionary<string, int>
	{
		{ "chrome", 10 },
		{ "firefox", 10 },
		{ "edge", 10 },
		{ "teams", 10 },
		{ "slack", 10 },
		{ "discord", 10 },
		{ "outlook", 10 },
		{ "onedrive", 9 },
		{ "dropbox", 9 },
		{ "adobe", 8 },
		{ "creative", 8 },
		{ "photoshop", 8 },
		{ "steam", 7 },
		{ "epic", 7 },
		{ "spotify", 7 },
		{ "skype", 6 },
		{ "zoom", 6 },
		{ "nvidia", 5 },
		{ "amd", 5 },
		{ "intel", 5 },
		{ "java", 4 },
		{ "update", 2 },
		{ "helper", 2 },
		{ "tray", 1 }
	};

	public int CalculateImpact(StartupItem item)
	{
		int num = 0;
		string text = item.Name.ToLower();
		string text2 = item.Command.ToLower();
		foreach (KeyValuePair<string, int> knownImpactScore in KnownImpactScores)
		{
			if (text.Contains(knownImpactScore.Key) || text2.Contains(knownImpactScore.Key))
			{
				num = Math.Max(num, knownImpactScore.Value);
				break;
			}
		}
		if (num == 0 && File.Exists(item.Command))
		{
			try
			{
				double num2 = (double)new FileInfo(item.Command).Length / 1048576.0;
				num = ((num2 > 100.0) ? 9 : ((num2 > 50.0) ? 7 : ((!(num2 > 10.0)) ? 3 : 5)));
			}
			catch
			{
				num = 5;
			}
		}
		int num3 = num;
		num = num3 + item.Location switch
		{
			StartupLocation.RegistryLocalMachine => 1, 
			StartupLocation.Service => 2, 
			_ => 0, 
		};
		if (item.DelaySeconds > 30)
		{
			num -= 2;
		}
		return Math.Clamp(num, 1, 10);
	}

	public string GetImpactDescription(int score)
	{
		if (score >= 5)
		{
			if (score < 9)
			{
				if (score >= 7)
				{
					return "High - Significant boot delay";
				}
				return "Medium - Noticeable impact";
			}
			return "Critical - Major boot impact";
		}
		if (score >= 3)
		{
			return "Low - Minor impact";
		}
		return "Minimal - Negligible impact";
	}

	public string GetImpactEmoji(int score)
	{
		if (score >= 5)
		{
			if (score < 9)
			{
				if (score >= 7)
				{
					return "\ud83d\udfe0";
				}
				return "\ud83d\udfe1";
			}
			return "\ud83d\udd34";
		}
		if (score >= 3)
		{
			return "\ud83d\udfe2";
		}
		return "⚪";
	}

	public List<StartupItem> GetHighImpactItems(List<StartupItem> items)
	{
		return (from i in items
			where i.IsEnabled && CalculateImpact(i) >= 7
			orderby CalculateImpact(i) descending
			select i).ToList();
	}

	public int EstimateBootTimeSeconds(List<StartupItem> items)
	{
		int num = 0;
		foreach (StartupItem item in items.Where((StartupItem i) => i.IsEnabled))
		{
			int num2 = CalculateImpact(item);
			int num3 = ((num2 >= 5) ? ((num2 >= 9) ? 8 : ((num2 < 7) ? 3 : 5)) : ((num2 < 3) ? 1 : 2));
			int num4 = num3;
			if (item.DelaySeconds == 0)
			{
				num += num4;
			}
		}
		return num;
	}

	public string GetOptimizationSuggestion(StartupItem item)
	{
		int num = CalculateImpact(item);
		if (num >= 9)
		{
			return "Consider adding 60+ second delay or disabling if not essential";
		}
		if (num >= 7)
		{
			return "Add 30-60 second delay to reduce boot spike";
		}
		if (num >= 5)
		{
			return "Consider 15-30 second delay for better boot distribution";
		}
		return "No optimization needed";
	}
}

