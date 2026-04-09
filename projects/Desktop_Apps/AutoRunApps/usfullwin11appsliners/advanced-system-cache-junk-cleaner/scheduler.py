"""
Helpers to install or remove a weekly Windows scheduled task to run the cleanup script.
Requires administrative privileges to register the task.
"""
import subprocess
from pathlib import Path
import logging
import sys

logger = logging.getLogger('cleanup')

def install_scheduled_task(cfg):
    script = Path(__file__).parent / 'main.py'
    if not script.exists():
        print('main.py not found; cannot install scheduled task')
        return
    # build command to run main.py with desired args
    cmd = f'schtasks /Create /SC WEEKLY /D MON /TN "SystemCleanupWeekly" /TR "\\"{sys.executable}\\" \\"{script}\\" --clean --execute --targets all" /ST 03:00 /F'
    try:
        subprocess.run(cmd, shell=True, check=True)
        logger.info('Scheduled task created')
        print('Scheduled task created (runs weekly).')
    except subprocess.CalledProcessError as e:
        logger.exception('Failed to create scheduled task: %s', e)
        print('Failed to create scheduled task. Run as Administrator.')

def remove_scheduled_task():
    cmd = 'schtasks /Delete /TN "SystemCleanupWeekly" /F'
    try:
        subprocess.run(cmd, shell=True, check=True)
        logger.info('Scheduled task removed')
        print('Scheduled task removed.')
    except subprocess.CalledProcessError as e:
        logger.exception('Failed to remove scheduled task: %s', e)
        print('Failed to remove scheduled task. Run as Administrator.')
