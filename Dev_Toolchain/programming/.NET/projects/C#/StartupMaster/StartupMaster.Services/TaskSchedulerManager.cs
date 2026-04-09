using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.Win32.TaskScheduler;
using StartupMaster.Models;

namespace StartupMaster.Services;

public class TaskSchedulerManager
{
	public List<StartupItem> GetItems()
	{
		List<StartupItem> list = new List<StartupItem>();
		try
		{
			using TaskService taskService = new TaskService();
			foreach (Task allTask in taskService.RootFolder.AllTasks)
			{
				try
				{
					if (allTask.Definition.Triggers.Any((Trigger t) => t is BootTrigger || t is LogonTrigger) && allTask.Definition.Actions.FirstOrDefault() is ExecAction execAction)
					{
						Trigger trigger = allTask.Definition.Triggers.FirstOrDefault((Trigger t) => t is BootTrigger || t is LogonTrigger);
						int delaySeconds = 0;
						if (trigger is BootTrigger { Delay: { TotalSeconds: >0.0 }, Delay: var delay2 })
						{
							delaySeconds = (int)delay2.TotalSeconds;
						}
						else if (trigger is LogonTrigger { Delay: { TotalSeconds: >0.0 }, Delay: var delay4 })
						{
							delaySeconds = (int)delay4.TotalSeconds;
						}
						list.Add(new StartupItem
						{
							Name = allTask.Name,
							Command = execAction.Path,
							Arguments = (execAction.Arguments ?? string.Empty),
							Location = StartupLocation.TaskScheduler,
							IsEnabled = allTask.Enabled,
							TaskName = allTask.Path,
							DelaySeconds = delaySeconds
						});
					}
				}
				catch
				{
				}
			}
		}
		catch
		{
		}
		return list;
	}

	public bool AddItem(StartupItem item)
	{
		try
		{
			using TaskService taskService = new TaskService();
			TaskDefinition taskDefinition = taskService.NewTask();
			taskDefinition.RegistrationInfo.Description = "Startup task: " + item.Name;
			LogonTrigger logonTrigger = new LogonTrigger();
			// MODIFICATION: Always force zero delay for immediate startup
			logonTrigger.Delay = TimeSpan.Zero;
			taskDefinition.Triggers.Add(logonTrigger);
			taskDefinition.Actions.Add(new ExecAction(item.Command, item.Arguments));
			taskDefinition.Settings.DisallowStartIfOnBatteries = false;
			taskDefinition.Settings.StopIfGoingOnBatteries = false;
			taskDefinition.Settings.ExecutionTimeLimit = TimeSpan.Zero;
			taskService.RootFolder.RegisterTaskDefinition(item.Name, taskDefinition, TaskCreation.CreateOrUpdate, null, null, TaskLogonType.InteractiveToken);
			item.TaskName = "\\" + item.Name;
			return true;
		}
		catch
		{
			return false;
		}
	}

	public bool RemoveItem(StartupItem item)
	{
		try
		{
			using TaskService taskService = new TaskService();
			taskService.RootFolder.DeleteTask(item.Name, exceptionOnNotExists: false);
			return true;
		}
		catch
		{
			return false;
		}
	}

	public bool DisableItem(StartupItem item)
	{
		try
		{
			using TaskService taskService = new TaskService();
			Task task = taskService.GetTask(item.TaskName);
			if (task != null)
			{
				task.Enabled = false;
				item.IsEnabled = false;
				return true;
			}
			return false;
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
			using TaskService taskService = new TaskService();
			Task task = taskService.GetTask(item.TaskName);
			if (task != null)
			{
				task.Enabled = true;
				item.IsEnabled = true;
				return true;
			}
			return false;
		}
		catch
		{
			return false;
		}
	}

	public bool UpdateDelay(StartupItem item)
	{
		try
		{
			using TaskService taskService = new TaskService();
			Task task = taskService.GetTask(item.TaskName);
			if (task == null)
			{
				return false;
			}
			Trigger trigger = task.Definition.Triggers.FirstOrDefault((Trigger t) => t is BootTrigger || t is LogonTrigger);
			if (trigger != null)
			{
				if (trigger is BootTrigger bootTrigger)
				{
					bootTrigger.Delay = TimeSpan.FromSeconds(item.DelaySeconds);
				}
				else if (trigger is LogonTrigger logonTrigger)
				{
					logonTrigger.Delay = TimeSpan.FromSeconds(item.DelaySeconds);
				}
				task.RegisterChanges();
				return true;
			}
			return false;
		}
		catch
		{
			return false;
		}
	}
}

