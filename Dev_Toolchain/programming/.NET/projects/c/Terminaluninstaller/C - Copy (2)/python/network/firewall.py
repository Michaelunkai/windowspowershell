"""
Firewall manager for Ultimate Uninstaller
Manages Windows Firewall rules
"""

import os
import subprocess
from typing import List, Dict, Generator, Optional
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
import json
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import CleanResult, ScanResult
from core.config import Config
from core.logger import Logger


class FirewallAction(Enum):
    ALLOW = "allow"
    BLOCK = "block"


class FirewallDirection(Enum):
    INBOUND = "in"
    OUTBOUND = "out"


class FirewallProtocol(Enum):
    TCP = "tcp"
    UDP = "udp"
    ANY = "any"


@dataclass
class FirewallRule:
    """Firewall rule information"""
    name: str
    direction: str
    action: str
    enabled: bool
    program: Optional[str] = None
    local_port: Optional[str] = None
    remote_port: Optional[str] = None
    protocol: Optional[str] = None
    profile: Optional[str] = None
    description: Optional[str] = None


@dataclass
class FirewallBackupEntry:
    """Firewall backup entry"""
    rule: FirewallRule
    timestamp: str


class FirewallManager:
    """Manages Windows Firewall rules"""

    PROTECTED_RULES = [
        'Core Networking', 'Remote Desktop', 'Windows Defender',
        'Windows Update', 'File and Printer Sharing',
        'Network Discovery', 'Remote Assistance',
    ]

    def __init__(self, config: Config, logger: Logger = None):
        self.config = config
        self.logger = logger
        self.name = "FirewallManager"
        self._rules: List[FirewallRule] = []
        self._backup: List[FirewallBackupEntry] = []

    def log_info(self, message: str):
        if self.logger:
            self.logger.info(f"[{self.name}] {message}")

    def log_error(self, message: str):
        if self.logger:
            self.logger.error(f"[{self.name}] {message}")

    def scan_rules(self, pattern: str = None) -> Generator[ScanResult, None, None]:
        """Scan firewall rules"""
        self.log_info("Scanning firewall rules")
        self._rules = []

        try:
            result = subprocess.run(
                ['netsh', 'advfirewall', 'firewall', 'show', 'rule',
                 'name=all', 'verbose'],
                capture_output=True, text=True, timeout=60
            )

            if result.returncode == 0:
                rules = self._parse_firewall_output(result.stdout)

                for rule in rules:
                    if pattern and pattern.lower() not in rule.name.lower():
                        continue

                    is_protected = any(
                        p.lower() in rule.name.lower()
                        for p in self.PROTECTED_RULES
                    )

                    self._rules.append(rule)

                    yield ScanResult(
                        module=self.name,
                        item_type="firewall_rule",
                        name=rule.name,
                        path=f"Firewall:{rule.direction}:{rule.name}",
                        size=0,
                        details={
                            'direction': rule.direction,
                            'action': rule.action,
                            'enabled': rule.enabled,
                            'program': rule.program,
                            'protocol': rule.protocol,
                            'local_port': rule.local_port,
                            'protected': is_protected,
                        }
                    )
        except Exception as e:
            self.log_error(f"Failed to scan firewall rules: {e}")

    def _parse_firewall_output(self, output: str) -> List[FirewallRule]:
        """Parse netsh firewall output"""
        rules = []
        current_rule = {}

        for line in output.split('\n'):
            line = line.strip()
            if not line:
                if current_rule.get('name'):
                    rules.append(FirewallRule(
                        name=current_rule.get('name', ''),
                        direction=current_rule.get('direction', 'in'),
                        action=current_rule.get('action', 'allow'),
                        enabled=current_rule.get('enabled', True),
                        program=current_rule.get('program'),
                        local_port=current_rule.get('local_port'),
                        remote_port=current_rule.get('remote_port'),
                        protocol=current_rule.get('protocol'),
                        profile=current_rule.get('profile'),
                        description=current_rule.get('description'),
                    ))
                current_rule = {}
                continue

            if ':' in line:
                key, value = line.split(':', 1)
                key = key.strip().lower()
                value = value.strip()

                if 'rule name' in key:
                    current_rule['name'] = value
                elif 'direction' in key:
                    current_rule['direction'] = value.lower()
                elif 'action' in key:
                    current_rule['action'] = value.lower()
                elif 'enabled' in key:
                    current_rule['enabled'] = value.lower() == 'yes'
                elif 'program' in key:
                    current_rule['program'] = value if value != 'Any' else None
                elif 'localport' in key:
                    current_rule['local_port'] = value if value != 'Any' else None
                elif 'remoteport' in key:
                    current_rule['remote_port'] = value if value != 'Any' else None
                elif 'protocol' in key:
                    current_rule['protocol'] = value.lower()
                elif 'profiles' in key:
                    current_rule['profile'] = value
                elif 'description' in key:
                    current_rule['description'] = value

        if current_rule.get('name'):
            rules.append(FirewallRule(
                name=current_rule.get('name', ''),
                direction=current_rule.get('direction', 'in'),
                action=current_rule.get('action', 'allow'),
                enabled=current_rule.get('enabled', True),
                program=current_rule.get('program'),
                local_port=current_rule.get('local_port'),
                remote_port=current_rule.get('remote_port'),
                protocol=current_rule.get('protocol'),
                profile=current_rule.get('profile'),
                description=current_rule.get('description'),
            ))

        return rules

    def delete_rule(self, rule_name: str) -> Generator[CleanResult, None, None]:
        """Delete a firewall rule"""
        is_protected = any(
            p.lower() in rule_name.lower()
            for p in self.PROTECTED_RULES
        )

        if is_protected:
            yield CleanResult(
                module=self.name,
                action="skip",
                target=rule_name,
                success=False,
                message="Protected rule"
            )
            return

        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=f"Firewall rule: {rule_name}",
                success=True,
                message="Would delete rule"
            )
            return

        try:
            result = subprocess.run(
                ['netsh', 'advfirewall', 'firewall', 'delete', 'rule',
                 f'name={rule_name}'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                yield CleanResult(
                    module=self.name,
                    action="delete",
                    target=f"Firewall rule: {rule_name}",
                    success=True,
                    message="Rule deleted"
                )
            else:
                yield CleanResult(
                    module=self.name,
                    action="delete",
                    target=f"Firewall rule: {rule_name}",
                    success=False,
                    message=result.stderr.strip()
                )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="delete",
                target=f"Firewall rule: {rule_name}",
                success=False,
                message=str(e)
            )

    def disable_rule(self, rule_name: str) -> Generator[CleanResult, None, None]:
        """Disable a firewall rule"""
        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="disable (dry run)",
                target=f"Firewall rule: {rule_name}",
                success=True,
                message="Would disable rule"
            )
            return

        try:
            result = subprocess.run(
                ['netsh', 'advfirewall', 'firewall', 'set', 'rule',
                 f'name={rule_name}', 'new', 'enable=no'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                yield CleanResult(
                    module=self.name,
                    action="disable",
                    target=f"Firewall rule: {rule_name}",
                    success=True,
                    message="Rule disabled"
                )
            else:
                yield CleanResult(
                    module=self.name,
                    action="disable",
                    target=f"Firewall rule: {rule_name}",
                    success=False,
                    message=result.stderr.strip()
                )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="disable",
                target=f"Firewall rule: {rule_name}",
                success=False,
                message=str(e)
            )

    def find_rules_by_program(self, program_path: str) -> List[FirewallRule]:
        """Find rules by program path"""
        return [
            r for r in self._rules
            if r.program and program_path.lower() in r.program.lower()
        ]

    def clean_orphaned_rules(self) -> Generator[CleanResult, None, None]:
        """Clean rules for non-existent programs"""
        for rule in self._rules:
            if rule.program and not os.path.exists(rule.program):
                yield from self.delete_rule(rule.name)

    def export_rules(self, path: str):
        """Export firewall rules to file"""
        try:
            result = subprocess.run(
                ['netsh', 'advfirewall', 'export', path],
                capture_output=True, text=True, timeout=60
            )
            return result.returncode == 0
        except Exception:
            return False

    def import_rules(self, path: str):
        """Import firewall rules from file"""
        try:
            result = subprocess.run(
                ['netsh', 'advfirewall', 'import', path],
                capture_output=True, text=True, timeout=60
            )
            return result.returncode == 0
        except Exception:
            return False

    def get_rules(self) -> List[FirewallRule]:
        """Get scanned rules"""
        return self._rules
