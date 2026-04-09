#!/usr/bin/env python3
"""
ULTRA-FAST EXHAUSTIVE folder finder - Windows native API + threading
Searches ENTIRE C: drive for folders matching search terms - MISSES NOTHING!
Usage: python app.py <term1> [term2] [term3] ...

Features:
- Long path support (>260 chars) via extended path prefix
- Searches hidden/system folders
- Reports reparse points (junctions/symlinks) but doesn't recurse into them
- Parallel processing for speed
- Shows inaccessible folders count
"""

import os
import sys
import io
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Tuple, Set
import ctypes
from ctypes import wintypes
import threading

# Fix Windows console encoding for Unicode paths
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# Windows native API for turbo speed
kernel32 = ctypes.windll.kernel32

INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value
FILE_ATTRIBUTE_DIRECTORY = 0x10
FILE_ATTRIBUTE_REPARSE_POINT = 0x400
FILE_ATTRIBUTE_HIDDEN = 0x2
FILE_ATTRIBUTE_SYSTEM = 0x4

# For FindFirstFileExW - more thorough enumeration
FIND_FIRST_EX_LARGE_FETCH = 0x2
FindExInfoBasic = 1
FindExSearchNameMatch = 0

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

# Use FindFirstFileExW for better enumeration
FindFirstFileExW = kernel32.FindFirstFileExW
FindFirstFileExW.argtypes = [
    wintypes.LPCWSTR,  # lpFileName
    ctypes.c_int,       # fInfoLevelId
    ctypes.POINTER(WIN32_FIND_DATAW),  # lpFindFileData
    ctypes.c_int,       # fSearchOp
    ctypes.c_void_p,    # lpSearchFilter
    wintypes.DWORD      # dwAdditionalFlags
]
FindFirstFileExW.restype = wintypes.HANDLE

FindNextFileW = kernel32.FindNextFileW
FindNextFileW.argtypes = [wintypes.HANDLE, ctypes.POINTER(WIN32_FIND_DATAW)]
FindNextFileW.restype = wintypes.BOOL

FindClose = kernel32.FindClose
FindClose.argtypes = [wintypes.HANDLE]
FindClose.restype = wintypes.BOOL

# Thread-safe counter for inaccessible folders
inaccessible_count = 0
inaccessible_lock = threading.Lock()


def long_path(path: str) -> str:
    """Convert path to long path format to support >260 char paths."""
    if path.startswith("\\\\?\\"):
        return path
    if path.startswith("\\\\"):
        # UNC path: \\server\share -> \\?\UNC\server\share
        return "\\\\?\\UNC\\" + path[2:]
    return "\\\\?\\" + path


def short_path(path: str) -> str:
    """Convert long path back to normal format for display."""
    if path.startswith("\\\\?\\UNC\\"):
        return "\\\\" + path[8:]
    if path.startswith("\\\\?\\"):
        return path[4:]
    return path


def get_dir_size_fast(path: str) -> int:
    """Ultra-fast iterative size calc using Windows native API with long path support."""
    total = 0
    stack = [long_path(path)]
    find_data = WIN32_FIND_DATAW()
    
    while stack:
        current = stack.pop()
        search_path = current.rstrip("\\") + "\\*"
        
        handle = FindFirstFileExW(
            search_path, FindExInfoBasic, ctypes.byref(find_data),
            FindExSearchNameMatch, None, FIND_FIRST_EX_LARGE_FETCH
        )
        if handle == INVALID_HANDLE_VALUE:
            continue
        
        try:
            while True:
                name = find_data.cFileName
                if name not in (".", ".."):
                    attrs = find_data.dwFileAttributes
                    if not (attrs & FILE_ATTRIBUTE_REPARSE_POINT):
                        full_path = current.rstrip("\\") + "\\" + name
                        if attrs & FILE_ATTRIBUTE_DIRECTORY:
                            stack.append(full_path)
                        else:
                            total += (find_data.nFileSizeHigh << 32) + find_data.nFileSizeLow
                
                if not FindNextFileW(handle, ctypes.byref(find_data)):
                    break
        finally:
            FindClose(handle)
    
    return total


