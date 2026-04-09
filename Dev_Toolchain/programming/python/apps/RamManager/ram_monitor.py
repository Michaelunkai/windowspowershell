"""
RAM Monitor Pro - Professional Real-time Process Memory Manager
A stunning, modern UI for monitoring and managing system memory
"""

import tkinter as tk
from tkinter import ttk, messagebox
import psutil
import ctypes
import sys
import os
import json
import subprocess
import re
from threading import Thread
import time
from datetime import datetime

# Path for persistent RAM limits storage
LIMITS_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "ram_limits.json"
)

# Windows API constants
PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_VM_READ = 0x0010
PROCESS_SET_QUOTA = 0x0100
PROCESS_VM_OPERATION = 0x0008
QUOTA_LIMITS_HARDWS_MAX_ENABLE = 0x00000004
QUOTA_LIMITS_HARDWS_MIN_DISABLE = 0x00000002

# ============================================================================
# PREMIUM COLOR PALETTE - Modern Dark Theme
# ============================================================================
COLORS = {
    # Background colors
    "bg_dark": "#0d1117",  # GitHub dark background
    "bg_medium": "#161b22",  # Slightly lighter
    "bg_light": "#21262d",  # Card backgrounds
    "bg_hover": "#30363d",  # Hover states
    # Header gradient
    "header_start": "#1a1f2c",  # Deep blue-gray
    "header_end": "#0d1117",  # Fade to main bg
    # Text colors
    "text_primary": "#f0f6fc",  # Bright white
    "text_secondary": "#8b949e",  # Muted gray
    "text_muted": "#6e7681",  # Very muted
    # Accent colors
    "accent_blue": "#58a6ff",  # Primary blue
    "accent_cyan": "#39d353",  # Success green
    "accent_purple": "#a371f7",  # Purple accent
    # Status colors
    "success": "#238636",  # Green
    "success_light": "#2ea043",  # Light green
    "warning": "#d29922",  # Yellow/orange
    "warning_light": "#e3b341",  # Light warning
    "danger": "#da3633",  # Red
    "danger_light": "#f85149",  # Light red
    "info": "#1f6feb",  # Blue
    "info_light": "#388bfd",  # Light blue
    # Critical process colors
    "critical_bg": "#3d1a1a",  # Dark red background
    "critical_text": "#ff6b6b",  # Bright red text
    "critical_border": "#6e2d2d",  # Red border
    # Selection colors
    "selected_bg": "#1f3a5f",  # Blue selection
    "selected_border": "#388bfd",  # Blue border
    # RAM Limit colors
    "limited_bg": "#2d1f3d",  # Purple background for limited
    "limited_text": "#c084fc",  # Purple text
    "limited_border": "#7c3aed",  # Purple border
    # Docker container colors
    "docker_bg": "#1a2f3d",  # Dark blue-cyan background
    "docker_text": "#2dd4bf",  # Teal/cyan text
    "docker_border": "#14b8a6",  # Teal border
    # WSL/vmmem colors
    "wsl_bg": "#2d2d1f",  # Dark yellow-brown background
    "wsl_text": "#fbbf24",  # Amber/yellow text
    # Progress bar colors
    "progress_low": "#238636",  # Green (0-50%)
    "progress_medium": "#d29922",  # Yellow (50-75%)
    "progress_high": "#da3633",  # Red (75-100%)
    "progress_bg": "#21262d",  # Background
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
}

# ============================================================================
# APPLICATION GROUPING - Combine multi-process apps into single entries
# ============================================================================
# Maps individual process names to their parent application group
APP_GROUPS = {
    # Docker - all Docker processes combined into one
    "docker desktop.exe": "Docker (Total)",
    "com.docker.backend.exe": "Docker (Total)",
    "com.docker.service": "Docker (Total)",
    "com.docker.build.exe": "Docker (Total)",
    "docker-buildx.exe": "Docker (Total)",
    "docker.exe": "Docker (Total)",
    "dockerd.exe": "Docker (Total)",
    "vpnkit.exe": "Docker (Total)",
    # Chrome - all Chrome processes combined
    "chrome.exe": "Chrome (Total)",
    # Firefox
    "firefox.exe": "Firefox (Total)",
    # Edge
    "msedge.exe": "Edge (Total)",
    # VS Code
    "code.exe": "VS Code (Total)",
    # Electron apps
    "electron.exe": "Electron Apps",
    # Microsoft Office
    "winword.exe": "Microsoft Office",
    "excel.exe": "Microsoft Office",
    "powerpnt.exe": "Microsoft Office",
    "outlook.exe": "Microsoft Office",
    # JetBrains IDEs
    "idea64.exe": "JetBrains IDE",
    "pycharm64.exe": "JetBrains IDE",
    "webstorm64.exe": "JetBrains IDE",
    "rider64.exe": "JetBrains IDE",
    "clion64.exe": "JetBrains IDE",
    "goland64.exe": "JetBrains IDE",
    "phpstorm64.exe": "JetBrains IDE",
    "datagrip64.exe": "JetBrains IDE",
    # Slack
    "slack.exe": "Slack (Total)",
    # Discord
    "discord.exe": "Discord (Total)",
    # Teams
    "teams.exe": "Teams (Total)",
    "ms-teams.exe": "Teams (Total)",
    # Spotify
    "spotify.exe": "Spotify (Total)",
    # Node.js (group all node processes)
    "node.exe": "Node.js (Total)",
    # Java apps
    "java.exe": "Java Apps",
    "javaw.exe": "Java Apps",
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
    "lsaiso.exe",
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
    "searchhost.exe",
    "explorer.exe",
    "shellexperiencehost.exe",
    "startmenuexperiencehost.exe",
    "textinputhost.exe",
    "applicationframehost.exe",
    "securityhealthservice.exe",
    "securityhealthsystray.exe",
    "msmpeng.exe",
    "smartscreen.exe",
    "memcompression",
    "memory compression",
    "audiodg.exe",
    "spoolsv.exe",
    "trustedinstaller.exe",
    "dllhost.exe",
    "wmiprvse.exe",
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

        # Style configurations
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
        }

        self.draw_button()

        # Bind events
        self.bind("<Enter>", self.on_enter)
        self.bind("<Leave>", self.on_leave)
        self.bind("<Button-1>", self.on_click)
        self.bind("<ButtonRelease-1>", self.on_release)

    def draw_button(self):
        self.delete("all")
        colors = self.styles.get(self.style, self.styles["primary"])
        bg_color = colors[1] if self.is_hovered else colors[0]
        text_color = colors[2]

        # Draw rounded rectangle
        radius = 8
        self.create_rounded_rect(
            2, 2, self.width - 2, self.height - 2, radius, fill=bg_color, outline=""
        )

        # Draw text
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

        # Background
        self.create_rounded_rect(
            0,
            0,
            self.width,
            self.height,
            radius,
            fill=COLORS["progress_bg"],
            outline=COLORS["border"],
        )

        # Progress fill
        if self.value > 0:
            fill_width = max(radius * 2, (self.width - 4) * (self.value / 100))

            # Color based on value
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

        # Percentage text
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


