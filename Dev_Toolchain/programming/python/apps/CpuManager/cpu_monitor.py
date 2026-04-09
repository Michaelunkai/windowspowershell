"""
CPU Monitor Pro - Professional Real-time Process CPU Manager
Optimized for AMD Ryzen 7 9800X3D 8-Core Processor
A stunning, modern UI for monitoring and managing CPU usage
"""

import tkinter as tk
from tkinter import ttk, messagebox
import psutil
import ctypes
import sys
import os
import json
import subprocess
from threading import Thread
import time
from datetime import datetime
from collections import deque

# Path for persistent CPU limits storage
LIMITS_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "cpu_limits.json"
)

# Windows API constants
PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_SET_INFORMATION = 0x0200
PROCESS_TERMINATE = 0x0001
THREAD_SET_INFORMATION = 0x0020

# Process priority classes
PRIORITY_CLASSES = {
    "Idle": psutil.IDLE_PRIORITY_CLASS,
    "Below Normal": psutil.BELOW_NORMAL_PRIORITY_CLASS,
    "Normal": psutil.NORMAL_PRIORITY_CLASS,
    "Above Normal": psutil.ABOVE_NORMAL_PRIORITY_CLASS,
    "High": psutil.HIGH_PRIORITY_CLASS,
    "Realtime": psutil.REALTIME_PRIORITY_CLASS,
}

PRIORITY_NAMES = {v: k for k, v in PRIORITY_CLASSES.items()}

# AMD Ryzen 7 9800X3D specific info
CPU_INFO = {
    "name": "AMD Ryzen 7 9800X3D",
    "cores": 8,
    "threads": 8,
    "base_clock": 4200,  # MHz
    "boost_clock": 5200,  # MHz
    "tdp": 120,  # Watts
    "architecture": "Zen 5 (Granite Ridge)",
    "cache_l3": "96 MB 3D V-Cache",
    "process": "4nm TSMC",
}

# ============================================================================
# PREMIUM COLOR PALETTE - Modern Dark Theme (same as RAM Monitor)
# ============================================================================
COLORS = {
    # Background colors
    "bg_dark": "#0d1117",
    "bg_medium": "#161b22",
    "bg_light": "#21262d",
    "bg_hover": "#30363d",
    # Text colors
    "text_primary": "#f0f6fc",
    "text_secondary": "#8b949e",
    "text_muted": "#6e7681",
    # Accent colors
    "accent_blue": "#58a6ff",
    "accent_cyan": "#39d353",
    "accent_purple": "#a371f7",
    "accent_orange": "#f0883e",
    # Status colors
    "success": "#238636",
    "success_light": "#2ea043",
    "warning": "#d29922",
    "warning_light": "#e3b341",
    "danger": "#da3633",
    "danger_light": "#f85149",
    "info": "#1f6feb",
    "info_light": "#388bfd",
    # Critical process colors
    "critical_bg": "#3d1a1a",
    "critical_text": "#ff6b6b",
    "critical_border": "#6e2d2d",
    # Selection colors
    "selected_bg": "#1f3a5f",
    "selected_border": "#388bfd",
    # CPU Limit colors (affinity restricted)
    "limited_bg": "#2d1f3d",
    "limited_text": "#c084fc",
    "limited_border": "#7c3aed",
    # High CPU colors
    "high_cpu_bg": "#3d2d1a",
    "high_cpu_text": "#fbbf24",
    # Progress bar colors
    "progress_low": "#238636",
    "progress_medium": "#d29922",
    "progress_high": "#da3633",
    "progress_bg": "#21262d",
    # Button colors
    "btn_danger": "#da3633",
    "btn_danger_hover": "#f85149",
    "btn_success": "#238636",
    "btn_success_hover": "#2ea043",
    "btn_info": "#1f6feb",
    "btn_info_hover": "#388bfd",
    "btn_secondary": "#30363d",
    "btn_secondary_hover": "#484f58",
    # Border colors
    "border": "#30363d",
    "border_light": "#484f58",
    # Core colors for per-core display
    "core_colors": [
        "#58a6ff",  # Blue
        "#39d353",  # Green
        "#f0883e",  # Orange
        "#a371f7",  # Purple
        "#ff6b6b",  # Red
        "#fbbf24",  # Yellow
        "#2dd4bf",  # Teal
        "#ec4899",  # Pink
    ],
}

# ============================================================================
# APPLICATION GROUPING - Combine multi-process apps into single entries
# ============================================================================
APP_GROUPS = {
    "chrome.exe": "Chrome (Total)",
    "firefox.exe": "Firefox (Total)",
    "msedge.exe": "Edge (Total)",
    "code.exe": "VS Code (Total)",
    "electron.exe": "Electron Apps",
    "node.exe": "Node.js (Total)",
    "java.exe": "Java Apps",
    "javaw.exe": "Java Apps",
    "python.exe": "Python (Total)",
    "pythonw.exe": "Python (Total)",
    "idea64.exe": "JetBrains IDE",
    "pycharm64.exe": "JetBrains IDE",
    "webstorm64.exe": "JetBrains IDE",
}

# Critical Windows processes
CRITICAL_PROCESSES = {
    "system",
    "system idle process",
    "registry",
    "smss.exe",
    "csrss.exe",
    "wininit.exe",
    "services.exe",
    "lsass.exe",
    "winlogon.exe",
    "dwm.exe",
    "fontdrvhost.exe",
    "sihost.exe",
    "taskhostw.exe",
    "ctfmon.exe",
    "conhost.exe",
    "ntoskrnl.exe",
    "svchost.exe",
    "runtimebroker.exe",
    "explorer.exe",
    "audiodg.exe",
    "spoolsv.exe",
    "memcompression",
}


class ModernButton(tk.Canvas):
    """Custom modern button with hover effects"""

    def __init__(
        self, parent, text, command, style="primary", width=150, height=38, **kwargs
    ):
        super().__init__(
            parent,
            width=width,
            height=height,
            bg=COLORS["bg_dark"],
            highlightthickness=0,
            **kwargs,
        )

        self.command = command
        self.text = text
        self.width = width
        self.height = height
        self.style = style
        self.is_hovered = False

        self.styles = {
            "primary": (COLORS["btn_info"], COLORS["btn_info_hover"], "#ffffff"),
            "danger": (COLORS["btn_danger"], COLORS["btn_danger_hover"], "#ffffff"),
            "success": (COLORS["btn_success"], COLORS["btn_success_hover"], "#ffffff"),
            "info": (COLORS["btn_info"], COLORS["btn_info_hover"], "#ffffff"),
            "secondary": (
                COLORS["btn_secondary"],
                COLORS["btn_secondary_hover"],
                COLORS["text_primary"],
            ),
            "purple": (COLORS["limited_border"], COLORS["limited_text"], "#ffffff"),
            "orange": (COLORS["accent_orange"], COLORS["warning_light"], "#ffffff"),
        }

        self.draw_button()

        self.bind("<Enter>", self.on_enter)
        self.bind("<Leave>", self.on_leave)
        self.bind("<Button-1>", self.on_click)
        self.bind("<ButtonRelease-1>", self.on_release)

    def draw_button(self):
        self.delete("all")
        colors = self.styles.get(self.style, self.styles["primary"])
        bg_color = colors[1] if self.is_hovered else colors[0]
        text_color = colors[2]

        radius = 8
        self.create_rounded_rect(
            2, 2, self.width - 2, self.height - 2, radius, fill=bg_color, outline=""
        )

        self.create_text(
            self.width // 2,
            self.height // 2,
            text=self.text,
            fill=text_color,
            font=("Segoe UI Semibold", 10),
        )

    def create_rounded_rect(self, x1, y1, x2, y2, radius, **kwargs):
        points = [
            x1 + radius,
            y1,
            x2 - radius,
            y1,
            x2,
            y1,
            x2,
            y1 + radius,
            x2,
            y2 - radius,
            x2,
            y2,
            x2 - radius,
            y2,
            x1 + radius,
            y2,
            x1,
            y2,
            x1,
            y2 - radius,
            x1,
            y1 + radius,
            x1,
            y1,
        ]
        return self.create_polygon(points, smooth=True, **kwargs)

    def on_enter(self, event):
        self.is_hovered = True
        self.draw_button()
        self.config(cursor="hand2")

    def on_leave(self, event):
        self.is_hovered = False
        self.draw_button()

    def on_click(self, event):
        pass

    def on_release(self, event):
        if self.command:
            self.command()


