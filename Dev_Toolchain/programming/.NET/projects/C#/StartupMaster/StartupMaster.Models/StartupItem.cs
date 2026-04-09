using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace StartupMaster.Models;

public class StartupItem : INotifyPropertyChanged
{
	private bool _isEnabled;

	private int _delaySeconds;

	private string _name;

	private string _command;

	private string _arguments;

	public string Name
	{
		get
		{
			return _name;
		}
		set
		{
			_name = value;
			OnPropertyChanged("Name");
		}
	}

	public string Command
	{
		get
		{
			return _command;
		}
		set
		{
			_command = value;
			OnPropertyChanged("Command");
		}
	}

	public string Arguments
	{
		get
		{
			return _arguments;
		}
		set
		{
			_arguments = value;
			OnPropertyChanged("Arguments");
		}
	}

	public StartupLocation Location { get; set; }

	public bool IsEnabled
	{
		get
		{
			return _isEnabled;
		}
		set
		{
			_isEnabled = value;
			OnPropertyChanged("IsEnabled");
		}
	}

	public int DelaySeconds
	{
		get
		{
			return _delaySeconds;
		}
		set
		{
			_delaySeconds = value;
			OnPropertyChanged("DelaySeconds");
		}
	}

	public string RegistryKey { get; set; }

	public string RegistryValueName { get; set; }

	public string FilePath { get; set; }

	public string TaskName { get; set; }

	public string ServiceName { get; set; }

	public bool IsCritical { get; set; }

	public string CriticalReason { get; set; }

	public bool IsDangerous { get; set; }

	public string DangerReason { get; set; }

	public string Publisher { get; set; }

	public double EstimatedImpactSeconds { get; set; }

	public string ImpactDisplay
	{
		get
		{
			if (!(EstimatedImpactSeconds > 0.0))
			{
				return "< 0.5s";
			}
			return $"~{EstimatedImpactSeconds:F1}s";
		}
	}

	public string LocationDisplay => Location switch
	{
		StartupLocation.RegistryCurrentUser => "Registry (User)", 
		StartupLocation.RegistryLocalMachine => "Registry (Machine)", 
		StartupLocation.StartupFolder => "Startup Folder", 
		StartupLocation.TaskScheduler => "Task Scheduler", 
		StartupLocation.Service => "Service", 
		_ => "Unknown", 
	};

	public string StatusDisplay
	{
		get
		{
			if (!IsCritical)
			{
				if (!IsEnabled)
				{
					return "✗ Disabled";
				}
				return "✓ Enabled";
			}
			return "\ud83d\udd12 Critical";
		}
	}

	public event PropertyChangedEventHandler PropertyChanged;

	protected void OnPropertyChanged([CallerMemberName] string name = null)
	{
		this.PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
	}
}

