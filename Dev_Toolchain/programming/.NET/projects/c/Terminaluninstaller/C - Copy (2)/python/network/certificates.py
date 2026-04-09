"""
Certificate cleaner for Ultimate Uninstaller
Manages and cleans Windows certificates
"""

import os
import subprocess
from typing import List, Dict, Generator, Optional, Set
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
import json
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import CleanResult, ScanResult
from core.config import Config
from core.logger import Logger


class CertificateStore(Enum):
    ROOT = "Root"
    CA = "CA"
    MY = "My"
    TRUST = "Trust"
    DISALLOWED = "Disallowed"
    AUTH_ROOT = "AuthRoot"
    TRUSTED_PUBLISHER = "TrustedPublisher"
    TRUSTED_PEOPLE = "TrustedPeople"


class CertificateLocation(Enum):
    CURRENT_USER = "CurrentUser"
    LOCAL_MACHINE = "LocalMachine"


@dataclass
class Certificate:
    """Certificate information"""
    thumbprint: str
    subject: str
    issuer: str
    not_before: str
    not_after: str
    store: str
    location: str
    has_private_key: bool = False
    is_expired: bool = False


@dataclass
class CertificateBackupEntry:
    """Certificate backup entry"""
    thumbprint: str
    store: str
    location: str
    export_path: str
    timestamp: str


