#!/usr/bin/env python3
"""
ULTRA-FAST directory size calculator - Windows native API + threading
Usage: pya [path1] [path2] ...
"""

import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Tuple, List

if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

# Windows-specific turbo mode
if sys.platform == "win32":
    import ctypes
    from ctypes import wintypes
    
    kernel32 = ctypes.windll.kernel32
    
    INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value
    FILE_ATTRIBUTE_DIRECTORY = 0x10
    FILE_ATTRIBUTE_REPARSE_POINT = 0x400
    
    class WIN32_FIND_DATAW(ctypes.Structure):
        _fields_ = [
            ("dwFileAttributes", wintypes.DWORD),
            ("ftCreationTime", wintypes.FILETIME),
            ("ftLastAccessTime", wintypes.FILETIME),
            ("ftLastWriteTime", wintypes.FILETIME),
            ("nFileSizeHigh", wintypes.DWORD),
            ("nFileSizeLow", wintypes.DWORD),
            ("dwReserved0", wintypes.DWORD),
            ("dwReserved1", wintypes.DWORD),
            ("cFileName", wintypes.WCHAR * 260),
            ("cAlternateFileName", wintypes.WCHAR * 14),
        ]
    
    FindFirstFileW = kernel32.FindFirstFileW
    FindFirstFileW.argtypes = [wintypes.LPCWSTR, ctypes.POINTER(WIN32_FIND_DATAW)]
    FindFirstFileW.restype = wintypes.HANDLE
    
    FindNextFileW = kernel32.FindNextFileW
    FindNextFileW.argtypes = [wintypes.HANDLE, ctypes.POINTER(WIN32_FIND_DATAW)]
    FindNextFileW.restype = wintypes.BOOL
    
    FindClose = kernel32.FindClose
    FindClose.argtypes = [wintypes.HANDLE]
    FindClose.restype = wintypes.BOOL
    
    def get_dir_size_fast(path: str) -> int:
        """Ultra-fast iterative size calc using Windows native API."""
        total = 0
        stack = [path]
        find_data = WIN32_FIND_DATAW()
        
        while stack:
            current = stack.pop()
            search_path = os.path.join(current, "*")
            
            handle = FindFirstFileW(search_path, ctypes.byref(find_data))
            if handle == INVALID_HANDLE_VALUE:
                continue
            
            try:
                while True:
                    name = find_data.cFileName
                    if name not in (".", ".."):
                        attrs = find_data.dwFileAttributes
                        if not (attrs & FILE_ATTRIBUTE_REPARSE_POINT):
                            if attrs & FILE_ATTRIBUTE_DIRECTORY:
                                stack.append(os.path.join(current, name))
                            else:
                                total += (find_data.nFileSizeHigh << 32) + find_data.nFileSizeLow
                    
                    if not FindNextFileW(handle, ctypes.byref(find_data)):
                        break
            finally:
                FindClose(handle)
        
        return total

else:
    # Linux/Mac: optimized os.scandir
    def get_dir_size_fast(path: str) -> int:
        """Ultra-fast iterative size calc using os.scandir."""
        total = 0
        stack = [path]
        
        while stack:
            current = stack.pop()
            try:
                with os.scandir(current) as it:
                    for entry in it:
                        try:
                            if entry.is_symlink():
                                continue
                            if entry.is_file(follow_symlinks=False):
                                total += entry.stat(follow_symlinks=False).st_size
                            elif entry.is_dir(follow_symlinks=False):
                                stack.append(entry.path)
                        except (PermissionError, OSError):
                            pass
            except (PermissionError, OSError):
                pass
        
        return total


# ── ANSI colors ──
C_RESET  = "\033[0m"
C_BOLD   = "\033[1m"
C_DIM    = "\033[2m"
C_RED    = "\033[91m"
C_YELLOW = "\033[93m"
C_GREEN  = "\033[92m"
C_CYAN   = "\033[96m"
C_BLUE   = "\033[94m"
C_MAG    = "\033[95m"
C_WHITE  = "\033[97m"

BAR_FULL  = "█"
BAR_EMPTY = "░"
BAR_WIDTH = 20


def format_size(size_bytes: int) -> str:
    """Smart size: GB/MB/KB depending on magnitude."""
    if size_bytes >= 1024 * 1024 * 1024:
        return f"{size_bytes / (1024**3):>8,.2f} GB"
    elif size_bytes >= 1024 * 1024:
        return f"{size_bytes / (1024**2):>8,.2f} MB"
    elif size_bytes >= 1024:
        return f"{size_bytes / 1024:>8,.1f} KB"
    else:
        return f"{size_bytes:>8,} B "


