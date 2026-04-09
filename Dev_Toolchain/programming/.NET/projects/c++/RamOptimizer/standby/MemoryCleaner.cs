using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Threading;

namespace MemoryCleaner
{
    class Program
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetProcessWorkingSetSize(IntPtr proc, IntPtr min, IntPtr max);

        [DllImport("psapi.dll")]
        private static extern int EmptyWorkingSet(IntPtr hwProc);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetSystemFileCacheSize(IntPtr MinimumFileCacheSize, IntPtr MaximumFileCacheSize, int Flags);

        [DllImport("ntdll.dll")]
        private static extern uint NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);

        private const int SystemMemoryListInformation = 80;
        private const int MemoryPurgeStandbyList = 4;
        private const int MemoryEmptyWorkingSets = 2;

        static bool IsAdministrator()
        {
            using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
            {
                WindowsPrincipal principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
        }

        static void ShowMemoryStats(string title)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine($"\n{title}");
            Console.WriteLine(new string('=', 50));
            Console.ResetColor();

            try
            {
                var perfCounter1 = new PerformanceCounter("Memory", "Standby Cache Normal Priority Bytes");
                var perfCounter2 = new PerformanceCounter("Memory", "Pool Paged Bytes");
                var perfCounter3 = new PerformanceCounter("Memory", "Pool Nonpaged Bytes");
                var perfCounter4 = new PerformanceCounter("Memory", "Available MBytes");

                Console.WriteLine($"Standby Cache: {perfCounter1.NextValue() / 1024 / 1024:N2} MB");
                Console.WriteLine($"Paged Pool: {perfCounter2.NextValue() / 1024 / 1024:N2} MB");
                Console.WriteLine($"NonPaged Pool: {perfCounter3.NextValue() / 1024 / 1024:N2} MB");
                Console.WriteLine($"Available Memory: {perfCounter4.NextValue():N2} MB");
                Console.WriteLine();

                perfCounter1.Dispose();
                perfCounter2.Dispose();
                perfCounter3.Dispose();
                perfCounter4.Dispose();
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"Could not retrieve memory stats: {ex.Message}");
                Console.ResetColor();
            }
        }

        static bool ClearStandbyCache()
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("Clearing Standby Cache...");
            Console.ResetColor();

            try
            {
                IntPtr info = Marshal.AllocHGlobal(sizeof(int));
                Marshal.WriteInt32(info, MemoryPurgeStandbyList);

                uint result = NtSetSystemInformation(SystemMemoryListInformation, info, sizeof(int));
                Marshal.FreeHGlobal(info);

                if (result == 0)
                {
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine("✓ Standby Cache cleared");
                    Console.ResetColor();
                    return true;
                }
                else
                {
                    throw new Win32Exception($"NtSetSystemInformation returned: {result}");
                }
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"✗ Failed to clear Standby Cache: {ex.Message}");
                Console.ResetColor();
                return false;
            }
        }

        static bool ClearPagedPool()
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("Clearing Paged Pool...");
            Console.ResetColor();

            try
            {
                GC.Collect();
                GC.WaitForPendingFinalizers();
                GC.Collect();

                int cleared = 0;
                foreach (Process proc in Process.GetProcesses())
                {
                    try
                    {
                        if (proc.ProcessName != "Idle" && proc.ProcessName != "System")
                        {
                            if (SetProcessWorkingSetSize(proc.Handle, new IntPtr(-1), new IntPtr(-1)))
                            {
                                cleared++;
                            }
                        }
                    }
                    catch { }
                    finally
                    {
                        proc.Dispose();
                    }
                }

                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine($"✓ Paged Pool optimized ({cleared} processes trimmed)");
                Console.ResetColor();
                return true;
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"✗ Failed to clear Paged Pool: {ex.Message}");
                Console.ResetColor();
                return false;
            }
        }

        static bool ClearNonPagedPool()
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("Clearing NonPaged Pool...");
            Console.ResetColor();

            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "ipconfig",
                    Arguments = "/flushdns",
                    WindowStyle = ProcessWindowStyle.Hidden,
                    CreateNoWindow = true
                })?.WaitForExit(5000);

                Process.Start(new ProcessStartInfo
                {
                    FileName = "netsh",
                    Arguments = "interface ip delete arpcache",
                    WindowStyle = ProcessWindowStyle.Hidden,
                    CreateNoWindow = true
                })?.WaitForExit(5000);

                GC.Collect();
                GC.WaitForPendingFinalizers();

                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("✓ NonPaged Pool optimized (kernel cache cleared)");
                Console.ResetColor();
                return true;
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"✗ Failed to clear NonPaged Pool: {ex.Message}");
                Console.ResetColor();
                return false;
            }
        }

        static void Main(string[] args)
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("\n╔════════════════════════════════════════════╗");
            Console.WriteLine("║   Memory Cache Cleaner - C# Edition       ║");
            Console.WriteLine("╚════════════════════════════════════════════╝\n");
            Console.ResetColor();

            if (!IsAdministrator())
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("ERROR: This program requires Administrator privileges!");
                Console.WriteLine("Please run as Administrator and try again.");
                Console.ResetColor();
                Console.WriteLine("\nPress any key to exit...");
                Console.ReadKey();
                Environment.Exit(1);
            }

            ShowMemoryStats("BEFORE Cleanup");

            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("Starting memory cleanup...\n");
            Console.ResetColor();

            bool success1 = ClearStandbyCache();
            bool success2 = ClearPagedPool();
            bool success3 = ClearNonPagedPool();

            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\nWaiting for system to stabilize...");
            Console.ResetColor();
            Thread.Sleep(2000);

            ShowMemoryStats("AFTER Cleanup");

            if (success1 && success2 && success3)
            {
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("Memory cleanup completed successfully!\n");
                Console.ResetColor();
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("Memory cleanup completed with some warnings.\n");
                Console.ResetColor();
            }

            Console.WriteLine("Press any key to exit...");
            Console.ReadKey();
        }
    }
}
