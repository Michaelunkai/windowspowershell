# Bounded Context

## Vocabulary

- **WSL2**: Windows Subsystem for Linux 2 - virtualized Linux environment on Windows.
- **Distro**: Linux distribution instance running in WSL2.
- **VHDX**: Virtual hard disk format used by WSL2 for storage. Cleanup
- **Script**: Bash script that removes non-essential files to minimize WSL2 distro size.
- **Phase**: A discrete cleanup stage targeting specific file categories. Parallel
- **Execution**: Running multiple cleanup operations simultaneously using background processes. Manual
- **Install**: Package explicitly installed by user (vs auto-installed as dependency).
- **APT**: Advanced Package Tool - Debian/Ubuntu package manager. dpkg: Low-level Debian package manager.
- **MCP**: Model Context Protocol - Claude Code extension servers. Node.js: JavaScript runtime required for Claude Code CLI. npm: Node package manager for installing global packages.

## Invariants

1. MUST preserve critical system libraries (/lib/x86_64-linux-gnu/libc.so.6, libcrypto.so.3, libssl.so.3).
2. MUST NOT delete /usr/bin, /usr/sbin, /bin, /sbin, /lib, /lib64, /usr/lib, /usr/lib
64. 
3. MUST preserve dpkg database (/var/lib/dpkg/info/*) and debconf (/var/cache/debconf/*).
4. MUST keep Perl modules (/usr/share/perl5/*, /usr/share/perl/*) for package management.
5. MUST preserve English locales (en_US.UTF-8, C.UTF-8) and locale generation files.
6. MUST restore APT sources and package lists after cleanup for apt install to work.
7. MUST NOT remove currently running kernel.
8. Script MUST never hang - all operations have timeouts.
9. Script MUST continue on errors (set +e, || true patterns).
10. SHOULD provide real-time progress feedback.
11. WARNING: Script WILL remove ~/.nvm, node_modules, pip, setuptools - Claude Code restore script must run AFTER cleanup.
