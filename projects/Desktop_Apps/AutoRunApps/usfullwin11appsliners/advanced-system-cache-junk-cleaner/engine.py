import os
import shutil
import send2trash
from utils import get_size, format_size


class CleanupEngine:

    def __init__(self):
        self.SYSTEM_TEMP = [
            os.getenv("TEMP"),
            os.getenv("TMP")
        ]

        self.USER_CACHE = [
            os.path.expanduser("~\\AppData\\Local\\Temp"),
            os.path.expanduser("~\\AppData\\Local\\Cache"),
            os.path.expanduser("~\\AppData\\Roaming\\Cache")
        ]

        self.CHROME_CACHE = [
            os.path.expanduser("~\\AppData\\Local\\Google\\Chrome\\User Data\\Default\\Cache")
        ]

        self.FIREFOX_CACHE = [
            os.path.expanduser("~\\AppData\\Local\\Mozilla\\Firefox\\Profiles")
        ]

        self.PIP_CACHE = [
            os.path.expanduser("~\\.cache\\pip"),
            os.path.expanduser("~\\.pip")
        ]

        self.THUMBNAIL_CACHE = [
            os.path.expanduser("~\\AppData\\Local\\Microsoft\\Windows\\Explorer")
        ]

        self.RECYCLE_BIN = [
            os.path.expanduser("~\\Recycle.Bin")
        ]

    # ================================================================
    def scan_paths(self, path_list):
        results = {}
        total = 0
        if not path_list:
            return results, 0

        for p in path_list:
            if not p or not os.path.exists(p):
                results[p] = "0B"
                continue

            size = get_size(p)
            results[p] = format_size(size)
            total += size

        return results, total

    # ================================================================
    def scan(self):
        report = {}

        groups = {
            "System Temp": self.SYSTEM_TEMP,
            "User Cache": self.USER_CACHE,
            "Chrome Cache": self.CHROME_CACHE,
            "Firefox Cache": self.FIREFOX_CACHE,
            "Pip Cache": self.PIP_CACHE,
            "Thumbnail Cache": self.THUMBNAIL_CACHE,
            "Recycle Bin": self.RECYCLE_BIN
        }

        total_all = 0

        for name, paths in groups.items():
            p_report, p_total = self.scan_paths(paths)
            report[name] = p_report
            total_all += p_total

        report["TOTAL CLEANABLE"] = format_size(total_all)
        return report

    # ================================================================
    def cleanup_execute(self):
        deleted_summary = {}

        def delete_path(p):
            if not p or not os.path.exists(p):
                return 0

            before = get_size(p)

            try:
                send2trash.send2trash(p)  # SAFE DELETE
            except:
                try:
                    if os.path.isfile(p):
                        os.remove(p)
                    else:
                        shutil.rmtree(p)
                except:
                    return 0

            return before

        groups = {
            "System Temp": self.SYSTEM_TEMP,
            "User Cache": self.USER_CACHE,
            "Chrome Cache": self.CHROME_CACHE,
            "Firefox Cache": self.FIREFOX_CACHE,
            "Pip Cache": self.PIP_CACHE,
            "Thumbnail Cache": self.THUMBNAIL_CACHE,
            "Recycle Bin": self.RECYCLE_BIN
        }

        total_deleted = 0

        for name, paths in groups.items():
            deleted = 0
            for p in paths:
                deleted += delete_path(p)

            deleted_summary[name] = format_size(deleted)
            total_deleted += deleted

        deleted_summary["TOTAL DELETED"] = format_size(total_deleted)
        return deleted_summary
