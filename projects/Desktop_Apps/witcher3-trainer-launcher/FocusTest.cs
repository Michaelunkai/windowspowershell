using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Text;

class FocusTest {
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int n);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool att);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool EnumWindows(EWP p, IntPtr l);
    [DllImport("user32.dll",CharSet=CharSet.Auto)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte sc, uint fl, UIntPtr ex);
    delegate bool EWP(IntPtr h, IntPtr l);

    static IntPtr FindTrainer() {
        IntPtr f = IntPtr.Zero;
        EnumWindows((h,l)=>{ var s=new StringBuilder(256); GetWindowText(h,s,256); if(s.ToString().Contains("Trainer")&&IsWindowVisible(h)){f=h;return false;} return true; }, IntPtr.Zero);
        return f;
    }

    static bool ForceFocus(IntPtr hwnd) {
        uint myTid = GetCurrentThreadId();
        uint xpid = 0;
        uint xTid = GetWindowThreadProcessId(hwnd, out xpid);
        AttachThreadInput(myTid, xTid, true);
        ShowWindow(hwnd, 9);
        BringWindowToTop(hwnd);
        SetForegroundWindow(hwnd);
        AttachThreadInput(myTid, xTid, false);
        Thread.Sleep(200);
        return GetForegroundWindow() == hwnd;
    }

    static void Main() {
        var p = Process.Start(new ProcessStartInfo(@"E:\games\The Witcher 3- Wild Hunt\Witcher3_FLiNG_Trainer_v4.04.exe") { WorkingDirectory = @"E:\games\The Witcher 3- Wild Hunt" });
        IntPtr hwnd = IntPtr.Zero;
        for(int i=0;i<20;i++){Thread.Sleep(500);hwnd=FindTrainer();if(hwnd!=IntPtr.Zero)break;}
        if(hwnd==IntPtr.Zero){Console.WriteLine("NOT FOUND");return;}
        bool ok = ForceFocus(hwnd);
        Console.WriteLine("ForceFocus result: " + ok);
        Console.WriteLine("Foreground: " + GetForegroundWindow() + " Trainer: " + hwnd);
        // Send NUM1
        keybd_event(0x61,0,0,UIntPtr.Zero); Thread.Sleep(50); keybd_event(0x61,0,2,UIntPtr.Zero);
        Thread.Sleep(1000);
        Console.WriteLine("Done - check if NUM1 toggled in trainer");
        Console.ReadLine();
    }
}
