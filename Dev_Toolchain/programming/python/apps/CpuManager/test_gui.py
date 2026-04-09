#!/usr/bin/env python3
"""Simple GUI test for frozen executable debugging"""

import tkinter as tk
import sys
import os
from datetime import datetime

def main():
    try:
        # Log to file if frozen
        if getattr(sys, 'frozen', False):
            with open('test_gui_debug.log', 'w') as f:
                f.write(f"Test GUI starting at {datetime.now()}\n")
                f.write(f"Python executable: {sys.executable}\n")
                f.write(f"Frozen: {getattr(sys, 'frozen', False)}\n")
                f.write(f"Working directory: {os.getcwd()}\n")
        
        print("Creating tkinter window...")
        root = tk.Tk()
        root.title("CPU Monitor Test")
        root.geometry("400x200")
        
        label = tk.Label(root, text="CPU Monitor GUI Test\nIf you see this, tkinter works!", 
                        font=("Arial", 14), fg="green")
        label.pack(expand=True)
        
        button = tk.Button(root, text="Close", command=root.quit, 
                          font=("Arial", 12))
        button.pack(pady=10)
        
        print("Starting mainloop...")
        root.mainloop()
        print("GUI closed normally")
        
    except Exception as e:
        error_msg = f"ERROR: {e}"
        print(error_msg)
        
        # Write error to file
        try:
            with open('test_gui_error.log', 'w') as f:
                import traceback
                f.write(f"Error at {datetime.now()}\n")
                f.write(f"Exception: {e}\n")
                f.write(traceback.format_exc())
        except:
            pass

if __name__ == "__main__":
    main()