class RAMMonitorApp:
    """Professional RAM Monitor Application"""

    def __init__(self, root):
        self.root = root
        self.root.title("RAM Monitor Pro")
        self.root.geometry("1300x850")
        self.root.minsize(1100, 700)
        self.root.configure(bg=COLORS["bg_dark"])

        # Center window on screen
        self.center_window()

        # State
        self.running = True
        self.update_interval = 1500
        self.grouped_view = tk.BooleanVar(value=True)
        self.raw_processes = []
        self.grouped_processes = []
        self.name_to_pids = {}
        self.selected_names = set()
        self.last_update = None
        self.live_indicator_state = True
        self.ram_limits = {}  # {process_name: limit_mb}
        self.known_pids = set()  # Track PIDs we've already applied limits to
        self.docker_running = False  # Track if Docker is running

        # Load persistent limits from disk
        self.load_limits()

        self.setup_styles()
        self.create_ui()
        self.start_monitoring()

        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

    def center_window(self):
        self.root.update_idletasks()
        width = 1300
        height = 850
        x = (self.root.winfo_screenwidth() // 2) - (width // 2)
        y = (self.root.winfo_screenheight() // 2) - (height // 2)
        self.root.geometry(f"{width}x{height}+{x}+{y}")

    def load_limits(self):
        """Load RAM limits from persistent storage"""
        try:
            if os.path.exists(LIMITS_FILE):
                with open(LIMITS_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    self.ram_limits = data.get("limits", {})
                    # Convert any string keys to proper format
                    self.ram_limits = {
                        str(k): int(v) for k, v in self.ram_limits.items()
                    }
        except (json.JSONDecodeError, IOError, ValueError) as e:
            # If file is corrupted, start fresh
            self.ram_limits = {}

    def save_limits(self):
        """Save RAM limits to persistent storage"""
        try:
            data = {
                "limits": self.ram_limits,
                "last_updated": datetime.now().isoformat(),
            }
            with open(LIMITS_FILE, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
        except IOError as e:
            # Silently fail - limits will still work in memory
            pass

    def setup_styles(self):
        style = ttk.Style()
        style.theme_use("clam")

        # Frame styles
        style.configure("Dark.TFrame", background=COLORS["bg_dark"])
        style.configure("Card.TFrame", background=COLORS["bg_light"])

        # Label styles
        style.configure(
            "Title.TLabel",
            background=COLORS["bg_dark"],
            foreground=COLORS["text_primary"],
            font=("Segoe UI", 28, "bold"),
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
            "Muted.TLabel",
            background=COLORS["bg_dark"],
            foreground=COLORS["text_muted"],
            font=("Segoe UI", 9),
        )

        # Checkbox style
        style.configure(
            "Dark.TCheckbutton",
            background=COLORS["bg_dark"],
            foreground=COLORS["text_primary"],
            font=("Segoe UI", 10),
        )
        style.map("Dark.TCheckbutton", background=[("active", COLORS["bg_dark"])])

        # Treeview style - Modern table look
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

        style.map(
            "Modern.Treeview.Heading", background=[("active", COLORS["bg_hover"])]
        )

        # Scrollbar style
        style.configure(
            "Dark.Vertical.TScrollbar",
            background=COLORS["bg_light"],
            troughcolor=COLORS["bg_medium"],
            borderwidth=0,
            arrowsize=14,
        )
        style.map(
            "Dark.Vertical.TScrollbar", background=[("active", COLORS["bg_hover"])]
        )

    def create_ui(self):
        # Main container
        main = ttk.Frame(self.root, style="Dark.TFrame")
        main.pack(fill=tk.BOTH, expand=True, padx=20, pady=15)

        # === HEADER SECTION ===
        self.create_header(main)

        # === TOOLBAR SECTION ===
        self.create_toolbar(main)

        # === TABLE SECTION ===
        self.create_table(main)

        # === FOOTER SECTION ===
        self.create_footer(main)

    def create_header(self, parent):
        header = ttk.Frame(parent, style="Dark.TFrame")
        header.pack(fill=tk.X, pady=(0, 20))

        # Left side - Title and subtitle
        left = ttk.Frame(header, style="Dark.TFrame")
        left.pack(side=tk.LEFT, fill=tk.Y)

        # App icon and title row
        title_row = ttk.Frame(left, style="Dark.TFrame")
        title_row.pack(anchor="w")

        # Memory icon
        icon_label = tk.Label(
            title_row,
            text="",
            font=("Segoe UI", 32),
            bg=COLORS["bg_dark"],
            fg=COLORS["accent_blue"],
        )
        icon_label.pack(side=tk.LEFT, padx=(0, 12))

        title_text = ttk.Frame(title_row, style="Dark.TFrame")
        title_text.pack(side=tk.LEFT)

        ttk.Label(title_text, text="RAM Monitor Pro", style="Title.TLabel").pack(
            anchor="w"
        )
        ttk.Label(
            title_text,
            text="Real-time Process Memory Manager  v2.0",
            style="Subtitle.TLabel",
        ).pack(anchor="w")

        # Right side - RAM Stats
        right = ttk.Frame(header, style="Dark.TFrame")
        right.pack(side=tk.RIGHT, fill=tk.Y)

        # Stats container
        stats_box = tk.Frame(right, bg=COLORS["bg_light"], padx=20, pady=15)
        stats_box.pack()

        # RAM Usage title with live indicator
        stats_title_row = tk.Frame(stats_box, bg=COLORS["bg_light"])
        stats_title_row.pack(fill=tk.X, pady=(0, 8))

        tk.Label(
            stats_title_row,
            text="SYSTEM MEMORY",
            bg=COLORS["bg_light"],
            fg=COLORS["text_muted"],
            font=("Segoe UI Semibold", 9),
        ).pack(side=tk.LEFT)

        # Live indicator dot
        self.live_dot = tk.Label(
            stats_title_row,
            text="",
            bg=COLORS["bg_light"],
            fg=COLORS["accent_cyan"],
            font=("Segoe UI", 10),
        )
        self.live_dot.pack(side=tk.RIGHT)

        # Big percentage display
        self.percent_label = tk.Label(
            stats_box,
            text="0.0%",
            bg=COLORS["bg_light"],
            fg=COLORS["accent_cyan"],
            font=("Segoe UI", 36, "bold"),
        )
        self.percent_label.pack()

        # Progress bar
        self.ram_progress = ProgressBar(stats_box, width=280, height=22)
        self.ram_progress.pack(pady=(5, 10))

        # Detailed stats
        self.stats_detail = tk.Label(
            stats_box,
            text="Loading...",
            bg=COLORS["bg_light"],
            fg=COLORS["text_secondary"],
            font=("Consolas", 10),
            justify=tk.CENTER,
        )
        self.stats_detail.pack()

        # Limited apps badge
        self.limited_badge = tk.Label(
            stats_box,
            text="",
            bg=COLORS["bg_light"],
            fg=COLORS["limited_text"],
            font=("Segoe UI Semibold", 9),
        )
        self.limited_badge.pack(pady=(5, 0))

        # Separator line
        sep = tk.Frame(parent, bg=COLORS["border"], height=1)
        sep.pack(fill=tk.X, pady=(0, 15))

    def create_toolbar(self, parent):
        toolbar = ttk.Frame(parent, style="Dark.TFrame")
        toolbar.pack(fill=tk.X, pady=(0, 12))

        # Left side - Search and options
        left = ttk.Frame(toolbar, style="Dark.TFrame")
        left.pack(side=tk.LEFT)

        # Search box with icon
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

        # Group checkbox
        self.grouped_check = ttk.Checkbutton(
            left,
            text="  Group by Application",
            variable=self.grouped_view,
            style="Dark.TCheckbutton",
            command=self.filter_processes,
        )
        self.grouped_check.pack(side=tk.LEFT, padx=(0, 20))

        # Right side - Selection info and clear button
        right = ttk.Frame(toolbar, style="Dark.TFrame")
        right.pack(side=tk.RIGHT)

        # Selection badge
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

        # Clear selection button
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
        # Table container with border
        table_container = tk.Frame(parent, bg=COLORS["border"], padx=1, pady=1)
        table_container.pack(fill=tk.BOTH, expand=True)

        table_inner = tk.Frame(table_container, bg=COLORS["bg_medium"])
        table_inner.pack(fill=tk.BOTH, expand=True)

        # Columns
        columns = ("icon", "instances", "name", "memory_mb", "memory_percent", "status")
        self.tree = ttk.Treeview(
            table_inner,
            columns=columns,
            show="headings",
            style="Modern.Treeview",
            selectmode="none",
        )

        # Configure columns
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
            "memory_mb",
            text="Memory (MB)",
            command=lambda: self.sort_column("memory_mb", True),
        )
        self.tree.heading(
            "memory_percent",
            text="Memory %",
            command=lambda: self.sort_column("memory_percent", True),
        )
        self.tree.heading(
            "status", text="Status", command=lambda: self.sort_column("status", False)
        )

        self.tree.column("icon", width=40, anchor="center", stretch=False)
        self.tree.column("instances", width=70, anchor="center", stretch=False)
        self.tree.column("name", width=350, anchor="w")
        self.tree.column("memory_mb", width=150, anchor="e")
        self.tree.column("memory_percent", width=120, anchor="e")
        self.tree.column("status", width=100, anchor="center")

        # Scrollbar
        scrollbar = ttk.Scrollbar(
            table_inner,
            orient=tk.VERTICAL,
            command=self.tree.yview,
            style="Dark.Vertical.TScrollbar",
        )
        self.tree.configure(yscrollcommand=scrollbar.set)

        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # Bind click event
        self.tree.bind("<Button-1>", self.on_tree_click)

        # Configure row tags
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
            "docker",
            foreground=COLORS["docker_text"],
            background=COLORS["docker_bg"],
        )
        self.tree.tag_configure(
            "wsl",
            foreground=COLORS["wsl_text"],
            background=COLORS["wsl_bg"],
        )

        # Sort state
        self.sort_reverse = True
        self.sort_column_name = "memory_mb"

    def create_footer(self, parent):
        footer = ttk.Frame(parent, style="Dark.TFrame")
        footer.pack(fill=tk.X, pady=(15, 0))

        # Buttons row
        btn_row = ttk.Frame(footer, style="Dark.TFrame")
        btn_row.pack(fill=tk.X, pady=(0, 12))

        # Left buttons
        btn_left = ttk.Frame(btn_row, style="Dark.TFrame")
        btn_left.pack(side=tk.LEFT)

        self.kill_btn = ModernButton(
            btn_left,
            "  Force Close",
            self.kill_selected,
            style="danger",
            width=160,
            height=42,
        )
        self.kill_btn.pack(side=tk.LEFT, padx=(0, 10))

        self.refresh_btn = ModernButton(
            btn_left,
            "  Refresh",
            self.refresh_processes,
            style="success",
            width=130,
            height=42,
        )
        self.refresh_btn.pack(side=tk.LEFT, padx=(0, 10))

        self.free_btn = ModernButton(
            btn_left, "  Free RAM", self.free_ram, style="info", width=130, height=42
        )
        self.free_btn.pack(side=tk.LEFT, padx=(0, 10))

        self.limit_btn = ModernButton(
            btn_left,
            "  Set RAM Limit",
            self.show_limit_dialog,
            style="purple",
            width=160,
            height=42,
        )
        self.limit_btn.pack(side=tk.LEFT, padx=(0, 10))

        self.show_limited_btn = ModernButton(
            btn_left,
            "  Limited",
            self.show_limited_dialog,
            style="secondary",
            width=120,
            height=42,
        )
        self.show_limited_btn.pack(side=tk.LEFT, padx=(0, 10))

        # Startup service toggle button
        self.startup_btn = ModernButton(
            btn_left,
            "  Auto-Start",
            self.toggle_startup_service,
            style="success" if self.is_startup_service_installed() else "secondary",
            width=130,
            height=42,
        )
        self.startup_btn.pack(side=tk.LEFT)

        # Right - Process count
        self.count_label = tk.Label(
            btn_row,
            text="",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_secondary"],
            font=("Segoe UI", 11),
        )
        self.count_label.pack(side=tk.RIGHT)

        # Legend row
        legend_frame = ttk.Frame(footer, style="Dark.TFrame")
        legend_frame.pack(fill=tk.X)

        # Legend items
        legends = [
            ("  CRITICAL", COLORS["critical_text"], COLORS["critical_bg"]),
            ("  High Memory", COLORS["danger_light"], COLORS["bg_dark"]),
            ("  Docker", COLORS["docker_text"], COLORS["docker_bg"]),
            ("  WSL", COLORS["wsl_text"], COLORS["wsl_bg"]),
            ("  Selected", COLORS["text_primary"], COLORS["selected_bg"]),
            ("  RAM Limited", COLORS["limited_text"], COLORS["limited_bg"]),
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

        # Last update time
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

        name = values[2]  # Name is index 2 now

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

                self.tree.item(item_id, tags=current_tags)

    def is_critical_process(self, name):
        return name.lower() in CRITICAL_PROCESSES

    def get_processes(self):
        processes = []
        for proc in psutil.process_iter(
            ["pid", "name", "memory_info", "memory_percent", "status"]
        ):
            try:
                info = proc.info
                memory_bytes = info["memory_info"].rss if info["memory_info"] else 0
                memory_mb = memory_bytes / (1024 * 1024)
                memory_percent = info["memory_percent"] or 0.0

                processes.append(
                    {
                        "pid": info["pid"],
                        "name": info["name"] or "Unknown",
                        "memory_bytes": memory_bytes,
                        "memory_mb": memory_mb,
                        "memory_percent": memory_percent,
                        "status": info["status"] or "unknown",
                        "is_critical": self.is_critical_process(info["name"] or ""),
                    }
                )
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
        return processes

    def get_docker_container_stats(self):
        """Get memory usage of Docker containers via docker stats command.

        Docker containers on Windows run inside WSL2/Hyper-V, so their memory
        doesn't show up in regular Windows process listings. This method queries
        Docker directly to get actual container memory usage.

        Returns a list of container stats with memory in MB.
        """
        containers = []
        try:
            # Check if Docker is available and running
            # Use CREATE_NO_WINDOW flag on Windows to hide console
            startupinfo = None
            creationflags = 0
            if sys.platform == "win32":
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startupinfo.wShowWindow = subprocess.SW_HIDE
                creationflags = subprocess.CREATE_NO_WINDOW

            result = subprocess.run(
                [
                    "docker",
                    "stats",
                    "--no-stream",
                    "--format",
                    "{{.Name}}|{{.MemUsage}}|{{.MemPerc}}|{{.Container}}",
                ],
                capture_output=True,
                text=True,
                timeout=5,
                startupinfo=startupinfo,
                creationflags=creationflags,
            )

            if result.returncode != 0:
                return containers

            total_memory = psutil.virtual_memory().total

            for line in result.stdout.strip().split("\n"):
                if not line or "|" not in line:
                    continue

                parts = line.split("|")
                if len(parts) >= 3:
                    name = parts[0].strip()
                    mem_usage = parts[1].strip()  # e.g., "1.5GiB / 7.7GiB"
                    mem_percent_str = parts[2].strip().replace("%", "")
                    container_id = parts[3].strip() if len(parts) > 3 else ""

                    # Parse memory usage to MB
                    memory_mb = self._parse_docker_memory(mem_usage)

                    try:
                        mem_percent = float(mem_percent_str)
                    except ValueError:
                        # Calculate percentage from memory if not available
                        mem_percent = (
                            (memory_mb * 1024 * 1024 / total_memory) * 100
                            if total_memory > 0
                            else 0.0
                        )

                    if memory_mb > 0:
                        containers.append(
                            {
                                "name": name,
                                "display_name": f"[Docker] {name}",
                                "container_id": container_id,
                                "memory_mb": memory_mb,
                                "memory_bytes": int(memory_mb * 1024 * 1024),
                                "memory_percent": mem_percent,
                                "status": "running",
                                "is_critical": False,
                                "is_docker": True,
                            }
                        )
        except FileNotFoundError:
            # Docker CLI not installed
            pass
        except subprocess.TimeoutExpired:
            # Docker daemon not responding
            pass
        except Exception:
            # Any other error - just skip Docker stats
            pass

        return containers

    def _parse_docker_memory(self, mem_string):
        """Parse Docker memory string like '1.5GiB / 7.7GiB' to MB."""
        try:
            # Get just the used memory (before the /)
            used_part = mem_string.split("/")[0].strip()

            # Extract number and unit
            match = re.match(r"([\d.]+)\s*(\w+)", used_part)
            if not match:
                return 0.0

            value = float(match.group(1))
            unit = match.group(2).upper()

            # Convert to MB
            if "GIB" in unit or "GB" in unit:
                return value * 1024
            elif "MIB" in unit or "MB" in unit:
                return value
            elif "KIB" in unit or "KB" in unit:
                return value / 1024
            elif "B" in unit and not any(x in unit for x in ["K", "M", "G"]):
                return value / (1024 * 1024)
            else:
                return value  # Assume MB
        except Exception:
            return 0.0

    def group_processes(self, processes):
        """Group processes by application, combining multi-process apps into single entries.

        Uses APP_GROUPS mapping to combine related processes (e.g., all Docker processes
        become one "Docker (Total)" entry showing combined RAM usage).
        """
        groups = {}
        # Track original process names for each group (for RAM limit matching)
        self.group_to_original_names = {}

        for proc in processes:
            original_name = proc["name"]
            # Check if this process should be grouped with others
            group_name = APP_GROUPS.get(original_name.lower(), original_name)

            if group_name not in groups:
                groups[group_name] = {
                    "pids": [],
                    "memory_bytes": 0,
                    "memory_mb": 0.0,
                    "memory_percent": 0.0,
                    "statuses": set(),
                    "is_critical": proc["is_critical"],
                    "original_names": set(),  # Track which processes are in this group
                }
            groups[group_name]["pids"].append(proc["pid"])
            groups[group_name]["memory_bytes"] += proc["memory_bytes"]
            groups[group_name]["memory_mb"] += proc["memory_mb"]
            groups[group_name]["memory_percent"] += proc["memory_percent"]
            groups[group_name]["statuses"].add(proc["status"])
            groups[group_name]["original_names"].add(original_name)

        grouped = []
        self.name_to_pids = {}
        self.group_to_original_names = {}

        for name, data in groups.items():
            pids_list = data["pids"]
            statuses_set = data["statuses"]

            self.name_to_pids[name] = pids_list
            self.group_to_original_names[name] = data["original_names"]

            if statuses_set == {"running"}:
                status = "running"
            elif len(statuses_set) > 1:
                status = "mixed"
            else:
                status = list(statuses_set)[0]

            # Determine if this is a grouped app (multiple original process names or high count)
            is_grouped_app = len(data["original_names"]) > 1 or (
                name.endswith("(Total)") and len(pids_list) > 1
            )

            grouped.append(
                {
                    "instances": len(pids_list),
                    "name": name,
                    "memory_bytes": data["memory_bytes"],
                    "memory_mb": data["memory_mb"],
                    "memory_percent": data["memory_percent"],
                    "status": status,
                    "pids": pids_list,
                    "is_critical": data["is_critical"],
                    "is_grouped": is_grouped_app,
                    "original_names": data["original_names"],
                }
            )

        return grouped

    def update_tree(self, processes):
        for item in self.tree.get_children():
            self.tree.delete(item)

        if self.sort_column_name == "instances" and not self.grouped_view.get():
            sort_key = "memory_mb"
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

            # Row color alternation
            if idx % 2 == 0:
                tags.append("evenrow")
            else:
                tags.append("oddrow")

            # Check if process has RAM limit
            has_limit = proc["name"] in self.ram_limits
            limit_mb = self.ram_limits.get(proc["name"], 0)
            over_limit = has_limit and proc["memory_mb"] > limit_mb

            # Status-based coloring
            if proc.get("is_critical", False):
                tags = ["critical"]  # Override row color for critical
            elif proc.get("is_docker", False):
                tags = ["docker"]  # Docker container styling
            elif proc.get("is_wsl", False):
                tags = ["wsl"]  # WSL/vmmem styling
            elif has_limit:
                tags = ["limited"]  # Override for limited processes
            elif proc["memory_percent"] > 10:
                tags.append("high")
            elif proc["memory_percent"] > 5:
                tags.append("medium")

            if proc["name"] in self.selected_names:
                tags.append("selected")

            # Icon based on type
            if proc.get("is_critical", False):
                icon = ""  # Warning
            elif proc.get("is_docker", False):
                icon = ""  # Docker whale icon
            elif proc.get("is_wsl", False):
                icon = ""  # Linux/WSL icon
            elif has_limit:
                icon = "" if over_limit else ""  # Lock or check for limited
            elif proc["memory_percent"] > 10:
                icon = ""  # High
            else:
                icon = ""  # App

            instances = proc.get("instances", 1)

            # Format values - cleaner display
            if has_limit:
                mem_mb = f"{proc['memory_mb']:,.1f} / {limit_mb}"
            else:
                mem_mb = f"{proc['memory_mb']:,.2f}"
            mem_pct = f"{proc['memory_percent']:.2f}%"

            self.tree.insert(
                "",
                tk.END,
                values=(
                    icon,
                    instances if instances > 1 else "1",
                    proc["name"],
                    mem_mb,
                    mem_pct,
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
        mem = psutil.virtual_memory()
        total_gb = mem.total / (1024**3)
        used_gb = mem.used / (1024**3)
        available_gb = mem.available / (1024**3)

        # Update percentage display
        self.percent_label.config(text=f"{mem.percent:.1f}%")

        # Color based on usage
        if mem.percent > 80:
            color = COLORS["danger_light"]
        elif mem.percent > 60:
            color = COLORS["warning_light"]
        else:
            color = COLORS["accent_cyan"]
        self.percent_label.config(fg=color)

        # Update progress bar
        self.ram_progress.set_value(mem.percent)

        # Update detailed stats
        stats_text = f"Used: {used_gb:.2f} GB  |  Total: {total_gb:.2f} GB  |  Free: {available_gb:.2f} GB"
        self.stats_detail.config(text=stats_text)

        # Update timestamp
        self.last_update = datetime.now()
        self.update_label.config(
            text=f"Updated: {self.last_update.strftime('%H:%M:%S')}"
        )

        # Toggle live indicator
        self.live_indicator_state = not self.live_indicator_state
        self.live_dot.config(text="" if self.live_indicator_state else "")

        # Update limited apps badge
        if self.ram_limits:
            num_limited = len(self.ram_limits)
            self.limited_badge.config(
                text=f"🔒 {num_limited} app{'s' if num_limited != 1 else ''} limited"
            )
        else:
            self.limited_badge.config(text="")

    def refresh_processes(self):
        self.raw_processes = self.get_processes()
        self.grouped_processes = self.group_processes(self.raw_processes)

        # Get Docker container stats
        docker_containers = self.get_docker_container_stats()
        self.docker_running = len(docker_containers) > 0

        # Calculate total Docker container memory
        docker_container_memory_mb = sum(c["memory_mb"] for c in docker_containers)
        docker_container_memory_bytes = sum(
            c["memory_bytes"] for c in docker_containers
        )
        docker_container_memory_pct = sum(
            c["memory_percent"] for c in docker_containers
        )
        docker_container_count = len(docker_containers)

        # Find or create Docker (Total) group and add container memory to it
        docker_group = None
        vmmem_group = None
        vmmem_memory_mb = 0

        for proc in self.grouped_processes:
            proc_name_lower = proc["name"].lower()

            if proc["name"] == "Docker (Total)":
                docker_group = proc
            elif proc_name_lower in ("vmmem", "vmmemwsl"):
                vmmem_group = proc
                vmmem_memory_mb = proc["memory_mb"]
                proc["is_wsl"] = True
            else:
                proc["is_wsl"] = False

        # If Docker is running, add container memory and vmmem to Docker (Total)
        if self.docker_running:
            if docker_group:
                # Add container memory to Docker (Total)
                docker_group["memory_mb"] += docker_container_memory_mb
                docker_group["memory_bytes"] += docker_container_memory_bytes
                docker_group["memory_percent"] += docker_container_memory_pct
                docker_group["instances"] += docker_container_count
                docker_group["is_docker"] = True

                # Also add vmmem memory if present (WSL2 backend for Docker)
                if vmmem_group:
                    docker_group["memory_mb"] += vmmem_memory_mb
                    docker_group["memory_bytes"] += vmmem_group["memory_bytes"]
                    docker_group["memory_percent"] += vmmem_group["memory_percent"]
                    docker_group["instances"] += vmmem_group["instances"]
                    # Remove vmmem from the list since it's now part of Docker
                    self.grouped_processes.remove(vmmem_group)

                # Store container names for reference
                docker_group["container_names"] = [c["name"] for c in docker_containers]
            else:
                # No Docker Windows processes but containers running - create Docker group
                if docker_container_count > 0 or vmmem_group:
                    total_mb = docker_container_memory_mb
                    total_bytes = docker_container_memory_bytes
                    total_pct = docker_container_memory_pct
                    total_instances = docker_container_count

                    if vmmem_group:
                        total_mb += vmmem_memory_mb
                        total_bytes += vmmem_group["memory_bytes"]
                        total_pct += vmmem_group["memory_percent"]
                        total_instances += vmmem_group["instances"]
                        self.grouped_processes.remove(vmmem_group)

                    self.grouped_processes.append(
                        {
                            "instances": total_instances,
                            "name": "Docker (Total)",
                            "memory_bytes": total_bytes,
                            "memory_mb": total_mb,
                            "memory_percent": total_pct,
                            "status": "running",
                            "pids": [],
                            "is_critical": False,
                            "is_docker": True,
                            "is_wsl": False,
                            "container_names": [c["name"] for c in docker_containers],
                        }
                    )
                    self.name_to_pids["Docker (Total)"] = []
        else:
            # Docker not running but vmmem exists - mark it as WSL only
            if vmmem_group:
                vmmem_group["name"] = "vmmem (WSL2)"
                vmmem_group["is_wsl"] = True

        self.enforce_ram_limits()  # Enforce RAM limits on each refresh
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
                "Click on processes to select them first.\n\n"
                "Click once to select, click again to deselect.\n"
                "You can select multiple processes!",
            )
            return

        # Check for Docker containers (can't be killed via Windows PIDs)
        docker_selected = [n for n in self.selected_names if n.startswith("[Docker]")]
        if docker_selected:
            messagebox.showinfo(
                "Docker Containers",
                f"Docker containers must be stopped via Docker:\n\n"
                + "\n".join([f"  {n}" for n in docker_selected[:5]])
                + ("\n  ..." if len(docker_selected) > 5 else "")
                + f"\n\nUse 'docker stop <container>' command\n"
                "or Docker Desktop to stop containers.",
            )
            # Remove Docker containers from selection and continue with others
            self.selected_names = {
                n for n in self.selected_names if not n.startswith("[Docker]")
            }
            if not self.selected_names:
                return

        critical_selected = [
            n for n in self.selected_names if self.is_critical_process(n)
        ]
        if critical_selected:
            result = messagebox.askyesno(
                "DANGER - CRITICAL PROCESSES!",
                f"You selected CRITICAL Windows processes:\n\n"
                + "\n".join([f"  {n}" for n in critical_selected[:5]])
                + ("\n  ..." if len(critical_selected) > 5 else "")
                + f"\n\nClosing these WILL CRASH Windows!\n\n"
                f"Are you ABSOLUTELY SURE?",
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

        names_display = "\n".join([f"  {n}" for n in names_selected[:8]])
        if len(names_selected) > 8:
            names_display += f"\n  ... and {len(names_selected) - 8} more"

        if not messagebox.askyesno(
            "Confirm Close",
            f"Close {len(all_pids)} process(es)?\n\n{names_display}\n\n"
            "Unsaved data may be lost!",
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

        msg = f"Closed {killed} process(es)."
        if failed:
            msg += f"\n\nFailed: {len(failed)}\n" + "\n".join(failed[:3])

        messagebox.showinfo("Complete", msg)
        self.refresh_processes()

    def free_ram(self):
        try:
            mem_before = psutil.virtual_memory()
            freed_count = 0

            for proc in psutil.process_iter(["pid"]):
                try:
                    handle = ctypes.windll.kernel32.OpenProcess(
                        PROCESS_QUERY_INFORMATION | PROCESS_VM_READ,
                        False,
                        proc.info["pid"],
                    )
                    if handle:
                        ctypes.windll.psapi.EmptyWorkingSet(handle)
                        ctypes.windll.kernel32.CloseHandle(handle)
                        freed_count += 1
                except:
                    continue

            try:
                ctypes.windll.kernel32.SetProcessWorkingSetSize(
                    ctypes.windll.kernel32.GetCurrentProcess(),
                    ctypes.c_size_t(-1),
                    ctypes.c_size_t(-1),
                )
            except:
                pass

            mem_after = psutil.virtual_memory()
            freed_mb = (mem_after.available - mem_before.available) / (1024 * 1024)

            self.refresh_processes()

            if freed_mb > 0:
                messagebox.showinfo(
                    "RAM Freed",
                    f"Freed {freed_mb:.1f} MB of RAM\n"
                    f"Optimized {freed_count} processes",
                )
            else:
                messagebox.showinfo(
                    "RAM Cleanup", f"Cleanup complete\nProcessed {freed_count} apps"
                )
        except Exception as e:
            messagebox.showerror("Error", f"Failed: {str(e)}")

    def show_limit_dialog(self):
        """Show dialog to set RAM limit for selected processes"""
        if not self.selected_names:
            messagebox.showwarning(
                "No Selection",
                "Select one or more processes first.\n\n"
                "Click on a process row to select it,\n"
                "then click 'Set RAM Limit' to set a memory cap.",
            )
            return

        # Create dialog window
        dialog = tk.Toplevel(self.root)
        dialog.title("Set RAM Limit")
        dialog.geometry("450x380")
        dialog.configure(bg=COLORS["bg_dark"])
        dialog.transient(self.root)
        dialog.grab_set()

        # Center dialog
        dialog.update_idletasks()
        x = self.root.winfo_x() + (self.root.winfo_width() // 2) - 225
        y = self.root.winfo_y() + (self.root.winfo_height() // 2) - 190
        dialog.geometry(f"+{x}+{y}")

        # Title
        tk.Label(
            dialog,
            text="  Set RAM Limit",
            bg=COLORS["bg_dark"],
            fg=COLORS["limited_text"],
            font=("Segoe UI", 16, "bold"),
        ).pack(pady=(20, 10))

        # Selected processes info
        names_list = list(self.selected_names)
        names_display = ", ".join(names_list[:3])
        if len(names_list) > 3:
            names_display += f" (+{len(names_list) - 3} more)"

        tk.Label(
            dialog,
            text=f"Setting limit for: {names_display}",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_secondary"],
            font=("Segoe UI", 10),
            wraplength=400,
        ).pack(pady=(0, 15))

        # Current usage info
        current_usage = 0
        for name in self.selected_names:
            for proc in self.grouped_processes:
                if proc["name"] == name:
                    current_usage += proc["memory_mb"]
                    break

        tk.Label(
            dialog,
            text=f"Current total usage: {current_usage:,.1f} MB",
            bg=COLORS["bg_dark"],
            fg=COLORS["accent_cyan"],
            font=("Consolas", 11),
        ).pack(pady=(0, 20))

        # Input frame
        input_frame = tk.Frame(dialog, bg=COLORS["bg_dark"])
        input_frame.pack(pady=10)

        tk.Label(
            input_frame,
            text="Max RAM (MB):",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_primary"],
            font=("Segoe UI", 11),
        ).pack(side=tk.LEFT, padx=(0, 10))

        limit_var = tk.StringVar(
            value=str(int(current_usage) if current_usage > 0 else 500)
        )
        limit_entry = tk.Entry(
            input_frame,
            textvariable=limit_var,
            bg=COLORS["bg_light"],
            fg=COLORS["text_primary"],
            insertbackground=COLORS["text_primary"],
            font=("Consolas", 14),
            width=10,
            relief=tk.FLAT,
            justify=tk.CENTER,
        )
        limit_entry.pack(side=tk.LEFT)
        limit_entry.select_range(0, tk.END)
        limit_entry.focus()

        # Info text
        tk.Label(
            dialog,
            text="The app will automatically trim process memory\n"
            "when it exceeds this limit (every 1.5 seconds).\n\n"
            "Note: Some apps may reclaim memory quickly.\n"
            "Set to 0 to remove the limit.",
            bg=COLORS["bg_dark"],
            fg=COLORS["text_muted"],
            font=("Segoe UI", 9),
            justify=tk.CENTER,
        ).pack(pady=15)

        # Show existing limits if any
        existing_limits = [
            f"{n}: {self.ram_limits[n]} MB" for n in names_list if n in self.ram_limits
        ]
        if existing_limits:
            tk.Label(
                dialog,
                text="Current limits: " + ", ".join(existing_limits[:2]),
                bg=COLORS["bg_dark"],
                fg=COLORS["warning_light"],
                font=("Segoe UI", 9),
            ).pack(pady=(0, 10))

        # Buttons
        btn_frame = tk.Frame(dialog, bg=COLORS["bg_dark"])
        btn_frame.pack(pady=20)

        def apply_limit():
            try:
                limit = int(limit_var.get())
                if limit < 0:
                    raise ValueError("Negative value")

                for name in self.selected_names:
                    if limit == 0:
                        # Remove limit and restore normal working set
                        self.ram_limits.pop(name, None)
                        self.remove_working_set_limit(name)
                    else:
                        self.ram_limits[name] = limit

                # Save limits to persistent storage
                self.save_limits()

                dialog.destroy()

                if limit > 0:
                    # Aggressively enforce limits immediately - run multiple times
                    # to ensure memory is actually reduced
                    self.raw_processes = self.get_processes()  # Refresh first
                    for _ in range(3):  # Try 3 times to really push it down
                        self.enforce_ram_limits()
                        time.sleep(0.1)  # Brief pause between attempts

                if limit == 0:
                    messagebox.showinfo(
                        "Limit Removed",
                        f"RAM limits removed for {len(names_list)} process(es).\n"
                        "Working set limits have been reset.",
                    )
                else:
                    messagebox.showinfo(
                        "Limit Applied",
                        f"RAM limit of {limit} MB applied to {len(names_list)} process(es).\n\n"
                        "Memory has been reduced and hard limit is now enforced.\n"
                        "The OS will prevent these processes from exceeding the limit.",
                    )

                self.refresh_processes()

            except ValueError:
                messagebox.showerror(
                    "Invalid Input", "Please enter a valid number (0 or higher)."
                )

        apply_btn = ModernButton(
            btn_frame,
            "  Apply Limit",
            apply_limit,
            style="primary",
            width=140,
            height=38,
        )
        apply_btn.pack(side=tk.LEFT, padx=(0, 10))

        cancel_btn = ModernButton(
            btn_frame, "Cancel", dialog.destroy, style="secondary", width=100, height=38
        )
        cancel_btn.pack(side=tk.LEFT)

        # Bind Enter key
        dialog.bind("<Return>", lambda e: apply_limit())
        dialog.bind("<Escape>", lambda e: dialog.destroy())

    def show_limited_dialog(self):
        """Show dialog listing all limited processes with unlimit buttons"""
        if not self.ram_limits:
            messagebox.showinfo(
                "No Limits",
                "No processes are currently limited.\n\n"
                "Select a process and click 'Set RAM Limit' to add one.",
            )
            return

        # Create dialog window
        dialog = tk.Toplevel(self.root)
        dialog.title("Limited Processes")
        dialog.geometry("500x400")
        dialog.configure(bg=COLORS["bg_dark"])
        dialog.transient(self.root)
        dialog.grab_set()

        # Center dialog
        dialog.update_idletasks()
        x = self.root.winfo_x() + (self.root.winfo_width() // 2) - 250
        y = self.root.winfo_y() + (self.root.winfo_height() // 2) - 200
        dialog.geometry(f"+{x}+{y}")

        # Title
        title_label = tk.Label(
            dialog,
            text=f"🔒 Limited Processes ({len(self.ram_limits)})",
            bg=COLORS["bg_dark"],
            fg=COLORS["limited_text"],
            font=("Segoe UI", 16, "bold"),
        )
        title_label.pack(pady=(20, 15))

        # Scrollable frame for the list
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

        # Track rows for updating
        rows = {}

        def unlimit_process(name, row_frame):
            """Remove limit for a specific process"""
            self.ram_limits.pop(name, None)
            self.remove_working_set_limit(name)
            self.save_limits()
            row_frame.destroy()
            rows.pop(name, None)

            # Update title
            if self.ram_limits:
                title_label.config(
                    text=f"🔒 Limited Processes ({len(self.ram_limits)})"
                )
            else:
                dialog.destroy()
                messagebox.showinfo(
                    "All Limits Removed", "All RAM limits have been removed."
                )

            self.refresh_processes()

        # Create a row for each limited process
        for name, limit_mb in sorted(self.ram_limits.items()):
            # Get current memory usage
            current_mb = 0
            for proc in self.grouped_processes:
                if proc["name"] == name:
                    current_mb = proc["memory_mb"]
                    break

            row = tk.Frame(scrollable_frame, bg=COLORS["bg_light"], pady=8, padx=10)
            row.pack(fill=tk.X, pady=3)
            rows[name] = row

            # Left side - process info
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

            status_color = (
                COLORS["danger_light"]
                if current_mb > limit_mb
                else COLORS["accent_cyan"]
            )
            tk.Label(
                info_frame,
                text=f"{current_mb:,.1f} MB / {limit_mb} MB limit",
                bg=COLORS["bg_light"],
                fg=status_color,
                font=("Consolas", 9),
                anchor="w",
            ).pack(anchor="w")

            # Right side - unlimit button
            unlimit_btn = tk.Button(
                row,
                text="✕ Unlimit",
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

        # Close button at bottom
        btn_frame = tk.Frame(dialog, bg=COLORS["bg_dark"])
        btn_frame.pack(pady=15)

        close_btn = ModernButton(
            btn_frame, "Close", dialog.destroy, style="secondary", width=100, height=38
        )
        close_btn.pack()

        # Bind Escape key
        dialog.bind("<Escape>", lambda e: dialog.destroy())

    def is_startup_service_installed(self):
        """Check if the background limit service is installed as a startup task"""
        return is_startup_task_installed()

    def toggle_startup_service(self):
        """Toggle the background limit service on/off"""
        is_installed = self.is_startup_service_installed()

        if is_installed:
            # Uninstall
            if messagebox.askyesno(
                "Disable Auto-Start",
                "RAM limits will NO LONGER be enforced automatically at Windows startup.\n\n"
                "Limits will only work while this app is running.\n\n"
                "Disable auto-start?",
            ):
                if uninstall_startup_task():
                    messagebox.showinfo(
                        "Auto-Start Disabled",
                        "Background service has been disabled.\n\n"
                        "RAM limits will only work while this app is running.",
                    )
                    self.startup_btn.style = "secondary"
                    self.startup_btn.draw_button()
                else:
                    messagebox.showerror("Error", "Failed to disable auto-start")
        else:
            # Install
            if not self.ram_limits:
                messagebox.showinfo(
                    "No Limits Set",
                    "You haven't set any RAM limits yet.\n\n"
                    "Set some limits first, then enable auto-start\n"
                    "to enforce them automatically at Windows startup.",
                )
                return

            if messagebox.askyesno(
                "Enable Auto-Start",
                "This will install a background service that runs at Windows startup.\n\n"
                "Your current RAM limits will be enforced automatically,\n"
                "even when this app is not running.\n\n"
                "Enable auto-start? (Requires administrator privileges)",
            ):
                if install_startup_task():
                    messagebox.showinfo(
                        "Auto-Start Enabled",
                        "Background service installed successfully!\n\n"
                        "Your RAM limits will now be enforced automatically\n"
                        "every time Windows starts.",
                    )
                    self.startup_btn.style = "success"
                    self.startup_btn.draw_button()
                else:
                    # Try with elevated privileges
                    try:
                        script_path = os.path.abspath(__file__)
                        ctypes.windll.shell32.ShellExecuteW(
                            None,
                            "runas",
                            sys.executable,
                            f'"{script_path}" --install',
                            None,
                            1,
                        )
                        time.sleep(2)
                        if self.is_startup_service_installed():
                            messagebox.showinfo(
                                "Auto-Start Enabled",
                                "Background service installed successfully!\n\n"
                                "Your RAM limits will now be enforced automatically.",
                            )
                            self.startup_btn.style = "success"
                            self.startup_btn.draw_button()
                        else:
                            messagebox.showwarning(
                                "Installation Pending",
                                "Please approve the administrator prompt to complete installation.",
                            )
                    except Exception as e:
                        messagebox.showerror(
                            "Installation Failed",
                            f"Failed to install startup service.\n\n"
                            f"Try running this app as administrator.\n\nError: {e}",
                        )

    def enforce_ram_limits(self):
        """Enforce RAM limits on all limited processes using hard working set limits.

        This method:
        1. Tracks all PIDs we've applied limits to
        2. Detects new process instances and applies limits immediately
        3. Continuously enforces limits on processes that exceed their allocation
        4. Uses hard working set limits so Windows prevents memory growth
        5. Handles grouped applications (e.g., "Docker (Total)" applies to all Docker processes)
        """
        if not self.ram_limits:
            return 0

        enforced_count = 0
        current_pids = set()

        for name, limit_mb in list(self.ram_limits.items()):
            # Get all PIDs and their individual memory usage for this process/group
            proc_info = []

            # Check if this is a grouped application
            if (
                hasattr(self, "group_to_original_names")
                and name in self.group_to_original_names
            ):
                # This is a grouped app - get all processes in the group
                original_names = self.group_to_original_names[name]
                for proc in self.raw_processes:
                    if proc["name"] in original_names:
                        proc_info.append(
                            {"pid": proc["pid"], "memory_mb": proc["memory_mb"]}
                        )
                        current_pids.add(proc["pid"])
            else:
                # Direct process name match
                for proc in self.raw_processes:
                    if proc["name"] == name:
                        proc_info.append(
                            {"pid": proc["pid"], "memory_mb": proc["memory_mb"]}
                        )
                        current_pids.add(proc["pid"])

            # Also check if any process maps to this group via APP_GROUPS
            if name.endswith("(Total)"):
                for proc in self.raw_processes:
                    group_name = APP_GROUPS.get(proc["name"].lower())
                    if group_name == name and proc["pid"] not in current_pids:
                        proc_info.append(
                            {"pid": proc["pid"], "memory_mb": proc["memory_mb"]}
                        )
                        current_pids.add(proc["pid"])

            if not proc_info:
                continue

            # Calculate per-process limit (divide total limit among instances)
            num_instances = len(proc_info)
            per_process_limit_mb = limit_mb / num_instances
            per_process_limit_bytes = int(per_process_limit_mb * 1024 * 1024)

            # Minimum working set (allow some memory, at least 5MB)
            min_ws = min(per_process_limit_bytes, 5 * 1024 * 1024)

            for pinfo in proc_info:
                pid = pinfo["pid"]
                current_mb = pinfo["memory_mb"]
                is_new_process = pid not in self.known_pids

                try:
                    # Open with rights to modify working set
                    handle = ctypes.windll.kernel32.OpenProcess(
                        PROCESS_QUERY_INFORMATION
                        | PROCESS_SET_QUOTA
                        | PROCESS_VM_OPERATION,
                        False,
                        pid,
                    )
                    if handle:
                        # Always empty working set for new processes or those over limit
                        if is_new_process or current_mb > per_process_limit_mb:
                            ctypes.windll.psapi.EmptyWorkingSet(handle)

                        # Set a hard maximum working set size
                        # SetProcessWorkingSetSizeEx(handle, min, max, flags)
                        try:
                            ctypes.windll.kernel32.SetProcessWorkingSetSizeEx(
                                handle,
                                ctypes.c_size_t(min_ws),
                                ctypes.c_size_t(per_process_limit_bytes),
                                QUOTA_LIMITS_HARDWS_MAX_ENABLE
                                | QUOTA_LIMITS_HARDWS_MIN_DISABLE,
                            )
                        except Exception:
                            # Fallback: use regular SetProcessWorkingSetSize
                            ctypes.windll.kernel32.SetProcessWorkingSetSize(
                                handle,
                                ctypes.c_size_t(min_ws),
                                ctypes.c_size_t(per_process_limit_bytes),
                            )

                        ctypes.windll.kernel32.CloseHandle(handle)
                        enforced_count += 1

                        # Mark this PID as processed
                        self.known_pids.add(pid)
                except Exception:
                    continue

        # Clean up PIDs that no longer exist
        self.known_pids = self.known_pids.intersection(current_pids)

        return enforced_count

    def remove_working_set_limit(self, name):
        """Remove working set limits for a process, allowing it to use memory freely"""
        for proc in self.raw_processes:
            if proc["name"] == name:
                try:
                    handle = ctypes.windll.kernel32.OpenProcess(
                        PROCESS_QUERY_INFORMATION
                        | PROCESS_SET_QUOTA
                        | PROCESS_VM_OPERATION,
                        False,
                        proc["pid"],
                    )
                    if handle:
                        # Reset to default (-1, -1) removes the limit
                        ctypes.windll.kernel32.SetProcessWorkingSetSize(
                            handle,
                            ctypes.c_size_t(-1),
                            ctypes.c_size_t(-1),
                        )
                        ctypes.windll.kernel32.CloseHandle(handle)
                except Exception:
                    continue

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
    """Run as background service - no GUI, just enforce RAM limits continuously"""
    import logging

    log_file = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "ram_service.log"
    )
    logging.basicConfig(
        filename=log_file,
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
    )
    logging.info("RAM Limit Background Service started")

    known_pids = set()
    last_limits = {}

    while True:
        try:
            # Load limits
            limits = {}
            if os.path.exists(LIMITS_FILE):
                try:
                    with open(LIMITS_FILE, "r", encoding="utf-8") as f:
                        data = json.load(f)
                        limits = {
                            str(k): int(v) for k, v in data.get("limits", {}).items()
                        }
                except:
                    pass

            if limits != last_limits:
                logging.info(f"Limits updated: {limits}")
                last_limits = limits.copy()

            if limits:
                # Get processes
                processes = []
                for proc in psutil.process_iter(["pid", "name", "memory_info"]):
                    try:
                        info = proc.info
                        memory_bytes = (
                            info["memory_info"].rss if info["memory_info"] else 0
                        )
                        processes.append(
                            {
                                "pid": info["pid"],
                                "name": info["name"] or "Unknown",
                                "memory_mb": memory_bytes / (1024 * 1024),
                            }
                        )
                    except:
                        continue

                current_pids = set()
                enforced = 0

                for name, limit_mb in limits.items():
                    proc_info = []

                    for proc in processes:
                        proc_name = proc["name"]
                        # Direct match or group match
                        if (
                            proc_name == name
                            or APP_GROUPS.get(proc_name.lower()) == name
                        ):
                            proc_info.append(proc)
                            current_pids.add(proc["pid"])

                    if not proc_info:
                        continue

                    per_process_limit_mb = limit_mb / len(proc_info)
                    per_process_limit_bytes = int(per_process_limit_mb * 1024 * 1024)
                    min_ws = min(per_process_limit_bytes, 5 * 1024 * 1024)

                    for pinfo in proc_info:
                        pid = pinfo["pid"]
                        is_new = pid not in known_pids
                        over_limit = pinfo["memory_mb"] > per_process_limit_mb

                        try:
                            handle = ctypes.windll.kernel32.OpenProcess(
                                PROCESS_QUERY_INFORMATION
                                | PROCESS_SET_QUOTA
                                | PROCESS_VM_OPERATION,
                                False,
                                pid,
                            )
                            if handle:
                                if is_new or over_limit:
                                    ctypes.windll.psapi.EmptyWorkingSet(handle)
                                try:
                                    ctypes.windll.kernel32.SetProcessWorkingSetSizeEx(
                                        handle,
                                        ctypes.c_size_t(min_ws),
                                        ctypes.c_size_t(per_process_limit_bytes),
                                        QUOTA_LIMITS_HARDWS_MAX_ENABLE
                                        | QUOTA_LIMITS_HARDWS_MIN_DISABLE,
                                    )
                                except:
                                    ctypes.windll.kernel32.SetProcessWorkingSetSize(
                                        handle,
                                        ctypes.c_size_t(min_ws),
                                        ctypes.c_size_t(per_process_limit_bytes),
                                    )
                                ctypes.windll.kernel32.CloseHandle(handle)
                                known_pids.add(pid)
                                enforced += 1
                        except:
                            continue

                known_pids = known_pids.intersection(current_pids)

            time.sleep(2)
        except Exception as e:
            logging.error(f"Service error: {e}")
            time.sleep(5)


def install_startup_task():
    """Install Windows Scheduled Task to run at startup"""
    script_path = os.path.abspath(__file__)
    task_name = "RAMMonitorLimitService"

    xml_content = f'''<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>RAM Monitor Pro - Background Limit Enforcer</Description>
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
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
    <RestartOnFailure>
      <Interval>PT1M</Interval>
      <Count>3</Count>
    </RestartOnFailure>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>pythonw</Command>
      <Arguments>"{script_path}" --service</Arguments>
      <WorkingDirectory>{os.path.dirname(script_path)}</WorkingDirectory>
    </Exec>
  </Actions>
</Task>'''

    xml_path = os.path.join(os.environ.get("TEMP", "."), "ram_limit_task.xml")
    try:
        with open(xml_path, "w", encoding="utf-16") as f:
            f.write(xml_content)

        # Delete existing task
        subprocess.run(
            ["schtasks", "/delete", "/tn", task_name, "/f"],
            capture_output=True,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )

        # Create new task
        result = subprocess.run(
            ["schtasks", "/create", "/tn", task_name, "/xml", xml_path],
            capture_output=True,
            text=True,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )

        os.remove(xml_path)
        return result.returncode == 0
    except Exception as e:
        try:
            os.remove(xml_path)
        except:
            pass
        return False


def uninstall_startup_task():
    """Remove the Windows Scheduled Task"""
    try:
        result = subprocess.run(
            ["schtasks", "/delete", "/tn", "RAMMonitorLimitService", "/f"],
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
            ["schtasks", "/query", "/tn", "RAMMonitorLimitService"],
            capture_output=True,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        return result.returncode == 0
    except:
        return False


def main():
    # Check for command line arguments
    if len(sys.argv) > 1:
        cmd = sys.argv[1].lower()
        if cmd == "--service":
            run_background_service()
            return
        elif cmd == "--install":
            if install_startup_task():
                print("✓ Startup task installed successfully!")
            else:
                print("✗ Failed to install startup task")
            return
        elif cmd == "--uninstall":
            if uninstall_startup_task():
                print("✓ Startup task removed successfully!")
            else:
                print("✗ Failed to remove startup task")
            return
        elif cmd == "--status":
            if is_startup_task_installed():
                print("✓ Auto-start is ENABLED")
            else:
                print("✗ Auto-start is DISABLED")
            return

    # Normal GUI mode
    if not check_admin():
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
            except:
                messagebox.showwarning("Warning", "Could not get admin rights.")

    root = tk.Tk()
    app = RAMMonitorApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
