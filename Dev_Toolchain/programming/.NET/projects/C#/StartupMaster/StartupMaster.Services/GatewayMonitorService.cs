using System;
using System.Diagnostics;
using System.IO;
using System.Management;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;

namespace StartupMaster.Services;

public class GatewayMonitorService : IDisposable
{
	private const int GATEWAY_PORT = 18789;

	private readonly string _nodePath;
	private readonly string _openclawScript;
	private readonly string _workingDirectory;
	private readonly string _agentsDirectory;

	private Process? _gatewayProcess;
	private CancellationTokenSource? _cancellationTokenSource;
	private Task? _monitorTask;
	private bool _disposed;

	private string _lastStatus = "";

	public bool IsRunning { get; private set; }

	public event EventHandler<string>? StatusChanged;
	public event EventHandler<Exception>? ErrorOccurred;

	public GatewayMonitorService()
	{
		_nodePath = FindNodeExecutable();

		string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
		string distScript = Path.Combine(appData, "npm", "node_modules", "openclaw", "dist", "index.js");
		string mjsScript = Path.Combine(appData, "npm", "node_modules", "openclaw", "openclaw.mjs");
		_openclawScript = File.Exists(distScript) ? distScript : mjsScript;

		string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
		_workingDirectory = Path.Combine(userProfile, ".openclaw");
		_agentsDirectory = Path.Combine(_workingDirectory, "agents");
		if (!Directory.Exists(_workingDirectory))
			_workingDirectory = userProfile;
	}

