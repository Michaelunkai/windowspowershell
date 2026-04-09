using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using System.Text;
using System.Diagnostics;

class Num2Test {
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int n);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool att);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool SetActiveWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool EnumWindows(EWP p, IntPtr l);
    [DllImport("user32.dll",CharSet=CharSet.Auto)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte sc, uint fl, UIntPtr ex);

    // SendInput
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint n, INPUT[] inp, int sz);
    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public KI ki; public ulong pad; }
    [StructLayout(LayoutKind.Sequential)] struct KI { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr extra; }

    delegate bool EWP(IntPtr h, IntPtr l);

    static IntPtr FindTrainer() {
        IntPtr f = IntPtr.Zero;
        EnumWindows((h,l)=>{ var s=new StringBuilder(256); GetWindowText(h,s,256); if(s.ToString().Contains("Trainer")&&IsWindowVisible(h)){f=h;return false;} return true;},IntPtr.Zero);
        return f;
    }

    static void ForceFocus(IntPtr hwnd) {
        uint myTid=GetCurrentThreadId(), xp=0;
        uint xTid=GetWindowThreadProcessId(hwnd,out xp);
        for(int i=0;i<10;i++){
            AttachThreadInput(myTid,xTid,true);
            ShowWindow(hwnd,9); BringWindowToTop(hwnd); SetForegroundWindow(hwnd); SetActiveWindow(hwnd);
            AttachThreadInput(myTid,xTid,false);
            Thread.Sleep(150);
            if(GetForegroundWindow()==hwnd) break;
            Thread.Sleep(100);
        }
        Thread.Sleep(200);
    }

    static void SendVK(byte vk) {
        keybd_event(vk,0,0,UIntPtr.Zero); Thread.Sleep(80);
        keybd_event(vk,0,2,UIntPtr.Zero); Thread.Sleep(500);
    }

    static void SendSC(byte sc) {
        keybd_event(0,sc,8,UIntPtr.Zero); Thread.Sleep(80);
        keybd_event(0,sc,8|2,UIntPtr.Zero); Thread.Sleep(500);
    }

    static void SendBoth(byte vk, byte sc) {
        keybd_event(vk,sc,8,UIntPtr.Zero); Thread.Sleep(80);
        keybd_event(vk,sc,8|2,UIntPtr.Zero); Thread.Sleep(500);
    }

    static void SendVI(byte vk, byte sc) {
        var d=new INPUT[2];
        d[0].type=1; d[0].ki.wVk=vk; d[0].ki.wScan=sc; d[0].ki.dwFlags=0;
        d[1].type=1; d[1].ki.wVk=vk; d[1].ki.wScan=sc; d[1].ki.dwFlags=2;
        SendInput(1,new INPUT[]{d[0]},System.Runtime.InteropServices.Marshal.SizeOf(typeof(INPUT)));
        Thread.Sleep(80);
        SendInput(1,new INPUT[]{d[1]},System.Runtime.InteropServices.Marshal.SizeOf(typeof(INPUT)));
        Thread.Sleep(500);
    }

    static void Main() {
        var hwnd = FindTrainer();
        if(hwnd==IntPtr.Zero){Console.WriteLine("No trainer");return;}
        Console.WriteLine("Trainer: "+hwnd);

        // Game must be running for hotkeys to work - we'll just test focus + num2 methods
        // Method 1: pure VK
        Console.WriteLine("\nMethod 1: VK only (0x62)");
        Console.Write("Press Enter to test..."); Console.ReadLine();
        ForceFocus(hwnd); SendVK(0x62);

        // Method 2: scan code only
        Console.WriteLine("Method 2: Scan code only (0x50)");
        Console.Write("Press Enter to test..."); Console.ReadLine();
        ForceFocus(hwnd); SendSC(0x50);

        // Method 3: VK + scan together with SCANCODE flag
        Console.WriteLine("Method 3: VK+SC with SCANCODE flag");
        Console.Write("Press Enter to test..."); Console.ReadLine();
        ForceFocus(hwnd); SendBoth(0x62, 0x50);

        // Method 4: SendInput VK+SC
        Console.WriteLine("Method 4: SendInput VK+SC");
        Console.Write("Press Enter to test..."); Console.ReadLine();
        ForceFocus(hwnd); SendVI(0x62, 0x50);

        Console.WriteLine("Done. Which method toggled NUM2?");
        Console.ReadLine();
    }
}
