; ====================================================
; Paragon Hard Disk Manager - FINAL WORKING VERSION
; Window-relative clicking that works on ANY monitor
; ====================================================

#NoEnv
#SingleInstance Force
SendMode Input
SetBatchLines -1
#InstallKeybdHook
#UseHook

global ParagonPath := "F:\backup\windowsapps\installed\fixers\Paragon Software\Hard Disk Manager 17 Business\program\hdm17.exe"
global PythonScript := "C:\Users\micha\.openclaw\workspace-openclaw-main\click_paragon_disk_volumes.py"

; Hotstring: type "ppppp"
:*:ppppp::
    Send {Backspace 5}
    LaunchAndClick()
return

; Hotkey: Ctrl+Alt+P
^!p::
    LaunchAndClick()
return

LaunchAndClick() {
    TrayTip, Paragon Launcher, Starting..., 1, 1
    
    ; Check if already running
    Process, Exist, hdm17.exe
    if (ErrorLevel = 0) {
        ; Not running, launch it
        if !FileExist(ParagonPath) {
            TrayTip, Error, Paragon not found!, 3, 3
            return
        }
        Run, "%ParagonPath%"
        TrayTip, Paragon Launcher, Waiting for app to load..., 3, 1
    } else {
        ; Already running, activate
        WinActivate, ahk_exe hdm17.exe
        Sleep, 500
    }
    
    ; Use Python script to do window-relative click (includes wait for load)
    RunWait, python "%PythonScript%", , Hide
    
    TrayTip, Done, Disks and volumes opened!, 2, 1
}

; Reload: Ctrl+Alt+R
^!r::
    Reload
return

; Exit: Ctrl+Alt+Q
^!q::
    ExitApp
return

TrayTip, Paragon Launcher, Ready! Type ppppp or press Ctrl+Alt+P, 2, 1
