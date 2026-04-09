using System;
using System.Windows;
using System.IO;

namespace GameLauncherPro
{
    public partial class App : Application
    {
        private void Application_DispatcherUnhandledException(object sender, System.Windows.Threading.DispatcherUnhandledExceptionEventArgs e)
        {
            var errorLog = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "GameLauncherPro", "error.log"
            );

            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(errorLog)!);
                File.AppendAllText(errorLog, $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {e.Exception}\n\n");
            }
            catch { }

            MessageBox.Show(
                $"An error occurred:\n\n{e.Exception.Message}\n\nThe application will continue running.\n\nError logged to: {errorLog}",
                "Error",
                MessageBoxButton.OK,
                MessageBoxImage.Error
            );

            e.Handled = true;
        }
    }
}
