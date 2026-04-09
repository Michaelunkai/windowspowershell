"""
Caching system for Ultimate Uninstaller
Provides memory and disk caching with TTL and LRU eviction
"""

import os
import json
import time
import zlib
import pickle
import hashlib
import threading
from pathlib import Path
from typing import Any, Optional, Dict, Callable, Tuple
from dataclasses import dataclass, field
from enum import Enum, auto
from collections import OrderedDict
from functools import wraps


class CachePolicy(Enum):
    """Cache eviction policies"""
    LRU = auto()
    LFU = auto()
    FIFO = auto()
    TTL = auto()


@dataclass
class CacheEntry:
    """Single cache entry"""
    key: str
    value: Any
    created: float
    accessed: float
    ttl: Optional[float]
    size: int
    hits: int = 0
    compressed: bool = False

    def is_expired(self) -> bool:
        """Check if entry has expired"""
        if self.ttl is None:
            return False
        return time.time() - self.created > self.ttl

    def touch(self):
        """Update access time and hit count"""
        self.accessed = time.time()
        self.hits += 1


class MemoryCache:
    """In-memory cache with LRU eviction"""

    def __init__(self, max_size_mb: int = 100, default_ttl: float = 3600):
        self.max_size = max_size_mb * 1024 * 1024
        self.default_ttl = default_ttl
        self._cache: OrderedDict[str, CacheEntry] = OrderedDict()
        self._size = 0
        self._lock = threading.RLock()
        self._stats = {
            'hits': 0,
            'misses': 0,
            'evictions': 0,
            'expirations': 0,
        }

    def get(self, key: str, default: Any = None) -> Any:
        """Get value from cache"""
        with self._lock:
            entry = self._cache.get(key)

            if entry is None:
                self._stats['misses'] += 1
                return default

            if entry.is_expired():
                self._remove(key)
                self._stats['expirations'] += 1
                self._stats['misses'] += 1
                return default

            entry.touch()
            self._cache.move_to_end(key)
            self._stats['hits'] += 1

            return entry.value

    def set(self, key: str, value: Any, ttl: float = None) -> bool:
        """Set value in cache"""
        with self._lock:
            try:
                size = self._estimate_size(value)

                if key in self._cache:
                    self._remove(key)

                self._evict_if_needed(size)

                entry = CacheEntry(
                    key=key,
                    value=value,
                    created=time.time(),
                    accessed=time.time(),
                    ttl=ttl or self.default_ttl,
                    size=size
                )

                self._cache[key] = entry
                self._size += size

                return True
            except:
                return False

    def delete(self, key: str) -> bool:
        """Delete key from cache"""
        with self._lock:
            if key in self._cache:
                self._remove(key)
                return True
            return False

    def clear(self):
        """Clear all cache entries"""
        with self._lock:
            self._cache.clear()
            self._size = 0

    def exists(self, key: str) -> bool:
        """Check if key exists and is not expired"""
        with self._lock:
            entry = self._cache.get(key)
            if entry is None:
                return False
            if entry.is_expired():
                self._remove(key)
                return False
            return True

    def _remove(self, key: str):
        """Remove entry from cache"""
        entry = self._cache.pop(key, None)
        if entry:
            self._size -= entry.size

    def _evict_if_needed(self, needed_size: int):
        """Evict entries if needed to make room"""
        while self._size + needed_size > self.max_size and self._cache:
            oldest_key = next(iter(self._cache))
            self._remove(oldest_key)
            self._stats['evictions'] += 1

    def _estimate_size(self, value: Any) -> int:
        """Estimate memory size of value"""
        try:
            return len(pickle.dumps(value))
        except:
            return 1024

    def get_stats(self) -> Dict:
        """Get cache statistics"""
        with self._lock:
            total_requests = self._stats['hits'] + self._stats['misses']
            hit_rate = self._stats['hits'] / total_requests if total_requests > 0 else 0

            return {
                'entries': len(self._cache),
                'size_bytes': self._size,
                'max_size_bytes': self.max_size,
                'hit_rate': hit_rate,
                **self._stats
            }

    def cleanup_expired(self) -> int:
        """Remove all expired entries"""
        removed = 0
        with self._lock:
            expired_keys = [
                key for key, entry in self._cache.items()
                if entry.is_expired()
            ]
            for key in expired_keys:
                self._remove(key)
                removed += 1
                self._stats['expirations'] += 1
        return removed


