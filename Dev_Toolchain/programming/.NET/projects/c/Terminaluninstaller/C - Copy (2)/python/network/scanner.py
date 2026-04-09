"""
Network scanner for Ultimate Uninstaller
Scans network configurations, DNS cache, and host entries
"""

import os
import subprocess
import re
from typing import List, Dict, Generator, Optional, Set
from dataclasses import dataclass, field
from enum import Enum
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseScanner, ScanResult
from core.config import Config
from core.logger import Logger


class NetworkItemType(Enum):
    DNS_CACHE = "dns_cache"
    HOST_ENTRY = "host_entry"
    PROXY_SETTING = "proxy_setting"
    NETWORK_PROFILE = "network_profile"
    FIREWALL_RULE = "firewall_rule"
    ARP_ENTRY = "arp_entry"
    ROUTE = "route"


@dataclass
class DnsCacheEntry:
    """DNS cache entry"""
    name: str
    record_type: str
    ttl: int
    data: str


@dataclass
class HostEntry:
    """Host file entry"""
    ip_address: str
    hostname: str
    line_number: int
    comment: Optional[str] = None


@dataclass
class ProxySetting:
    """Proxy configuration"""
    enabled: bool
    server: str
    port: int
    bypass_list: List[str] = field(default_factory=list)


@dataclass
class NetworkProfile:
    """Network profile information"""
    name: str
    description: str
    profile_type: str
    ssid: Optional[str] = None