	private static string FindNodeExecutable()
	{
		string[] candidates = new[]
		{
			Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "nodejs", "node.exe"),
			Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "nodejs", "node.exe"),
		};
		foreach (string path in candidates)
		{
			if (File.Exists(path))
				return path;
		}
		return "node";
	}

	public void Start()
	{
		if (!IsRunning)
		{
			_cancellationTokenSource = new CancellationTokenSource();
			_monitorTask = Task.Run(() => MonitorGatewayAsync(_cancellationTokenSource.Token));
			IsRunning = true;
		}
	}

	public void Stop()
	{
		if (IsRunning)
		{
			IsRunning = false;
			_cancellationTokenSource?.Cancel();
			try { _monitorTask?.Wait(TimeSpan.FromSeconds(5)); } catch { }
		}
	}

	private async Task MonitorGatewayAsync(CancellationToken ct)
	{
		// Step 0: Clean stale session lock files from previous boot
		// These block agents from starting after unclean shutdown/reboot
		CleanStaleLockFiles();

		// Step 1: Check if gateway is ALREADY running (from gateway.cmd or previous instance)
		if (IsPortListening())
		{
			SetStatus("Gateway running");
		}
		else
		{
			SetStatus("Starting gateway...");
			StartGatewayProcess();
		}

		// Wait for gateway + all 4 agents to fully initialize (45s for multi-agent)
		await SafeDelay(45000, ct);

		// Step 2: Health monitoring loop
		while (!ct.IsCancellationRequested)
		{
			try
			{
				if (IsGatewayAlive())
				{
					SetStatus("Gateway running");
					// All good - check again in 60 seconds
					await SafeDelay(60000, ct);
				}
				else
				{
					// Port not listening - quick recheck after 10s to confirm
					await SafeDelay(10000, ct);

					if (!IsGatewayAlive())
					{
						// Confirmed dead - clean locks and restart
						CleanStaleLockFiles();
						SetStatus("Restarting gateway...");
						StartGatewayProcess();
						await SafeDelay(45000, ct);
					}
				}
			}
			catch (OperationCanceledException) { break; }
			catch (Exception ex)
			{
				RaiseError(ex);
				await SafeDelay(30000, ct);
			}
		}
	}

	/// <summary>
	/// Remove stale .lock files from all agent session directories.
	/// After reboot, these persist on disk while in-memory lock registry is empty,
	/// causing agents to hang in "bootstrapping" state forever.
	/// </summary>
	private void CleanStaleLockFiles()
	{
		try
		{
			if (!Directory.Exists(_agentsDirectory))
				return;

			foreach (string agentDir in Directory.GetDirectories(_agentsDirectory))
			{
				string sessionsDir = Path.Combine(agentDir, "sessions");
				if (!Directory.Exists(sessionsDir))
					continue;

				foreach (string lockFile in Directory.GetFiles(sessionsDir, "*.lock"))
				{
					try
					{
						File.Delete(lockFile);
					}
					catch { }
				}
			}
		}
		catch { }
	}

	private void StartGatewayProcess()
	{
		try
		{
			// Double-check port isn't already in use (prevent duplicate gateway)
			if (IsPortListening())
			{
				SetStatus("Gateway already running on port " + GATEWAY_PORT);
				return;
			}

			var startInfo = new ProcessStartInfo
			{
				FileName = _nodePath,
				// --max-old-space-size=4096: prevent OOM after days/weeks of running
				// --disable-warning: suppress ExperimentalWarning noise
				// --force: kill stale lock holder if same PID gets reused after reboot
				Arguments = $"--max-old-space-size=4096 --disable-warning=ExperimentalWarning \"{_openclawScript}\" gateway --port {GATEWAY_PORT} --force",
				WorkingDirectory = _workingDirectory,
				UseShellExecute = false,
				CreateNoWindow = true,
				RedirectStandardOutput = false,
				RedirectStandardError = false,
				RedirectStandardInput = false,
			};

			// Set env vars matching gateway.cmd
			startInfo.EnvironmentVariables["OPENCLAW_GATEWAY_PORT"] = GATEWAY_PORT.ToString();
			startInfo.EnvironmentVariables["OPENCLAW_GATEWAY_TOKEN"] = "moltbot-local-token-2026";
			startInfo.EnvironmentVariables["OPENCLAW_SERVICE_MARKER"] = "openclaw";
			startInfo.EnvironmentVariables["OPENCLAW_SERVICE_KIND"] = "gateway";
			startInfo.EnvironmentVariables["OPENCLAW_SERVICE_VERSION"] = "2026.2.17";

			_gatewayProcess = new Process { StartInfo = startInfo };
			_gatewayProcess.Start();

			SetStatus("Gateway started (PID " + _gatewayProcess.Id + ")");
		}
		catch (Exception ex)
		{
			RaiseError(ex);
			SetStatus("Failed to start: " + ex.Message);
		}
	}

	/// <summary>
	/// Fast check: port first, then tracked process.
	/// </summary>
	private bool IsGatewayAlive()
	{
		// Fastest: check if port 18789 is listening
		if (IsPortListening())
			return true;

		// Fast: check our tracked process
		try
		{
			if (_gatewayProcess != null && !_gatewayProcess.HasExited)
				return true;
		}
		catch { }

		return false;
	}

	/// <summary>
	/// Instant port check - no WMI, works during boot, no false positives.
	/// </summary>
	private static bool IsPortListening()
	{
		try
		{
			using var client = new TcpClient();
			var result = client.BeginConnect(IPAddress.Loopback, GATEWAY_PORT, null, null);
			bool connected = result.AsyncWaitHandle.WaitOne(TimeSpan.FromMilliseconds(500));
			if (connected)
			{
				client.EndConnect(result);
				return true;
			}
		}
		catch { }
		return false;
	}

	private void SetStatus(string status)
	{
		if (status != _lastStatus)
		{
			_lastStatus = status;
			StatusChanged?.Invoke(this, status);
		}
	}

	private void RaiseError(Exception ex)
	{
		ErrorOccurred?.Invoke(this, ex);
	}

	private static async Task SafeDelay(int ms, CancellationToken ct)
	{
		try { await Task.Delay(ms, ct); }
		catch (OperationCanceledException) { }
	}

	public void Dispose()
	{
		if (!_disposed)
		{
			_disposed = true;
			Stop();
			try { _cancellationTokenSource?.Dispose(); } catch { }
			// DO NOT kill gateway - leave it running
		}
	}
}
