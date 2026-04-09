# 🔨 COMPILATION INSTRUCTIONS

## ⚠️ IMPORTANT: You need to recompile to get multi-target support!

The source code has been updated for v2.0, but the `.exe` files are still the old v1.0 version.

## 🚀 Quick Compile (Easiest Method)

### Option 1: Use the batch file
1. Open Windows Explorer
2. Navigate to: `F:\study\Dev_Toolchain\programming\.net\projects\c++\KillServices`
3. **Double-click `compile.bat`**
4. Wait for it to finish
5. Done!

### Option 2: Manual Command Prompt
```batch
cd F:\study\Dev_Toolchain\programming\.net\projects\c++\KillServices

F:\DevKit\compilers\mingw64\bin\g++.exe -O3 -std=c++11 -o service_killer.exe service_killer.cpp -ladvapi32 -lntdll -static-libgcc -static-libstdc++

F:\DevKit\compilers\mingw64\bin\g++.exe -O3 -std=c++11 -o ultimate_killer.exe ultimate_killer.cpp -ladvapi32 -lntdll -static-libgcc -static-libstdc++

F:\DevKit\compilers\mingw64\bin\g++.exe -O3 -std=c++11 -o nuclear.exe nuclear.cpp -ladvapi32 -lntdll -static-libgcc -static-libstdc++
```

### Option 3: PowerShell
```powershell
cd "F:\study\Dev_Toolchain\programming\.net\projects\c++\KillServices"

& "F:\DevKit\compilers\mingw64\bin\g++.exe" -O3 -std=c++11 -o service_killer.exe service_killer.cpp -ladvapi32 -lntdll -static-libgcc -static-libstdc++

& "F:\DevKit\compilers\mingw64\bin\g++.exe" -O3 -std=c++11 -o ultimate_killer.exe ultimate_killer.cpp -ladvapi32 -lntdll -static-libgcc -static-libstdc++

& "F:\DevKit\compilers\mingw64\bin\g++.exe" -O3 -std=c++11 -o nuclear.exe nuclear.cpp -ladvapi32 -lntdll -static-libgcc -static-libstdc++
```

## ✅ Verify Compilation Worked

After compiling, test with multiple targets:

```batch
.\service_killer.exe notepad chrome
```

**You should see:**
```
[TARGET] Service: notepad
[KILLED] Process PID: xxxx
[TARGET] Service: chrome
[KILLED] Process PID: yyyy
[KILLED] Process PID: zzzz
...
[COMPLETE] Total processes killed: 15
```

**If you only see ONE target being killed**, the compilation didn't work - try again!

## 🔍 What Changed in the Code

The key change in `service_killer.cpp` main():

**OLD (v1.0):**
```cpp
int main(int argc, char* argv[]) {
    std::string serviceName = argv[1];
    ForceKillService(serviceName, killedPids);
    // Only processes first argument!
}
```

**NEW (v2.0):**
```cpp
int main(int argc, char* argv[]) {
    // Process all services/processes passed as arguments
    for (int i = 1; i < argc; i++) {
        std::string serviceName = argv[i];
        ForceKillService(serviceName, killedPids);
    }
    // Loops through ALL arguments!
}
```

## 🐛 Troubleshooting

### "g++ is not recognized"
Make sure the path is correct:
```batch
F:\DevKit\compilers\mingw64\bin\g++.exe --version
```

Should show GCC version info.

### Compilation takes forever
- This is normal for first compile (creating static binary)
- Can take 30-60 seconds
- Be patient!

### "Permission denied" / "Access is denied"
- Close the executable if it's running
- Run Command Prompt as Administrator
- Try again

### Still not working?
Check if the source files have the loop:
```batch
findstr /C:"for (int i = 1; i < argc; i++)" service_killer.cpp
```

Should find the line. If not, the file wasn't updated properly.

## 📋 Files That Need Compiling

- ✅ `service_killer.cpp` → `service_killer.exe` (MAIN ONE)
- ✅ `ultimate_killer.cpp` → `ultimate_killer.exe`
- ✅ `nuclear.cpp` → `nuclear.exe`

## 🎯 After Successful Compilation

Test immediately:
```batch
# Start some test processes
start notepad
start notepad

# Kill them both with one command
.\service_killer.exe notepad

# Should see: [COMPLETE] Total processes killed: 2 (or more)
```

Then try with real targets:
```batch
.\service_killer.exe chrome Todoist docker node
```

Should kill ALL of them in one go!

---

**Once compilation works, you'll have the full multi-target power! 🚀**