class NetworkScanner(BaseScanner):
    """Scans network configurations"""

    PROTECTED_HOSTS = [
        'localhost', 'broadcasthost',
        'local', 'ip6-localhost', 'ip6-loopback',
    ]

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._dns_cache: List[DnsCacheEntry] = []
        self._host_entries: List[HostEntry] = []

    def scan(self, pattern: str = None) -> Generator[ScanResult, None, None]:
        """Scan network configurations"""
        self.log_info("Scanning network configurations")

        yield from self._scan_dns_cache(pattern)
        yield from self._scan_hosts_file(pattern)
        yield from self._scan_proxy_settings(pattern)
        yield from self._scan_network_profiles(pattern)

    def _scan_dns_cache(self, pattern: str = None) -> Generator[ScanResult, None, None]:
        """Scan DNS cache"""
        try:
            result = subprocess.run(
                ['ipconfig', '/displaydns'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                entries = self._parse_dns_output(result.stdout)
                for entry in entries:
                    if pattern and pattern.lower() not in entry.name.lower():
                        continue

                    self._dns_cache.append(entry)
                    yield ScanResult(
                        module=self.name,
                        item_type=NetworkItemType.DNS_CACHE.value,
                        name=entry.name,
                        path=f"DNS:{entry.name}",
                        size=0,
                        details={
                            'record_type': entry.record_type,
                            'ttl': entry.ttl,
                            'data': entry.data,
                        }
                    )
        except Exception as e:
            self.log_error(f"Failed to scan DNS cache: {e}")

    def _parse_dns_output(self, output: str) -> List[DnsCacheEntry]:
        """Parse ipconfig /displaydns output"""
        entries = []
        current_name = None
        current_type = None
        current_ttl = 0
        current_data = None

        for line in output.split('\n'):
            line = line.strip()

            if 'Record Name' in line:
                if current_name and current_data:
                    entries.append(DnsCacheEntry(
                        name=current_name,
                        record_type=current_type or 'A',
                        ttl=current_ttl,
                        data=current_data
                    ))
                current_name = line.split(':')[-1].strip()
                current_type = None
                current_ttl = 0
                current_data = None

            elif 'Record Type' in line:
                type_val = line.split(':')[-1].strip()
                type_map = {'1': 'A', '5': 'CNAME', '28': 'AAAA'}
                current_type = type_map.get(type_val, type_val)

            elif 'Time To Live' in line:
                try:
                    current_ttl = int(line.split(':')[-1].strip())
                except ValueError:
                    current_ttl = 0

            elif 'Data' in line or 'A (Host) Record' in line:
                current_data = line.split(':')[-1].strip()

        if current_name and current_data:
            entries.append(DnsCacheEntry(
                name=current_name,
                record_type=current_type or 'A',
                ttl=current_ttl,
                data=current_data
            ))

        return entries

    def _scan_hosts_file(self, pattern: str = None) -> Generator[ScanResult, None, None]:
        """Scan hosts file entries"""
        hosts_path = os.path.join(
            os.environ.get('SYSTEMROOT', 'C:\\Windows'),
            'System32', 'drivers', 'etc', 'hosts'
        )

        if not os.path.exists(hosts_path):
            return

        try:
            with open(hosts_path, 'r', encoding='utf-8', errors='ignore') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue

                    parts = line.split()
                    if len(parts) >= 2:
                        ip = parts[0]
                        hostname = parts[1]
                        comment = ' '.join(parts[2:]) if len(parts) > 2 else None

                        if hostname.lower() in self.PROTECTED_HOSTS:
                            continue

                        if pattern and pattern.lower() not in hostname.lower():
                            continue

                        entry = HostEntry(
                            ip_address=ip,
                            hostname=hostname,
                            line_number=line_num,
                            comment=comment
                        )
                        self._host_entries.append(entry)

                        yield ScanResult(
                            module=self.name,
                            item_type=NetworkItemType.HOST_ENTRY.value,
                            name=hostname,
                            path=f"HOSTS:{line_num}:{hostname}",
                            size=0,
                            details={
                                'ip_address': ip,
                                'line_number': line_num,
                                'comment': comment,
                            }
                        )
        except Exception as e:
            self.log_error(f"Failed to scan hosts file: {e}")

    def _scan_proxy_settings(self, pattern: str = None) -> Generator[ScanResult, None, None]:
        """Scan proxy settings from registry"""
        try:
            import winreg
            key_path = r"Software\Microsoft\Windows\CurrentVersion\Internet Settings"

            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path) as key:
                try:
                    proxy_enable = winreg.QueryValueEx(key, 'ProxyEnable')[0]
                    proxy_server = winreg.QueryValueEx(key, 'ProxyServer')[0]

                    if proxy_enable and proxy_server:
                        if ':' in proxy_server:
                            server, port = proxy_server.rsplit(':', 1)
                            port = int(port)
                        else:
                            server = proxy_server
                            port = 80

                        yield ScanResult(
                            module=self.name,
                            item_type=NetworkItemType.PROXY_SETTING.value,
                            name=f"Proxy: {server}:{port}",
                            path="HKCU\\Internet Settings\\ProxyServer",
                            size=0,
                            details={
                                'enabled': bool(proxy_enable),
                                'server': server,
                                'port': port,
                            }
                        )
                except WindowsError:
                    pass
        except Exception as e:
            self.log_error(f"Failed to scan proxy settings: {e}")

    def _scan_network_profiles(self, pattern: str = None) -> Generator[ScanResult, None, None]:
        """Scan network profiles"""
        try:
            result = subprocess.run(
                ['netsh', 'wlan', 'show', 'profiles'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if 'All User Profile' in line or 'User Profile' in line:
                        profile_name = line.split(':')[-1].strip()
                        if not profile_name:
                            continue

                        if pattern and pattern.lower() not in profile_name.lower():
                            continue

                        yield ScanResult(
                            module=self.name,
                            item_type=NetworkItemType.NETWORK_PROFILE.value,
                            name=profile_name,
                            path=f"WLAN:{profile_name}",
                            size=0,
                            details={
                                'profile_type': 'wireless',
                            }
                        )
        except Exception as e:
            self.log_error(f"Failed to scan network profiles: {e}")

    def get_dns_cache(self) -> List[DnsCacheEntry]:
        """Get cached DNS entries"""
        return self._dns_cache

    def get_host_entries(self) -> List[HostEntry]:
        """Get host file entries"""
        return self._host_entries
