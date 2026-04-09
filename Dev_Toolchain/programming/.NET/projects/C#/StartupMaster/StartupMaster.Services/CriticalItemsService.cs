using System;
using System.Collections.Generic;
using StartupMaster.Models;

namespace StartupMaster.Services;

public static class CriticalItemsService
{
	private static readonly HashSet<string> HiddenServices = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
	{
		"RpcSs", "DcomLaunch", "RpcEptMapper", "LSM", "SamSs", "LanmanServer", "LanmanWorkstation", "Winmgmt", "EventLog", "PlugPlay",
		"Power", "ProfSvc", "UserManager", "Netlogon", "gpsvc", "Schedule", "CryptSvc", "Dhcp", "Dnscache", "NlaSvc",
		"nsi", "W32Time", "Wcmsvc", "WdiServiceHost", "WdiSystemHost", "BrokerInfrastructure", "SystemEventsBroker", "TimeBrokerSvc", "StateRepository", "CoreMessagingRegistrar",
		"CDPSvc", "CDPUserSvc", "DevicesFlowUserSvc", "DeviceAssociationBrokerSvc", "WinDefend", "wscsvc", "SecurityHealthService", "mpssvc", "BFE", "IKEEXT",
		"VaultSvc", "KeyIso", "SgrmBroker", "Netlogon", "SamSs", "LsaSrv", "Themes", "UxSms", "DWM", "FontCache",
		"GraphicsPerfSvc", "DispBrokerDesktopSvc", "WMPNetworkSvc", "StorSvc", "stisvc", "VSS", "SDRSVC", "swprv", "Netman", "netprofm",
		"WlanSvc", "Dot3Svc", "Netwtw", "WwanSvc", "icssvc", "lmhosts", "NetTcpPortSharing", "wuauserv", "BITS", "TrustedInstaller",
		"msiserver", "AppXSvc", "ClipSVC", "TokenBroker", "LicenseManager", "InstallService", "AppReadiness", "WSearch", "SysMain", "DiagTrack",
		"hidserv", "TabletInputService", "SensorService", "SensrSvc", "DeviceAssociationService", "WPDBusEnum", "wudfsvc", "WiaRpc", "Appinfo", "SENS",
		"ShellHWDetection", "SessionEnv", "TermService", "UmRdpService", "AudioSrv", "AudioEndpointBuilder", "Audiosrv", "MMCSS", "PortableDeviceEnumerator", "WbioSrvc"
	};

	private static readonly HashSet<string> SafeServicePatterns = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
	{
		"docker", "vmware", "virtualbox", "hyper-v", "wsl", "steam", "origin", "epic", "uplay", "battlenet",
		"adobe", "creative", "dropbox", "onedrive", "google", "nvidia", "amd", "intel", "realtek", "gigabyte",
		"asus", "msi", "razer", "logitech", "corsair", "steelseries", "discord", "spotify", "zoom", "teams",
		"slack", "antivirus", "avg", "avast", "norton", "mcafee", "kaspersky", "backup", "sync", "cloud"
	};

