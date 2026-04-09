📌 🔥 System Cleanup Tool – Advanced System Cache & Junk Cleaner (GUI + CLI)

A powerful Windows system cleanup utility that automatically scans and removes unwanted temporary files, cache, thumbnails, browser data, pip cache, and more.

Built with Python + Tkinter GUI + CLI Support, this tool makes your PC faster, lighter, and cleaner with a single click.

- ✔ Tkinter GUI  
- ✔ CLI Mode  
- ✔ Fast System Scan  
- ✔ Safe Cleanup Engine  
- ✔ Cache/Temp/Pip/Browser Cleanup  
- ✔ Human-Readable Size  
- ✔ Multi-threaded Scan  
- ✔ Zero Risk (System-Protected Folder Blocking)  

---

# 📸 Screenshots

### ⭐ GUI Home Screen  
![App Screenshot](https://github.com/nirajj87/advanced-system-cache-junk-cleaner/raw/main/screenshot.png)


---

### ⭐ After Scan (Detailed Report)  

---


---

# 🚀 Features

### ✔ **Deep System Scan**
Scans all the major safe-to-clean directories:

- System temp  
- User temp  
- Browser cache (Chrome / Firefox)  
- Pip cache  
- Windows thumbnails  
- Recycle bin  
- AppData caches  

---

### ✔ **1-Click Cleanup**
Safely removes:

- Temporary files  
- Cache folders  
- Browser leftover data  
- Thumbnail caches  
- Old pip build cache  
- Recycle bin contents  

---

### ✔ **Safe Engine (No System-Damage Risk)**  
Your tool **never touches**:

❌ System32  
❌ Program Files  
❌ Windows core folders  
❌ Registry  
❌ App configurations  
❌ Drivers  

It only cleans **user-owned cache & temp**.

---

# 📦 Installation

### 1️⃣ Clone Repo
```bash
git clone https://github.com/yourname/system_cleanup_tool.git
cd system_cleanup_tool

2️⃣ Install Requirements
pip install -r requirements.txt


Your requirements.txt:

psutil
humanize
colorama
watchdog
tk

🖥️ Usage
▶ GUI Mode
python main.py --gui

▶ Scan Only (CLI)
python main.py --scan

▶ Cleanup (CLI)
python main.py --clean

📁 Project Structure
system_cleanup_tool/
│── main.py
│── gui.py
│── engine.py
│── utils.py
│── config.json
│── assets/
│     ├── gui_start.png
│     ├── gui_scan.png
│     └── demo.gif
│── requirements.txt
│── README.md

🧠 How It Works
1. GUI/CLI calls → Engine
2. Engine scans using safe-list paths
3. Size is calculated using humanize
4. Cleanup removes only allowed files
5. Nothing harmful is touched
🔒 Security
✔ Read-Only Scan
✔ Delete only user temp + cache
✔ No admin required
✔ System folders ignored
✔ No registry access
✔ No external network calls

This tool is 100% safe for production PCs.

🛠 Future Upgrades

Auto scheduler

Background real-time cleanup

GPU + RAM monitoring

Browser history cleanup

Cross-platform packaging (EXE build)

❤️ Contribute

Pull requests are welcome!

⭐ Leave a Star

If you like this tool, give it a ⭐ on GitHub!
