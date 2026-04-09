"""
Network cleaner for Ultimate Uninstaller
Cleans network configurations, DNS cache, and host entries
"""

import os
import subprocess
import shutil
from typing import List, Dict, Generator, Optional
from dataclasses import dataclass, field
from datetime import datetime
import json
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseCleaner, CleanResult, ScanResult
from core.config import Config
from core.logger import Logger


@dataclass
class NetworkBackupEntry:
    """Network backup entry"""
    item_type: str
    name: str
    data: Dict
    timestamp: str


@dataclass
class NetworkBackup:
    """Network backup container"""
    entries: List[NetworkBackupEntry] = field(default_factory=list)
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    hosts_content: str = ""


class NetworkCleaner(BaseCleaner):
    """Cleans network configurations"""

    PROTECTED_HOSTS = [
        'localhost', 'broadcasthost',
        'local', 'ip6-localhost', 'ip6-loopback',
    ]

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._backup: Optional[NetworkBackup] = None
        self._cleaned_items: List[str] = []

    def clean(self, items: List[ScanResult]) -> Generator[CleanResult, None, None]:
        """Clean network items"""
        self._backup = NetworkBackup()
        self._backup_hosts_file()

        for item in items:
            if self.is_cancelled():
                break
            self.wait_if_paused()

            if item.item_type == 'dns_cache':
                yield from self._clean_dns_cache()
            elif item.item_type == 'host_entry':
                yield from self._clean_host_entry(item)
            elif item.item_type == 'proxy_setting':
                yield from self._clean_proxy(item)
            elif item.item_type == 'network_profile':
                yield from self._clean_network_profile(item)

    def _backup_hosts_file(self):
        """Backup hosts file content"""
        hosts_path = os.path.join(
            os.environ.get('SYSTEMROOT', 'C:\\Windows'),
            'System32', 'drivers', 'etc', 'hosts'
        )

        if os.path.exists(hosts_path):
            try:
                with open(hosts_path, 'r', encoding='utf-8', errors='ignore') as f:
                    self._backup.hosts_content = f.read()
            except Exception:
                pass

    def _clean_dns_cache(self) -> Generator[CleanResult, None, None]:
        """Flush DNS cache"""
        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="flush (dry run)",
                target="DNS Cache",
                success=True,
                message="Would flush DNS cache"
            )
            return

        try:
            result = subprocess.run(
                ['ipconfig', '/flushdns'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                self._cleaned_items.append("DNS Cache")
                yield CleanResult(
                    module=self.name,
                    action="flush",
                    target="DNS Cache",
                    success=True,
                    message="DNS cache flushed"
                )
            else:
                yield CleanResult(
                    module=self.name,
                    action="flush",
                    target="DNS Cache",
                    success=False,
                    message=result.stderr.strip()
                )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="flush",
                target="DNS Cache",
                success=False,
                message=str(e)
            )

    def _clean_host_entry(self, item: ScanResult) -> Generator[CleanResult, None, None]:
        """Remove host entry"""
        hostname = item.name
        line_number = item.details.get('line_number', 0)

        if hostname.lower() in self.PROTECTED_HOSTS:
            yield CleanResult(
                module=self.name,
                action="skip",
                target=hostname,
                success=False,
                message="Protected host entry"
            )
            return

        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=f"Host entry: {hostname}",
                success=True,
                message="Would remove host entry"
            )
            return

        hosts_path = os.path.join(
            os.environ.get('SYSTEMROOT', 'C:\\Windows'),
            'System32', 'drivers', 'etc', 'hosts'
        )

        try:
            with open(hosts_path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()

            new_lines = []
            removed = False

            for i, line in enumerate(lines, 1):
                stripped = line.strip()
                if stripped and not stripped.startswith('#'):
                    parts = stripped.split()
                    if len(parts) >= 2 and parts[1].lower() == hostname.lower():
                        self._backup.entries.append(NetworkBackupEntry(
                            item_type='host_entry',
                            name=hostname,
                            data={'line': line, 'line_number': i},
                            timestamp=datetime.now().isoformat()
                        ))
                        removed = True
                        continue
                new_lines.append(line)

            if removed:
                with open(hosts_path, 'w', encoding='utf-8') as f:
                    f.writelines(new_lines)

                self._cleaned_items.append(hostname)
                yield CleanResult(
                    module=self.name,
                    action="delete",
                    target=f"Host entry: {hostname}",
                    success=True,
                    message="Removed"
                )
            else:
                yield CleanResult(
                    module=self.name,
                    action="delete",
                    target=f"Host entry: {hostname}",
                    success=False,
                    message="Entry not found"
                )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="delete",
                target=f"Host entry: {hostname}",
                success=False,
                message=str(e)
            )

    def _clean_proxy(self, item: ScanResult) -> Generator[CleanResult, None, None]:
        """Remove proxy settings"""
        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="delete (dry run)",
                target="Proxy settings",
                success=True,
                message="Would remove proxy settings"
            )
            return

        try:
            import winreg
            key_path = r"Software\Microsoft\Windows\CurrentVersion\Internet Settings"

            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path, 0,
                              winreg.KEY_ALL_ACCESS) as key:
                try:
                    old_enable = winreg.QueryValueEx(key, 'ProxyEnable')[0]
                    old_server = winreg.QueryValueEx(key, 'ProxyServer')[0]

                    self._backup.entries.append(NetworkBackupEntry(
                        item_type='proxy_setting',
                        name='proxy',
                        data={'enable': old_enable, 'server': old_server},
                        timestamp=datetime.now().isoformat()
                    ))

                    winreg.SetValueEx(key, 'ProxyEnable', 0, winreg.REG_DWORD, 0)
                    winreg.DeleteValue(key, 'ProxyServer')

                    self._cleaned_items.append("Proxy settings")
                    yield CleanResult(
                        module=self.name,
                        action="delete",
                        target="Proxy settings",
                        success=True,
                        message="Proxy disabled and removed"
                    )
                except WindowsError as e:
                    yield CleanResult(
                        module=self.name,
                        action="delete",
                        target="Proxy settings",
                        success=False,
                        message=str(e)
                    )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="delete",
                target="Proxy settings",
                success=False,
                message=str(e)
            )

    def _clean_network_profile(self, item: ScanResult) -> Generator[CleanResult, None, None]:
        """Remove network profile"""
        profile_name = item.name

        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=f"Network profile: {profile_name}",
                success=True,
                message="Would remove network profile"
            )
            return

        try:
            export_result = subprocess.run(
                ['netsh', 'wlan', 'export', 'profile', f'name={profile_name}',
                 'folder=%TEMP%'],
                capture_output=True, text=True, timeout=30
            )

            result = subprocess.run(
                ['netsh', 'wlan', 'delete', 'profile', f'name={profile_name}'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                self._cleaned_items.append(profile_name)
                yield CleanResult(
                    module=self.name,
                    action="delete",
                    target=f"Network profile: {profile_name}",
                    success=True,
                    message="Profile removed"
                )
            else:
                yield CleanResult(
                    module=self.name,
                    action="delete",
                    target=f"Network profile: {profile_name}",
                    success=False,
                    message=result.stderr.strip()
                )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="delete",
                target=f"Network profile: {profile_name}",
                success=False,
                message=str(e)
            )

    def save_backup(self, path: str):
        """Save backup to file"""
        if self._backup:
            backup_data = {
                'entries': [
                    {
                        'item_type': e.item_type,
                        'name': e.name,
                        'data': e.data,
                        'timestamp': e.timestamp
                    }
                    for e in self._backup.entries
                ],
                'created_at': self._backup.created_at,
                'hosts_content': self._backup.hosts_content,
            }
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(backup_data, f, indent=2)

    def restore_backup(self, path: str) -> Generator[CleanResult, None, None]:
        """Restore from backup file"""
        with open(path, 'r', encoding='utf-8') as f:
            backup_data = json.load(f)

        if backup_data.get('hosts_content'):
            hosts_path = os.path.join(
                os.environ.get('SYSTEMROOT', 'C:\\Windows'),
                'System32', 'drivers', 'etc', 'hosts'
            )
            try:
                with open(hosts_path, 'w', encoding='utf-8') as f:
                    f.write(backup_data['hosts_content'])
                yield CleanResult(
                    module=self.name,
                    action="restore",
                    target="hosts file",
                    success=True,
                    message="Restored"
                )
            except Exception as e:
                yield CleanResult(
                    module=self.name,
                    action="restore",
                    target="hosts file",
                    success=False,
                    message=str(e)
                )

    def get_cleaned_items(self) -> List[str]:
        """Get list of cleaned items"""
        return self._cleaned_items
