"""
Development tools cleaner for Ultimate Uninstaller
Cleans development tools and IDEs
"""

import os
from typing import Generator
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import CleanResult
from core.config import Config
from core.logger import Logger
from .base import AppCleanerBase, AppCleanSpec


class DevelopmentToolsCleaner(AppCleanerBase):
    """Cleaner for development tools and IDEs"""

    def _load_specs(self):
        """Load development tools specifications"""
        self._specs = {
            'nodejs': AppCleanSpec(
                name='nodejs',
                display_name='Node.js',
                registry_patterns=[
                    'Node.js', 'nodejs', 'npm',
                ],
                process_names=[
                    'node.exe', 'npm.cmd',
                ],
                appdata_folders=[
                    'npm',
                    'npm-cache',
                ],
                program_folders=[
                    'nodejs',
                ],
            ),

            'python': AppCleanSpec(
                name='python',
                display_name='Python',
                registry_patterns=[
                    'Python', 'PythonCore',
                ],
                process_names=[
                    'python.exe', 'pythonw.exe', 'pip.exe',
                ],
                appdata_folders=[
                    'Python',
                    'pip',
                ],
                program_folders=[
                    'Python',
                    'Python39',
                    'Python310',
                    'Python311',
                    'Python312',
                ],
            ),

            'git': AppCleanSpec(
                name='git',
                display_name='Git',
                registry_patterns=[
                    'Git', 'GitForWindows',
                ],
                process_names=[
                    'git.exe', 'git-bash.exe', 'gitk.exe',
                ],
                appdata_folders=[
                    'GitCredentialManager',
                ],
                program_folders=[
                    'Git',
                ],
            ),

            'jetbrains': AppCleanSpec(
                name='jetbrains',
                display_name='JetBrains IDEs',
                registry_patterns=[
                    'JetBrains', 'IntelliJ', 'PyCharm', 'WebStorm',
                    'PhpStorm', 'Rider', 'CLion', 'GoLand', 'DataGrip',
                ],
                process_names=[
                    'idea64.exe', 'pycharm64.exe', 'webstorm64.exe',
                    'phpstorm64.exe', 'rider64.exe', 'clion64.exe',
                    'goland64.exe', 'datagrip64.exe',
                ],
                appdata_folders=[
                    'JetBrains',
                ],
                program_folders=[
                    'JetBrains',
                ],
            ),

            'docker': AppCleanSpec(
                name='docker',
                display_name='Docker Desktop',
                registry_patterns=[
                    'Docker', 'Docker Desktop',
                ],
                process_names=[
                    'Docker Desktop.exe', 'dockerd.exe',
                    'com.docker.backend.exe', 'com.docker.proxy.exe',
                ],
                appdata_folders=[
                    'Docker',
                    'Docker Desktop',
                ],
                programdata_folders=[
                    'Docker',
                ],
                program_folders=[
                    'Docker',
                ],
            ),

            'android_studio': AppCleanSpec(
                name='android_studio',
                display_name='Android Studio',
                registry_patterns=[
                    'Android Studio', 'AndroidStudio',
                ],
                process_names=[
                    'studio64.exe', 'adb.exe', 'emulator.exe',
                ],
                appdata_folders=[
                    '.android',
                    'Google',
                ],
                program_folders=[
                    'Android',
                    'Android Studio',
                ],
            ),

            'java': AppCleanSpec(
                name='java',
                display_name='Java JDK/JRE',
                registry_patterns=[
                    'Java', 'JavaSoft', 'JDK', 'JRE',
                ],
                process_names=[
                    'java.exe', 'javaw.exe', 'javac.exe',
                ],
                appdata_folders=[
                    '.java',
                ],
                program_folders=[
                    'Java',
                ],
            ),

            'rust': AppCleanSpec(
                name='rust',
                display_name='Rust',
                registry_patterns=[
                    'Rust', 'rustup', 'cargo',
                ],
                process_names=[
                    'rustc.exe', 'cargo.exe', 'rustup.exe',
                ],
                appdata_folders=[
                    '.rustup',
                    '.cargo',
                ],
            ),

            'golang': AppCleanSpec(
                name='golang',
                display_name='Go',
                registry_patterns=[
                    'Go', 'golang',
                ],
                process_names=[
                    'go.exe',
                ],
                appdata_folders=[
                    'go',
                ],
                program_folders=[
                    'Go',
                ],
            ),

            'sublime_text': AppCleanSpec(
                name='sublime_text',
                display_name='Sublime Text',
                registry_patterns=[
                    'Sublime Text',
                ],
                process_names=[
                    'sublime_text.exe',
                ],
                appdata_folders=[
                    'Sublime Text',
                    'Sublime Text 3',
                ],
                program_folders=[
                    'Sublime Text',
                    'Sublime Text 3',
                ],
            ),

            'notepadpp': AppCleanSpec(
                name='notepadpp',
                display_name='Notepad++',
                registry_patterns=[
                    'Notepad++',
                ],
                process_names=[
                    'notepad++.exe',
                ],
                appdata_folders=[
                    'Notepad++',
                ],
                program_folders=[
                    'Notepad++',
                ],
            ),
        }

    def clean_npm_cache(self) -> Generator[CleanResult, None, None]:
        """Clean npm cache"""
        npm_cache = os.path.join(os.environ.get('APPDATA', ''), 'npm-cache')
        if os.path.exists(npm_cache):
            yield from self._remove_directory(npm_cache)

    def clean_pip_cache(self) -> Generator[CleanResult, None, None]:
        """Clean pip cache"""
        pip_cache = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'pip', 'cache')
        if os.path.exists(pip_cache):
            yield from self._remove_directory(pip_cache)

    def clean_gradle_cache(self) -> Generator[CleanResult, None, None]:
        """Clean Gradle cache"""
        gradle_cache = os.path.join(os.environ.get('USERPROFILE', ''), '.gradle', 'caches')
        if os.path.exists(gradle_cache):
            yield from self._remove_directory(gradle_cache)

    def clean_maven_cache(self) -> Generator[CleanResult, None, None]:
        """Clean Maven local repository"""
        maven_repo = os.path.join(os.environ.get('USERPROFILE', ''), '.m2', 'repository')
        if os.path.exists(maven_repo):
            yield from self._remove_directory(maven_repo)

    def clean_cargo_cache(self) -> Generator[CleanResult, None, None]:
        """Clean Cargo/Rust cache"""
        cargo_cache = os.path.join(os.environ.get('USERPROFILE', ''), '.cargo', 'registry')
        if os.path.exists(cargo_cache):
            yield from self._remove_directory(cargo_cache)

    def clean_docker_data(self) -> Generator[CleanResult, None, None]:
        """Clean Docker data"""
        docker_paths = [
            os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Docker'),
            os.path.join(os.environ.get('PROGRAMDATA', ''), 'Docker'),
        ]

        for path in docker_paths:
            if os.path.exists(path):
                yield from self._remove_directory(path)

    def clean_all_caches(self) -> Generator[CleanResult, None, None]:
        """Clean all development caches"""
        yield from self.clean_npm_cache()
        yield from self.clean_pip_cache()
        yield from self.clean_gradle_cache()
        yield from self.clean_maven_cache()
        yield from self.clean_cargo_cache()
