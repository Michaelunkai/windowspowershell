using System;
using System.Collections.Generic;
using System.IO;
using StartupMaster.Models;

namespace StartupMaster.Services;

public static class BootImpactEstimator
{
	private static readonly Dictionary<string, double> KnownAppImpacts = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase)
	{
		{ "steam", 5.0 },
		{ "steamservice", 3.0 },
		{ "discord", 4.0 },
		{ "spotify", 3.5 },
		{ "teams", 6.0 },
		{ "slack", 4.0 },
		{ "zoom", 3.5 },
		{ "chrome", 3.0 },
		{ "firefox", 2.5 },
		{ "edge", 2.0 },
		{ "msedge", 2.0 },
		{ "onedrive", 4.0 },
		{ "dropbox", 3.5 },
		{ "googledrive", 3.0 },
		{ "adobe", 5.0 },
		{ "creative cloud", 6.0 },
		{ "ccxprocess", 3.0 },
		{ "photoshop", 8.0 },
		{ "illustrator", 7.0 },
		{ "premiere", 8.0 },
		{ "nvidia", 2.0 },
		{ "nvcontainer", 1.5 },
		{ "nvbackend", 1.0 },
		{ "amd", 1.5 },
		{ "radeon", 2.0 },
		{ "realtek", 1.0 },
		{ "rthdvcpl", 1.0 },
		{ "intel", 1.0 },
		{ "igfx", 0.8 },
		{ "logitech", 1.5 },
		{ "razer", 2.0 },
		{ "corsair", 1.5 },
		{ "vmware", 3.0 },
		{ "virtualbox", 2.5 },
		{ "docker", 4.0 },
		{ "antivirus", 3.0 },
		{ "avg", 2.5 },
		{ "avast", 3.0 },
		{ "autohotkey", 0.5 },
		{ "ahk", 0.5 },
		{ "clipboard", 0.3 },
		{ "snip", 0.3 },
		{ "wallpaper", 0.5 },
		{ "rainmeter", 1.0 },
		{ "f.lux", 0.3 },
		{ "nightlight", 0.2 }
	};

	private const double ServiceBaseImpact = 1.0;

	private const double RegistryBaseImpact = 0.8;

	private const double TaskSchedulerBaseImpact = 0.5;

	private const double StartupFolderBaseImpact = 1.0;

	public static void EstimateImpact(StartupItem item)
	{
		double num = 0.0;
		string text = (item.Name + " " + item.Command).ToLower();
		foreach (KeyValuePair<string, double> knownAppImpact in KnownAppImpacts)
		{
			if (text.Contains(knownAppImpact.Key.ToLower()))
			{
				num = Math.Max(num, knownAppImpact.Value);
			}
		}
		if (num == 0.0)
		{
			num = item.Location switch
			{
				StartupLocation.Service => 1.0, 
				StartupLocation.RegistryCurrentUser => 0.8, 
				StartupLocation.RegistryLocalMachine => 0.8, 
				StartupLocation.TaskScheduler => 0.5, 
				StartupLocation.StartupFolder => 1.0, 
				_ => 0.5, 
			};
			string executablePath = GetExecutablePath(item.Command);
			if (!string.IsNullOrEmpty(executablePath) && File.Exists(executablePath))
			{
				try
				{
					double num2 = (double)new FileInfo(executablePath).Length / 1048576.0;
					if (num2 > 100.0)
					{
						num += 3.0;
					}
					else if (num2 > 50.0)
					{
						num += 2.0;
					}
					else if (num2 > 20.0)
					{
						num += 1.0;
					}
					else if (num2 > 5.0)
					{
						num += 0.5;
					}
				}
				catch
				{
				}
			}
			if (item.Location == StartupLocation.Service)
			{
				num *= 1.5;
			}
		}
		item.EstimatedImpactSeconds = Math.Round(num, 1);
	}

	private static string? GetExecutablePath(string? command)
	{
		if (string.IsNullOrEmpty(command))
		{
			return null;
		}
		string text = command.Trim();
		if (text.StartsWith("\""))
		{
			int num = text.IndexOf('"', 1);
			if (num > 0)
			{
				text = text.Substring(1, num - 1);
			}
		}
		else
		{
			int num2 = text.IndexOf(' ');
			if (num2 > 0)
			{
				text = text.Substring(0, num2);
			}
		}
		return Environment.ExpandEnvironmentVariables(text);
	}

	public static void EstimateAll(IEnumerable<StartupItem> items)
	{
		foreach (StartupItem item in items)
		{
			EstimateImpact(item);
		}
	}

	public static double GetTotalPotentialSavings(IEnumerable<StartupItem> items)
	{
		double num = 0.0;
		foreach (StartupItem item in items)
		{
			if (item.IsEnabled)
			{
				num += item.EstimatedImpactSeconds;
			}
		}
		return num;
	}
}

