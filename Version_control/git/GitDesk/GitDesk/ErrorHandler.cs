using System;
using System.IO;
using System.Windows;

namespace GitDesk
{
    /// <summary>
    /// Enterprise-grade error handling with user-friendly messages and logging.
    /// </summary>
    public static class ErrorHandler
    {
        private static readonly string LogPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "GitDesk", "errors.log");

        public static void Handle(Exception ex, string context, bool showDialog = true)
        {
            string message = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {context}\n{ex.GetType().Name}: {ex.Message}\n{ex.StackTrace}\n\n";
            
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(LogPath)!);
                File.AppendAllText(LogPath, message);
            }
            catch { }

            if (showDialog)
            {
                string userMessage = GetUserFriendlyMessage(ex, context);
                MessageBox.Show(userMessage, "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        public static void LogInfo(string message)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(LogPath)!);
                File.AppendAllText(LogPath, $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] INFO: {message}\n");
            }
            catch { }
        }

        public static string GetUserFriendlyMessage(Exception ex, string context)
        {
            // Git-specific errors
            if (ex.Message.Contains("not a git repository"))
                return $"The selected folder is not a Git repository.\n\nContext: {context}";
            
            if (ex.Message.Contains("merge conflict"))
                return $"There are merge conflicts that need to be resolved.\n\nContext: {context}";
            
            if (ex.Message.Contains("uncommitted changes"))
                return $"You have uncommitted changes. Please commit or stash them first.\n\nContext: {context}";
            
            if (ex.Message.Contains("authentication"))
                return $"Authentication failed. Check your credentials.\n\nContext: {context}";
            
            if (ex.Message.Contains("network") || ex.Message.Contains("connection"))
                return $"Network error. Check your internet connection.\n\nContext: {context}";
            
            if (ex.Message.Contains("permission") || ex.Message.Contains("access denied"))
                return $"Permission denied. Try running as administrator.\n\nContext: {context}";
            
            if (ex is LibGit2Sharp.NotFoundException)
                return $"Git object not found. The repository may be corrupted.\n\nContext: {context}";
            
            if (ex is LibGit2Sharp.BareRepositoryException)
                return $"This operation cannot be performed on a bare repository.\n\nContext: {context}";
            
            if (ex is LibGit2Sharp.UnmergedIndexEntriesException)
                return $"Cannot perform operation with unmerged index entries. Resolve conflicts first.\n\nContext: {context}";
            
            // Generic fallback
            return $"{context} failed:\n\n{ex.Message}\n\nCheck logs for details.";
        }

        public static T HandleWithFallback<T>(Func<T> operation, T fallback, string context, bool silent = false)
        {
            try
            {
                return operation();
            }
            catch (Exception ex)
            {
                if (!silent)
                    Handle(ex, context, showDialog: false);
                return fallback;
            }
        }

        public static void HandleWithFallback(Action operation, string context, bool silent = false)
        {
            try
            {
                operation();
            }
            catch (Exception ex)
            {
                if (!silent)
                    Handle(ex, context, showDialog: false);
            }
        }
    }
}