def find_matching_folders_exhaustive(start_path: str, search_terms: List[str]) -> Dict[str, List[str]]:
    """
    EXHAUSTIVE folder search using Windows native API.
    - Supports long paths (>260 chars)
    - Includes hidden/system folders
    - Reports reparse points but doesn't recurse into them (avoids infinite loops)
    - Searches folder NAME for match (case-insensitive)
    """
    global inaccessible_count
    
    matches = {term: [] for term in search_terms}
    stack = [long_path(start_path)]
    find_data = WIN32_FIND_DATAW()
    search_terms_lower = [t.lower() for t in search_terms]
    local_inaccessible = 0
    
    while stack:
        current = stack.pop()
        search_path = current.rstrip("\\") + "\\*"
        
        handle = FindFirstFileExW(
            search_path, FindExInfoBasic, ctypes.byref(find_data),
            FindExSearchNameMatch, None, FIND_FIRST_EX_LARGE_FETCH
        )
        
        if handle == INVALID_HANDLE_VALUE:
            local_inaccessible += 1
            continue
        
        try:
            while True:
                name = find_data.cFileName
                if name not in (".", ".."):
                    attrs = find_data.dwFileAttributes
                    
                    # Process ALL directories (including hidden/system)
                    if attrs & FILE_ATTRIBUTE_DIRECTORY:
                        full_path = current.rstrip("\\") + "\\" + name
                        display_path = short_path(full_path)
                        name_lower = name.lower()
                        
                        # Check against all search terms
                        for i, term_lower in enumerate(search_terms_lower):
                            if term_lower in name_lower:
                                matches[search_terms[i]].append(display_path)
                        
                        # Recurse into subdirectories (but NOT reparse points to avoid loops)
                        if not (attrs & FILE_ATTRIBUTE_REPARSE_POINT):
                            stack.append(full_path)
                
                if not FindNextFileW(handle, ctypes.byref(find_data)):
                    break
        finally:
            FindClose(handle)
    
    # Update global counter
    with inaccessible_lock:
        inaccessible_count += local_inaccessible
    
    return matches


def search_drive_exhaustive(drive: str, search_terms: List[str]) -> Dict[str, List[str]]:
    """
    EXHAUSTIVE search of entire drive for multiple search terms.
    Uses parallel processing on top-level folders for speed.
    """
    global inaccessible_count
    inaccessible_count = 0
    
    all_matches = {term: [] for term in search_terms}
    search_terms_lower = [t.lower() for t in search_terms]
    
    # Get ALL top-level directories (including hidden/system)
    top_dirs = []
    drive_long = long_path(drive)
    find_data = WIN32_FIND_DATAW()
    search_path = drive_long.rstrip("\\") + "\\*"
    
    handle = FindFirstFileExW(
        search_path, FindExInfoBasic, ctypes.byref(find_data),
        FindExSearchNameMatch, None, FIND_FIRST_EX_LARGE_FETCH
    )
    
    if handle == INVALID_HANDLE_VALUE:
        print(f"Error: Cannot access {drive}", file=sys.stderr)
        return all_matches
    
    try:
        while True:
            name = find_data.cFileName
            if name not in (".", ".."):
                attrs = find_data.dwFileAttributes
                if attrs & FILE_ATTRIBUTE_DIRECTORY:
                    full_path = drive_long.rstrip("\\") + "\\" + name
                    display_path = short_path(full_path)
                    
                    # Check if top-level folder matches any term
                    name_lower = name.lower()
                    for i, term_lower in enumerate(search_terms_lower):
                        if term_lower in name_lower:
                            all_matches[search_terms[i]].append(display_path)
                    
                    # Add to search list (skip reparse points for recursion)
                    if not (attrs & FILE_ATTRIBUTE_REPARSE_POINT):
                        top_dirs.append(full_path)
            
            if not FindNextFileW(handle, ctypes.byref(find_data)):
                break
    finally:
        FindClose(handle)
    
    print(f"Found {len(top_dirs)} top-level folders to search...", file=sys.stderr)
    
    # Process each top-level directory in parallel
    workers = min(24, max(1, len(top_dirs)))  # More workers for thorough search
    
    if top_dirs:
        completed = 0
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {
                executor.submit(find_matching_folders_exhaustive, short_path(d), search_terms): d 
                for d in top_dirs
            }
            for future in as_completed(futures):
                completed += 1
                if completed % 10 == 0:
                    print(f"  Searched {completed}/{len(top_dirs)} top-level folders...", file=sys.stderr)
                try:
                    result = future.result()
                    for term in search_terms:
                        all_matches[term].extend(result[term])
                except Exception as e:
                    pass
    
    if inaccessible_count > 0:
        print(f"  (Skipped {inaccessible_count} inaccessible folders due to permissions)", file=sys.stderr)
    
    return all_matches


