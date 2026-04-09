using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Forms;
using System.Windows.Resources;
using Microsoft.Win32;

namespace StartupMaster.Services;

public class TrayIconService : IDisposable
{
	private readonly NotifyIcon _notifyIcon;

	private readonly ToolStripMenuItem _startupMenuItem;

	private readonly ToolStripMenuItem _gatewayStatusItem;

	private readonly string _appPath;

	private readonly string _appName = "StartupMaster";

	private readonly string _registryKey = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run";

	private bool _disposed;

	public TrayIconService()
	{
		_appPath = Environment.ProcessPath ?? AppContext.BaseDirectory;
		_notifyIcon = new NotifyIcon
		{
			Visible = true,
			Text = "Startup Master v2.0 - Windows Startup Manager"
		};
		LoadIcon();
		ContextMenuStrip contextMenuStrip = new ContextMenuStrip();
		contextMenuStrip.RenderMode = ToolStripRenderMode.System;
		contextMenuStrip.BackColor = Color.FromArgb(32, 32, 32);
		contextMenuStrip.ForeColor = Color.White;
		contextMenuStrip.ShowImageMargin = true;

		ToolStripMenuItem toolStripMenuItem = new ToolStripMenuItem("Show Startup Master", null, delegate
		{
			ShowMainWindow();
		});
		toolStripMenuItem.Font = new Font("Segoe UI", 9f, System.Drawing.FontStyle.Bold);
		contextMenuStrip.Items.Add(toolStripMenuItem);
		contextMenuStrip.Items.Add(new ToolStripSeparator());
		_gatewayStatusItem = new ToolStripMenuItem("Gateway: Monitoring...")
		{
			Enabled = false
		};
		contextMenuStrip.Items.Add(_gatewayStatusItem);
		ToolStripMenuItem value2 = new ToolStripMenuItem("Restart Gateway", null, delegate
		{
			RestartGateway();
		});
		contextMenuStrip.Items.Add(value2);
		contextMenuStrip.Items.Add(new ToolStripSeparator());
		ToolStripMenuItem controlPanelItem = new ToolStripMenuItem("ControlPanel", null, delegate
		{
			OpenControlPanel();
		});
		controlPanelItem.Font = new Font("Segoe UI", 9f, System.Drawing.FontStyle.Bold);
		controlPanelItem.ForeColor = Color.FromArgb(0, 200, 255);
		contextMenuStrip.Items.Add(controlPanelItem);
		contextMenuStrip.Items.Add(new ToolStripSeparator());
		_startupMenuItem = new ToolStripMenuItem("Run on Windows Startup", null, delegate
		{
			ToggleStartup();
		});
		_startupMenuItem.Checked = IsInStartup();
		contextMenuStrip.Items.Add(_startupMenuItem);
		contextMenuStrip.Items.Add(new ToolStripSeparator());
		ToolStripMenuItem value3 = new ToolStripMenuItem("Exit Startup Master", null, delegate
		{
			ExitApplication();
		});
		contextMenuStrip.Items.Add(value3);
		_notifyIcon.ContextMenuStrip = contextMenuStrip;
		_notifyIcon.DoubleClick += delegate
		{
			ShowMainWindow();
		};
	}

