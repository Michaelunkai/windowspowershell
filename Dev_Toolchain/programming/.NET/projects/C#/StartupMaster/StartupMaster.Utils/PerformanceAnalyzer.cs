using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using StartupMaster.Models;

namespace StartupMaster.Utils;

public class PerformanceAnalyzer
{
	public AnalysisReport AnalyzeStartupItems(List<StartupItem> items)
	{
		AnalysisReport analysisReport = new AnalysisReport
		{
			TotalItems = items.Count,
			EnabledItems = items.Count((StartupItem i) => i.IsEnabled),
			DisabledItems = items.Count((StartupItem i) => !i.IsEnabled),
			ByLocation = new Dictionary<string, int>(),
			Recommendations = new List<string>(),
			HighImpactItems = new List<StartupItem>(),
			PotentialIssues = new List<string>()
		};
		foreach (StartupItem item in items)
		{
			string locationDisplay = item.LocationDisplay;
			if (!analysisReport.ByLocation.ContainsKey(locationDisplay))
			{
				analysisReport.ByLocation[locationDisplay] = 0;
			}
			analysisReport.ByLocation[locationDisplay]++;
		}
		int delayedItems = items.Where((StartupItem i) => i.DelaySeconds > 0).Count();
		int immediateStartItems = items.Where((StartupItem i) => i.IsEnabled && i.DelaySeconds == 0).Count();
		analysisReport.DelayedItems = delayedItems;
		analysisReport.ImmediateStartItems = immediateStartItems;
		DetectIssues(items, analysisReport);
		GenerateRecommendations(items, analysisReport);
		IdentifyHighImpactItems(items, analysisReport);
		return analysisReport;
	}

	private void DetectIssues(List<StartupItem> items, AnalysisReport report)
	{
		foreach (StartupItem item in items.Where((StartupItem i) => i.IsEnabled))
		{
			if (!string.IsNullOrEmpty(item.Command))
			{
				string text = item.Command.Trim('"');
				if (!File.Exists(text) && !text.Contains("%") && !text.StartsWith("$"))
				{
					report.PotentialIssues.Add("Missing executable: " + item.Name + " → " + text);
				}
			}
		}
		foreach (IGrouping<string, StartupItem> item2 in from i in items
			where i.IsEnabled
			group i by i.Command.ToLower() into g
			where g.Count() > 1
			select g)
		{
			report.PotentialIssues.Add($"Duplicate startup entry: {item2.First().Name} ({item2.Count()}x)");
		}
		if (report.ImmediateStartItems > 15)
		{
			report.PotentialIssues.Add($"High number of immediate starts ({report.ImmediateStartItems}). Consider adding delays.");
		}
		int num = items.Count((StartupItem i) => i.Location == StartupLocation.RegistryCurrentUser || i.Location == StartupLocation.RegistryLocalMachine);
		int num2 = items.Count((StartupItem i) => i.Location == StartupLocation.TaskScheduler);
		if (num > num2 * 2)
		{
			report.PotentialIssues.Add("Many registry startup items. Consider moving some to Task Scheduler for better delay control.");
		}
	}

	private void GenerateRecommendations(List<StartupItem> items, AnalysisReport report)
	{
		string[] source = new string[6] { "chrome", "firefox", "teams", "slack", "discord", "outlook" };
		foreach (StartupItem item in items.Where((StartupItem i) => i.IsEnabled && i.DelaySeconds == 0))
		{
			string cmd = item.Command.ToLower();
			if (source.Any((string app) => cmd.Contains(app)))
			{
				report.Recommendations.Add("Add startup delay to " + item.Name + " (detected resource-heavy application)");
			}
		}
		int num = items.Where((StartupItem i) => i.IsEnabled && (i.Location == StartupLocation.RegistryCurrentUser || i.Location == StartupLocation.RegistryLocalMachine)).Count();
		if (num > 5)
		{
			report.Recommendations.Add($"Consider moving {num} registry items to Task Scheduler for delay support");
		}
		if (report.EnabledItems > 20)
		{
			report.Recommendations.Add($"High startup item count ({report.EnabledItems}). Review and disable non-essential items.");
		}
		report.Recommendations.Add("Create a backup before making changes");
		if (report.PotentialIssues.Count > 0)
		{
			report.Recommendations.Add($"Address {report.PotentialIssues.Count} potential issues detected");
		}
	}