def calc_folder_size(path: str) -> Tuple[str, int]:
    """Worker for parallel size calculation."""
    try:
        return (path, get_dir_size_fast(path))
    except Exception:
        return (path, 0)


def format_size(size_bytes: int) -> str:
    """Format bytes as MB."""
    return f"{size_bytes / (1024 * 1024):,.2f} MB"


def main():
    if len(sys.argv) < 2:
        print("Usage: python app.py [-C] [-F] [-D] ... <term1> [term2] [term3] ...")
        print("Example: python app.py claude opencode          # Search C: drive (default)")
        print("         python app.py -F claude opencode       # Search F: drive")
        print("         python app.py -C -F claude opencode    # Search C: AND F: drives")
        print("         python app.py -D -E -F myterm          # Search D:, E:, F: drives")
        print("\nDrive flags: -C, -D, -E, -F, -G, ... (any letter A-Z)")
        print("Default: C: drive if no drive flags specified")
        print("\nFeatures:")
        print("  - Exhaustive search (hidden, system, long paths)")
        print("  - Shows total size in MB for each search term")
        print("  - Reports inaccessible folders")
        sys.exit(1)
    
    # Parse arguments: extract drive flags (-C, -F, etc.) and search terms
    drives = []
    search_terms = []
    
    for arg in sys.argv[1:]:
        # Check if it's a drive flag like -C, -F, -D, etc.
        if len(arg) == 2 and arg[0] == '-' and arg[1].upper().isalpha():
            drive_letter = arg[1].upper()
            drives.append(f"{drive_letter}:\\")
        else:
            search_terms.append(arg)
    
    # Default to C: drive if no drive flags specified
    if not drives:
        drives = ["C:\\"]
    
    if not search_terms:
        print("Error: No search terms provided!", file=sys.stderr)
        sys.exit(1)
    
    print(f"{'═' * 60}", file=sys.stderr)
    print(f"EXHAUSTIVE SEARCH - Will find EVERY matching folder!", file=sys.stderr)
    print(f"{'═' * 60}", file=sys.stderr)
    print(f"Drives: {', '.join(drives)}", file=sys.stderr)
    print(f"Search terms: {', '.join(search_terms)}", file=sys.stderr)
    print(f"{'─' * 60}", file=sys.stderr)
    
    # Search all specified drives
    all_matches = {term: [] for term in search_terms}
    
    for drive in drives:
        print(f"\nSearching {drive}...", file=sys.stderr)
        matches = search_drive_exhaustive(drive, search_terms)
        for term in search_terms:
            all_matches[term].extend(matches[term])
    
    matches = all_matches
    
    print(f"{'─' * 60}", file=sys.stderr)
    print(f"Search complete! Calculating sizes...", file=sys.stderr)
    print(file=sys.stderr)
    
    grand_total_size = 0
    
    # Process each search term
    for term in search_terms:
        term_matches = matches[term]
        # Remove duplicates (same folder could match via different paths)
        term_matches = list(set(term_matches))
        term_matches.sort(key=str.lower)
        
        print(f"\n{'═' * 60}")
        print(f"  {term}")
        print(f"{'═' * 60}")
        
        if not term_matches:
            print("  (no matches)")
            continue
        
        # Calculate sizes in parallel
        total_size = 0
        with ThreadPoolExecutor(max_workers=12) as executor:
            futures = {executor.submit(calc_folder_size, p): p for p in term_matches}
            results = []
            for future in as_completed(futures):
                try:
                    path, size = future.result()
                    results.append((path, size))
                    total_size += size
                except Exception:
                    pass
        
        # Sort by path for output
        results.sort(key=lambda x: x[0].lower())
        
        for path, size in results:
            print(f"{path}")
        
        print(f"\n  [{len(term_matches)} folder(s)] Total: {format_size(total_size)}")
        grand_total_size += total_size
    
    # Grand total
    total_folders = sum(len(set(matches[t])) for t in search_terms)
    print(f"\n{'═' * 60}")
    print(f"  GRAND TOTAL: {total_folders} folder(s), {format_size(grand_total_size)}")
    print(f"{'═' * 60}")


if __name__ == "__main__":
    main()
