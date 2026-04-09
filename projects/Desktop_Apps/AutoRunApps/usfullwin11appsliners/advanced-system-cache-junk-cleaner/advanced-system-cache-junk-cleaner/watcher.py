"""
Watcher using watchdog to monitor allowed target folders. On new file creation, runs a quick scan and logs.
"""
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import threading
import time
import logging
from pathlib import Path

logger = logging.getLogger('cleanup')

class NewFileHandler(FileSystemEventHandler):
    def __init__(self, targets_map, cfg, callback=None):
        super().__init__()
        self.targets_map = targets_map
        self.cfg = cfg
        self.callback = callback

    def on_created(self, event):
        if event.is_directory:
            return
        logger.info('New file detected: %s', event.src_path)
        if self.callback:
            try:
                self.callback(event.src_path)
            except Exception:
                logger.exception('Callback failed')

def start_watcher_interactive(targets_map, cfg):
    paths = set()
    for cat, lst in targets_map.items():
        for p in lst:
            try:
                pp = Path(p)
                if pp.exists():
                    paths.add(str(pp))
            except Exception:
                continue
    if not paths:
        print('No paths to watch')
        return
    observer = Observer()
    handler = NewFileHandler(targets_map, cfg, callback=lambda s: print('New file:', s))
    for p in paths:
        observer.schedule(handler, p, recursive=False)
    observer.start()
    print('Watcher started for paths:')
    for p in paths:
        print(' -', p)
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