	private void IdentifyHighImpactItems(List<StartupItem> items, AnalysisReport report)
	{
		string[] source = new string[17]
		{
			"update", "cloud", "sync", "backup", "antivirus", "security", "chrome", "firefox", "edge", "teams",
			"slack", "discord", "onedrive", "dropbox", "google", "adobe", "creative"
		};
		foreach (StartupItem item in items.Where((StartupItem i) => i.IsEnabled))
		{
			string name = item.Name.ToLower();
			string command = item.Command.ToLower();
			if (source.Any((string kw) => name.Contains(kw) || command.Contains(kw)))
			{
				report.HighImpactItems.Add(item);
			}
		}
	}

	public string GenerateTextReport(AnalysisReport report)
	{
		StringBuilder stringBuilder = new StringBuilder();
		stringBuilder.AppendLine("========================================");
		stringBuilder.AppendLine("   STARTUP PERFORMANCE ANALYSIS");
		stringBuilder.AppendLine("========================================");
		stringBuilder.AppendLine();
		StringBuilder stringBuilder2 = stringBuilder;
		StringBuilder stringBuilder3 = stringBuilder2;
		StringBuilder.AppendInterpolatedStringHandler handler = new StringBuilder.AppendInterpolatedStringHandler(11, 1, stringBuilder2);
		handler.AppendLiteral("Generated: ");
		handler.AppendFormatted(DateTime.Now, "yyyy-MM-dd HH:mm:ss");
		stringBuilder3.AppendLine(ref handler);
		stringBuilder.AppendLine();
		stringBuilder.AppendLine("SUMMARY");
		stringBuilder.AppendLine("-------");
		stringBuilder2 = stringBuilder;
		StringBuilder stringBuilder4 = stringBuilder2;
		handler = new StringBuilder.AppendInterpolatedStringHandler(22, 1, stringBuilder2);
		handler.AppendLiteral("Total Items:          ");
		handler.AppendFormatted(report.TotalItems);
		stringBuilder4.AppendLine(ref handler);
		stringBuilder2 = stringBuilder;
		StringBuilder stringBuilder5 = stringBuilder2;
		handler = new StringBuilder.AppendInterpolatedStringHandler(22, 1, stringBuilder2);
		handler.AppendLiteral("Enabled:              ");
		handler.AppendFormatted(report.EnabledItems);
		stringBuilder5.AppendLine(ref handler);
		stringBuilder2 = stringBuilder;
		StringBuilder stringBuilder6 = stringBuilder2;
		handler = new StringBuilder.AppendInterpolatedStringHandler(22, 1, stringBuilder2);
		handler.AppendLiteral("Disabled:             ");
		handler.AppendFormatted(report.DisabledItems);
		stringBuilder6.AppendLine(ref handler);
		stringBuilder2 = stringBuilder;
		StringBuilder stringBuilder7 = stringBuilder2;
		handler = new StringBuilder.AppendInterpolatedStringHandler(22, 1, stringBuilder2);
		handler.AppendLiteral("Immediate Starts:     ");
		handler.AppendFormatted(report.ImmediateStartItems);
		stringBuilder7.AppendLine(ref handler);
		stringBuilder2 = stringBuilder;
		StringBuilder stringBuilder8 = stringBuilder2;
		handler = new StringBuilder.AppendInterpolatedStringHandler(22, 1, stringBuilder2);
		handler.AppendLiteral("Delayed Starts:       ");
		handler.AppendFormatted(report.DelayedItems);
		stringBuilder8.AppendLine(ref handler);
		stringBuilder.AppendLine();
		stringBuilder.AppendLine("BY LOCATION");
		stringBuilder.AppendLine("-----------");
		foreach (KeyValuePair<string, int> item in report.ByLocation.OrderByDescending((KeyValuePair<string, int> x) => x.Value))
		{
			stringBuilder2 = stringBuilder;
			StringBuilder stringBuilder9 = stringBuilder2;
			handler = new StringBuilder.AppendInterpolatedStringHandler(1, 2, stringBuilder2);
			handler.AppendFormatted<string>(item.Key, -25);
			handler.AppendLiteral(" ");
			handler.AppendFormatted(item.Value);
			stringBuilder9.AppendLine(ref handler);
		}
		stringBuilder.AppendLine();
		if (report.HighImpactItems.Count > 0)
		{
			stringBuilder2 = stringBuilder;
			StringBuilder stringBuilder10 = stringBuilder2;
			handler = new StringBuilder.AppendInterpolatedStringHandler(20, 1, stringBuilder2);
			handler.AppendLiteral("HIGH-IMPACT ITEMS (");
			handler.AppendFormatted(report.HighImpactItems.Count);
			handler.AppendLiteral(")");
			stringBuilder10.AppendLine(ref handler);
			stringBuilder.AppendLine("------------------");
			foreach (StartupItem item2 in report.HighImpactItems.Take(10))
			{
				stringBuilder2 = stringBuilder;
				StringBuilder stringBuilder11 = stringBuilder2;
				handler = new StringBuilder.AppendInterpolatedStringHandler(2, 1, stringBuilder2);
				handler.AppendLiteral("- ");
				handler.AppendFormatted(item2.Name);
				stringBuilder11.AppendLine(ref handler);
			}
			stringBuilder.AppendLine();
		}
		if (report.PotentialIssues.Count > 0)
		{
			stringBuilder2 = stringBuilder;
			StringBuilder stringBuilder12 = stringBuilder2;
			handler = new StringBuilder.AppendInterpolatedStringHandler(19, 1, stringBuilder2);
			handler.AppendLiteral("POTENTIAL ISSUES (");
			handler.AppendFormatted(report.PotentialIssues.Count);
			handler.AppendLiteral(")");
			stringBuilder12.AppendLine(ref handler);
			stringBuilder.AppendLine("----------------");
			foreach (string potentialIssue in report.PotentialIssues)
			{
				stringBuilder2 = stringBuilder;
				StringBuilder stringBuilder13 = stringBuilder2;
				handler = new StringBuilder.AppendInterpolatedStringHandler(2, 1, stringBuilder2);
				handler.AppendLiteral("⚠ ");
				handler.AppendFormatted(potentialIssue);
				stringBuilder13.AppendLine(ref handler);
			}
			stringBuilder.AppendLine();
		}
		if (report.Recommendations.Count > 0)
		{
			stringBuilder2 = stringBuilder;
			StringBuilder stringBuilder14 = stringBuilder2;
			handler = new StringBuilder.AppendInterpolatedStringHandler(18, 1, stringBuilder2);
			handler.AppendLiteral("RECOMMENDATIONS (");
			handler.AppendFormatted(report.Recommendations.Count);
			handler.AppendLiteral(")");
			stringBuilder14.AppendLine(ref handler);
			stringBuilder.AppendLine("---------------");
			foreach (string recommendation in report.Recommendations)
			{
				stringBuilder2 = stringBuilder;
				StringBuilder stringBuilder15 = stringBuilder2;
				handler = new StringBuilder.AppendInterpolatedStringHandler(2, 1, stringBuilder2);
				handler.AppendLiteral("→ ");
				handler.AppendFormatted(recommendation);
				stringBuilder15.AppendLine(ref handler);
			}
			stringBuilder.AppendLine();
		}
		stringBuilder.AppendLine("========================================");
		return stringBuilder.ToString();
	}
}

