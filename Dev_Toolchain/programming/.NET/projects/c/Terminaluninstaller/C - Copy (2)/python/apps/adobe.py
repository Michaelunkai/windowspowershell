"""
Adobe application cleaner for Ultimate Uninstaller
Cleans Adobe products traces
"""

import os
from typing import Generator
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import CleanResult
from core.config import Config
from core.logger import Logger
from .base import AppCleanerBase, AppCleanSpec


class AdobeCleaner(AppCleanerBase):
    """Cleaner for Adobe applications"""

    def _load_specs(self):
        """Load Adobe application specifications"""
        self._specs = {
            'adobe_reader': AppCleanSpec(
                name='adobe_reader',
                display_name='Adobe Acrobat Reader',
                registry_patterns=[
                    'Adobe', 'Acrobat', 'AcroRd32',
                ],
                process_names=[
                    'AcroRd32.exe', 'Acrobat.exe', 'AdobeARM.exe',
                    'AdobeCollabSync.exe',
                ],
                appdata_folders=[
                    'Adobe',
                    os.path.join('Adobe', 'Acrobat'),
                ],
                programdata_folders=[
                    'Adobe',
                ],
                program_folders=[
                    os.path.join('Adobe', 'Acrobat Reader DC'),
                    os.path.join('Adobe', 'Acrobat DC'),
                    'Adobe',
                ],
            ),

            'adobe_creative_cloud': AppCleanSpec(
                name='adobe_creative_cloud',
                display_name='Adobe Creative Cloud',
                registry_patterns=[
                    'Adobe', 'Creative Cloud', 'ACC',
                ],
                process_names=[
                    'Creative Cloud.exe', 'CCXProcess.exe', 'CCLibrary.exe',
                    'CoreSync.exe', 'AdobeIPCBroker.exe', 'node.exe',
                ],
                appdata_folders=[
                    'Adobe',
                    os.path.join('Adobe', 'Creative Cloud'),
                    os.path.join('Adobe', 'Creative Cloud Libraries'),
                ],
                programdata_folders=[
                    'Adobe',
                ],
                program_folders=[
                    os.path.join('Adobe', 'Adobe Creative Cloud'),
                    'Adobe',
                ],
            ),

            'adobe_photoshop': AppCleanSpec(
                name='adobe_photoshop',
                display_name='Adobe Photoshop',
                registry_patterns=[
                    'Photoshop', 'Adobe Photoshop',
                ],
                process_names=[
                    'Photoshop.exe', 'PhotoshopPrefsManager.exe',
                ],
                appdata_folders=[
                    os.path.join('Adobe', 'Adobe Photoshop'),
                ],
                program_folders=[
                    os.path.join('Adobe', 'Adobe Photoshop 2024'),
                    os.path.join('Adobe', 'Adobe Photoshop 2023'),
                    os.path.join('Adobe', 'Adobe Photoshop CC'),
                ],
            ),

            'adobe_illustrator': AppCleanSpec(
                name='adobe_illustrator',
                display_name='Adobe Illustrator',
                registry_patterns=[
                    'Illustrator', 'Adobe Illustrator',
                ],
                process_names=[
                    'Illustrator.exe',
                ],
                appdata_folders=[
                    os.path.join('Adobe', 'Adobe Illustrator'),
                ],
                program_folders=[
                    os.path.join('Adobe', 'Adobe Illustrator 2024'),
                    os.path.join('Adobe', 'Adobe Illustrator 2023'),
                ],
            ),

            'adobe_premiere': AppCleanSpec(
                name='adobe_premiere',
                display_name='Adobe Premiere Pro',
                registry_patterns=[
                    'Premiere', 'Adobe Premiere',
                ],
                process_names=[
                    'Adobe Premiere Pro.exe',
                ],
                appdata_folders=[
                    os.path.join('Adobe', 'Premiere Pro'),
                ],
                program_folders=[
                    os.path.join('Adobe', 'Adobe Premiere Pro 2024'),
                    os.path.join('Adobe', 'Adobe Premiere Pro 2023'),
                ],
            ),

            'adobe_flash': AppCleanSpec(
                name='adobe_flash',
                display_name='Adobe Flash Player',
                registry_patterns=[
                    'Flash Player', 'Macromedia', 'ShockwaveFlash',
                ],
                process_names=[
                    'FlashPlayerPlugin.exe', 'FlashUtil.exe',
                ],
                appdata_folders=[
                    'Macromedia',
                    os.path.join('Adobe', 'Flash Player'),
                    os.path.join('Macromedia', 'Flash Player'),
                ],
                program_folders=[
                    'Macromedia',
                    os.path.join('Adobe', 'Flash Player'),
                ],
            ),
        }

    def clean_all_adobe(self) -> Generator[CleanResult, None, None]:
        """Clean all Adobe products"""
        for app_name in self._specs.keys():
            yield from self._clean_app(app_name)

    def clean_adobe_caches(self) -> Generator[CleanResult, None, None]:
        """Clean Adobe cache folders"""
        cache_paths = [
            os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Adobe'),
            os.path.join(os.environ.get('APPDATA', ''), 'Adobe'),
            os.path.join(os.environ.get('TEMP', ''), 'Adobe'),
        ]

        for path in cache_paths:
            if os.path.exists(path):
                cache_dir = os.path.join(path, 'Cache')
                if os.path.exists(cache_dir):
                    yield from self._remove_directory(cache_dir)

                for item in os.listdir(path):
                    item_path = os.path.join(path, item)
                    if os.path.isdir(item_path) and 'cache' in item.lower():
                        yield from self._remove_directory(item_path)

    def clean_adobe_logs(self) -> Generator[CleanResult, None, None]:
        """Clean Adobe log files"""
        log_paths = [
            os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Adobe'),
            os.path.join(os.environ.get('APPDATA', ''), 'Adobe'),
            os.path.join(os.environ.get('PROGRAMDATA', ''), 'Adobe'),
        ]

        for path in log_paths:
            if os.path.exists(path):
                for root, dirs, files in os.walk(path):
                    for f in files:
                        if f.endswith('.log'):
                            file_path = os.path.join(root, f)
                            if self.config.dry_run:
                                yield CleanResult(
                                    module=self.name,
                                    action="delete (dry run)",
                                    target=file_path,
                                    success=True,
                                    message="Would delete"
                                )
                            else:
                                try:
                                    os.remove(file_path)
                                    yield CleanResult(
                                        module=self.name,
                                        action="delete",
                                        target=file_path,
                                        success=True,
                                        message="Deleted"
                                    )
                                except:
                                    pass