	private static readonly HashSet<string> HiddenRegistryItems = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "SecurityHealth", "SecurityHealthSystray", "Windows Defender", "WindowsDefender", "ctfmon" };

	private static readonly string[] HiddenTaskPrefixes = new string[5] { "\\Microsoft\\Windows\\", "\\Microsoft\\Office\\", "\\Microsoft\\EdgeUpdate", "\\Microsoft\\VisualStudio", "\\WPD\\" };

	private static readonly HashSet<string> ShowableTasks = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

	public static void EvaluateItem(StartupItem item)
	{
		item.IsCritical = false;
		item.CriticalReason = null;
		item.IsDangerous = false;
		item.DangerReason = null;
		if (item.Location == StartupLocation.Service)
		{
			string text = item.ServiceName ?? item.Command ?? "";
			if (HiddenServices.Contains(text))
			{
				item.IsCritical = true;
				item.CriticalReason = "Core Windows service";
				return;
			}
			string command = item.Command;
			if (command != null && command.Contains("svchost", StringComparison.OrdinalIgnoreCase))
			{
				item.IsCritical = true;
				item.CriticalReason = "Windows system service";
				return;
			}
			string command2 = item.Command;
			if (command2 != null && command2.Contains("\\Windows\\", StringComparison.OrdinalIgnoreCase))
			{
				string command3 = item.Command;
				if (command3 != null && !command3.Contains("\\Windows\\System32\\drivers", StringComparison.OrdinalIgnoreCase) && !IsSafeService(text, item.Name ?? ""))
				{
					item.IsCritical = true;
					item.CriticalReason = "Windows system component";
					return;
				}
			}
			string publisher = item.Publisher;
			if (publisher != null && publisher.Contains("Microsoft", StringComparison.OrdinalIgnoreCase))
			{
				string command4 = item.Command;
				if (command4 != null && command4.Contains("\\Windows\\", StringComparison.OrdinalIgnoreCase))
				{
					item.IsCritical = true;
					item.CriticalReason = "Microsoft system service";
					return;
				}
			}
		}
		if (item.Location == StartupLocation.RegistryCurrentUser || item.Location == StartupLocation.RegistryLocalMachine)
		{
			string item2 = item.Name ?? item.RegistryValueName ?? "";
			if (HiddenRegistryItems.Contains(item2))
			{
				item.IsCritical = true;
				item.CriticalReason = "Windows security component";
				return;
			}
			string command5 = item.Command;
			if (command5 != null && command5.Contains("SecurityHealth", StringComparison.OrdinalIgnoreCase))
			{
				item.IsCritical = true;
				item.CriticalReason = "Windows Security";
				return;
			}
		}
		if (item.Location != StartupLocation.TaskScheduler)
		{
			return;
		}
		string text2 = item.TaskName ?? "";
		string[] hiddenTaskPrefixes = HiddenTaskPrefixes;
		foreach (string value in hiddenTaskPrefixes)
		{
			if (text2.StartsWith(value, StringComparison.OrdinalIgnoreCase))
			{
				item.IsCritical = true;
				item.CriticalReason = "Windows system task";
				break;
			}
		}
	}

	private static bool IsSafeService(string serviceName, string displayName)
	{
		string text = (serviceName + " " + displayName).ToLower();
		foreach (string safeServicePattern in SafeServicePatterns)
		{
			if (text.Contains(safeServicePattern.ToLower()))
			{
				return true;
			}
		}
		return false;
	}

	public static void EvaluateAll(IEnumerable<StartupItem> items)
	{
		foreach (StartupItem item in items)
		{
			EvaluateItem(item);
			EvaluateDangerous(item);
		}
	}

	private static void EvaluateDangerous(StartupItem item)
	{
		// ONLY mark items as dangerous if they are CORE WINDOWS COMPONENTS
		// that will break Windows functionality if disabled
		
		var itemText = (item.Name + " " + item.Command + " " + item.Publisher).ToLower();
		
		// ONLY Windows core components that will break Windows itself
		// Must be from Microsoft AND in Windows directories
		bool isMicrosoftComponent = false;
		bool isInWindowsDirectory = false;
		bool isSystemCritical = false;
		
		// Check if it's a Microsoft component
		if (item.Publisher != null && item.Publisher.Contains("Microsoft", StringComparison.OrdinalIgnoreCase))
		{
			isMicrosoftComponent = true;
		}
		
		// Check if it's in Windows system directories
		if (item.Command != null)
		{
			if (item.Command.Contains("\\Windows\\System32", StringComparison.OrdinalIgnoreCase) ||
			    item.Command.Contains("\\Windows\\SysWOW64", StringComparison.OrdinalIgnoreCase))
			{
				isInWindowsDirectory = true;
			}
		}
		
		// Check if it's a system-critical component
		if (itemText.Contains("ctfmon") || // Windows language/input services
		    itemText.Contains("dwm") ||     // Desktop Window Manager
		    itemText.Contains("explorer") ||// Windows Explorer
		    itemText.Contains("winlogon") ||// Windows Logon
		    itemText.Contains("csrss") ||   // Client Server Runtime
		    itemText.Contains("lsass") ||   // Local Security Authority
		    itemText.Contains("services") ||// Windows Services
		    itemText.Contains("smss") ||    // Session Manager
		    itemText.Contains("wininit"))   // Windows Initialization
		{
			isSystemCritical = true;
		}
		
		// ONLY mark as dangerous if ALL three conditions are met
		if (isMicrosoftComponent && isInWindowsDirectory && isSystemCritical)
		{
			item.IsDangerous = true;
			item.DangerReason = "Core Windows component - disabling may break Windows";
		}
		else
		{
			item.IsDangerous = false;
			item.DangerReason = null;
		}
	}
}