	private void LoadIcon()
	{
		// Try loading embedded resource icon first
		try
		{
			using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("app.ico");
			if (stream != null)
			{
				_notifyIcon.Icon = new Icon(stream, 32, 32);
				return;
			}
		}
		catch
		{
		}
		// Try WPF pack resource
		try
		{
			StreamResourceInfo resourceStream = System.Windows.Application.GetResourceStream(new Uri("pack://application:,,,/app.ico", UriKind.Absolute));
			if (resourceStream != null)
			{
				_notifyIcon.Icon = new Icon(resourceStream.Stream, 32, 32);
				return;
			}
		}
		catch
		{
		}
		// Try file-based icon
		try
		{
			string text = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "app.ico");
			if (File.Exists(text))
			{
				_notifyIcon.Icon = new Icon(text, 32, 32);
				return;
			}
		}
		catch
		{
		}
		// Generate a custom rocket icon programmatically as ultimate fallback
		_notifyIcon.Icon = GenerateRocketIcon();
	}

	private static Icon GenerateRocketIcon()
	{
		using Bitmap bmp = new Bitmap(32, 32);
		using Graphics g = Graphics.FromImage(bmp);
		g.SmoothingMode = SmoothingMode.AntiAlias;
		g.Clear(Color.Transparent);

		// Draw a rocket shape
		// Body (rounded rect)
		using (var bodyBrush = new LinearGradientBrush(
			new Rectangle(10, 2, 12, 22), Color.FromArgb(0, 150, 255), Color.FromArgb(0, 100, 200), 90f))
		{
			g.FillEllipse(bodyBrush, 10, 2, 12, 24);
		}

		// Nose cone
		using (var noseBrush = new SolidBrush(Color.FromArgb(255, 200, 0)))
		{
			System.Drawing.Point[] nose = { new(16, 0), new(12, 8), new(20, 8) };
			g.FillPolygon(noseBrush, nose);
		}

		// Fins
		using (var finBrush = new SolidBrush(Color.FromArgb(255, 80, 0)))
		{
			System.Drawing.Point[] leftFin = { new(10, 20), new(5, 28), new(12, 24) };
			System.Drawing.Point[] rightFin = { new(22, 20), new(27, 28), new(20, 24) };
			g.FillPolygon(finBrush, leftFin);
			g.FillPolygon(finBrush, rightFin);
		}

		// Flame
		using (var flameBrush = new SolidBrush(Color.FromArgb(255, 140, 0)))
		{
			System.Drawing.Point[] flame = { new(13, 24), new(16, 31), new(19, 24) };
			g.FillPolygon(flameBrush, flame);
		}
		using (var innerFlame = new SolidBrush(Color.FromArgb(255, 255, 100)))
		{
			System.Drawing.Point[] flame2 = { new(14, 24), new(16, 29), new(18, 24) };
			g.FillPolygon(innerFlame, flame2);
		}

		// Window on rocket body
		using (var windowBrush = new SolidBrush(Color.FromArgb(200, 230, 255)))
		{
			g.FillEllipse(windowBrush, 13, 10, 6, 6);
		}

		return Icon.FromHandle(bmp.GetHicon());
	}

	public void UpdateGatewayStatus(string status)
	{
		if (_gatewayStatusItem != null)
		{
			_gatewayStatusItem.Text = "Gateway: " + status;
		}
	}

	private void ShowMainWindow()
	{
		var app = System.Windows.Application.Current;
		if (app == null) return;

		app.Dispatcher.Invoke(() =>
		{
			// Lazy-create MainWindow on first open (avoids heavy init at boot)
			if (app.MainWindow == null)
			{
				app.MainWindow = new StartupMaster.MainWindow();
			}
			app.MainWindow.Show();
			app.MainWindow.WindowState = WindowState.Normal;
			app.MainWindow.Activate();
		});
	}

	private bool IsInStartup()
	{
		try
		{
			using RegistryKey registryKey = Registry.CurrentUser.OpenSubKey(_registryKey, writable: false);
			return !string.IsNullOrEmpty(registryKey?.GetValue(_appName) as string);
		}
		catch
		{
			return false;
		}
	}

	private void ToggleStartup()
	{
		try
		{
			using RegistryKey registryKey = Registry.CurrentUser.OpenSubKey(_registryKey, writable: true);
			if (registryKey != null)
			{
				if (IsInStartup())
				{
					registryKey.DeleteValue(_appName, throwOnMissingValue: false);
					_startupMenuItem.Checked = false;
					_notifyIcon.ShowBalloonTip(2000, "Startup Master", "Removed from Windows Startup", ToolTipIcon.Info);
				}
				else
				{
					registryKey.SetValue(_appName, "\"" + _appPath + "\"");
					_startupMenuItem.Checked = true;
					_notifyIcon.ShowBalloonTip(2000, "Startup Master", "Added to Windows Startup", ToolTipIcon.Info);
				}
			}
		}
		catch (Exception ex)
		{
			System.Windows.MessageBox.Show("Failed to modify startup settings: " + ex.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Hand);
		}
	}

	private void RestartGateway()
	{
		GatewayMonitorService gatewayMonitor = App.GatewayMonitor;
		if (gatewayMonitor != null)
		{
			gatewayMonitor.Stop();
			Thread.Sleep(1000);
			gatewayMonitor.Start();
			ShowNotification("Gateway", "Gateway restarted manually");
		}
	}

	private void OpenControlPanel()
	{
		const string obRepo = @"C:\Users\micha\Documents\WindowsPowerShell\AI_ML\AI_and_Machine_Learning\Artificial_Intelligence\Claude\notes\web\ob";
		const string siteUrl = "https://ob-autodeploy.netlify.app/";

		ShowNotification("ControlPanel", "Syncing local vault with ob-autodeploy...");

		// Run git sync in background then open browser
		Task.Run(() =>
		{
			try
			{
				var psi = new ProcessStartInfo("powershell.exe")
				{
					Arguments = $"-NoProfile -WindowStyle Hidden -Command \"Set-Location '{obRepo}'; git add -A; git diff --cached --quiet; if ($LASTEXITCODE -ne 0) {{ git commit -m 'sync: auto-sync from ControlPanel'; git push }}\"",
					UseShellExecute = false,
					CreateNoWindow = true
				};
				using var proc = Process.Start(psi);
				proc?.WaitForExit(30000);
			}
			catch { /* sync failure is non-fatal */ }

			// Open browser on UI thread
			Process.Start(new ProcessStartInfo(siteUrl) { UseShellExecute = true });
		});
	}

	private void ExitApplication()
	{
		_notifyIcon.Visible = false;
		System.Windows.Application.Current.Shutdown();
	}

	public void ShowNotification(string title, string message, ToolTipIcon icon = ToolTipIcon.Info)
	{
		_notifyIcon.ShowBalloonTip(3000, title, message, icon);
	}

	public void RefreshStartupStatus()
	{
		_startupMenuItem.Checked = IsInStartup();
	}

	public void Dispose()
	{
		if (!_disposed)
		{
			_disposed = true;
			_notifyIcon.Visible = false;
			_notifyIcon.Dispose();
		}
	}
}

