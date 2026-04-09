using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using System.Text;

class Launcher
{
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc p, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool SetActiveWindow(IntPtr hWnd);

    delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    const byte VK_NUMPAD0 = 0x60;
    const byte VK_NUMPAD1 = 0x61;
    const byte VK_NUMPAD2 = 0x62;
    const byte VK_NUMPAD3 = 0x63;
    const byte VK_NUMPAD4 = 0x64;
    const byte VK_NUMPAD5 = 0x65;
    const byte VK_NUMPAD6 = 0x66;
    const byte VK_NUMPAD7 = 0x67;
    const byte VK_NUMPAD8 = 0x68;
    const byte VK_CONTROL = 0x11;
    const byte VK_NUMLOCK = 0x90;
    const uint KE_KEYUP   = 0x0002;
    const int  SW_MINIMIZE = 6;
    const int  SW_RESTORE  = 9;

    static uint myTid      = 0;
    static uint trainerTid = 0;
    static IntPtr trainerHwnd = IntPtr.Zero;

    static IntPtr FindWin(string c1, string c2)
    {
        IntPtr f = IntPtr.Zero;
        EnumWindows((h, l) => {
            var sb = new StringBuilder(256);
            GetWindowText(h, sb, 256);
            string t = sb.ToString();
            if (t.Contains(c1) && t.Contains(c2) && IsWindowVisible(h)) { f = h; return false; }
            return true;
        }, IntPtr.Zero);
        return f;
    }

    static IntPtr FindWinExact(string title)
    {
        IntPtr f = IntPtr.Zero;
        EnumWindows((h, l) => {
            var sb = new StringBuilder(256);
            GetWindowText(h, sb, 256);
            if (sb.ToString() == title && IsWindowVisible(h)) { f = h; return false; }
            return true;
        }, IntPtr.Zero);
        return f;
    }

    // Attach thread, focus, send key, detach — all atomic
    static void SendMod(byte vk)
    {
        AttachThreadInput(myTid, trainerTid, true);
        ShowWindow(trainerHwnd, SW_RESTORE);
        BringWindowToTop(trainerHwnd);
        SetForegroundWindow(trainerHwnd);
        SetActiveWindow(trainerHwnd);
        Thread.Sleep(200);  // settle while still attached
        keybd_event(vk, 0, 0, UIntPtr.Zero);
        Thread.Sleep(100);
        keybd_event(vk, 0, KE_KEYUP, UIntPtr.Zero);
        Thread.Sleep(200);  // key processed while still attached
        AttachThreadInput(myTid, trainerTid, false);
        Thread.Sleep(300);
    }

    static void SendCtrlMod(byte vk)
    {
        AttachThreadInput(myTid, trainerTid, true);
        ShowWindow(trainerHwnd, SW_RESTORE);
        BringWindowToTop(trainerHwnd);
        SetForegroundWindow(trainerHwnd);
        SetActiveWindow(trainerHwnd);
        Thread.Sleep(200);
        keybd_event(VK_CONTROL, 0, KE_KEYUP, UIntPtr.Zero); // release stuck ctrl
        Thread.Sleep(60);
        keybd_event(VK_CONTROL, 0, 0, UIntPtr.Zero);
        Thread.Sleep(80);
        keybd_event(vk, 0, 0, UIntPtr.Zero);
        Thread.Sleep(100);
        keybd_event(vk, 0, KE_KEYUP, UIntPtr.Zero);
        Thread.Sleep(80);
        keybd_event(VK_CONTROL, 0, KE_KEYUP, UIntPtr.Zero);
        Thread.Sleep(200);
        AttachThreadInput(myTid, trainerTid, false);
        Thread.Sleep(300);
    }

    static void Main()
    {
        string trainerPath = @"E:\games\The Witcher 3- Wild Hunt\Witcher3_FLiNG_Trainer_v4.04.exe";
        string gamePath    = @"E:\games\The Witcher 3- Wild Hunt\bin\x64\witcher3.exe";

        myTid = GetCurrentThreadId();

        foreach (var n in new[] { "Witcher3_FLiNG_Trainer_v4.04", "witcher3" })
            foreach (var p in Process.GetProcessesByName(n))
                try { p.Kill(); p.WaitForExit(2000); } catch { }
        Thread.Sleep(1000);

        Process.Start(new ProcessStartInfo(trainerPath) { WorkingDirectory = System.IO.Path.GetDirectoryName(trainerPath) });

        for (int i = 0; i < 30; i++) { Thread.Sleep(500); trainerHwnd = FindWin("Witcher 3", "Trainer"); if (trainerHwnd != IntPtr.Zero) break; }
        if (trainerHwnd == IntPtr.Zero) { Console.WriteLine("Trainer not found!"); return; }

        uint xpid = 0;
        trainerTid = GetWindowThreadProcessId(trainerHwnd, out xpid);

        Process.Start(new ProcessStartInfo(gamePath) { WorkingDirectory = System.IO.Path.GetDirectoryName(gamePath) });

        Console.WriteLine("Waiting for game window...");
        IntPtr gameHwnd = IntPtr.Zero;
        for (int i = 0; i < 120; i++) { Thread.Sleep(1000); gameHwnd = FindWinExact("The Witcher 3"); if (gameHwnd != IntPtr.Zero) break; }
        if (gameHwnd == IntPtr.Zero) { Console.WriteLine("Game not found!"); return; }

        Console.WriteLine("Waiting 15s for trainer to hook game...");
        Thread.Sleep(15000);

        ShowWindow(gameHwnd, SW_MINIMIZE);
        Thread.Sleep(1500);

        if (!Control.IsKeyLocked(Keys.NumLock))
        {
            keybd_event(VK_NUMLOCK, 0, 0, UIntPtr.Zero);
            Thread.Sleep(60);
            keybd_event(VK_NUMLOCK, 0, KE_KEYUP, UIntPtr.Zero);
            Thread.Sleep(150);
        }

        Console.WriteLine("Activating all mods...");

        SendMod(VK_NUMPAD1);          // Infinite Health
        SendMod(VK_NUMPAD2);          // Infinite Stamina
        SendMod(VK_NUMPAD3);          // Infinite Adrenaline
        SendMod(VK_NUMPAD4);          // Zero Toxicity
        SendMod(VK_NUMPAD5);          // Infinite Oxygen
        SendMod(VK_NUMPAD6);          // Infinite Horse Stamina
        SendMod(VK_NUMPAD7);          // Minimize Horse Fear Level
        SendMod(VK_NUMPAD8);          // Drain Enemies Stamina
        SendMod(VK_NUMPAD0);          // One Hit Kill
        SendCtrlMod(VK_NUMPAD5);      // Infinite Equipment Durability
        SendCtrlMod(VK_NUMPAD6);      // Zero Weight
        SendCtrlMod(VK_NUMPAD7);      // Infinite Potions & Bombs

        Console.WriteLine("All 12 mods ON. Restoring game...");
        Thread.Sleep(500);
        ShowWindow(gameHwnd, SW_RESTORE);
        SetForegroundWindow(gameHwnd);
        Console.WriteLine("Done.");
        Thread.Sleep(1000);
    }
}
