; ====================================================
; Paragon Hard Disk Manager - COMPLETE Automation
; ====================================================
; Type "ppppp" to run FULL automation including restart
; ⚠️ WARNING: This WILL restart your computer!
; ====================================================

#NoEnv
#SingleInstance Force
SendMode Input
SetBatchLines -1

global PythonScript := "C:\Users\micha\.openclaw\workspace-openclaw-main\paragon_complete.py"

; Hotstring: type "ppppp"
:*:ppppp::
    Send {Backspace 5}
    RunParagonComplete()
return

; Hotkey: Ctrl+Alt+P
^!p::
    RunParagonComplete()
return

RunParagonComplete() {
    TrayTip, Paragon, Starting COMPLETE automation (WILL RESTART!)..., 3, 2
    
    ; Run the complete Python script
    RunWait, python "%PythonScript%", , Hide
    
    TrayTip, Done!, Computer restarting..., 2, 1
}

; Reload: Ctrl+Alt+R
^!r::
    Reload
return

; Exit: Ctrl+Alt+Q
^!q::
    ExitApp
return

TrayTip, Paragon Launcher, Ready! Type ppppp or Ctrl+Alt+P`n⚠️ Will restart computer!, 3, 2
