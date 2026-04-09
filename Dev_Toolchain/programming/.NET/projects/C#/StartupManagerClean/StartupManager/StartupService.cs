using Microsoft.Win32;
using Microsoft.Win32.TaskScheduler;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace StartupManager;

/// <summary>
/// Manages Windows startup items with FULL ADMINISTRATOR PERMISSIONS.
/// Can modify EVERYTHING: Registry (HKCU & HKLM), Startup folders, Task Scheduler.
/// All changes are PERMANENT and saved immediately.
/// </summary>
public class StartupService
{
    private const string RunKeyCU = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run";
    private const string RunKeyLM = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run";
    private const string ApprovedKeyCU = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run";
    private const string ApprovedKeyLM = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run";
    
    private readonly string _startupFolderCU = Environment.GetFolderPath(Environment.SpecialFolder.Startup);
    private readonly string _startupFolderLM = @"C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup";

    private Dictionary<string, StartupItemMetadata> _itemMetadata = new();

    private class StartupItemMetadata
    {
        public string Location { get; set; } = "";
        public string TaskPath { get; set; } = "";
    }

    public List<StartupItem> GetAllItems()
    {
        var items = new List<StartupItem>();
        _itemMetadata.Clear();
        
        // 1. Current User Registry
        items.AddRange(GetRegistryItems(Registry.CurrentUser, RunKeyCU, ApprovedKeyCU, "Registry (Current User)"));
        
        // 2. Local Machine Registry (all users)
        items.AddRange(GetRegistryItems(Registry.LocalMachine, RunKeyLM, ApprovedKeyLM, "Registry (All Users)"));
        
        // 3. Current User Startup Folder
        items.AddRange(GetStartupFolderItems(_startupFolderCU, "Startup Folder (Current User)"));
        
        // 4. All Users Startup Folder
        items.AddRange(GetStartupFolderItems(_startupFolderLM, "Startup Folder (All Users)"));

        // 5. Task Scheduler
        items.AddRange(GetTaskSchedulerItems());

        return items;
    }

    private List<StartupItem> GetRegistryItems(RegistryKey rootKey, string runKeyPath, string approvedKeyPath, string location)
    {
        var items = new List<StartupItem>();
        
        try
        {
            using var runKey = rootKey.OpenSubKey(runKeyPath);
            if (runKey == null) return items;

            var disabledItems = new HashSet<string>();
            
            try
            {
                using var approvedKey = rootKey.OpenSubKey(approvedKeyPath);
                if (approvedKey != null)
                {
                    foreach (var valueName in approvedKey.GetValueNames())
                    {
                        var data = approvedKey.GetValue(valueName) as byte[];
                        if (data != null && data.Length >= 1 && data[0] != 2)
                        {
                            disabledItems.Add(valueName);
                        }
                    }
                }
            }
            catch { }

            foreach (var valueName in runKey.GetValueNames())
            {
                var command = runKey.GetValue(valueName)?.ToString() ?? "";
                if (!string.IsNullOrWhiteSpace(command))
                {
                    var item = new StartupItem
                    {
                        Name = valueName,
                        Command = command,
                        IsEnabled = !disabledItems.Contains(valueName),
                        Location = location
                    };
                    items.Add(item);
                    _itemMetadata[valueName] = new StartupItemMetadata { Location = location };
                }
            }
        }
        catch { }

        return items;
    }

    private List<StartupItem> GetStartupFolderItems(string folderPath, string location)
    {
        var items = new List<StartupItem>();
        
        try
        {
            if (!Directory.Exists(folderPath)) return items;

            foreach (var file in Directory.GetFiles(folderPath, "*.lnk").Concat(Directory.GetFiles(folderPath, "*.exe")))
            {
                var fileName = Path.GetFileNameWithoutExtension(file);
                var item = new StartupItem
                {
                    Name = fileName,
                    Command = file,
                    IsEnabled = true,
                    Location = location
                };
                items.Add(item);
                _itemMetadata[fileName] = new StartupItemMetadata { Location = location };
            }
        }
        catch { }

        return items;
    }

