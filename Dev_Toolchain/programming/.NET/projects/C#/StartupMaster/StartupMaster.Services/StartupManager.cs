using System.Collections.Generic;
using System.Linq;
using StartupMaster.Models;

namespace StartupMaster.Services;

public class StartupManager
{
	private readonly RegistryStartupManager _registryManager = new RegistryStartupManager();

	private readonly StartupFolderManager _folderManager = new StartupFolderManager();

	private readonly TaskSchedulerManager _taskManager = new TaskSchedulerManager();

	private readonly ServicesManager _servicesManager = new ServicesManager();

	public List<StartupItem> GetAllItems()
	{
		List<StartupItem> list = new List<StartupItem>();
		list.AddRange(_registryManager.GetItems());
		list.AddRange(_folderManager.GetItems());
		list.AddRange(_taskManager.GetItems());
		list.AddRange(_servicesManager.GetItems());
		CriticalItemsService.EvaluateAll(list);
		List<StartupItem> list2 = list.Where((StartupItem i) => !i.IsCritical).ToList();
		BootImpactEstimator.EstimateAll(list2);
		return list2.OrderByDescending((StartupItem i) => i.EstimatedImpactSeconds).ToList();
	}

	public bool AddItem(StartupItem item)
	{
		return item.Location switch
		{
			StartupLocation.RegistryCurrentUser => _registryManager.AddItem(item), 
			StartupLocation.RegistryLocalMachine => _registryManager.AddItem(item), 
			StartupLocation.StartupFolder => _folderManager.AddItem(item), 
			StartupLocation.TaskScheduler => _taskManager.AddItem(item), 
			_ => false, 
		};
	}

	public bool RemoveItem(StartupItem item)
	{
		return item.Location switch
		{
			StartupLocation.RegistryCurrentUser => _registryManager.RemoveItem(item), 
			StartupLocation.RegistryLocalMachine => _registryManager.RemoveItem(item), 
			StartupLocation.StartupFolder => _folderManager.RemoveItem(item), 
			StartupLocation.TaskScheduler => _taskManager.RemoveItem(item), 
			_ => false, 
		};
	}

	public bool DisableItem(StartupItem item)
	{
		return item.Location switch
		{
			StartupLocation.RegistryCurrentUser => _registryManager.DisableItem(item), 
			StartupLocation.RegistryLocalMachine => _registryManager.DisableItem(item), 
			StartupLocation.StartupFolder => _folderManager.DisableItem(item), 
			StartupLocation.TaskScheduler => _taskManager.DisableItem(item), 
			StartupLocation.Service => _servicesManager.DisableItem(item), 
			_ => false, 
		};
	}

	public bool EnableItem(StartupItem item)
	{
		return item.Location switch
		{
			StartupLocation.RegistryCurrentUser => _registryManager.EnableItem(item), 
			StartupLocation.RegistryLocalMachine => _registryManager.EnableItem(item), 
			StartupLocation.StartupFolder => _folderManager.EnableItem(item), 
			StartupLocation.TaskScheduler => _taskManager.EnableItem(item), 
			StartupLocation.Service => _servicesManager.EnableItem(item), 
			_ => false, 
		};
	}

	public bool UpdateDelay(StartupItem item)
	{
		if (item.Location == StartupLocation.TaskScheduler)
		{
			return _taskManager.UpdateDelay(item);
		}
		return false;
	}
}