class DiskCache:
    """Disk-based cache with compression"""

    def __init__(self, cache_dir: str, max_size_mb: int = 500,
                 compression: bool = True, default_ttl: float = 86400):
        self.cache_dir = Path(cache_dir)
        self.max_size = max_size_mb * 1024 * 1024
        self.compression = compression
        self.default_ttl = default_ttl
        self._index_file = self.cache_dir / "cache_index.json"
        self._index: Dict[str, dict] = {}
        self._lock = threading.RLock()
        self._size = 0

        self._init_cache()

    def _init_cache(self):
        """Initialize cache directory and index"""
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self._load_index()
        self._calculate_size()

    def _load_index(self):
        """Load cache index from disk"""
        try:
            if self._index_file.exists():
                with open(self._index_file, 'r') as f:
                    self._index = json.load(f)
        except:
            self._index = {}

    def _save_index(self):
        """Save cache index to disk"""
        try:
            with open(self._index_file, 'w') as f:
                json.dump(self._index, f)
        except:
            pass

    def _calculate_size(self):
        """Calculate total cache size"""
        self._size = 0
        for info in self._index.values():
            self._size += info.get('size', 0)

    def _key_to_path(self, key: str) -> Path:
        """Convert cache key to file path"""
        hash_key = hashlib.sha256(key.encode()).hexdigest()
        subdir = hash_key[:2]
        return self.cache_dir / subdir / f"{hash_key}.cache"

    def get(self, key: str, default: Any = None) -> Any:
        """Get value from disk cache"""
        with self._lock:
            if key not in self._index:
                return default

            info = self._index[key]

            if info.get('ttl') and time.time() - info['created'] > info['ttl']:
                self.delete(key)
                return default

            cache_path = self._key_to_path(key)

            try:
                with open(cache_path, 'rb') as f:
                    data = f.read()

                if info.get('compressed'):
                    data = zlib.decompress(data)

                value = pickle.loads(data)

                info['accessed'] = time.time()
                info['hits'] = info.get('hits', 0) + 1
                self._save_index()

                return value
            except:
                self.delete(key)
                return default

    def set(self, key: str, value: Any, ttl: float = None) -> bool:
        """Set value in disk cache"""
        with self._lock:
            try:
                data = pickle.dumps(value)

                compressed = False
                if self.compression and len(data) > 1024:
                    compressed_data = zlib.compress(data, level=6)
                    if len(compressed_data) < len(data) * 0.9:
                        data = compressed_data
                        compressed = True

                if key in self._index:
                    self.delete(key)

                self._evict_if_needed(len(data))

                cache_path = self._key_to_path(key)
                cache_path.parent.mkdir(parents=True, exist_ok=True)

                with open(cache_path, 'wb') as f:
                    f.write(data)

                self._index[key] = {
                    'created': time.time(),
                    'accessed': time.time(),
                    'ttl': ttl or self.default_ttl,
                    'size': len(data),
                    'compressed': compressed,
                    'hits': 0,
                }

                self._size += len(data)
                self._save_index()

                return True
            except Exception:
                return False

    def delete(self, key: str) -> bool:
        """Delete key from cache"""
        with self._lock:
            if key not in self._index:
                return False

            cache_path = self._key_to_path(key)

            try:
                if cache_path.exists():
                    self._size -= self._index[key].get('size', 0)
                    cache_path.unlink()
            except:
                pass

            del self._index[key]
            self._save_index()
            return True

    def clear(self):
        """Clear all cache"""
        with self._lock:
            import shutil
            for item in self.cache_dir.iterdir():
                if item.is_dir() and len(item.name) == 2:
                    shutil.rmtree(item, ignore_errors=True)
            self._index = {}
            self._size = 0
            self._save_index()

    def _evict_if_needed(self, needed_size: int):
        """Evict entries if needed"""
        while self._size + needed_size > self.max_size and self._index:
            oldest_key = min(
                self._index.keys(),
                key=lambda k: self._index[k].get('accessed', 0)
            )
            self.delete(oldest_key)

    def get_stats(self) -> Dict:
        """Get cache statistics"""
        with self._lock:
            total_hits = sum(info.get('hits', 0) for info in self._index.values())

            return {
                'entries': len(self._index),
                'size_bytes': self._size,
                'max_size_bytes': self.max_size,
                'total_hits': total_hits,
                'compression_enabled': self.compression,
            }