    private List<StartupItem> GetTaskSchedulerItems()
    {
        var items = new List<StartupItem>();
        
        try
        {
            using var ts = new TaskService();
            
            foreach (var task in ts.RootFolder.AllTasks)
            {
                try
                {
                    if (task.Definition.Triggers.Any(t => 
                        t is LogonTrigger || 
                        t is BootTrigger))
                    {
                        var action = task.Definition.Actions.FirstOrDefault();
                        var command = action switch
                        {
                            ExecAction execAction => $"{execAction.Path} {execAction.Arguments}".Trim(),
                            _ => task.Path
                        };

                        var item = new StartupItem
                        {
                            Name = task.Name,
                            Command = command,
                            IsEnabled = task.Enabled,
                            Location = "Task Scheduler"
                        };
                        items.Add(item);
                        _itemMetadata[task.Name] = new StartupItemMetadata 
                        { 
                            Location = "Task Scheduler",
                            TaskPath = task.Path
                        };
                    }
                }
                catch { }
            }
        }
        catch { }

        return items;
    }

    public bool AddItem(string name, string command)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyCU, true);
            if (key == null) return false;
            
            key.SetValue(name, command);
            EnableItem(name);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public bool EnableItem(string name)
    {
        if (!_itemMetadata.TryGetValue(name, out var metadata))
            return false;

        try
        {
            if (metadata.Location == "Task Scheduler")
            {
                using var ts = new TaskService();
                var task = ts.GetTask(metadata.TaskPath);
                if (task != null)
                {
                    task.Enabled = true;
                    return true;
                }
            }
            else if (metadata.Location.StartsWith("Registry"))
            {
                var rootKey = metadata.Location.Contains("Current User") ? Registry.CurrentUser : Registry.LocalMachine;
                var approvedPath = metadata.Location.Contains("Current User") ? ApprovedKeyCU : ApprovedKeyLM;
                
                using var key = rootKey.CreateSubKey(approvedPath);
                if (key != null)
                {
                    byte[] enabledData = new byte[12] { 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
                    key.SetValue(name, enabledData, RegistryValueKind.Binary);
                    return true;
                }
            }
        }
        catch { }

        return false;
    }

    public bool DisableItem(string name)
    {
        if (!_itemMetadata.TryGetValue(name, out var metadata))
            return false;

        try
        {
            if (metadata.Location == "Task Scheduler")
            {
                using var ts = new TaskService();
                var task = ts.GetTask(metadata.TaskPath);
                if (task != null)
                {
                    task.Enabled = false;
                    return true;
                }
            }
            else if (metadata.Location.StartsWith("Registry"))
            {
                var rootKey = metadata.Location.Contains("Current User") ? Registry.CurrentUser : Registry.LocalMachine;
                var approvedPath = metadata.Location.Contains("Current User") ? ApprovedKeyCU : ApprovedKeyLM;
                
                using var key = rootKey.CreateSubKey(approvedPath);
                if (key != null)
                {
                    byte[] disabledData = new byte[12] { 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
                    key.SetValue(name, disabledData, RegistryValueKind.Binary);
                    return true;
                }
            }
        }
        catch { }

        return false;
    }

    public bool DeleteItem(string name)
    {
        if (!_itemMetadata.TryGetValue(name, out var metadata))
            return false;

        try
        {
            if (metadata.Location == "Task Scheduler")
            {
                using var ts = new TaskService();
                var task = ts.GetTask(metadata.TaskPath);
                if (task != null)
                {
                    ts.RootFolder.DeleteTask(task.Name, false);
                    return true;
                }
            }
            else if (metadata.Location.StartsWith("Registry"))
            {
                var rootKey = metadata.Location.Contains("Current User") ? Registry.CurrentUser : Registry.LocalMachine;
                var runPath = metadata.Location.Contains("Current User") ? RunKeyCU : RunKeyLM;
                var approvedPath = metadata.Location.Contains("Current User") ? ApprovedKeyCU : ApprovedKeyLM;
                
                using var runKey = rootKey.OpenSubKey(runPath, true);
                runKey?.DeleteValue(name, false);
                
                using var approvedKey = rootKey.OpenSubKey(approvedPath, true);
                approvedKey?.DeleteValue(name, false);
                
                return true;
            }
            else if (metadata.Location.StartsWith("Startup Folder"))
            {
                var folderPath = metadata.Location.Contains("Current User") ? _startupFolderCU : _startupFolderLM;
                var lnkFile = Path.Combine(folderPath, name + ".lnk");
                var exeFile = Path.Combine(folderPath, name + ".exe");
                
                if (File.Exists(lnkFile))
                {
                    File.Delete(lnkFile);
                    return true;
                }
                if (File.Exists(exeFile))
                {
                    File.Delete(exeFile);
                    return true;
                }
            }
        }
        catch { }

        return false;
    }
}
