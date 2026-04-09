using System;
using System.Windows;
using System.Windows.Forms;
using System.Drawing;
using System.IO;
using System.Reflection;

namespace StartupManager;

public class TrayIconService : IDisposable
{
    private readonly NotifyIcon _trayIcon;
    private readonly Window _mainWindow;

    public TrayIconService(Window mainWindow)
    {
        _mainWindow = mainWindow;
        
        Icon? trayIcon = null;
        try
        {
            var iconPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "tray.ico");
            if (File.Exists(iconPath))
            {
                trayIcon = new Icon(iconPath);
            }
        }
        catch { }
        
        _trayIcon = new NotifyIcon
        {
            Icon = trayIcon ?? SystemIcons.Application,
            Text = "Startup Manager",
            Visible = true
        };

        _trayIcon.DoubleClick += (s, e) =>
        {
            _mainWindow.Show();
            _mainWindow.WindowState = WindowState.Normal;
            _mainWindow.Activate();
        };

        var contextMenu = new ContextMenuStrip();
        contextMenu.Items.Add("Show", null, (s, e) =>
        {
            _mainWindow.Show();
            _mainWindow.WindowState = WindowState.Normal;
            _mainWindow.Activate();
        });
        contextMenu.Items.Add("-");
        contextMenu.Items.Add("Exit", null, (s, e) => System.Windows.Application.Current.Shutdown());
        
        _trayIcon.ContextMenuStrip = contextMenu;
    }

    public void Dispose()
    {
        _trayIcon.Visible = false;
        _trayIcon.Dispose();
    }
}