class Cache:
    """Unified cache interface with memory and disk tiers"""

    def __init__(self, memory_mb: int = 100, disk_mb: int = 500,
                 disk_dir: str = None, compression: bool = True,
                 default_ttl: float = 3600):
        self.memory = MemoryCache(max_size_mb=memory_mb, default_ttl=default_ttl)
        self.disk = None

        if disk_dir:
            self.disk = DiskCache(
                cache_dir=disk_dir,
                max_size_mb=disk_mb,
                compression=compression,
                default_ttl=default_ttl * 24
            )

    def get(self, key: str, default: Any = None) -> Any:
        """Get from cache (memory first, then disk)"""
        value = self.memory.get(key)
        if value is not None:
            return value

        if self.disk:
            value = self.disk.get(key)
            if value is not None:
                self.memory.set(key, value)
                return value

        return default

    def set(self, key: str, value: Any, ttl: float = None,
            persist: bool = True) -> bool:
        """Set in cache (memory and optionally disk)"""
        success = self.memory.set(key, value, ttl)

        if persist and self.disk:
            self.disk.set(key, value, ttl)

        return success

    def delete(self, key: str) -> bool:
        """Delete from all cache tiers"""
        self.memory.delete(key)
        if self.disk:
            self.disk.delete(key)
        return True

    def clear(self):
        """Clear all caches"""
        self.memory.clear()
        if self.disk:
            self.disk.clear()

    def get_stats(self) -> Dict:
        """Get combined statistics"""
        stats = {
            'memory': self.memory.get_stats(),
        }
        if self.disk:
            stats['disk'] = self.disk.get_stats()
        return stats


class CacheManager:
    """Global cache manager singleton"""

    _instance: Optional['CacheManager'] = None
    _lock = threading.Lock()

    def __init__(self, cache: Cache = None):
        self.cache = cache or Cache()
        self._named_caches: Dict[str, Cache] = {}

    @classmethod
    def get_instance(cls) -> 'CacheManager':
        """Get singleton instance"""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = cls()
        return cls._instance

    def get_cache(self, name: str = None) -> Cache:
        """Get named cache or default"""
        if name is None:
            return self.cache
        return self._named_caches.get(name, self.cache)

    def create_cache(self, name: str, **kwargs) -> Cache:
        """Create named cache"""
        cache = Cache(**kwargs)
        self._named_caches[name] = cache
        return cache


def cached(ttl: float = 3600, key_func: Callable = None):
    """Decorator for caching function results"""
    def decorator(func: Callable) -> Callable:
        cache = MemoryCache(default_ttl=ttl)

        @wraps(func)
        def wrapper(*args, **kwargs):
            if key_func:
                cache_key = key_func(*args, **kwargs)
            else:
                cache_key = f"{func.__name__}:{hash((args, tuple(sorted(kwargs.items()))))}"

            result = cache.get(cache_key)
            if result is not None:
                return result

            result = func(*args, **kwargs)
            cache.set(cache_key, result, ttl)
            return result

        wrapper.cache_clear = cache.clear
        wrapper.cache_stats = cache.get_stats
        return wrapper

    return decorator