def size_color(size_bytes: int) -> str:
    """Color based on size magnitude."""
    if size_bytes >= 1024 * 1024 * 1024:
        return C_RED
    elif size_bytes >= 100 * 1024 * 1024:
        return C_YELLOW
    elif size_bytes >= 10 * 1024 * 1024:
        return C_GREEN
    elif size_bytes >= 1024 * 1024:
        return C_CYAN
    else:
        return C_DIM


def make_bar(fraction: float) -> str:
    """Create a visual bar from 0.0 to 1.0."""
    filled = int(fraction * BAR_WIDTH)
    filled = min(filled, BAR_WIDTH)
    if fraction > 0.5:
        color = C_RED
    elif fraction > 0.2:
        color = C_YELLOW
    else:
        color = C_GREEN
    return f"{color}{BAR_FULL * filled}{C_DIM}{BAR_EMPTY * (BAR_WIDTH - filled)}{C_RESET}"


def calc_subdir_size(args: Tuple[str, str]) -> Tuple[str, int]:
    """Worker function for threading."""
    name, path = args
    try:
        return (name, get_dir_size_fast(path))
    except Exception:
        return (name, 0)


def get_folder_sizes(path: str) -> Tuple[List[Tuple[str, int]], int]:
    """Get sizes of all immediate subfolders and root files."""
    folders = []
    root_files_size = 0
    subdirs = []

    try:
        with os.scandir(path) as it:
            for entry in it:
                try:
                    if entry.is_symlink():
                        continue
                    if entry.is_file(follow_symlinks=False):
                        root_files_size += entry.stat(follow_symlinks=False).st_size
                    elif entry.is_dir(follow_symlinks=False):
                        subdirs.append((entry.name, entry.path))
                except (PermissionError, OSError):
                    pass
    except (PermissionError, OSError) as e:
        print(f"Error: {path}: {e}", file=sys.stderr)
        return [], 0

    if subdirs:
        workers = min(32, len(subdirs))
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {executor.submit(calc_subdir_size, s): s[0] for s in subdirs}
            for future in as_completed(futures):
                try:
                    result = future.result()
                    folders.append(result)
                except Exception:
                    pass

    folders.sort(key=lambda x: x[1], reverse=True)
    return folders, root_files_size


def print_row(indent: str, num: str, name: str, size_bytes: int, parent_bytes: int, name_width: int):
    """Print a single formatted row with number, name, bar, size, and percent."""
    sc = size_color(size_bytes)
    pct = (size_bytes / parent_bytes * 100) if parent_bytes > 0 else 0
    bar = make_bar(size_bytes / parent_bytes) if parent_bytes > 0 else make_bar(0)
    pct_str = f"{pct:5.1f}%"
    print(f"{indent}{C_DIM}{num}{C_RESET} {sc}{name:<{name_width}}{C_RESET}  {bar}  {sc}{format_size(size_bytes)}{C_RESET}  {C_DIM}{pct_str}{C_RESET}")


def print_drilldown(path: str, parent_size: int, depth: int, current: int, indent: str):
    """Recursively print top-10 heaviest subfolders up to given depth."""
    if current >= depth:
        return
    folders, files_size = get_folder_sizes(path)
    top10 = [(n, s) for n, s in folders if s > 0][:10]
    if not top10 and files_size == 0:
        return

    LEVEL_COLORS = [C_CYAN, C_YELLOW, C_MAG, C_BLUE, C_GREEN]
    lc = LEVEL_COLORS[current % len(LEVEL_COLORS)]

    for name, size in top10:
        if size < 1024:  # skip < 1 KB in drilldown
            continue
        sub_path = os.path.join(path, name)
        sub_folders, sub_files = get_folder_sizes(sub_path)
        sub_top10 = [(n, s) for n, s in sub_folders if s > 0][:10]
        if not sub_top10 and sub_files == 0:
            continue

        sub_total = sum(s for _, s in sub_top10) + sub_files
        sub_max = max((len(f[0]) for f in sub_top10), default=7)
        sub_max = max(sub_max, 7)

        print(f"\n{indent}{lc}{'▼'} {C_BOLD}{name}{C_RESET}  {C_DIM}({format_size(size).strip()}  ·  {len(sub_top10)} subfolder{'s' if len(sub_top10) != 1 else ''}){C_RESET}")
        print(f"{indent}{lc}{'│'}{C_RESET}")

        for i, (sn, ss) in enumerate(sub_top10, 1):
            is_last = (i == len(sub_top10) and sub_files == 0)
            branch = "└─" if is_last else "├─"
            num = f"{i:>2}."
            sc = size_color(ss)
            pct = (ss / size * 100) if size > 0 else 0
            bar = make_bar(ss / size) if size > 0 else make_bar(0)
            print(f"{indent}{lc}{branch}{C_RESET} {C_DIM}{num}{C_RESET} {sc}{sn:<{sub_max}}{C_RESET}  {bar}  {sc}{format_size(ss)}{C_RESET}  {C_DIM}{pct:5.1f}%{C_RESET}")

        if sub_files > 0:
            sc = size_color(sub_files)
            pct = (sub_files / size * 100) if size > 0 else 0
            bar = make_bar(sub_files / size) if size > 0 else make_bar(0)
            print(f"{indent}{lc}└─{C_RESET} {C_DIM}   {sc}{'<files>':<{sub_max}}{C_RESET}  {bar}  {sc}{format_size(sub_files)}{C_RESET}  {C_DIM}{pct:5.1f}%{C_RESET}")

        if current + 1 < depth:
            print_drilldown(sub_path, size, depth, current + 1, indent + "     ")