class ProgressBar(tk.Canvas):
    """Custom animated progress bar"""

    def __init__(self, parent, width=300, height=24, **kwargs):
        super().__init__(
            parent,
            width=width,
            height=height,
            bg=COLORS["bg_dark"],
            highlightthickness=0,
            **kwargs,
        )
        self.width = width
        self.height = height
        self.value = 0
        self.draw_bar()

    def set_value(self, value):
        self.value = max(0, min(100, value))
        self.draw_bar()

    def draw_bar(self):
        self.delete("all")
        radius = self.height // 2

        self.create_rounded_rect(
            0,
            0,
            self.width,
            self.height,
            radius,
            fill=COLORS["progress_bg"],
            outline=COLORS["border"],
        )

        if self.value > 0:
            fill_width = max(radius * 2, (self.width - 4) * (self.value / 100))

            if self.value < 50:
                color = COLORS["progress_low"]
            elif self.value < 75:
                color = COLORS["progress_medium"]
            else:
                color = COLORS["progress_high"]

            self.create_rounded_rect(
                2,
                2,
                fill_width + 2,
                self.height - 2,
                radius - 2,
                fill=color,
                outline="",
            )

        self.create_text(
            self.width // 2,
            self.height // 2,
            text=f"{self.value:.1f}%",
            fill=COLORS["text_primary"],
            font=("Segoe UI Semibold", 9),
        )

    def create_rounded_rect(self, x1, y1, x2, y2, radius, **kwargs):
        points = [
            x1 + radius,
            y1,
            x2 - radius,
            y1,
            x2,
            y1,
            x2,
            y1 + radius,
            x2,
            y2 - radius,
            x2,
            y2,
            x2 - radius,
            y2,
            x1 + radius,
            y2,
            x1,
            y2,
            x1,
            y2 - radius,
            x1,
            y1 + radius,
            x1,
            y1,
        ]
        return self.create_polygon(points, smooth=True, **kwargs)


class CoreUsageBar(tk.Canvas):
    """Single core usage bar with color"""

    def __init__(self, parent, core_id, color, width=35, height=80, **kwargs):
        super().__init__(
            parent,
            width=width,
            height=height + 20,
            bg=COLORS["bg_light"],
            highlightthickness=0,
            **kwargs,
        )
        self.width = width
        self.height = height
        self.core_id = core_id
        self.color = color
        self.value = 0
        self.draw_bar()

    def set_value(self, value):
        self.value = max(0, min(100, value))
        self.draw_bar()

    def draw_bar(self):
        self.delete("all")

        # Background bar
        self.create_rectangle(
            4,
            4,
            self.width - 4,
            self.height - 4,
            fill=COLORS["bg_dark"],
            outline=COLORS["border"],
        )

        # Fill
        if self.value > 0:
            fill_height = (self.height - 8) * (self.value / 100)
            y_start = self.height - 4 - fill_height

            # Color based on usage
            if self.value < 50:
                fill_color = self.color
            elif self.value < 80:
                fill_color = COLORS["warning"]
            else:
                fill_color = COLORS["danger"]

            self.create_rectangle(
                5,
                y_start,
                self.width - 5,
                self.height - 5,
                fill=fill_color,
                outline="",
            )

        # Core label
        self.create_text(
            self.width // 2,
            self.height + 8,
            text=f"C{self.core_id}",
            fill=COLORS["text_secondary"],
            font=("Consolas", 8),
        )


