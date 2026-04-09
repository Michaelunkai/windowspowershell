using System;
using System.CodeDom.Compiler;
using System.Diagnostics;
using System.Linq;
using System.Windows;
using System.Windows.Forms;
using Microsoft.Win32;
using Microsoft.Win32.TaskScheduler;
using ModernWpf;
using StartupMaster.Services;

namespace StartupMaster;

public partial class App : System.Windows.Application
{
	private TrayIconService? _trayIconService;

	private GatewayMonitorService? _gatewayMonitor;


	public static TrayIconService? TrayIcon { get; private set; }

	public static GatewayMonitorService? GatewayMonitor { get; private set; }

	protected override void OnStartup(StartupEventArgs e)
	{
		base.OnStartup(e);
		ThemeManager.Current.ApplicationTheme = ApplicationTheme.Dark;

		// DO NOT create MainWindow here - it's heavy (WMI, registry scans)
		// It will be created lazily when user clicks "Show" from tray

		_trayIconService = new TrayIconService();
		TrayIcon = _trayIconService;
		_gatewayMonitor = new GatewayMonitorService();
		GatewayMonitor = _gatewayMonitor;
		_gatewayMonitor.StatusChanged += delegate(object? s, string status)
		{
			try { Dispatcher.BeginInvoke(() => _trayIconService?.UpdateGatewayStatus(status)); } catch { }
		};
		_gatewayMonitor.ErrorOccurred += delegate(object? s, Exception ex)
		{
			try { Dispatcher.BeginInvoke(() => _trayIconService?.UpdateGatewayStatus("Error")); } catch { }
		};
		_gatewayMonitor.Start();

		// Run heavy Task Scheduler + WMI operations off the UI thread
		System.Threading.Tasks.Task.Run(() =>
		{
			EnsureStartupRegistration();
			DisableConflictingGatewayTask();
		});
	}

	private void EnsureStartupRegistration()
	{
		try
		{
			string appPath = Environment.ProcessPath ?? AppContext.BaseDirectory;

			// Remove old registry entry if exists (doesn't work for admin apps)
			try
			{
				using var regKey = Registry.CurrentUser.OpenSubKey(
					@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", writable: true);
				regKey?.DeleteValue("StartupMaster", throwOnMissingValue: false);
			}
			catch { }

			// Use Task Scheduler with highest privileges - works for admin apps on boot
			using var ts = new TaskService();
			const string taskName = "StartupMaster_AutoStart";

			var existingTask = ts.GetTask(taskName);
			if (existingTask != null)
			{
				// Check if path matches current exe
				var action = existingTask.Definition.Actions.FirstOrDefault() as ExecAction;
				if (action != null && string.Equals(action.Path, appPath, StringComparison.OrdinalIgnoreCase))
				{
					return; // Already registered with correct path
				}
				// Path changed, recreate
				ts.RootFolder.DeleteTask(taskName, false);
			}

			var td = ts.NewTask();
			td.RegistrationInfo.Description = "Start Startup Master on Windows logon with admin privileges";
			td.Principal.RunLevel = TaskRunLevel.Highest;
			td.Principal.LogonType = TaskLogonType.InteractiveToken;

			var logonTrigger = new LogonTrigger();
			logonTrigger.Delay = TimeSpan.Zero;
			td.Triggers.Add(logonTrigger);

			td.Actions.Add(new ExecAction(appPath, null, null));

			td.Settings.DisallowStartIfOnBatteries = false;
			td.Settings.StopIfGoingOnBatteries = false;
			td.Settings.ExecutionTimeLimit = TimeSpan.Zero;
			td.Settings.AllowHardTerminate = false;
			td.Settings.StartWhenAvailable = true;

			ts.RootFolder.RegisterTaskDefinition(
				taskName, td,
				TaskCreation.CreateOrUpdate,
				null, null,
				TaskLogonType.InteractiveToken);
		}
		catch
		{
			// Silently fail - not critical
		}
	}

	private void DisableConflictingGatewayTask()
	{
		try
		{
			using var ts = new TaskService();

			// Disable the OpenClaw Gateway scheduled task so it won't run on NEXT boot
			// StartupMaster handles gateway from now on
			// IMPORTANT: Do NOT kill any running gateway processes - they have active sessions!
			var gatewayTask = ts.GetTask("OpenClaw Gateway");
			if (gatewayTask != null && gatewayTask.Definition.Settings.Enabled)
			{
				gatewayTask.Definition.Settings.Enabled = false;
				ts.RootFolder.RegisterTaskDefinition(
					"OpenClaw Gateway", gatewayTask.Definition,
					TaskCreation.Update, null, null,
					TaskLogonType.InteractiveToken);
			}
		}
		catch { }
	}

	protected override void OnExit(ExitEventArgs e)
	{
		_gatewayMonitor?.Dispose();
		_trayIconService?.Dispose();
		base.OnExit(e);
	}

}