def pya(path: str, depth: int = 0) -> int:
    """Show sizes of all folders in directory. Returns total."""
    path = os.path.abspath(path)

    folders, root_files_size = get_folder_sizes(path)

    if not folders and root_files_size == 0:
        print(f"\n{C_BOLD}═══ {path} ═══{C_RESET}")
        print("  (empty)")
        return 0

    total = root_files_size
    for _, size in folders:
        total += size

    # Header
    print(f"\n{C_BOLD}{'═' * 60}{C_RESET}")
    print(f"  {C_BOLD}{C_CYAN}{path}{C_RESET}  {C_DIM}({format_size(total).strip()} total){C_RESET}")
    print(f"{C_BOLD}{'═' * 60}{C_RESET}")

    visible = [(n, s) for n, s in folders if s > 0]
    max_name_len = max((len(f[0]) for f in visible), default=7)
    max_name_len = max(max_name_len, 7)

    # Column header
    print(f"  {C_DIM}{'#':>3}  {'Folder':<{max_name_len}}  {'':^{BAR_WIDTH}}  {'Size':>11}  {'%':>6}{C_RESET}")
    print(f"  {C_DIM}{'─' * (3 + 2 + max_name_len + 2 + BAR_WIDTH + 2 + 11 + 2 + 6)}{C_RESET}")

    for i, (name, size) in enumerate(visible, 1):
        print_row("  ", f"{i:>3}.", name, size, total, max_name_len)

    if root_files_size > 0:
        print_row("  ", "   ", "<files>", root_files_size, total, max_name_len)

    # Footer
    print(f"  {C_DIM}{'─' * (3 + 2 + max_name_len + 2 + BAR_WIDTH + 2 + 11 + 2 + 6)}{C_RESET}")
    print(f"  {C_BOLD}{'':>3}  {'TOTAL':<{max_name_len}}  {'':^{BAR_WIDTH}}  {format_size(total)}  {C_RESET}")

    if depth > 0:
        top10 = visible[:10]
        if top10:
            print(f"\n{C_BOLD}{'─' * 60}{C_RESET}")
            print(f"  {C_BOLD}Top {len(top10)} breakdown{C_RESET}  {C_DIM}(depth {depth}){C_RESET}")
            print(f"{C_BOLD}{'─' * 60}{C_RESET}")
            print_drilldown(path, total, depth, 0, "  ")

    return total


def main():
    args = sys.argv[1:]
    depth = 1

    filtered = []
    i = 0
    while i < len(args):
        if args[i] == "--depth" and i + 1 < len(args):
            depth = int(args[i + 1])
            i += 2
        elif args[i] == "--no-drill":
            depth = 0
            i += 1
        else:
            filtered.append(args[i])
            i += 1

    paths = filtered if filtered else ["."]

    path_totals = []
    grand_total = 0

    for path in paths:
        if not os.path.exists(path):
            print(f"\n{C_RED}Error:{C_RESET} {path} does not exist")
            continue
        total = pya(path, depth=depth)
        path_totals.append((path, total))
        grand_total += total

    if len(paths) > 1:
        print(f"\n{C_BOLD}{'═' * 50}")
        print(f"  GRAND TOTAL")
        print(f"{'═' * 50}{C_RESET}")
        ml = max(len(p) for p, _ in path_totals)
        for p, t in path_totals:
            sc = size_color(t)
            print(f"  {sc}{p:<{ml}}  {format_size(t)}{C_RESET}")
        print(f"  {C_DIM}{'─' * 48}{C_RESET}")
        print(f"  {C_BOLD}{'All':<{ml}}  {format_size(grand_total)}{C_RESET}")


if __name__ == "__main__":
    main()
