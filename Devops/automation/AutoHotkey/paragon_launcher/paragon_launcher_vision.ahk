; ============================================
; Paragon Hard Disk Manager Auto-Launcher
; VISION-POWERED VERSION - No hardcoded coordinates!
; Trigger: Type "ppppp" anywhere
; ============================================

#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%
SendMode Input
SetBatchLines -1
#InstallKeybdHook
#UseHook

; Configuration
global ParagonPath := "F:\backup\windowsapps\installed\fixers\Paragon Software\Hard Disk Manager 17 Business\program\hdm17.exe"
global MaxWaitSeconds := 30
global VisionClickPath := "C:\Users\micha\.openclaw\skills\vision-click\vision_click.py"

; Hotstring trigger - type "ppppp" to activate
:*:ppppp::
    Send {Backspace 5}
    LaunchParagonAndClickVision()
return

LaunchParagonAndClickVision() {
    ; Show tray notification
    TrayTip, Paragon Launcher, Launching Paragon Hard Disk Manager..., 2, 1
    
    ; Check if Paragon is already running
    Process, Exist, hdm17.exe
    if (ErrorLevel > 0) {
        ; Already running, just activate it
        WinActivate, ahk_exe hdm17.exe
        WinWaitActive, ahk_exe hdm17.exe, , 3
        Sleep, 500
    } else {
        ; Launch Paragon
        if !FileExist(ParagonPath) {
            TrayTip, Error, Paragon executable not found!, 5, 3
            return
        }
        
        Run, "%ParagonPath%"
        
        ; Wait for the process to start
        startTime := A_TickCount
        Loop {
            Process, Exist, hdm17.exe
            if (ErrorLevel > 0)
                break
            
            elapsed := (A_TickCount - startTime) / 1000
            if (elapsed > 10) {
                TrayTip, Error, Paragon process did not start, 3, 3
                return
            }
            Sleep, 200
        }
        
        ; Wait for window to appear
        WinWait, ahk_exe hdm17.exe, , %MaxWaitSeconds%
        if ErrorLevel {
            TrayTip, Timeout, Window did not appear, 3, 2
            return
        }
        
        WinActivate, ahk_exe hdm17.exe
        WinWaitActive, ahk_exe hdm17.exe, , 5
        
        ; Extra delay for UI to fully load
        Sleep, 3000
    }
    
    ; Use vision-click to find and click "Disks and volumes"
    TrayTip, Vision Click, Finding "Disks and volumes"..., 2, 1
    
    RunWait, python "%VisionClickPath%" click --text "Disks and volumes" --wait 1, , Hide
    
    if (ErrorLevel = 0) {
        TrayTip, Success, Clicked "Disks and volumes"!, 2, 1
    } else {
        TrayTip, Error, Could not find or click element, 3, 3
    }
}

; Hotkey to test the function directly (Ctrl+Alt+P)
^!p::
    LaunchParagonAndClickVision()
return

; Add hotkey to reload script (Ctrl+Alt+R)
^!r::
    TrayTip, Script Reloading, Paragon Launcher script reloading..., 1, 1
    Sleep, 500
    Reload
return

; Add hotkey to exit script (Ctrl+Alt+Q)
^!q::
    TrayTip, Script Exiting, Goodbye!, 1, 1
    Sleep, 500
    ExitApp
return

; Show startup notification
TrayTip, Paragon Launcher (Vision), Script loaded! Type "ppppp" or press Ctrl+Alt+P., 3, 1
