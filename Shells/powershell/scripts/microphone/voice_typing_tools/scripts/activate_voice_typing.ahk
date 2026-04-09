SetTitleMatchMode 2
if !WinExist("Notepad") {
    Run "notepad.exe"
    WinWait "Notepad",, 10
}
WinActivate "Notepad"
WinWaitActive "Notepad",, 5
Sleep 1000
WinGetPos &X, &Y, &W, &H, "Notepad"
Click X + (W // 2), Y + (H // 2)
Sleep 500
Send "#h"
Sleep 3000
