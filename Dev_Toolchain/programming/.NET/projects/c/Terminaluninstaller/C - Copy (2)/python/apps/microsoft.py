"""
Microsoft application cleaner for Ultimate Uninstaller
Cleans Microsoft products traces
"""

import os
from typing import Generator
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import CleanResult
from core.config import Config
from core.logger import Logger
from .base import AppCleanerBase, AppCleanSpec


class MicrosoftCleaner(AppCleanerBase):
    """Cleaner for Microsoft applications"""

    def _load_specs(self):
        """Load Microsoft application specifications"""
        self._specs = {
            'vscode': AppCleanSpec(
                name='vscode',
                display_name='Visual Studio Code',
                registry_patterns=[
                    'Visual Studio Code', 'VSCode', 'Code.exe',
                ],
                process_names=[
                    'Code.exe', 'Code - Insiders.exe',
                ],
                appdata_folders=[
                    'Code',
                    os.path.join('Code', 'Cache'),
                    os.path.join('Code', 'CachedData'),
                    os.path.join('Code', 'GPUCache'),
                    os.path.join('Code', 'User'),
                ],
                program_folders=[
                    'Microsoft VS Code',
                    'Microsoft VS Code Insiders',
                ],
            ),

            'visual_studio': AppCleanSpec(
                name='visual_studio',
                display_name='Visual Studio',
                registry_patterns=[
                    'Visual Studio', 'VisualStudio', 'devenv',
                ],
                process_names=[
                    'devenv.exe', 'MSBuild.exe', 'VsHub.exe',
                    'ServiceHub.Host.CLR.exe', 'ServiceHub.IdentityHost.exe',
                ],
                appdata_folders=[
                    os.path.join('Microsoft', 'VisualStudio'),
                ],
                programdata_folders=[
                    os.path.join('Microsoft', 'VisualStudio'),
                ],
                program_folders=[
                    os.path.join('Microsoft Visual Studio'),
                ],
            ),

            'office': AppCleanSpec(
                name='office',
                display_name='Microsoft Office',
                registry_patterns=[
                    'Microsoft Office', 'Office16', 'Office15',
                ],
                process_names=[
                    'WINWORD.EXE', 'EXCEL.EXE', 'POWERPNT.EXE',
                    'OUTLOOK.EXE', 'ONENOTE.EXE', 'MSACCESS.EXE',
                    'MSPUB.EXE', 'OfficeClickToRun.exe',
                ],
                appdata_folders=[
                    os.path.join('Microsoft', 'Office'),
                    os.path.join('Microsoft', 'Word'),
                    os.path.join('Microsoft', 'Excel'),
                    os.path.join('Microsoft', 'PowerPoint'),
                ],
                programdata_folders=[
                    os.path.join('Microsoft', 'Office'),
                ],
                program_folders=[
                    os.path.join('Microsoft Office'),
                ],
            ),

            'teams': AppCleanSpec(
                name='teams',
                display_name='Microsoft Teams',
                registry_patterns=[
                    'Microsoft Teams', 'Teams',
                ],
                process_names=[
                    'Teams.exe', 'ms-teams.exe',
                ],
                appdata_folders=[
                    'Microsoft Teams',
                    os.path.join('Microsoft', 'Teams'),
                ],
                program_folders=[
                    'Microsoft Teams',
                ],
            ),

            'onedrive': AppCleanSpec(
                name='onedrive',
                display_name='Microsoft OneDrive',
                registry_patterns=[
                    'OneDrive', 'SkyDrive',
                ],
                process_names=[
                    'OneDrive.exe', 'OneDriveSetup.exe',
                ],
                appdata_folders=[
                    os.path.join('Microsoft', 'OneDrive'),
                ],
                programdata_folders=[
                    os.path.join('Microsoft OneDrive'),
                ],
                program_folders=[
                    'Microsoft OneDrive',
                ],
            ),

            'edge': AppCleanSpec(
                name='edge',
                display_name='Microsoft Edge',
                registry_patterns=[
                    'Microsoft Edge', 'Edge', 'msedge',
                ],
                process_names=[
                    'msedge.exe', 'MicrosoftEdge.exe', 'MicrosoftEdgeUpdate.exe',
                ],
                appdata_folders=[
                    os.path.join('Microsoft', 'Edge'),
                ],
                program_folders=[
                    os.path.join('Microsoft', 'Edge'),
                ],
            ),

            'skype': AppCleanSpec(
                name='skype',
                display_name='Skype',
                registry_patterns=[
                    'Skype',
                ],
                process_names=[
                    'Skype.exe', 'SkypeApp.exe', 'SkypeHost.exe',
                ],
                appdata_folders=[
                    'Skype',
                    os.path.join('Microsoft', 'Skype for Desktop'),
                ],
                program_folders=[
                    'Skype',
                    os.path.join('Microsoft', 'Skype for Desktop'),
                ],
            ),

            'dotnet': AppCleanSpec(
                name='dotnet',
                display_name='.NET Framework/Core',
                registry_patterns=[
                    '.NET', 'dotnet', 'NETFramework',
                ],
                process_names=[
                    'dotnet.exe',
                ],
                appdata_folders=[
                    '.dotnet',
                    'NuGet',
                ],
                program_folders=[
                    'dotnet',
                ],
            ),
        }

    def clean_microsoft_caches(self) -> Generator[CleanResult, None, None]:
        """Clean Microsoft cache folders"""
        cache_paths = [
            os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Microsoft'),
        ]

        for path in cache_paths:
            if os.path.exists(path):
                for item in os.listdir(path):
                    item_path = os.path.join(path, item)
                    if os.path.isdir(item_path):
                        cache_sub = os.path.join(item_path, 'Cache')
                        if os.path.exists(cache_sub):
                            yield from self._remove_directory(cache_sub)

    def clean_vscode_extensions(self) -> Generator[CleanResult, None, None]:
        """Clean VS Code extensions cache"""
        extensions_path = os.path.join(
            os.environ.get('USERPROFILE', ''),
            '.vscode', 'extensions'
        )

        if os.path.exists(extensions_path):
            yield from self._remove_directory(extensions_path)

    def clean_nuget_cache(self) -> Generator[CleanResult, None, None]:
        """Clean NuGet package cache"""
        nuget_paths = [
            os.path.join(os.environ.get('USERPROFILE', ''), '.nuget', 'packages'),
            os.path.join(os.environ.get('LOCALAPPDATA', ''), 'NuGet', 'Cache'),
        ]

        for path in nuget_paths:
            if os.path.exists(path):
                yield from self._remove_directory(path)

    def clean_temp_files(self) -> Generator[CleanResult, None, None]:
        """Clean Microsoft temp files"""
        temp_patterns = ['*.tmp', '*.log', '*.bak']

        ms_paths = [
            os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Microsoft'),
            os.path.join(os.environ.get('APPDATA', ''), 'Microsoft'),
        ]

        for path in ms_paths:
            if os.path.exists(path):
                for root, dirs, files in os.walk(path):
                    for f in files:
                        if any(f.endswith(ext.replace('*', '')) for ext in temp_patterns):
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
