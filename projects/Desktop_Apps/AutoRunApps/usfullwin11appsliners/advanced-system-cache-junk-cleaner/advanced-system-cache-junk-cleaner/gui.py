import os
import tkinter as tk
from tkinter import ttk, messagebox
import threading
from engine import CleanupEngine


class CleanupGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("System Cleanup Tool")
        self.root.geometry("750x550")

        self.engine = CleanupEngine()

        ttk.Label(
            root,
            text="🧹 System Cleanup Tool (GUI)",
            font=("Segoe UI", 16, "bold")
        ).pack(pady=10)

        # Buttons
        btn_frame = ttk.Frame(root)
        btn_frame.pack(pady=10)

        ttk.Button(btn_frame, text="Scan System", width=20, command=self.run_scan)\
            .grid(row=0, column=0, padx=10)

        ttk.Button(btn_frame, text="Clean System", width=20, command=self.run_cleanup)\
            .grid(row=0, column=1, padx=10)

        # Output box
        self.output_box = tk.Text(root, height=22, width=90, wrap="word")
        self.output_box.pack(pady=10)

    def log(self, msg):
        self.output_box.insert(tk.END, msg + "\n")
        self.output_box.see(tk.END)

    # ----------------------------------------------------------
    # SCAN
    # ----------------------------------------------------------
    def run_scan(self):
        self.output_box.delete(1.0, tk.END)
        self.log("🔍 Scanning system... Please wait...")

        threading.Thread(target=self._scan_thread, daemon=True).start()

    def _scan_thread(self):
        result = self.engine.scan()
        self.log("\n==== Cleanup Scan Report ====\n")

        for category, data in result.items():
            if category == "TOTAL CLEANABLE":
                self.log(f"\n{category}: {data}")
                continue

            self.log(f"\n{category}:")
            for path, size in data.items():
                self.log(f"  - {path} → {size}")

    # ----------------------------------------------------------
    # CLEAN
    # ----------------------------------------------------------
    def run_cleanup(self):
        self.output_box.delete(1.0, tk.END)
        self.log("🧽 Cleaning system... Please wait...")

        threading.Thread(target=self._cleanup_thread, daemon=True).start()

    def _cleanup_thread(self):
        result = self.engine.cleanup_execute()

        self.log("\n==== Cleanup Results ====\n")
        for category, size in result.items():
            self.log(f"{category}: {size}")

        self.log("\n✔ Cleanup Completed!")


def launch_gui():
    root = tk.Tk()
    CleanupGUI(root)
    root.mainloop()