class CertificateCleaner:
    """Manages and cleans Windows certificates"""

    PROTECTED_ISSUERS = [
        'Microsoft', 'Windows', 'DigiCert', 'VeriSign',
        'GlobalSign', 'Comodo', 'GeoTrust', 'Symantec',
        'Let\'s Encrypt', 'Entrust', 'GoDaddy',
    ]

    def __init__(self, config: Config, logger: Logger = None):
        self.config = config
        self.logger = logger
        self.name = "CertificateCleaner"
        self._certificates: List[Certificate] = []
        self._backup: List[CertificateBackupEntry] = []

    def log_info(self, message: str):
        if self.logger:
            self.logger.info(f"[{self.name}] {message}")

    def log_error(self, message: str):
        if self.logger:
            self.logger.error(f"[{self.name}] {message}")

    def scan_certificates(self, pattern: str = None,
                         store: CertificateStore = None,
                         location: CertificateLocation = None
                         ) -> Generator[ScanResult, None, None]:
        """Scan certificates"""
        self.log_info("Scanning certificates")
        self._certificates = []

        stores = [store] if store else list(CertificateStore)
        locations = [location] if location else list(CertificateLocation)

        for loc in locations:
            for st in stores:
                try:
                    yield from self._scan_store(st, loc, pattern)
                except Exception as e:
                    self.log_error(f"Failed to scan {loc.value}\\{st.value}: {e}")

    def _scan_store(self, store: CertificateStore,
                   location: CertificateLocation,
                   pattern: str = None) -> Generator[ScanResult, None, None]:
        """Scan a specific certificate store"""
        ps_script = f'''
        $certs = Get-ChildItem -Path "Cert:\\{location.value}\\{store.value}" -ErrorAction SilentlyContinue
        foreach ($cert in $certs) {{
            $expired = $cert.NotAfter -lt (Get-Date)
            Write-Output "$($cert.Thumbprint)|$($cert.Subject)|$($cert.Issuer)|$($cert.NotBefore)|$($cert.NotAfter)|$($cert.HasPrivateKey)|$expired"
        }}
        '''

        try:
            result = subprocess.run(
                ['powershell', '-NoProfile', '-Command', ps_script],
                capture_output=True, text=True, timeout=60
            )

            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if not line or '|' not in line:
                        continue

                    parts = line.split('|')
                    if len(parts) < 7:
                        continue

                    thumbprint = parts[0].strip()
                    subject = parts[1].strip()
                    issuer = parts[2].strip()
                    not_before = parts[3].strip()
                    not_after = parts[4].strip()
                    has_private_key = parts[5].strip().lower() == 'true'
                    is_expired = parts[6].strip().lower() == 'true'

                    if pattern:
                        if (pattern.lower() not in subject.lower() and
                            pattern.lower() not in issuer.lower()):
                            continue

                    cert = Certificate(
                        thumbprint=thumbprint,
                        subject=subject,
                        issuer=issuer,
                        not_before=not_before,
                        not_after=not_after,
                        store=store.value,
                        location=location.value,
                        has_private_key=has_private_key,
                        is_expired=is_expired,
                    )
                    self._certificates.append(cert)

                    is_protected = any(
                        p.lower() in issuer.lower()
                        for p in self.PROTECTED_ISSUERS
                    )

                    yield ScanResult(
                        module=self.name,
                        item_type="certificate",
                        name=self._extract_cn(subject) or thumbprint[:16],
                        path=f"Cert:\\{location.value}\\{store.value}\\{thumbprint}",
                        size=0,
                        details={
                            'thumbprint': thumbprint,
                            'subject': subject,
                            'issuer': issuer,
                            'not_before': not_before,
                            'not_after': not_after,
                            'store': store.value,
                            'location': location.value,
                            'has_private_key': has_private_key,
                            'is_expired': is_expired,
                            'protected': is_protected,
                        }
                    )
        except Exception as e:
            self.log_error(f"Failed to scan store: {e}")

    def _extract_cn(self, subject: str) -> Optional[str]:
        """Extract Common Name from subject"""
        for part in subject.split(','):
            part = part.strip()
            if part.startswith('CN='):
                return part[3:]
        return None

    def delete_certificate(self, thumbprint: str, store: str,
                          location: str) -> Generator[CleanResult, None, None]:
        """Delete a certificate"""
        cert = next(
            (c for c in self._certificates if c.thumbprint == thumbprint),
            None
        )

        if cert:
            is_protected = any(
                p.lower() in cert.issuer.lower()
                for p in self.PROTECTED_ISSUERS
            )

            if is_protected and not self.config.force:
                yield CleanResult(
                    module=self.name,
                    action="skip",
                    target=f"Certificate: {thumbprint[:16]}",
                    success=False,
                    message="Protected certificate issuer"
                )
                return

        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=f"Certificate: {thumbprint[:16]}",
                success=True,
                message="Would delete certificate"
            )
            return

        ps_script = f'''
        $cert = Get-ChildItem -Path "Cert:\\{location}\\{store}\\{thumbprint}" -ErrorAction SilentlyContinue
        if ($cert) {{
            Remove-Item -Path "Cert:\\{location}\\{store}\\{thumbprint}" -Force
            Write-Output "Deleted"
        }} else {{
            Write-Output "NotFound"
        }}
        '''

        try:
            result = subprocess.run(
                ['powershell', '-NoProfile', '-Command', ps_script],
                capture_output=True, text=True, timeout=30
            )

            if 'Deleted' in result.stdout:
                yield CleanResult(
                    module=self.name,
                    action="delete",
                    target=f"Certificate: {thumbprint[:16]}",
                    success=True,
                    message="Certificate deleted"
                )
            elif 'NotFound' in result.stdout:
                yield CleanResult(
                    module=self.name,
                    action="delete",
                    target=f"Certificate: {thumbprint[:16]}",
                    success=False,
                    message="Certificate not found"
                )
            else:
                yield CleanResult(
                    module=self.name,
                    action="delete",
                    target=f"Certificate: {thumbprint[:16]}",
                    success=False,
                    message=result.stderr.strip()
                )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="delete",
                target=f"Certificate: {thumbprint[:16]}",
                success=False,
                message=str(e)
            )

    def clean_expired_certificates(self) -> Generator[CleanResult, None, None]:
        """Clean all expired certificates"""
        for cert in self._certificates:
            if cert.is_expired:
                is_protected = any(
                    p.lower() in cert.issuer.lower()
                    for p in self.PROTECTED_ISSUERS
                )

                if not is_protected:
                    yield from self.delete_certificate(
                        cert.thumbprint, cert.store, cert.location
                    )

    def find_certificates_by_issuer(self, issuer: str) -> List[Certificate]:
        """Find certificates by issuer"""
        return [
            c for c in self._certificates
            if issuer.lower() in c.issuer.lower()
        ]

    def find_certificates_by_subject(self, subject: str) -> List[Certificate]:
        """Find certificates by subject"""
        return [
            c for c in self._certificates
            if subject.lower() in c.subject.lower()
        ]

    def export_certificate(self, thumbprint: str, store: str,
                          location: str, path: str) -> bool:
        """Export certificate to file"""
        ps_script = f'''
        $cert = Get-ChildItem -Path "Cert:\\{location}\\{store}\\{thumbprint}" -ErrorAction SilentlyContinue
        if ($cert) {{
            Export-Certificate -Cert $cert -FilePath "{path}" -Type CERT
            Write-Output "Exported"
        }}
        '''

        try:
            result = subprocess.run(
                ['powershell', '-NoProfile', '-Command', ps_script],
                capture_output=True, text=True, timeout=30
            )
            return 'Exported' in result.stdout
        except Exception:
            return False

    def get_certificates(self) -> List[Certificate]:
        """Get scanned certificates"""
        return self._certificates

    def get_expired_count(self) -> int:
        """Get count of expired certificates"""
        return sum(1 for c in self._certificates if c.is_expired)