class CPUMonitorApp:
    """Professional CPU Monitor Application for AMD Ryzen 7 9800X3D"""

    def __init__(self, root):
        self.root = root
        self.root.title("CPU Monitor Pro - Ryzen 9800X3D")
        self.root.geometry("1350x900")
        self.root.minsize(1200, 750)
        self.root.configure(bg=COLORS["bg_dark"])

        self.center_window()

        # State
        self.running = True
        self.update_interval = 1000  # 1 second for CPU monitoring
        self.grouped_view = tk.BooleanVar(value=True)
        self.raw_processes = []
        self.grouped_processes = []
        self.name_to_pids = {}
        self.selected_names = set()
        self.last_update = None
        self.live_indicator_state = True
        self.cpu_limits = {}  # {process_name: {"cores": [0,1,2], "priority": "Normal"}}
        self.known_pids = set()

        # CPU history for graphs
        self.cpu_history = deque(maxlen=60)  # 60 seconds of history
        self.per_core_history = [deque(maxlen=60) for _ in range(CPU_INFO["cores"])]

        # Current CPU frequency tracking
        self.current_freq = 0
        self.current_per_core = [0] * CPU_INFO["cores"]

        self.load_limits()
        self.setup_styles()
        self.create_ui()
        self.start_monitoring()

        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

    def center_window(self):
        self.root.update_idletasks()
        width = 1350
        height = 900
        x = (self.root.winfo_screenwidth() // 2) - (width // 2)
        y = (self.root.winfo_screenheight() // 2) - (height // 2)
        self.root.geometry(f"{width}x{height}+{x}+{y}")

    def load_limits(self):
        """Load CPU limits from persistent storage"""
        try:
            if os.path.exists(LIMITS_FILE):
                with open(LIMITS_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    self.cpu_limits = data.get("limits", {})
        except (json.JSONDecodeError, IOError, ValueError):
            self.cpu_limits = {}

    def save_limits(self):
        """Save CPU limits to persistent storage"""
        try:
            data = {
                "limits": self.cpu_limits,
                "last_updated": datetime.now().isoformat(),
            }
            with open(LIMITS_FILE, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
        except IOError:
            pass

    def setup_styles(self):
        style = ttk.Style()
        style.theme_use("clam")

        style.configure("Dark.TFrame", background=COLORS["bg_dark"])
        style.configure("Card.TFrame", background=COLORS["bg_light"])

        style.configure(
            "Title.TLabel",
            background=COLORS["bg_dark"],
            foreground=COLORS["text_primary"],
            font=("Segoe UI", 24, "bold"),
        )

        style.configure(
            "Subtitle.TLabel",
            background=COLORS["bg_dark"],
            foreground=COLORS["text_secondary"],
            font=("Segoe UI", 11),
        )

        style.configure(
            "Stats.TLabel",
            background=COLORS["bg_dark"],
            foreground=COLORS["accent_cyan"],
            font=("Consolas", 13),
        )

        style.configure(
            "Dark.TLabel",
            background=COLORS["bg_dark"],
            foreground=COLORS["text_primary"],
            font=("Segoe UI", 10),
        )

        style.configure(
            "Dark.TCheckbutton",
            background=COLORS["bg_dark"],
            foreground=COLORS["text_primary"],
            font=("Segoe UI", 10),
        )
        style.map("Dark.TCheckbutton", background=[("active", COLORS["bg_dark"])])

        style.configure(
            "Modern.Treeview",
            background=COLORS["bg_medium"],
            foreground=COLORS["text_primary"],
            fieldbackground=COLORS["bg_medium"],
            font=("Segoe UI", 10),
            rowheight=32,
            borderwidth=0,
        )

        style.configure(
            "Modern.Treeview.Heading",
            background=COLORS["bg_light"],
            foreground=COLORS["text_primary"],
            font=("Segoe UI Semibold", 10),
            borderwidth=0,
            relief="flat",
        )

        style.map(
            "Modern.Treeview",
            background=[("selected", COLORS["selected_bg"])],
            foreground=[("selected", COLORS["text_primary"])],
        )

        style.configure(
            "Dark.Vertical.TScrollbar",
            background=COLORS["bg_light"],
            troughcolor=COLORS["bg_medium"],
            borderwidth=0,
        )

    def create_ui(self):
        main = ttk.Frame(self.root, style="Dark.TFrame")
        main.pack(fill=tk.BOTH, expand=True, padx=20, pady=15)

        self.create_header(main)
        self.create_cpu_panel(main)
        self.create_toolbar(main)
        self.create_table(main)
        self.create_footer(main)

    def create_header(self, parent):
        header = ttk.Frame(parent, style="Dark.TFrame")
        header.pack(fill=tk.X, pady=(0, 15))

        left = ttk.Frame(header, style="Dark.TFrame")
        left.pack(side=tk.LEFT, fill=tk.Y)

        title_row = ttk.Frame(left, style="Dark.TFrame")
        title_row.pack(anchor="w")

        icon_label = tk.Label(
            title_row,
            text="",
            font=("Segoe UI", 28),
            bg=COLORS["bg_dark"],
            fg=COLORS["accent_orange"],
        )
        icon_label.pack(side=tk.LEFT, padx=(0, 12))

        title_text = ttk.Frame(title_row, style="Dark.TFrame")
        title_text.pack(side=tk.LEFT)

        ttk.Label(title_text, text="CPU Monitor Pro", style="Title.TLabel").pack(
            anchor="w"
        )
        ttk.Label(
            title_text,
            text=f"{CPU_INFO['name']}  |  {CPU_INFO['cores']}C/{CPU_INFO['threads']}T  |  v2.0",
            style="Subtitle.TLabel",
        ).pack(anchor="w")

        # Right side - CPU Stats
        right = ttk.Frame(header, style="Dark.TFrame")
        right.pack(side=tk.RIGHT, fill=tk.Y)

        stats_box = tk.Frame(right, bg=COLORS["bg_light"], padx=20, pady=12)
        stats_box.pack()

        stats_title_row = tk.Frame(stats_box, bg=COLORS["bg_light"])
        stats_title_row.pack(fill=tk.X, pady=(0, 6))

        tk.Label(
            stats_title_row,
            text="CPU UTILIZATION",
            bg=COLORS["bg_light"],
            fg=COLORS["text_muted"],
            font=("Segoe UI Semibold", 9),
        ).pack(side=tk.LEFT)

        self.live_dot = tk.Label(
            stats_title_row,
            text="",
            bg=COLORS["bg_light"],
            fg=COLORS["accent_cyan"],
            font=("Segoe UI", 10),
        )
        self.live_dot.pack(side=tk.RIGHT)

        self.percent_label = tk.Label(
            stats_box,
            text="0.0%",
            bg=COLORS["bg_light"],
            fg=COLORS["accent_orange"],
            font=("Segoe UI", 32, "bold"),
        )
        self.percent_label.pack()

        self.cpu_progress = ProgressBar(stats_box, width=260, height=20)
        self.cpu_progress.pack(pady=(5, 8))

        self.freq_label = tk.Label(
            stats_box,
            text=f"Freq: 0 MHz / {CPU_INFO['boost_clock']} MHz",
            bg=COLORS["bg_light"],
            fg=COLORS["text_secondary"],
            font=("Consolas", 10),
        )
        self.freq_label.pack()

        self.limited_badge = tk.Label(
            stats_box,
            text="",
            bg=COLORS["bg_light"],
            fg=COLORS["limited_text"],
            font=("Segoe UI Semibold", 9),
        )
        self.limited_badge.pack(pady=(5, 0))

    def create_cpu_panel(self, parent):
        """Create per-core CPU usage panel"""
        panel = tk.Frame(parent, bg=COLORS["bg_light"], padx=15, pady=10)
        panel.pack(fill=tk.X, pady=(0, 12))

        # Title row
        title_row = tk.Frame(panel, bg=COLORS["bg_light"])
        title_row.pack(fill=tk.X, pady=(0, 8))

        tk.Label(
            title_row,
            text="PER-CORE UTILIZATION",
            bg=COLORS["bg_light"],
            fg=COLORS["text_muted"],
            font=("Segoe UI Semibold", 9),
        ).pack(side=tk.LEFT)

        tk.Label(
            title_row,
            text=f"{CPU_INFO['architecture']}  |  {CPU_INFO['cache_l3']}  |  {CPU_INFO['process']}",
            bg=COLORS["bg_light"],
            fg=COLORS["text_secondary"],
            font=("Segoe UI", 9),
        ).pack(side=tk.RIGHT)

        # Core bars container
        cores_frame = tk.Frame(panel, bg=COLORS["bg_light"])
        cores_frame.pack(fill=tk.X, pady=5)

        self.core_bars = []
        for i in range(CPU_INFO["cores"]):
            color = COLORS["core_colors"][i % len(COLORS["core_colors"])]
            bar = CoreUsageBar(cores_frame, i, color, width=40, height=70)
            bar.pack(side=tk.LEFT, padx=8, pady=5)
            self.core_bars.append(bar)

        # Per-core percentage labels
        self.core_pct_frame = tk.Frame(panel, bg=COLORS["bg_light"])
        self.core_pct_frame.pack(fill=tk.X)

        self.core_pct_labels = []
        for i in range(CPU_INFO["cores"]):
            lbl = tk.Label(
                self.core_pct_frame,
                text="0%",
                bg=COLORS["bg_light"],
                fg=COLORS["core_colors"][i % len(COLORS["core_colors"])],
                font=("Consolas", 9),
                width=5,
            )
            lbl.pack(side=tk.LEFT, padx=8)
            self.core_pct_labels.append(lbl)

        sep = tk.Frame(parent, bg=COLORS["border"], height=1)
        sep.pack(fill=tk.X, pady=(0, 10))

    def create_toolbar(self, parent):
        toolbar = ttk.Frame(parent, style="Dark.TFrame")
        toolbar.pack(fill=tk.X, pady=(0, 10))

        left = ttk.Frame(toolbar, style="Dark.TFrame")
        left.pack(side=tk.LEFT)

        search_frame = tk.Frame(left, bg=COLORS["bg_light"], padx=10, pady=6)
        search_frame.pack(side=tk.LEFT, padx=(0, 15))

        tk.Label(
            search_frame,
            text="",
            bg=COLORS["bg_light"],
            fg=COLORS["text_muted"],
            font=("Segoe UI", 11),
        ).pack(side=tk.LEFT)

        self.search_var = tk.StringVar()
        self.search_var.trace("w", self.filter_processes)

        search_entry = tk.Entry(
            search_frame,
            textvariable=self.search_var,
            bg=COLORS["bg_light"],
            fg=COLORS["text_primary"],
            insertbackground=COLORS["text_primary"],
            font=("Segoe UI", 11),
            width=25,
            relief=tk.FLAT,
            bd=0,
        )
        search_entry.pack(side=tk.LEFT, padx=(8, 0))

        self.grouped_check = ttk.Checkbutton(
            left,
            text="  Group by Application",
            variable=self.grouped_view,
            style="Dark.TCheckbutton",
            command=self.filter_processes,
        )
        self.grouped_check.pack(side=tk.LEFT, padx=(0, 20))

        right = ttk.Frame(toolbar, style="Dark.TFrame")
        right.pack(side=tk.RIGHT)

        self.selection_frame = tk.Frame(
            right, bg=COLORS["selected_bg"], padx=12, pady=4
        )
        self.selection_frame.pack(side=tk.LEFT, padx=(0, 10))

        self.selection_label = tk.Label(
            self.selection_frame,
            text="0 Selected",
            bg=COLORS["selected_bg"],
            fg=COLORS["text_primary"],
            font=("Segoe UI Semibold", 10),
        )
        self.selection_label.pack()

        self.clear_btn = ModernButton(
            right,
            "  Clear",
            self.clear_selection,
            style="secondary",
            width=100,
            height=32,
        )
        self.clear_btn.pack(side=tk.LEFT)

    def create_table(self, parent):
        table_container = tk.Frame(parent, bg=COLORS["border"], padx=1, pady=1)
        table_container.pack(fill=tk.BOTH, expand=True)

        table_inner = tk.Frame(table_container, bg=COLORS["bg_medium"])
        table_inner.pack(fill=tk.BOTH, expand=True)

        columns = (
            "icon",
            "instances",
            "name",
            "cpu_percent",
            "threads",
            "priority",
            "status",
        )
        self.tree = ttk.Treeview(
            table_inner,
            columns=columns,
            show="headings",
            style="Modern.Treeview",
            selectmode="none",
        )

        self.tree.heading("icon", text="")
        self.tree.heading(
            "instances",
            text="Count",
            command=lambda: self.sort_column("instances", True),
        )
        self.tree.heading(
            "name", text="Application", command=lambda: self.sort_column("name", False)
        )
        self.tree.heading(
            "cpu_percent",
            text="CPU %",
            command=lambda: self.sort_column("cpu_percent", True),
        )
        self.tree.heading(
            "threads", text="Threads", command=lambda: self.sort_column("threads", True)
        )
        self.tree.heading(
            "priority",
            text="Priority",
            command=lambda: self.sort_column("priority", False),
        )
        self.tree.heading(
            "status", text="Status", command=lambda: self.sort_column("status", False)
        )

        self.tree.column("icon", width=40, anchor="center", stretch=False)
        self.tree.column("instances", width=70, anchor="center", stretch=False)
        self.tree.column("name", width=350, anchor="w")
        self.tree.column("cpu_percent", width=120, anchor="e")
        self.tree.column("threads", width=80, anchor="center")
        self.tree.column("priority", width=120, anchor="center")
        self.tree.column("status", width=100, anchor="center")

        scrollbar = ttk.Scrollbar(
            table_inner,
            orient=tk.VERTICAL,
            command=self.tree.yview,
            style="Dark.Vertical.TScrollbar",
        )
        self.tree.configure(yscrollcommand=scrollbar.set)

        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        self.tree.bind("<Button-1>", self.on_tree_click)

        self.tree.tag_configure(
            "critical",
            foreground=COLORS["critical_text"],
            background=COLORS["critical_bg"],
        )
        self.tree.tag_configure("high", foreground=COLORS["danger_light"])
        self.tree.tag_configure("medium", foreground=COLORS["warning_light"])
        self.tree.tag_configure("normal", foreground=COLORS["text_primary"])
        self.tree.tag_configure("selected", background=COLORS["selected_bg"])
        self.tree.tag_configure("oddrow", background=COLORS["bg_medium"])
        self.tree.tag_configure("evenrow", background=COLORS["bg_light"])
        self.tree.tag_configure(
            "limited",
            foreground=COLORS["limited_text"],
            background=COLORS["limited_bg"],
        )
        self.tree.tag_configure(
            "high_cpu",
            foreground=COLORS["high_cpu_text"],
            background=COLORS["high_cpu_bg"],
        )

        self.sort_reverse = True
        self.sort_column_name = "cpu_percent"

    def create_footer(self, parent):
        footer = ttk.Frame(parent, style="Dark.TFrame")
        footer.pack(fill=tk.X, pady=(12, 0))

        btn_row = ttk.Frame(footer, style="Dark.TFrame")
        btn_row.pack(fill=tk.X, pady=(0, 10))

        btn_left = ttk.Frame(btn_row, style="Dark.TFrame")
        btn_left.pack(side=tk.LEFT)

        self.kill_btn = ModernButton(
            btn_left,
            "  End Process",
            self.kill_selected,
            style="danger",
            width=150,
            height=42,
        )
        self.kill_btn.pack(side=tk.LEFT, padx=(0, 10))

        self.refresh_btn = ModernButton(
            btn_left,
            "  Refresh",
            self.refresh_processes,
            style="success",
            width=120,
            height=42,
        )
        self.refresh_btn.pack(side=tk.LEFT, padx=(0, 10))

        self.affinity_btn = ModernButton(
            btn_left,
            "  Set Affinity",
            self.show_affinity_dialog,
            style="purple",
            width=140,
            height=42,
        )
        self.affinity_btn.pack(side=tk.LEFT, padx=(0, 10))

        self.priority_btn = ModernButton(
            btn_left,
            "  Set Priority",
            self.show_priority_dialog,
            style="orange",
            width=140,
            height=42,
        )
        self.priority_btn.pack(side=tk.LEFT, padx=(0, 10))

        self.limit_cpu_btn = ModernButton(
            btn_left,
            "  Limit CPU",
            self.show_cpu_limit_dialog,
            style="info",
            width=130,
            height=42,
        )
        self.limit_cpu_btn.pack(side=tk.LEFT, padx=(0, 10))

        self.show_limited_btn = ModernButton(
            btn_left,
            "  Limited",
            self.show_limited_dialog,
            style="secondary",
            width=110,
            height=42,
        )
        self.show_limited_btn.pack(side=tk.LEFT, padx=(0, 10))

        self.startup_btn = ModernButton(
            btn_left,
            "  Auto-Start",
            self.toggle_startup_service,
            style="success" if self.is_startup_service_installed() else "secondary",
            width=120,
            height=42,
        )
        self.startup_btn.pack(side=tk.LEFT)

        self.count_label = tk.Label(
            btn_row,
            text="",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_secondary"],
            font=("Segoe UI", 11),
        )
        self.count_label.pack(side=tk.RIGHT)

        legend_frame = ttk.Frame(footer, style="Dark.TFrame")
        legend_frame.pack(fill=tk.X)

        legends = [
            ("  CRITICAL", COLORS["critical_text"], COLORS["critical_bg"]),
            ("  High CPU", COLORS["high_cpu_text"], COLORS["high_cpu_bg"]),
            ("  Selected", COLORS["text_primary"], COLORS["selected_bg"]),
            ("  Affinity Limited", COLORS["limited_text"], COLORS["limited_bg"]),
        ]

        tk.Label(
            legend_frame,
            text="Legend:",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_muted"],
            font=("Segoe UI", 9),
        ).pack(side=tk.LEFT, padx=(0, 10))

        for text, fg, bg in legends:
            badge = tk.Frame(legend_frame, bg=bg, padx=8, pady=3)
            badge.pack(side=tk.LEFT, padx=(0, 8))
            tk.Label(badge, text=text, bg=bg, fg=fg, font=("Segoe UI", 9)).pack()

        self.update_label = tk.Label(
            legend_frame,
            text="",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_muted"],
            font=("Segoe UI", 9),
        )
        self.update_label.pack(side=tk.RIGHT)

    def on_tree_click(self, event):
        item_id = self.tree.identify_row(event.y)
        if not item_id:
            return

        values = self.tree.item(item_id)["values"]
        if not values or len(values) < 3:
            return

        name = values[2]

        if name in self.selected_names:
            self.selected_names.discard(name)
        else:
            self.selected_names.add(name)

        self.update_visual_selection()
        self.selection_label.config(text=f"{len(self.selected_names)} Selected")

    def clear_selection(self):
        self.selected_names.clear()
        self.update_visual_selection()
        self.selection_label.config(text="0 Selected")

    def update_visual_selection(self):
        for item_id in self.tree.get_children():
            values = self.tree.item(item_id)["values"]
            if values and len(values) >= 3:
                name = values[2]
                current_tags = list(self.tree.item(item_id)["tags"])
                current_tags = [t for t in current_tags if t != "selected"]

                if name in self.selected_names:
                    current_tags.append("selected")

                self.tree.item(item_id, tags=tuple(current_tags))

    def is_critical_process(self, name):
        return name.lower() in CRITICAL_PROCESSES

    def get_processes(self):
        processes = []
        for proc in psutil.process_iter(
            ["pid", "name", "cpu_percent", "num_threads", "status", "nice"]
        ):
            try:
                info = proc.info
                cpu_pct = info["cpu_percent"] or 0.0

                # Get priority name
                try:
                    nice = info["nice"]
                    priority = PRIORITY_NAMES.get(nice, "Normal")
                except:
                    priority = "Normal"

                processes.append(
                    {
                        "pid": info["pid"],
                        "name": info["name"] or "Unknown",
                        "cpu_percent": cpu_pct,
                        "threads": info["num_threads"] or 0,
                        "status": info["status"] or "unknown",
                        "priority": priority,
                        "is_critical": self.is_critical_process(info["name"] or ""),
                    }
                )
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
        return processes

    def group_processes(self, processes):
        groups = {}
        self.group_to_original_names = {}

        for proc in processes:
            original_name = proc["name"]
            group_name = APP_GROUPS.get(original_name.lower(), original_name)

            if group_name not in groups:
                groups[group_name] = {
                    "pids": [],
                    "cpu_percent": 0.0,
                    "threads": 0,
                    "statuses": set(),
                    "priorities": set(),
                    "is_critical": proc["is_critical"],
                    "original_names": set(),
                }
            groups[group_name]["pids"].append(proc["pid"])
            groups[group_name]["cpu_percent"] += proc["cpu_percent"]
            groups[group_name]["threads"] += proc["threads"]
            groups[group_name]["statuses"].add(proc["status"])
            groups[group_name]["priorities"].add(proc["priority"])
            groups[group_name]["original_names"].add(original_name)

        grouped = []
        self.name_to_pids = {}
        self.group_to_original_names = {}

        for name, data in groups.items():
            pids_list = data["pids"]
            self.name_to_pids[name] = pids_list
            self.group_to_original_names[name] = data["original_names"]

            if data["statuses"] == {"running"}:
                status = "running"
            elif len(data["statuses"]) > 1:
                status = "mixed"
            else:
                status = list(data["statuses"])[0]

            # Most common priority
            priority = max(set(data["priorities"]), key=list(data["priorities"]).count)

            grouped.append(
                {
                    "instances": len(pids_list),
                    "name": name,
                    "cpu_percent": data["cpu_percent"],
                    "threads": data["threads"],
                    "status": status,
                    "priority": priority,
                    "pids": pids_list,
                    "is_critical": data["is_critical"],
                    "original_names": data["original_names"],
                }
            )

        return grouped

    def update_tree(self, processes):
        for item in self.tree.get_children():
            self.tree.delete(item)

        if self.sort_column_name == "instances" and not self.grouped_view.get():
            sort_key = "cpu_percent"
        else:
            sort_key = self.sort_column_name

        processes.sort(
            key=lambda x: x.get(sort_key, 0)
            if isinstance(x.get(sort_key, 0), (int, float))
            else str(x.get(sort_key, "")),
            reverse=self.sort_reverse,
        )

        for idx, proc in enumerate(processes):
            tags = []

            if idx % 2 == 0:
                tags.append("evenrow")
            else:
                tags.append("oddrow")

            has_limit = proc["name"] in self.cpu_limits

            if proc.get("is_critical", False):
                tags = ["critical"]
            elif has_limit:
                tags = ["limited"]
            elif proc["cpu_percent"] > 50:
                tags = ["high_cpu"]
            elif proc["cpu_percent"] > 20:
                tags.append("high")
            elif proc["cpu_percent"] > 5:
                tags.append("medium")

            if proc["name"] in self.selected_names:
                tags.append("selected")

            # Icon
            if proc.get("is_critical", False):
                icon = ""
            elif has_limit:
                icon = ""
            elif proc["cpu_percent"] > 50:
                icon = ""
            else:
                icon = ""

            instances = proc.get("instances", 1)
            cpu_pct = f"{proc['cpu_percent']:.1f}%"

            self.tree.insert(
                "",
                tk.END,
                values=(
                    icon,
                    instances if instances > 1 else "1",
                    proc["name"],
                    cpu_pct,
                    proc["threads"],
                    proc["priority"],
                    proc["status"],
                ),
                tags=tuple(tags),
            )

        total_procs = sum(p.get("instances", 1) for p in processes)
        if self.grouped_view.get():
            self.count_label.config(
                text=f"{len(processes)} apps  |  {total_procs} processes"
            )
        else:
            self.count_label.config(text=f"{len(processes)} processes")

    def update_stats(self):
        # Overall CPU usage
        cpu_percent = psutil.cpu_percent(interval=None)
        self.cpu_history.append(cpu_percent)

        self.percent_label.config(text=f"{cpu_percent:.1f}%")

        if cpu_percent > 80:
            color = COLORS["danger_light"]
        elif cpu_percent > 60:
            color = COLORS["warning_light"]
        else:
            color = COLORS["accent_orange"]
        self.percent_label.config(fg=color)

        self.cpu_progress.set_value(cpu_percent)

        # Per-core usage
        per_core = psutil.cpu_percent(interval=None, percpu=True)
        self.current_per_core = per_core

        for i, pct in enumerate(per_core[: CPU_INFO["cores"]]):
            self.per_core_history[i].append(pct)
            self.core_bars[i].set_value(pct)
            self.core_pct_labels[i].config(text=f"{pct:.0f}%")

        # CPU frequency
        try:
            freq = psutil.cpu_freq()
            if freq:
                self.current_freq = freq.current
                self.freq_label.config(
                    text=f"Freq: {freq.current:.0f} MHz / {CPU_INFO['boost_clock']} MHz"
                )
        except:
            pass

        # Update timestamp
        self.last_update = datetime.now()
        self.update_label.config(
            text=f"Updated: {self.last_update.strftime('%H:%M:%S')}"
        )

        # Toggle live indicator
        self.live_indicator_state = not self.live_indicator_state
        self.live_dot.config(text="" if self.live_indicator_state else "")

        # Update limited apps badge
        if self.cpu_limits:
            num_limited = len(self.cpu_limits)
            self.limited_badge.config(
                text=f"{num_limited} app{'s' if num_limited != 1 else ''} limited"
            )
        else:
            self.limited_badge.config(text="")

    def refresh_processes(self):
        self.raw_processes = self.get_processes()
        self.grouped_processes = self.group_processes(self.raw_processes)
        self.enforce_cpu_limits()
        self.filter_processes()
        self.update_stats()

    def filter_processes(self, *args):
        search_text = self.search_var.get().lower()

        if self.grouped_view.get():
            source = self.grouped_processes
        else:
            source = [{"instances": 1, **p} for p in self.raw_processes]

        if search_text:
            filtered = [p for p in source if search_text in p["name"].lower()]
        else:
            filtered = source

        self.update_tree(filtered)

    def sort_column(self, col, numeric):
        self.sort_column_name = col
        self.sort_reverse = (
            not self.sort_reverse
            if hasattr(self, "_last_sort") and self._last_sort == col
            else True
        )
        self._last_sort = col
        self.filter_processes()

    def kill_selected(self):
        if not self.selected_names:
            messagebox.showwarning(
                "No Selection",
                "Click on processes to select them first.",
            )
            return

        critical_selected = [
            n for n in self.selected_names if self.is_critical_process(n)
        ]
        if critical_selected:
            result = messagebox.askyesno(
                "DANGER - CRITICAL PROCESSES!",
                f"You selected CRITICAL Windows processes:\n\n"
                + "\n".join([f"  {n}" for n in critical_selected[:5]])
                + "\n\nClosing these WILL CRASH Windows!\n\nAre you ABSOLUTELY SURE?",
                icon="warning",
            )
            if not result:
                return

        all_pids = []
        names_selected = list(self.selected_names)

        for name in names_selected:
            if self.grouped_view.get() and name in self.name_to_pids:
                all_pids.extend(self.name_to_pids[name])
            else:
                for p in self.raw_processes:
                    if p["name"] == name:
                        all_pids.append(p["pid"])
                        break

        all_pids = list(set(all_pids))

        if not messagebox.askyesno(
            "Confirm",
            f"End {len(all_pids)} process(es)?\n\nUnsaved data may be lost!",
        ):
            return

        killed = 0
        failed = []
        for pid in all_pids:
            try:
                proc = psutil.Process(pid)
                proc.terminate()
                try:
                    proc.wait(timeout=2)
                except psutil.TimeoutExpired:
                    proc.kill()
                killed += 1
            except psutil.NoSuchProcess:
                killed += 1
            except psutil.AccessDenied:
                failed.append(f"PID {pid}: Access Denied")
            except Exception as e:
                failed.append(f"PID {pid}: {str(e)}")

        self.selected_names.clear()
        self.selection_label.config(text="0 Selected")

        msg = f"Ended {killed} process(es)."
        if failed:
            msg += f"\n\nFailed: {len(failed)}\n" + "\n".join(failed[:3])

        messagebox.showinfo("Complete", msg)
        self.refresh_processes()

    def show_affinity_dialog(self):
        """Show dialog to set CPU affinity for selected processes"""
        if not self.selected_names:
            messagebox.showwarning(
                "No Selection",
                "Select one or more processes first.\n\n"
                "Click on a process row to select it,\n"
                "then click 'Set Affinity' to limit CPU cores.",
            )
            return

        dialog = tk.Toplevel(self.root)
        dialog.title("Set CPU Affinity")
        dialog.geometry("500x500")
        dialog.configure(bg=COLORS["bg_dark"])
        dialog.transient(self.root)
        dialog.grab_set()

        dialog.update_idletasks()
        x = self.root.winfo_x() + (self.root.winfo_width() // 2) - 250
        y = self.root.winfo_y() + (self.root.winfo_height() // 2) - 250
        dialog.geometry(f"+{x}+{y}")

        tk.Label(
            dialog,
            text="  Set CPU Affinity",
            bg=COLORS["bg_dark"],
            fg=COLORS["limited_text"],
            font=("Segoe UI", 16, "bold"),
        ).pack(pady=(20, 10))

        names_list = list(self.selected_names)
        names_display = ", ".join(names_list[:3])
        if len(names_list) > 3:
            names_display += f" (+{len(names_list) - 3} more)"

        tk.Label(
            dialog,
            text=f"Setting affinity for: {names_display}",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_secondary"],
            font=("Segoe UI", 10),
            wraplength=450,
        ).pack(pady=(0, 15))

        tk.Label(
            dialog,
            text="Select which CPU cores this process can use:",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_primary"],
            font=("Segoe UI", 11),
        ).pack(pady=(0, 10))

        # Core checkboxes
        cores_frame = tk.Frame(dialog, bg=COLORS["bg_dark"])
        cores_frame.pack(pady=10)

        core_vars = []
        for i in range(CPU_INFO["cores"]):
            var = tk.BooleanVar(value=True)
            color = COLORS["core_colors"][i % len(COLORS["core_colors"])]

            cb = tk.Checkbutton(
                cores_frame,
                text=f"Core {i}",
                variable=var,
                bg=COLORS["bg_dark"],
                fg=color,
                selectcolor=COLORS["bg_light"],
                activebackground=COLORS["bg_dark"],
                activeforeground=color,
                font=("Segoe UI Semibold", 11),
            )
            cb.grid(row=i // 4, column=i % 4, padx=15, pady=8, sticky="w")
            core_vars.append(var)

        # Quick select buttons
        quick_frame = tk.Frame(dialog, bg=COLORS["bg_dark"])
        quick_frame.pack(pady=15)

        def select_all():
            for v in core_vars:
                v.set(True)

        def select_none():
            for v in core_vars:
                v.set(False)

        def select_half():
            for i, v in enumerate(core_vars):
                v.set(i < CPU_INFO["cores"] // 2)

        def select_one():
            for i, v in enumerate(core_vars):
                v.set(i == 0)

        ModernButton(
            quick_frame, "All", select_all, style="secondary", width=70, height=30
        ).pack(side=tk.LEFT, padx=5)
        ModernButton(
            quick_frame, "None", select_none, style="secondary", width=70, height=30
        ).pack(side=tk.LEFT, padx=5)
        ModernButton(
            quick_frame, "Half", select_half, style="secondary", width=70, height=30
        ).pack(side=tk.LEFT, padx=5)
        ModernButton(
            quick_frame, "Single", select_one, style="secondary", width=70, height=30
        ).pack(side=tk.LEFT, padx=5)

        tk.Label(
            dialog,
            text="Limiting cores restricts which CPUs a process can use.\n"
            "This can help reduce CPU usage for specific applications.\n\n"
            "Fewer cores = less CPU available to the process.",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_muted"],
            font=("Segoe UI", 9),
            justify=tk.CENTER,
        ).pack(pady=15)

        # Buttons
        btn_frame = tk.Frame(dialog, bg=COLORS["bg_dark"])
        btn_frame.pack(pady=20)

        def apply_affinity():
            selected_cores = [i for i, v in enumerate(core_vars) if v.get()]

            if not selected_cores:
                messagebox.showerror("Error", "You must select at least one core!")
                return

            for name in self.selected_names:
                self.cpu_limits[name] = {
                    "cores": selected_cores,
                    "priority": self.cpu_limits.get(name, {}).get("priority", "Normal"),
                }

            self.save_limits()
            dialog.destroy()

            # Enforce immediately
            self.enforce_cpu_limits()

            messagebox.showinfo(
                "Affinity Applied",
                f"CPU affinity set to {len(selected_cores)} core(s) for {len(names_list)} process(es).\n\n"
                f"Cores: {', '.join(map(str, selected_cores))}",
            )
            self.refresh_processes()

        def remove_limit():
            for name in self.selected_names:
                if name in self.cpu_limits:
                    # Keep priority but remove core restriction
                    if "priority" in self.cpu_limits[name]:
                        self.cpu_limits[name].pop("cores", None)
                        if not self.cpu_limits[name]:
                            del self.cpu_limits[name]
                    else:
                        del self.cpu_limits[name]

            self.save_limits()
            dialog.destroy()
            messagebox.showinfo("Limit Removed", "CPU affinity limits removed.")
            self.refresh_processes()

        ModernButton(
            btn_frame, "  Apply", apply_affinity, style="primary", width=130, height=38
        ).pack(side=tk.LEFT, padx=5)
        ModernButton(
            btn_frame,
            "  Remove Limit",
            remove_limit,
            style="danger",
            width=140,
            height=38,
        ).pack(side=tk.LEFT, padx=5)
        ModernButton(
            btn_frame, "Cancel", dialog.destroy, style="secondary", width=100, height=38
        ).pack(side=tk.LEFT, padx=5)

        dialog.bind("<Escape>", lambda e: dialog.destroy())

    def show_cpu_limit_dialog(self):
        """Show dialog to set CPU % limit for selected processes (like RAM limit)"""
        if not self.selected_names:
            messagebox.showwarning(
                "No Selection",
                "Select one or more processes first.\n\n"
                "Click on a process row to select it,\n"
                "then click 'Limit CPU' to set a CPU usage cap.",
            )
            return

        dialog = tk.Toplevel(self.root)
        dialog.title("Set CPU Limit")
        dialog.geometry("450x400")
        dialog.configure(bg=COLORS["bg_dark"])
        dialog.transient(self.root)
        dialog.grab_set()

        dialog.update_idletasks()
        x = self.root.winfo_x() + (self.root.winfo_width() // 2) - 225
        y = self.root.winfo_y() + (self.root.winfo_height() // 2) - 200
        dialog.geometry(f"+{x}+{y}")

        tk.Label(
            dialog,
            text="  Set CPU Limit",
            bg=COLORS["bg_dark"],
            fg=COLORS["accent_blue"],
            font=("Segoe UI", 16, "bold"),
        ).pack(pady=(20, 10))

        names_list = list(self.selected_names)
        names_display = ", ".join(names_list[:3])
        if len(names_list) > 3:
            names_display += f" (+{len(names_list) - 3} more)"

        tk.Label(
            dialog,
            text=f"Setting CPU limit for: {names_display}",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_secondary"],
            font=("Segoe UI", 10),
            wraplength=400,
        ).pack(pady=(0, 15))

        # Current CPU usage info
        current_cpu = 0
        for name in self.selected_names:
            for proc in self.grouped_processes:
                if proc["name"] == name:
                    current_cpu += proc["cpu_percent"]
                    break

        tk.Label(
            dialog,
            text=f"Current total CPU usage: {current_cpu:.1f}%",
            bg=COLORS["bg_dark"],
            fg=COLORS["accent_cyan"],
            font=("Consolas", 11),
        ).pack(pady=(0, 20))

        # Input frame
        input_frame = tk.Frame(dialog, bg=COLORS["bg_dark"])
        input_frame.pack(pady=10)

        tk.Label(
            input_frame,
            text="Max CPU % (12.5 = 1 core, 25 = 2 cores, etc.):",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_primary"],
            font=("Segoe UI", 11),
        ).pack(pady=(0, 10))

        # Preset buttons
        preset_frame = tk.Frame(dialog, bg=COLORS["bg_dark"])
        preset_frame.pack(pady=5)

        limit_var = tk.StringVar(value="50")

        def set_preset(val):
            limit_var.set(str(val))

        # Presets based on 8 cores: 12.5% per core
        ModernButton(
            preset_frame,
            "12.5% (1 core)",
            lambda: set_preset(12.5),
            style="secondary",
            width=110,
            height=30,
        ).pack(side=tk.LEFT, padx=3)
        ModernButton(
            preset_frame,
            "25% (2 cores)",
            lambda: set_preset(25),
            style="secondary",
            width=110,
            height=30,
        ).pack(side=tk.LEFT, padx=3)
        ModernButton(
            preset_frame,
            "50% (4 cores)",
            lambda: set_preset(50),
            style="secondary",
            width=110,
            height=30,
        ).pack(side=tk.LEFT, padx=3)

        # Entry
        entry_frame = tk.Frame(dialog, bg=COLORS["bg_dark"])
        entry_frame.pack(pady=15)

        limit_entry = tk.Entry(
            entry_frame,
            textvariable=limit_var,
            bg=COLORS["bg_light"],
            fg=COLORS["text_primary"],
            insertbackground=COLORS["text_primary"],
            font=("Consolas", 16),
            width=8,
            relief=tk.FLAT,
            justify=tk.CENTER,
        )
        limit_entry.pack(side=tk.LEFT)
        limit_entry.select_range(0, tk.END)
        limit_entry.focus()

        tk.Label(
            entry_frame,
            text=" %",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_primary"],
            font=("Segoe UI", 14),
        ).pack(side=tk.LEFT)

        tk.Label(
            dialog,
            text="CPU limit works by restricting the process to fewer cores.\n"
            "Lower % = fewer cores available = less CPU usage.\n\n"
            "Set to 0 to remove the limit.",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_muted"],
            font=("Segoe UI", 9),
            justify=tk.CENTER,
        ).pack(pady=15)

        # Buttons
        btn_frame = tk.Frame(dialog, bg=COLORS["bg_dark"])
        btn_frame.pack(pady=20)

        def apply_cpu_limit():
            try:
                limit_pct = float(limit_var.get())
                if limit_pct < 0 or limit_pct > 100:
                    raise ValueError("Invalid percentage")

                if limit_pct == 0:
                    # Remove limit
                    for name in self.selected_names:
                        if name in self.cpu_limits:
                            self.cpu_limits[name].pop("cpu_limit", None)
                            self.cpu_limits[name].pop("cores", None)
                            if not self.cpu_limits[name]:
                                del self.cpu_limits[name]
                    self.save_limits()
                    dialog.destroy()
                    messagebox.showinfo("Limit Removed", "CPU limits removed.")
                else:
                    # Calculate cores needed for this percentage
                    # 100% = 8 cores, 50% = 4 cores, 25% = 2 cores, 12.5% = 1 core
                    cores_needed = max(1, int((limit_pct / 100) * CPU_INFO["cores"]))
                    cores_to_use = list(range(cores_needed))

                    for name in self.selected_names:
                        if name not in self.cpu_limits:
                            self.cpu_limits[name] = {}
                        self.cpu_limits[name]["cpu_limit"] = limit_pct
                        self.cpu_limits[name]["cores"] = cores_to_use

                    self.save_limits()
                    dialog.destroy()

                    # Enforce immediately
                    self.enforce_cpu_limits()

                    messagebox.showinfo(
                        "CPU Limit Applied",
                        f"CPU limit of {limit_pct}% applied to {len(names_list)} process(es).\n\n"
                        f"Restricted to {cores_needed} core(s): {cores_to_use}",
                    )

                self.refresh_processes()

            except ValueError:
                messagebox.showerror(
                    "Invalid Input", "Please enter a valid percentage (0-100)."
                )

        ModernButton(
            btn_frame,
            "  Apply Limit",
            apply_cpu_limit,
            style="primary",
            width=140,
            height=38,
        ).pack(side=tk.LEFT, padx=10)
        ModernButton(
            btn_frame, "Cancel", dialog.destroy, style="secondary", width=100, height=38
        ).pack(side=tk.LEFT)

        dialog.bind("<Return>", lambda e: apply_cpu_limit())
        dialog.bind("<Escape>", lambda e: dialog.destroy())

    def show_priority_dialog(self):
        """Show dialog to set process priority"""
        if not self.selected_names:
            messagebox.showwarning(
                "No Selection",
                "Select one or more processes first.",
            )
            return

        dialog = tk.Toplevel(self.root)
        dialog.title("Set Priority")
        dialog.geometry("400x400")
        dialog.configure(bg=COLORS["bg_dark"])
        dialog.transient(self.root)
        dialog.grab_set()

        dialog.update_idletasks()
        x = self.root.winfo_x() + (self.root.winfo_width() // 2) - 200
        y = self.root.winfo_y() + (self.root.winfo_height() // 2) - 200
        dialog.geometry(f"+{x}+{y}")

        tk.Label(
            dialog,
            text="  Set Priority",
            bg=COLORS["bg_dark"],
            fg=COLORS["accent_orange"],
            font=("Segoe UI", 16, "bold"),
        ).pack(pady=(20, 15))

        names_list = list(self.selected_names)
        names_display = ", ".join(names_list[:3])
        if len(names_list) > 3:
            names_display += f" (+{len(names_list) - 3} more)"

        tk.Label(
            dialog,
            text=f"Setting priority for: {names_display}",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_secondary"],
            font=("Segoe UI", 10),
            wraplength=350,
        ).pack(pady=(0, 15))

        priority_var = tk.StringVar(value="Normal")

        priorities_frame = tk.Frame(dialog, bg=COLORS["bg_dark"])
        priorities_frame.pack(pady=10)

        priority_colors = {
            "Idle": COLORS["text_muted"],
            "Below Normal": COLORS["info_light"],
            "Normal": COLORS["accent_cyan"],
            "Above Normal": COLORS["warning_light"],
            "High": COLORS["accent_orange"],
            "Realtime": COLORS["danger_light"],
        }

        for priority in [
            "Idle",
            "Below Normal",
            "Normal",
            "Above Normal",
            "High",
            "Realtime",
        ]:
            rb = tk.Radiobutton(
                priorities_frame,
                text=priority,
                variable=priority_var,
                value=priority,
                bg=COLORS["bg_dark"],
                fg=priority_colors[priority],
                selectcolor=COLORS["bg_light"],
                activebackground=COLORS["bg_dark"],
                activeforeground=priority_colors[priority],
                font=("Segoe UI", 11),
            )
            rb.pack(anchor="w", pady=5)

        tk.Label(
            dialog,
            text="Higher priority = more CPU time.\n"
            "Use with caution - High/Realtime can\n"
            "slow down other applications.",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_muted"],
            font=("Segoe UI", 9),
            justify=tk.CENTER,
        ).pack(pady=15)

        btn_frame = tk.Frame(dialog, bg=COLORS["bg_dark"])
        btn_frame.pack(pady=20)

        def apply_priority():
            priority = priority_var.get()

            for name in self.selected_names:
                if name not in self.cpu_limits:
                    self.cpu_limits[name] = {}
                self.cpu_limits[name]["priority"] = priority

            self.save_limits()
            dialog.destroy()

            # Apply immediately
            self.enforce_cpu_limits()

            messagebox.showinfo(
                "Priority Applied",
                f"Priority set to '{priority}' for {len(names_list)} process(es).",
            )
            self.refresh_processes()

        ModernButton(
            btn_frame, "  Apply", apply_priority, style="primary", width=120, height=38
        ).pack(side=tk.LEFT, padx=10)
        ModernButton(
            btn_frame, "Cancel", dialog.destroy, style="secondary", width=100, height=38
        ).pack(side=tk.LEFT)

        dialog.bind("<Escape>", lambda e: dialog.destroy())

    def show_limited_dialog(self):
        """Show dialog listing all limited processes"""
        if not self.cpu_limits:
            messagebox.showinfo(
                "No Limits",
                "No processes are currently limited.\n\n"
                "Select a process and click 'Set Affinity' or 'Set Priority' to add one.",
            )
            return

        dialog = tk.Toplevel(self.root)
        dialog.title("Limited Processes")
        dialog.geometry("550x450")
        dialog.configure(bg=COLORS["bg_dark"])
        dialog.transient(self.root)
        dialog.grab_set()

        dialog.update_idletasks()
        x = self.root.winfo_x() + (self.root.winfo_width() // 2) - 275
        y = self.root.winfo_y() + (self.root.winfo_height() // 2) - 225
        dialog.geometry(f"+{x}+{y}")

        title_label = tk.Label(
            dialog,
            text=f" Limited Processes ({len(self.cpu_limits)})",
            bg=COLORS["bg_dark"],
            fg=COLORS["limited_text"],
            font=("Segoe UI", 16, "bold"),
        )
        title_label.pack(pady=(20, 15))

        container = tk.Frame(dialog, bg=COLORS["bg_dark"])
        container.pack(fill=tk.BOTH, expand=True, padx=20, pady=(0, 10))

        canvas = tk.Canvas(container, bg=COLORS["bg_dark"], highlightthickness=0)
        scrollbar = ttk.Scrollbar(container, orient="vertical", command=canvas.yview)
        scrollable_frame = tk.Frame(canvas, bg=COLORS["bg_dark"])

        scrollable_frame.bind(
            "<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )

        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)

        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        rows = {}

        def unlimit_process(name, row_frame):
            self.cpu_limits.pop(name, None)
            self.save_limits()
            row_frame.destroy()
            rows.pop(name, None)

            if self.cpu_limits:
                title_label.config(text=f" Limited Processes ({len(self.cpu_limits)})")
            else:
                dialog.destroy()
                messagebox.showinfo(
                    "All Limits Removed", "All CPU limits have been removed."
                )

            self.refresh_processes()

        for name, limits in sorted(self.cpu_limits.items()):
            row = tk.Frame(scrollable_frame, bg=COLORS["bg_light"], pady=8, padx=10)
            row.pack(fill=tk.X, pady=3)
            rows[name] = row

            info_frame = tk.Frame(row, bg=COLORS["bg_light"])
            info_frame.pack(side=tk.LEFT, fill=tk.X, expand=True)

            tk.Label(
                info_frame,
                text=name,
                bg=COLORS["bg_light"],
                fg=COLORS["text_primary"],
                font=("Segoe UI Semibold", 11),
                anchor="w",
            ).pack(anchor="w")

            details = []
            if "cores" in limits:
                details.append(f"Cores: {limits['cores']}")
            if "priority" in limits:
                details.append(f"Priority: {limits['priority']}")

            tk.Label(
                info_frame,
                text="  |  ".join(details),
                bg=COLORS["bg_light"],
                fg=COLORS["accent_cyan"],
                font=("Consolas", 9),
                anchor="w",
            ).pack(anchor="w")

            unlimit_btn = tk.Button(
                row,
                text=" Unlimit",
                bg=COLORS["btn_danger"],
                fg="#ffffff",
                font=("Segoe UI", 9),
                relief=tk.FLAT,
                cursor="hand2",
                padx=10,
                pady=4,
                command=lambda n=name, r=row: unlimit_process(n, r),
            )
            unlimit_btn.pack(side=tk.RIGHT, padx=(10, 0))

        btn_frame = tk.Frame(dialog, bg=COLORS["bg_dark"])
        btn_frame.pack(pady=15)

        ModernButton(
            btn_frame, "Close", dialog.destroy, style="secondary", width=100, height=38
        ).pack()

        dialog.bind("<Escape>", lambda e: dialog.destroy())

    def enforce_cpu_limits(self):
        """Enforce CPU affinity and priority limits on all limited processes"""
        if not self.cpu_limits:
            return 0

        enforced_count = 0

        for name, limits in list(self.cpu_limits.items()):
            pids = []

            # Get all PIDs for this process/group
            if (
                hasattr(self, "group_to_original_names")
                and name in self.group_to_original_names
            ):
                original_names = self.group_to_original_names[name]
                for proc in self.raw_processes:
                    if proc["name"] in original_names:
                        pids.append(proc["pid"])
            else:
                for proc in self.raw_processes:
                    if proc["name"] == name:
                        pids.append(proc["pid"])

            # Also check APP_GROUPS
            if name.endswith("(Total)"):
                for proc in self.raw_processes:
                    group_name = APP_GROUPS.get(proc["name"].lower())
                    if group_name == name and proc["pid"] not in pids:
                        pids.append(proc["pid"])

            for pid in pids:
                try:
                    proc = psutil.Process(pid)

                    # Set affinity
                    if "cores" in limits:
                        try:
                            proc.cpu_affinity(limits["cores"])
                            enforced_count += 1
                        except (psutil.AccessDenied, psutil.NoSuchProcess):
                            pass

                    # Set priority
                    if "priority" in limits:
                        try:
                            priority_class = PRIORITY_CLASSES.get(
                                limits["priority"], psutil.NORMAL_PRIORITY_CLASS
                            )
                            proc.nice(priority_class)
                        except (psutil.AccessDenied, psutil.NoSuchProcess):
                            pass

                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue

        return enforced_count

    def is_startup_service_installed(self):
        """Check if startup task is installed"""
        return is_startup_task_installed()

    def toggle_startup_service(self):
        """Toggle the background limit service on/off"""
        is_installed = self.is_startup_service_installed()

        if is_installed:
            if messagebox.askyesno(
                "Disable Auto-Start",
                "CPU limits will NO LONGER be enforced automatically at Windows startup.\n\n"
                "Disable auto-start?",
            ):
                if uninstall_startup_task():
                    messagebox.showinfo(
                        "Auto-Start Disabled", "Background service has been disabled."
                    )
                    self.startup_btn.style = "secondary"
                    self.startup_btn.draw_button()
                else:
                    messagebox.showerror("Error", "Failed to disable auto-start")
        else:
            if not self.cpu_limits:
                messagebox.showinfo(
                    "No Limits Set",
                    "You haven't set any CPU limits yet.\n\n"
                    "Set some limits first, then enable auto-start.",
                )
                return

            if messagebox.askyesno(
                "Enable Auto-Start",
                "This will install a background service that runs at Windows startup.\n\n"
                "Your current CPU limits will be enforced automatically.\n\n"
                "Enable auto-start?",
            ):
                if install_startup_task():
                    messagebox.showinfo(
                        "Auto-Start Enabled",
                        "Background service installed successfully!",
                    )
                    self.startup_btn.style = "success"
                    self.startup_btn.draw_button()
                else:
                    messagebox.showerror(
                        "Error",
                        "Failed to install startup task. Try running as administrator.",
                    )

    def start_monitoring(self):
        def monitor_loop():
            while self.running:
                try:
                    self.root.after(0, self.refresh_processes)
                except:
                    break
                time.sleep(self.update_interval / 1000)

        self.monitor_thread = Thread(target=monitor_loop, daemon=True)
        self.monitor_thread.start()
        self.refresh_processes()

    def on_close(self):
        self.running = False
        self.root.destroy()


def check_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False


def run_background_service():
    """Run as background service - no GUI, just enforce CPU limits continuously"""
    import logging

    log_file = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "cpu_service.log"
    )
    logging.basicConfig(
        filename=log_file,
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
    )
    logging.info("CPU Limit Background Service started")

    last_limits = {}

    while True:
        try:
            limits = {}
            if os.path.exists(LIMITS_FILE):
                try:
                    with open(LIMITS_FILE, "r", encoding="utf-8") as f:
                        data = json.load(f)
                        limits = data.get("limits", {})
                except:
                    pass

            if limits != last_limits:
                logging.info(f"Limits updated: {limits}")
                last_limits = limits.copy()

            if limits:
                for proc in psutil.process_iter(["pid", "name"]):
                    try:
                        info = proc.info
                        name = info["name"]

                        # Check direct match or group match
                        limit_config = limits.get(name) or limits.get(
                            APP_GROUPS.get(name.lower())
                        )

                        if limit_config:
                            p = psutil.Process(info["pid"])

                            if "cores" in limit_config:
                                try:
                                    p.cpu_affinity(limit_config["cores"])
                                except:
                                    pass

                            if "priority" in limit_config:
                                try:
                                    priority_class = PRIORITY_CLASSES.get(
                                        limit_config["priority"],
                                        psutil.NORMAL_PRIORITY_CLASS,
                                    )
                                    p.nice(priority_class)
                                except:
                                    pass
                    except:
                        continue

            time.sleep(3)
        except Exception as e:
            logging.error(f"Service error: {e}")
            time.sleep(5)


def install_startup_task():
    """Install Windows Scheduled Task to run at startup"""
    script_path = os.path.abspath(__file__)
    task_name = "CPUMonitorLimitService"

    xml_content = f'''<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>CPU Monitor Pro - Background Limit Enforcer</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>pythonw</Command>
      <Arguments>"{script_path}" --service</Arguments>
      <WorkingDirectory>{os.path.dirname(script_path)}</WorkingDirectory>
    </Exec>
  </Actions>
</Task>'''

    xml_path = os.path.join(os.environ.get("TEMP", "."), "cpu_limit_task.xml")
    try:
        with open(xml_path, "w", encoding="utf-16") as f:
            f.write(xml_content)

        subprocess.run(
            ["schtasks", "/delete", "/tn", task_name, "/f"],
            capture_output=True,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )

        result = subprocess.run(
            ["schtasks", "/create", "/tn", task_name, "/xml", xml_path],
            capture_output=True,
            text=True,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )

        os.remove(xml_path)
        return result.returncode == 0
    except:
        try:
            os.remove(xml_path)
        except:
            pass
        return False


def uninstall_startup_task():
    """Remove the Windows Scheduled Task"""
    try:
        result = subprocess.run(
            ["schtasks", "/delete", "/tn", "CPUMonitorLimitService", "/f"],
            capture_output=True,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        return result.returncode == 0
    except:
        return False


def is_startup_task_installed():
    """Check if startup task is installed"""
    try:
        result = subprocess.run(
            ["schtasks", "/query", "/tn", "CPUMonitorLimitService"],
            capture_output=True,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        return result.returncode == 0
    except:
        return False


def main():
    # Add error logging for frozen executable debugging
    log_file = None
    try:
        # Check if we're running as a frozen executable
        if getattr(sys, 'frozen', False):
            # Create a log file for debugging
            log_file = open('cpu_monitor_debug.log', 'w')
            log_file.write(f"Starting CPU Monitor at {datetime.now()}\n")
            log_file.flush()
        
        if len(sys.argv) > 1:
            cmd = sys.argv[1].lower()
            if cmd == "--service":
                run_background_service()
                return
            elif cmd == "--install":
                if install_startup_task():
                    print(" Startup task installed successfully!")
                else:
                    print(" Failed to install startup task")
                return
            elif cmd == "--uninstall":
                if uninstall_startup_task():
                    print(" Startup task removed successfully!")
                else:
                    print(" Failed to remove startup task")
                return

        # Normal GUI mode - create root first for frozen apps
        root = tk.Tk()
        root.withdraw()  # Hide initially
        
        if log_file:
            log_file.write("Root window created\n")
            log_file.flush()

        # Check admin after creating root to avoid messagebox issues
        if not check_admin():
            if log_file:
                log_file.write("Not running as admin, asking user\n")
                log_file.flush()
                
            if messagebox.askyesno(
                "Administrator Rights",
                "This app works best with administrator rights.\n"
                "Some processes may not be accessible.\n\n"
                "Restart as administrator?",
            ):
                try:
                    ctypes.windll.shell32.ShellExecuteW(
                        None, "runas", sys.executable, " ".join(sys.argv), None, 1
                    )
                    sys.exit()
                except Exception as e:
                    if log_file:
                        log_file.write(f"Failed to elevate: {e}\n")
                        log_file.flush()
                    messagebox.showwarning("Warning", "Could not get admin rights.")

        # Show the window and start the app
        root.deiconify()
        if log_file:
            log_file.write("Creating CPUMonitorApp\n")
            log_file.flush()
            
        app = CPUMonitorApp(root)
        if log_file:
            log_file.write("Starting mainloop\n")
            log_file.flush()
            
        root.mainloop()
        
    except Exception as e:
        if log_file:
            log_file.write(f"FATAL ERROR: {e}\n")
            import traceback
            log_file.write(traceback.format_exc())
            log_file.flush()
        
        # Try to show error in a simple way
        try:
            import tkinter.messagebox as mb
            root = tk.Tk()
            root.withdraw()
            mb.showerror("CPU Monitor Error", f"Fatal error: {e}")
        except:
            # Last resort - write to console
            print(f"FATAL ERROR: {e}")
            import traceback
            traceback.print_exc()
    finally:
        if log_file:
            log_file.close()


if __name__ == "__main__":
    main()
