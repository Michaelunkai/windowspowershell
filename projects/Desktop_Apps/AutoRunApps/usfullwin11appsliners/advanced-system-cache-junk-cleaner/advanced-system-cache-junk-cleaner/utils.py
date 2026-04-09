import os

def get_size(path):
    total = 0

    if not os.path.exists(path):
        return 0

    # If it's a file
    if os.path.isfile(path):
        try:
            return os.path.getsize(path)
        except:
            return 0

    # If it's a folder
    for root, dirs, files in os.walk(path):
        for f in files:
            fp = os.path.join(root, f)
            try:
                total += os.path.getsize(fp)
            except:
                pass  # skip unreadable files/folders

    return total


def format_size(size):
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if size < 1024:
            return f"{size:.2f}{unit}"
        size /= 1024
    return f"{size:.2f}TB"
