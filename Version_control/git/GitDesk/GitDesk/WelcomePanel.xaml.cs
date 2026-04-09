using System;
using System.Collections.Generic;
using System.IO;
using System.Windows;
using System.Windows.Controls;

namespace GitDesk
{
    public partial class WelcomePanel : UserControl
    {
        private static readonly string RecentFile = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "GitDesk", "recent.txt");

        public event Action<string>? RepoSelected;

        public WelcomePanel()
        {
            InitializeComponent();
            LoadRecent();
        }

        private void LoadRecent()
        {
            var recent = RepoManager.GetRecentRepos();
            RecentReposList.Items.Clear();
            foreach (var repo in recent)
            {
                RecentReposList.Items.Add(repo.Path);
            }
        }

        private void OpenRepo_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new System.Windows.Forms.FolderBrowserDialog { ShowNewFolderButton = false };
            if (dlg.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                RepoSelected?.Invoke(dlg.SelectedPath);
        }

        private void CloneRepo_Click(object sender, RoutedEventArgs e)
        {
            // Forward to main window
            var main = Window.GetWindow(this) as MainWindow;
            main?.CloneRepo_Click(sender, e);
        }

        private void InitRepo_Click(object sender, RoutedEventArgs e)
        {
            var main = Window.GetWindow(this) as MainWindow;
            main?.InitRepo_Click(sender, e);
        }

        private void RecentRepo_DoubleClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            if (RecentReposList.SelectedItem is string path)
                RepoSelected?.Invoke(path);
        }
    }
}
