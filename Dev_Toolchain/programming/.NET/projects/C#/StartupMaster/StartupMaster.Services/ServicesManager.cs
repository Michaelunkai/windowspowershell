using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management;
using System.ServiceProcess;
using Microsoft.Win32;
using StartupMaster.Models;

namespace StartupMaster.Services;

public class ServicesManager
{
	public List<StartupItem> GetItems()
	{
		List<StartupItem> list = new List<StartupItem>();
		try
		{
			foreach (ServiceController item in from s in ServiceController.GetServices()
				where s.StartType == ServiceStartMode.Automatic || s.StartType == ServiceStartMode.Boot || s.StartType == ServiceStartMode.System
				select s)
			{
				try
				{
					StartupItem startupItem = new StartupItem
					{
						Name = item.DisplayName,
						Command = item.ServiceName,
						Arguments = GetServiceStartType(item.StartType),
						Location = StartupLocation.Service,
						IsEnabled = (item.StartType == ServiceStartMode.Automatic || item.StartType == ServiceStartMode.Boot || item.StartType == ServiceStartMode.System),
						ServiceName = item.ServiceName,
						Publisher = GetServicePublisher(item.ServiceName)
					};
					if (item.StartType == ServiceStartMode.Boot || item.StartType == ServiceStartMode.System)
					{
						startupItem.IsCritical = true;
						startupItem.CriticalReason = $"{item.StartType} service - required for Windows startup";
					}
					list.Add(startupItem);
				}
				catch
				{
				}
			}
			try
			{
				foreach (string serviceName in GetDelayedAutoStartServices())
				{
					if (!list.Any((StartupItem i) => i.ServiceName == serviceName))
					{
						try
						{
							ServiceController serviceController = new ServiceController(serviceName);
							list.Add(new StartupItem
							{
								Name = serviceController.DisplayName,
								Command = serviceController.ServiceName,
								Arguments = "Automatic (Delayed)",
								Location = StartupLocation.Service,
								IsEnabled = true,
								ServiceName = serviceController.ServiceName,
								Publisher = GetServicePublisher(serviceName)
							});
						}
						catch
						{
						}
					}
				}
			}
			catch
			{
			}
		}
		catch
		{
		}
		return list;
	}

	private string GetServiceStartType(ServiceStartMode mode)
	{
		return mode switch
		{
			ServiceStartMode.Boot => "Boot", 
			ServiceStartMode.System => "System", 
			ServiceStartMode.Automatic => "Automatic", 
			ServiceStartMode.Manual => "Manual", 
			ServiceStartMode.Disabled => "Disabled", 
			_ => "Unknown", 
		};
	}

	private string? GetServicePublisher(string serviceName)
	{
		try
		{
			using RegistryKey registryKey = Registry.LocalMachine.OpenSubKey("SYSTEM\\CurrentControlSet\\Services\\" + serviceName);
			string text = registryKey?.GetValue("ImagePath")?.ToString();
			if (!string.IsNullOrEmpty(text))
			{
				text = text.Trim('"');
				if (text.StartsWith("\\SystemRoot\\"))
				{
					text = text.Replace("\\SystemRoot\\", "C:\\Windows\\");
				}
				if (text.StartsWith("system32", StringComparison.OrdinalIgnoreCase))
				{
					text = "C:\\Windows\\" + text;
				}
				int num = text.IndexOf(' ');
				if (num > 0)
				{
					text = text.Substring(0, num);
				}
				if (File.Exists(text))
				{
					return FileVersionInfo.GetVersionInfo(text).CompanyName;
				}
			}
		}
		catch
		{
		}
		return null;
	}

	private List<string> GetDelayedAutoStartServices()
	{
		List<string> list = new List<string>();
		try
		{
			using RegistryKey registryKey = Registry.LocalMachine.OpenSubKey("SYSTEM\\CurrentControlSet\\Services");
			if (registryKey != null)
			{
				string[] subKeyNames = registryKey.GetSubKeyNames();
				foreach (string text in subKeyNames)
				{
					try
					{
						using RegistryKey registryKey2 = registryKey.OpenSubKey(text);
						object obj = registryKey2?.GetValue("Start");
						object obj2 = registryKey2?.GetValue("DelayedAutostart");
						if (obj != null && (int)obj == 2 && obj2 != null && (int)obj2 == 1)
						{
							list.Add(text);
						}
					}
					catch
					{
					}
				}
			}
		}
		catch
		{
		}
		return list;
	}

	public bool DisableItem(StartupItem item)
	{
		if (item.IsCritical)
		{
			return false;
		}
		try
		{
			using ManagementObject managementObject = new ManagementObject("Win32_Service.Name='" + item.ServiceName + "'");
			managementObject.Get();
			managementObject.InvokeMethod("ChangeStartMode", new object[1] { "Manual" });
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
			using ManagementObject managementObject = new ManagementObject("Win32_Service.Name='" + item.ServiceName + "'");
			managementObject.Get();
			managementObject.InvokeMethod("ChangeStartMode", new object[1] { "Automatic" });
			item.IsEnabled = true;
			return true;
		}
		catch
		{
			return false;
		}
	}

	public bool StopService(StartupItem item)
	{
		if (item.IsCritical)
		{
			return false;
		}
		try
		{
			ServiceController serviceController = new ServiceController(item.ServiceName);
			if (serviceController.Status == ServiceControllerStatus.Running)
			{
				serviceController.Stop();
				serviceController.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(30.0));
			}
			return true;
		}
		catch
		{
			return false;
		}
	}

	public bool StartService(StartupItem item)
	{
		try
		{
			ServiceController serviceController = new ServiceController(item.ServiceName);
			if (serviceController.Status == ServiceControllerStatus.Stopped)
			{
				serviceController.Start();
				serviceController.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(30.0));
			}
			return true;
		}
		catch
		{
			return false;
		}
	}
}

