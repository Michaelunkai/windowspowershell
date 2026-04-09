# MEGACLEAN 4X - No Skip Version
# All operations complete without timeout limits

$ErrorActionPreference = 'SilentlyContinue'
$script:completed = 0
$script:total = 203
$start = Get-Date
$startFree = [math]::Round(((Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" -EA 0).FreeSpace/1GB),2)

function Clean {
    param([string]$name, [scriptblock]$action)
    $script:completed++
    Write-Host "[$script:completed/$script:total] " -NoNewline -ForegroundColor Cyan
    Write-Host "$name " -NoNewline -ForegroundColor Yellow

    try {
        & $action
        Write-Host "OK" -ForegroundColor Green
    } catch {
        Write-Host "SKIP" -ForegroundColor Red
    }
}

Write-Host "`n=== MEGACLEAN 4X STARTED ===" -ForegroundColor Magenta
Write-Host "C: Free before: ${startFree}GB" -ForegroundColor Gray

# PHASE 1: WINDOWS TEMP
Write-Host "`n[PHASE 1/12] WINDOWS TEMP" -ForegroundColor White
Clean "win-temp" { Remove-Item "C:\Windows\Temp\*" -Recurse -Force -EA 0 }
Clean "win-temp2" { Remove-Item "C:\Temp\*" -Recurse -Force -EA 0 }
Clean "win-systemtemp" { Remove-Item "C:\Windows\SystemTemp\*" -Recurse -Force -EA 0 }
Clean "win-cbstemp" { Remove-Item "C:\Windows\CbsTemp\*" -Recurse -Force -EA 0 }
Clean "serviceprofile-local" { Remove-Item "C:\Windows\ServiceProfiles\LocalService\AppData\Local\Temp\*" -Recurse -Force -EA 0 }
Clean "serviceprofile-network" { Remove-Item "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp\*" -Recurse -Force -EA 0 }
Clean "serviceprofile-fontcache" { Remove-Item "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache\*" -Recurse -Force -EA 0 }

# PHASE 2: WINDOWS LOGS
Write-Host "`n[PHASE 2/12] WINDOWS LOGS" -ForegroundColor White
Clean "win-logs" { Remove-Item "C:\Windows\Logs\*" -Recurse -Force -EA 0 }
Clean "win-cbs" { Remove-Item "C:\Windows\Logs\CBS\*" -Recurse -Force -EA 0 }
Clean "win-dism" { Remove-Item "C:\Windows\Logs\DISM\*" -Recurse -Force -EA 0 }
Clean "win-dpx" { Remove-Item "C:\Windows\Logs\DPX\*" -Recurse -Force -EA 0 }
Clean "win-mosetup" { Remove-Item "C:\Windows\Logs\MoSetup\*" -Recurse -Force -EA 0 }
Clean "win-measuredboot" { Remove-Item "C:\Windows\Logs\MeasuredBoot\*" -Recurse -Force -EA 0 }
Clean "win-sih" { Remove-Item "C:\Windows\Logs\SIH\*" -Recurse -Force -EA 0 }
Clean "win-windowsupdate" { Remove-Item "C:\Windows\Logs\WindowsUpdate\*" -Recurse -Force -EA 0 }
Clean "win-waasmedia" { Remove-Item "C:\Windows\Logs\waasmedic\*" -Recurse -Force -EA 0 }
Clean "win-inf" { Remove-Item "C:\Windows\inf\*.log" -Force -EA 0 }
Clean "win-debug" { Remove-Item "C:\Windows\Debug\*" -Recurse -Force -EA 0 }
Clean "win-panther" { Remove-Item "C:\Windows\Panther\*" -Recurse -Force -EA 0 }
Clean "win-pantherUn" { Remove-Item "C:\Windows\Panther\UnattendGC\*" -Recurse -Force -EA 0 }
Clean "win-minidump" { Remove-Item "C:\Windows\Minidump\*" -Recurse -Force -EA 0 }
Clean "win-memorydmp" { Remove-Item "C:\Windows\MEMORY.DMP" -Force -EA 0 }
Clean "win-livekernelreports" { Remove-Item "C:\Windows\LiveKernelReports\*" -Recurse -Force -EA 0 }
Clean "win-sys32-logfiles" { Remove-Item "C:\Windows\System32\LogFiles\*" -Recurse -Force -EA 0 }
Clean "win-sys32-wdi" { Remove-Item "C:\Windows\System32\WDI\LogFiles\*" -Recurse -Force -EA 0 }
Clean "win-sys32-sru" { Remove-Item "C:\Windows\System32\sru\*" -Recurse -Force -EA 0 }
Clean "win-sys32-spool" { Remove-Item "C:\Windows\System32\spool\PRINTERS\*" -Recurse -Force -EA 0 }
Clean "win-sys32-winevt" { Remove-Item "C:\Windows\System32\winevt\Logs\*.evtx" -Force -EA 0 }
Clean "win-perflogs" { Remove-Item "C:\PerfLogs\*" -Recurse -Force -EA 0 }

# PHASE 3: WINDOWS SYSTEM
Write-Host "`n[PHASE 3/12] WINDOWS SYSTEM" -ForegroundColor White
Clean "win-prefetch" { Remove-Item "C:\Windows\Prefetch\*" -Recurse -Force -EA 0 }
Clean "win-softwaredist" {
    net stop wuauserv 2>$null
    Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -EA 0
    Remove-Item "C:\Windows\SoftwareDistribution\DataStore\*" -Recurse -Force -EA 0
    net start wuauserv 2>$null
}
Clean "win-catroot2" { Remove-Item "C:\Windows\System32\catroot2\*" -Recurse -Force -EA 0 }
Clean "win-wer" { Remove-Item "C:\Windows\WER\*" -Recurse -Force -EA 0 }
Clean "win-installer-temp" { Remove-Item "C:\Windows\Installer\$PatchCache$\*" -Recurse -Force -EA 0 }
Clean "win-installer-msi" { Get-ChildItem "C:\Windows\Installer\*.msi" -EA 0|?{$_.Length -gt 5MB}|Remove-Item -Force -EA 0 }
Clean "win-installer-msp" { Get-ChildItem "C:\Windows\Installer\*.msp" -EA 0|?{$_.Length -gt 5MB}|Remove-Item -Force -EA 0 }
Clean "win-assembly-temp" { Remove-Item "C:\Windows\assembly\temp\*" -Recurse -Force -EA 0 }
Clean "win-winsxs-temp" { Remove-Item "C:\Windows\WinSxS\Temp\*" -Recurse -Force -EA 0 }
Clean "win-winsxs-backup" { Remove-Item "C:\Windows\WinSxS\Backup\*" -Recurse -Force -EA 0 }
Clean "win-winsxs-manifest" { Remove-Item "C:\Windows\WinSxS\ManifestCache\*" -Recurse -Force -EA 0 }
Clean "dism-cleanup" { Dism.exe /online /Cleanup-Image /StartComponentCleanup /quiet 2>$null }
Clean "dism-resetbase" { Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase /quiet 2>$null }
Clean "dism-superseded" { Dism.exe /online /Cleanup-Image /SPSuperseded /quiet 2>$null }

# PHASE 4: USER TEMP/CACHE
Write-Host "`n[PHASE 4/12] USER TEMP/CACHE" -ForegroundColor White
Clean "user-temp" { Remove-Item "C:\Users\*\AppData\Local\Temp\*" -Recurse -Force -EA 0 }
Clean "user-recent" { Remove-Item "C:\Users\*\AppData\Roaming\Microsoft\Windows\Recent\*" -Recurse -Force -EA 0 }
Clean "user-recentauto" { Remove-Item "C:\Users\*\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations\*" -Recurse -Force -EA 0 }
Clean "user-recentcustom" { Remove-Item "C:\Users\*\AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations\*" -Recurse -Force -EA 0 }
Clean "user-inetcache" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\*" -Recurse -Force -EA 0 }
Clean "user-webcache" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Windows\WebCache\*" -Recurse -Force -EA 0 }
Clean "user-caches" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Windows\Caches\*" -Recurse -Force -EA 0 }
Clean "user-tempinet" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" -Recurse -Force -EA 0 }
Clean "user-history" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Windows\History\*" -Recurse -Force -EA 0 }
Clean "user-thumbcache" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*" -Force -EA 0 }
Clean "user-iconcache" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Windows\Explorer\iconcache_*" -Force -EA 0 }
Clean "user-iconcachedb" { Remove-Item "C:\Users\*\AppData\Local\IconCache.db" -Force -EA 0 }
Clean "user-wer" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Windows\WER\*" -Recurse -Force -EA 0 }
Clean "user-crashdumps" { Remove-Item "C:\Users\*\AppData\Local\CrashDumps\*" -Recurse -Force -EA 0 }
Clean "user-d3dscache" { Remove-Item "C:\Users\*\AppData\Local\D3DSCache\*" -Recurse -Force -EA 0 }
Clean "user-fontcache" { Remove-Item "C:\Users\*\AppData\Local\FontCache\*" -Recurse -Force -EA 0 }
Clean "user-notifications" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Windows\Notifications\*" -Recurse -Force -EA 0 }
Clean "user-actioncenter" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Windows\ActionCenterCache\*" -Recurse -Force -EA 0 }
Clean "user-connecteddevices" { Remove-Item "C:\Users\*\AppData\Local\ConnectedDevicesPlatform\*" -Recurse -Force -EA 0 }
Clean "user-comms" { Remove-Item "C:\Users\*\AppData\Local\Comms\*" -Recurse -Force -EA 0 }
Clean "user-dbg" { Remove-Item "C:\Users\*\AppData\Local\DBG\*" -Recurse -Force -EA 0 }
Clean "user-tsclient" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\*" -Recurse -Force -EA 0 }
Clean "user-onedrive-logs" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\OneDrive\logs\*" -Recurse -Force -EA 0 }
Clean "user-cmdanalysis" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Windows\PowerShell\CommandAnalysis\*" -Recurse -Force -EA 0 }
Clean "user-squirrel" { Remove-Item "C:\Users\*\AppData\Local\SquirrelTemp\*" -Recurse -Force -EA 0 }
Clean "user-cache" { Remove-Item "C:\Users\*\.cache\*" -Recurse -Force -EA 0 }

# PHASE 5: BROWSERS
Write-Host "`n[PHASE 5/12] BROWSERS" -ForegroundColor White
Clean "chrome-cache" { Remove-Item "C:\Users\*\AppData\Local\Google\Chrome\User Data\*\Cache\*" -Recurse -Force -EA 0 }
Clean "chrome-codecache" { Remove-Item "C:\Users\*\AppData\Local\Google\Chrome\User Data\*\Code Cache\*" -Recurse -Force -EA 0 }
Clean "chrome-gpucache" { Remove-Item "C:\Users\*\AppData\Local\Google\Chrome\User Data\GPUCache\*" -Recurse -Force -EA 0 }
Clean "chrome-shadercache" { Remove-Item "C:\Users\*\AppData\Local\Google\Chrome\User Data\ShaderCache\*" -Recurse -Force -EA 0 }
Clean "chrome-serviceworker" { Remove-Item "C:\Users\*\AppData\Local\Google\Chrome\User Data\*\Service Worker\*" -Recurse -Force -EA 0 }
Clean "chrome-storage" { Remove-Item "C:\Users\*\AppData\Local\Google\Chrome\User Data\*\Storage\*" -Recurse -Force -EA 0 }
Clean "chrome-crashpad" { Remove-Item "C:\Users\*\AppData\Local\Google\Chrome\User Data\Crashpad\*" -Recurse -Force -EA 0 }
Clean "chrome-safetycheck" { Remove-Item "C:\Users\*\AppData\Local\Google\Chrome\User Data\SafetyTips\*" -Recurse -Force -EA 0 }
Clean "chrome-optimization" { Remove-Item "C:\Users\*\AppData\Local\Google\Chrome\User Data\OptimizationGuidePredictionModels\*" -Recurse -Force -EA 0 }
Clean "edge-cache" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Edge\User Data\*\Cache\*" -Recurse -Force -EA 0 }
Clean "edge-codecache" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Edge\User Data\*\Code Cache\*" -Recurse -Force -EA 0 }
Clean "edge-gpucache" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Edge\User Data\GPUCache\*" -Recurse -Force -EA 0 }
Clean "edge-shadercache" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Edge\User Data\ShaderCache\*" -Recurse -Force -EA 0 }
Clean "edge-serviceworker" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Edge\User Data\*\Service Worker\*" -Recurse -Force -EA 0 }
Clean "edge-storage" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Edge\User Data\*\Storage\*" -Recurse -Force -EA 0 }
Clean "edge-crashpad" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Edge\User Data\Crashpad\*" -Recurse -Force -EA 0 }
Clean "edge-provenance" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Edge\User Data\ProvenanceData\*" -Recurse -Force -EA 0 }
Clean "firefox-cache" { Remove-Item "C:\Users\*\AppData\Local\Mozilla\Firefox\Profiles\*\cache2\*" -Recurse -Force -EA 0 }
Clean "firefox-shader" { Remove-Item "C:\Users\*\AppData\Local\Mozilla\Firefox\Profiles\*\shader-cache\*" -Recurse -Force -EA 0 }
Clean "firefox-startupCache" { Remove-Item "C:\Users\*\AppData\Local\Mozilla\Firefox\Profiles\*\startupCache\*" -Recurse -Force -EA 0 }
Clean "firefox-thumbnails" { Remove-Item "C:\Users\*\AppData\Local\Mozilla\Firefox\Profiles\*\thumbnails\*" -Recurse -Force -EA 0 }
Clean "firefox-storage" { Remove-Item "C:\Users\*\AppData\Local\Mozilla\Firefox\Profiles\*\storage\*" -Recurse -Force -EA 0 }
Clean "brave-cache" { Remove-Item "C:\Users\*\AppData\Local\BraveSoftware\Brave-Browser\User Data\*\Cache\*" -Recurse -Force -EA 0 }
Clean "brave-codecache" { Remove-Item "C:\Users\*\AppData\Local\BraveSoftware\Brave-Browser\User Data\*\Code Cache\*" -Recurse -Force -EA 0 }
Clean "brave-gpucache" { Remove-Item "C:\Users\*\AppData\Local\BraveSoftware\Brave-Browser\User Data\GPUCache\*" -Recurse -Force -EA 0 }
Clean "opera-cache" { Remove-Item "C:\Users\*\AppData\Local\Opera Software\Opera Stable\Cache\*" -Recurse -Force -EA 0 }
Clean "opera-codecache" { Remove-Item "C:\Users\*\AppData\Local\Opera Software\Opera Stable\Code Cache\*" -Recurse -Force -EA 0 }

# PHASE 6: DEV PACKAGE MANAGERS
Write-Host "`n[PHASE 6/12] DEV PACKAGE MANAGERS" -ForegroundColor White
Clean "npm-cache" { Remove-Item "C:\Users\*\AppData\Local\npm-cache\*" -Recurse -Force -EA 0 }
Clean "npm-cache2" { Remove-Item "C:\Users\*\AppData\Roaming\npm-cache\*" -Recurse -Force -EA 0 }
Clean "npm-logs" { Remove-Item "C:\Users\*\.npm\_logs\*" -Recurse -Force -EA 0 }
Clean "yarn-cache" { Remove-Item "C:\Users\*\AppData\Local\Yarn\Cache\*" -Recurse -Force -EA 0 }
Clean "yarn-cache2" { Remove-Item "C:\Users\*\.yarn\cache\*" -Recurse -Force -EA 0 }
Clean "pnpm-cache" { Remove-Item "C:\Users\*\AppData\Local\pnpm\cache\*" -Recurse -Force -EA 0 }
Clean "pnpm-cache2" { Remove-Item "C:\Users\*\AppData\Local\pnpm-cache\*" -Recurse -Force -EA 0 }
Clean "pnpm-store" { Remove-Item "C:\Users\*\AppData\Local\pnpm-store\*" -Recurse -Force -EA 0 }
Clean "bun-cache" { Remove-Item "C:\Users\*\.bun\install\cache\*" -Recurse -Force -EA 0 }
Clean "pip-cache" { Remove-Item "C:\Users\*\AppData\Local\pip\cache\*" -Recurse -Force -EA 0 }
Clean "pip-httpCache" { Remove-Item "C:\Users\*\AppData\Local\pip\http\*" -Recurse -Force -EA 0 }
Clean "pip-wheels" { Remove-Item "C:\Users\*\AppData\Local\pip\wheels\*" -Recurse -Force -EA 0 }
Clean "uv-cache" { Remove-Item "C:\Users\*\AppData\Local\uv\cache\*" -Recurse -Force -EA 0 }
Clean "pipx-cache" { Remove-Item "C:\Users\*\.local\pipx\cache\*" -Recurse -Force -EA 0 }
Clean "conda-pkgs" { Remove-Item "C:\Users\*\.conda\pkgs\*" -Recurse -Force -EA 0 }
Clean "nuget-cache" { Remove-Item "C:\Users\*\.nuget\packages\*" -Recurse -Force -EA 0 }
Clean "nuget-httpcache" { Remove-Item "C:\Users\*\AppData\Local\NuGet\Cache\*" -Recurse -Force -EA 0 }
Clean "nuget-v3cache" { Remove-Item "C:\Users\*\AppData\Local\NuGet\v3-cache\*" -Recurse -Force -EA 0 }
Clean "cargo-registry" { Remove-Item "C:\Users\*\.cargo\registry\cache\*" -Recurse -Force -EA 0 }
Clean "cargo-index" { Remove-Item "C:\Users\*\.cargo\registry\index\*" -Recurse -Force -EA 0 }
Clean "cargo-git" { Remove-Item "C:\Users\*\.cargo\git\*" -Recurse -Force -EA 0 }
Clean "rustup-downloads" { Remove-Item "C:\Users\*\.rustup\downloads\*" -Recurse -Force -EA 0 }
Clean "rustup-tmp" { Remove-Item "C:\Users\*\.rustup\tmp\*" -Recurse -Force -EA 0 }
Clean "go-cache" { Remove-Item "C:\Users\*\AppData\Local\go-build\*" -Recurse -Force -EA 0 }
Clean "go-modcache" { Remove-Item "C:\Users\*\go\pkg\mod\cache\*" -Recurse -Force -EA 0 }
Clean "gradle-cache" { Remove-Item "C:\Users\*\.gradle\caches\*" -Recurse -Force -EA 0 }
Clean "gradle-wrapper" { Remove-Item "C:\Users\*\.gradle\wrapper\dists\*" -Recurse -Force -EA 0 }
Clean "maven-repo" { Remove-Item "C:\Users\*\.m2\repository\*" -Recurse -Force -EA 0 }
Clean "composer-cache" { Remove-Item "C:\Users\*\AppData\Local\Composer\cache\*" -Recurse -Force -EA 0 }
Clean "node-gyp" { Remove-Item "C:\Users\*\AppData\Local\node-gyp\*" -Recurse -Force -EA 0 }
Clean "deno-cache" { Remove-Item "C:\Users\*\AppData\Local\deno\deps\*" -Recurse -Force -EA 0 }
Clean "deno-gen" { Remove-Item "C:\Users\*\AppData\Local\deno\gen\*" -Recurse -Force -EA 0 }
Clean "vcpkg-cache" { Remove-Item "C:\Users\*\AppData\Local\vcpkg\*" -Recurse -Force -EA 0 }
Clean "gem-cache" { Remove-Item "C:\Users\*\.gem\ruby\*\cache\*" -Recurse -Force -EA 0 }
Clean "cocoapods-cache" { Remove-Item "C:\Users\*\Library\Caches\CocoaPods\*" -Recurse -Force -EA 0 }
Clean "bower-cache" { Remove-Item "C:\Users\*\.bower\cache\*" -Recurse -Force -EA 0 }

# PHASE 7: IDE/EDITORS
Write-Host "`n[PHASE 7/12] IDE/EDITORS" -ForegroundColor White
Clean "vscode-cache" { Remove-Item "C:\Users\*\AppData\Roaming\Code\Cache\*" -Recurse -Force -EA 0 }
Clean "vscode-cacheddata" { Remove-Item "C:\Users\*\AppData\Roaming\Code\CachedData\*" -Recurse -Force -EA 0 }
Clean "vscode-cachedext" { Remove-Item "C:\Users\*\AppData\Roaming\Code\CachedExtensions\*" -Recurse -Force -EA 0 }
Clean "vscode-cachedvsix" { Remove-Item "C:\Users\*\AppData\Roaming\Code\CachedExtensionVSIXs\*" -Recurse -Force -EA 0 }
Clean "vscode-logs" { Remove-Item "C:\Users\*\AppData\Roaming\Code\logs\*" -Recurse -Force -EA 0 }
Clean "vscode-workspaceStorage" { Remove-Item "C:\Users\*\AppData\Roaming\Code\User\workspaceStorage\*" -Recurse -Force -EA 0 }
Clean "vscode-history" { Remove-Item "C:\Users\*\AppData\Roaming\Code\User\History\*" -Recurse -Force -EA 0 }
Clean "vscode-cpptools" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\vscode-cpptools\ipch\*" -Recurse -Force -EA 0 }
Clean "cursor-cache" { Remove-Item "C:\Users\*\AppData\Local\Cursor\Cache\*" -Recurse -Force -EA 0 }
Clean "cursor-cache2" { Remove-Item "C:\Users\*\AppData\Roaming\Cursor\Cache\*" -Recurse -Force -EA 0 }
Clean "cursor-logs" { Remove-Item "C:\Users\*\AppData\Roaming\Cursor\logs\*" -Recurse -Force -EA 0 }
Clean "jetbrains-caches" { Remove-Item "C:\Users\*\AppData\Local\JetBrains\*\caches\*" -Recurse -Force -EA 0 }
Clean "jetbrains-index" { Remove-Item "C:\Users\*\AppData\Local\JetBrains\*\index\*" -Recurse -Force -EA 0 }
Clean "jetbrains-transient" { Remove-Item "C:\Users\*\AppData\Local\JetBrains\Transient\*" -Recurse -Force -EA 0 }
Clean "jetbrains-log" { Remove-Item "C:\Users\*\AppData\Local\JetBrains\*\log\*" -Recurse -Force -EA 0 }
Clean "vs-compmodel" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\VisualStudio\*\ComponentModelCache\*" -Recurse -Force -EA 0 }
Clean "vs-extensions" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\VisualStudio\*\Extensions\*\Temp\*" -Recurse -Force -EA 0 }
Clean "vs-mefcache" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\VisualStudio\*\Mef\*" -Recurse -Force -EA 0 }
Clean "playwright-cache" { Remove-Item "C:\Users\*\AppData\Local\ms-playwright\*" -Recurse -Force -EA 0 }
Clean "puppeteer-cache" { Remove-Item "C:\Users\*\AppData\Roaming\Code\User\globalStorage\saoudrizwan.claude-dev\puppeteer\*" -Recurse -Force -EA 0 }
Clean "sublimetext-cache" { Remove-Item "C:\Users\*\AppData\Local\Sublime Text\Cache\*" -Recurse -Force -EA 0 }
Clean "atom-cache" { Remove-Item "C:\Users\*\AppData\Local\atom\*\Cache\*" -Recurse -Force -EA 0 }

# PHASE 8: APPS
Write-Host "`n[PHASE 8/12] APPS" -ForegroundColor White
Clean "slack-cache" { Remove-Item "C:\Users\*\AppData\Local\Slack\Cache\*" -Recurse -Force -EA 0 }
Clean "slack-codecache" { Remove-Item "C:\Users\*\AppData\Local\Slack\Code Cache\*" -Recurse -Force -EA 0 }
Clean "slack-gpucache" { Remove-Item "C:\Users\*\AppData\Local\Slack\GPUCache\*" -Recurse -Force -EA 0 }
Clean "slack-logs" { Remove-Item "C:\Users\*\AppData\Local\Slack\logs\*" -Recurse -Force -EA 0 }
Clean "discord-cache" { Remove-Item "C:\Users\*\AppData\Local\Discord\Cache\*" -Recurse -Force -EA 0 }
Clean "discord-codecache" { Remove-Item "C:\Users\*\AppData\Local\Discord\Code Cache\*" -Recurse -Force -EA 0 }
Clean "discord-gpucache" { Remove-Item "C:\Users\*\AppData\Local\Discord\GPUCache\*" -Recurse -Force -EA 0 }
Clean "teams-cache" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Teams\Cache\*" -Recurse -Force -EA 0 }
Clean "teams-tmp" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Teams\tmp\*" -Recurse -Force -EA 0 }
Clean "teams-blob" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Teams\blob_storage\*" -Recurse -Force -EA 0 }
Clean "spotify-data" { Remove-Item "C:\Users\*\AppData\Local\Spotify\Data\*" -Recurse -Force -EA 0 }
Clean "spotify-storage" { Remove-Item "C:\Users\*\AppData\Local\Spotify\Storage\*" -Recurse -Force -EA 0 }
Clean "zoom-logs" { Remove-Item "C:\Users\*\AppData\Roaming\Zoom\logs\*" -Recurse -Force -EA 0 }
Clean "zoom-data" { Remove-Item "C:\Users\*\AppData\Roaming\Zoom\data\*" -Recurse -Force -EA 0 }
Clean "steam-htmlcache" { Remove-Item "C:\Users\*\AppData\Local\Steam\htmlcache\*" -Recurse -Force -EA 0 }
Clean "steam-appcache" { Remove-Item "C:\Users\*\AppData\Local\Steam\appcache\*" -Recurse -Force -EA 0 }
Clean "postman-logs" { Remove-Item "C:\Users\*\AppData\Local\Postman\logs\*" -Recurse -Force -EA 0 }
Clean "github-logs" { Remove-Item "C:\Users\*\AppData\Local\GitHubDesktop\logs\*" -Recurse -Force -EA 0 }
Clean "electron-cache" { Remove-Item "C:\Users\*\AppData\Local\electron\Cache\*" -Recurse -Force -EA 0 }
Clean "electron-gpucache" { Remove-Item "C:\Users\*\AppData\Local\electron\GPUCache\*" -Recurse -Force -EA 0 }
Clean "claude-cache" { Remove-Item "C:\Users\*\AppData\Roaming\Claude\Cache\*" -Recurse -Force -EA 0 }
Clean "todoist-updater" { Remove-Item "C:\Users\*\AppData\Local\todoist-updater\pending\*" -Recurse -Force -EA 0 }
Clean "wemod-pkgs" { Remove-Item "C:\Users\*\AppData\Local\WeMod\packages\*" -Recurse -Force -EA 0 }
Clean "nvidia-glcache" { Remove-Item "C:\Users\*\AppData\Local\NVIDIA\GLCache\*" -Recurse -Force -EA 0 }
Clean "nvidia-dxcache" { Remove-Item "C:\Users\*\AppData\Local\NVIDIA\DXCache\*" -Recurse -Force -EA 0 }
Clean "amd-dxcache" { Remove-Item "C:\Users\*\AppData\Local\AMD\DxCache\*" -Recurse -Force -EA 0 }

# PHASE 9: DOCKER/CONTAINERS
Write-Host "`n[PHASE 9/12] DOCKER/CONTAINERS" -ForegroundColor White
Clean "docker-logs" { Remove-Item "C:\Users\*\AppData\Local\Docker\log\*" -Recurse -Force -EA 0 }
Clean "docker-wsl" { Remove-Item "C:\Users\*\AppData\Local\Docker\wsl\disk\*" -Recurse -Force -EA 0 }
Clean "docker-data" { Remove-Item "C:\ProgramData\DockerDesktop\log\*" -Recurse -Force -EA 0 }
Clean "wsl-temp" { Remove-Item "C:\Users\*\AppData\Local\Temp\wsl*" -Recurse -Force -EA 0 }
Clean "containers-snapshots" { Remove-Item "C:\ProgramData\Microsoft\Windows\Containers\Snapshots\*" -Recurse -Force -EA 0 }

# PHASE 10: PROGRAMDATA
Write-Host "`n[PHASE 10/12] PROGRAMDATA" -ForegroundColor White
Clean "pd-wer" { Remove-Item "C:\ProgramData\Microsoft\Windows\WER\*" -Recurse -Force -EA 0 }
Clean "pd-search" { Remove-Item "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\*.log" -Force -EA 0 }
Clean "pd-diagnosis" { Remove-Item "C:\ProgramData\Microsoft\Diagnosis\*" -Recurse -Force -EA 0 }
Clean "pd-diagtriggers" { Remove-Item "C:\ProgramData\Microsoft\Diagnosis\DownloadedSettings\*" -Recurse -Force -EA 0 }
Clean "pd-usoshared" { Remove-Item "C:\ProgramData\USOShared\Logs\*" -Recurse -Force -EA 0 }
Clean "pd-usoprivate" { Remove-Item "C:\ProgramData\USOPrivate\UpdateStore\*" -Recurse -Force -EA 0 }
Clean "pd-nvidia-dl" { Remove-Item "C:\ProgramData\NVIDIA Corporation\Downloader\*" -Recurse -Force -EA 0 }
Clean "pd-nvidia-updatus" { Remove-Item "C:\ProgramData\NVIDIA\Updatus\*" -Recurse -Force -EA 0 }
Clean "pd-nvidia-geforce" { Remove-Item "C:\ProgramData\NVIDIA Corporation\GeForce Experience\Update\*" -Recurse -Force -EA 0 }
Clean "pd-pkgcache" { Remove-Item "C:\ProgramData\Package Cache\*" -Recurse -Force -EA 0 }
Clean "pd-choco-logs" { Remove-Item "C:\ProgramData\chocolatey\logs\*" -Recurse -Force -EA 0 }
Clean "pd-choco-temp" { Remove-Item "C:\ProgramData\chocolatey\tmp\*" -Recurse -Force -EA 0 }
Clean "pd-eset" { Remove-Item "C:\Users\*\AppData\Local\ESET\ESETOnlineScanner\*" -Recurse -Force -EA 0 }
Clean "pd-kaspersky" { Remove-Item "C:\KVRT2020_Data\*" -Recurse -Force -EA 0 }
Clean "pd-adw" { Remove-Item "C:\AdwCleaner\*" -Recurse -Force -EA 0 }

# PHASE 11: ROOT CLEANUP
Write-Host "`n[PHASE 11/12] ROOT CLEANUP" -ForegroundColor White
Clean "root-esd" { Remove-Item "C:\ESD\*" -Recurse -Force -EA 0 }
Clean "root-swsetup" { Remove-Item "C:\swsetup\*" -Recurse -Force -EA 0 }
Clean "root-amd" { Remove-Item "C:\AMD\*" -Recurse -Force -EA 0 }
Clean "root-intel" { Remove-Item "C:\Intel\*" -Recurse -Force -EA 0 }
Clean "root-nvidia" { Remove-Item "C:\NVIDIA\*" -Recurse -Force -EA 0 }
Clean "root-dell" { Remove-Item "C:\dell\*" -Recurse -Force -EA 0 }
Clean "root-hp" { Remove-Item "C:\HP\*" -Recurse -Force -EA 0 }
Clean "root-drivers" { Remove-Item "C:\drivers\*" -Recurse -Force -EA 0 }
Clean "root-temp" { Remove-Item "C:\temp\*" -Recurse -Force -EA 0 }
Clean "root-tmp" { Remove-Item "C:\tmp\*" -Recurse -Force -EA 0 }
Clean "root-inetpub" { Remove-Item "C:\inetpub\logs\*" -Recurse -Force -EA 0 }
Clean "root-logs" { Get-ChildItem "C:\*.log" -Force -EA 0|Remove-Item -Force -EA 0 }
Clean "root-txt" { Get-ChildItem "C:\*.txt" -Force -EA 0|?{$_.Name -match 'log|install|setup|debug'}|Remove-Item -Force -EA 0 }

# PHASE 12: FINAL OPS
Write-Host "`n[PHASE 12/12] FINAL OPS" -ForegroundColor White
Clean "recycle-bin" { Clear-RecycleBin -Force -EA 0 }
Clean "event-app" { wevtutil cl Application 2>$null }
Clean "event-sec" { wevtutil cl Security 2>$null }
Clean "event-sys" { wevtutil cl System 2>$null }
Clean "event-setup" { wevtutil cl Setup 2>$null }
Clean "delivery-opt" { Delete-DeliveryOptimizationCache -Force -EA 0 }
Clean "shadow-copies" { vssadmin delete shadows /all /quiet 2>$null }
Clean "dns-cache" { ipconfig /flushdns 2>$null }
Clean "arp-cache" { netsh interface ip delete arpcache 2>$null }
Clean "thumbnail-cache" { Remove-Item "C:\Users\*\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*" -Force -EA 0 }
Clean "icon-cache" {
    taskkill /IM explorer.exe /F 2>$null
    Remove-Item "C:\Users\*\AppData\Local\Microsoft\Windows\Explorer\iconcache*" -Force -EA 0
    Remove-Item "C:\Users\*\AppData\Local\IconCache.db" -Force -EA 0
    ie4uinit.exe -ClearIconCache 2>$null
    Start-Sleep 2
    Start-Process explorer 2>$null
}
Clean "font-cache" {
    net stop FontCache 2>$null
    Remove-Item "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache\*" -Force -EA 0
    net start FontCache 2>$null
}
Clean "refresh" {
    Stop-Process -Name explorer -Force -EA 0
    Start-Sleep 2
    Start-Process explorer 2>$null
}
Clean "fix-downloads-path" {
    New-Item -Path "F:\Downloads" -ItemType Directory -Force 2>$null
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}" -Value "F:\Downloads" -EA 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}" -Value "F:\Downloads" -EA 0
}
Clean "reset-quickaccess" {
    Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Force -Recurse -EA 0
    Start-Sleep -Seconds 1
    $shell = New-Object -ComObject Shell.Application
    $folders = @("F:\backup\windowsapps","F:\backup\windowsapps\installed","F:\backup\windowsapps\install","F:\backup\windowsapps\profile","C:\users\micha\Videos","C:\games","F:\study","F:\backup","C:\Users\micha","F:\games")
    foreach ($folder in $folders) {
        if ($folder -like "C:\*") {
            if (($folder -notlike "*micha*") -and ($folder -ne "C:\games")) {
                $folder = $folder -replace "^C:", "F:"
            }
        }
        $ns = $shell.Namespace($folder)
        if ($ns) { $ns.Self.InvokeVerb("pintohome") }
    }
}
Clean "restart-explorer" {
    Get-Process explorer -EA 0 | Stop-Process -Force -EA 0
    Start-Sleep 1
    Start-Process explorer -EA 0
}

# Cleanup memory
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

# Results
$elapsed = ((Get-Date) - $start).ToString('mm\:ss')
$endFree = [math]::Round(((Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" -EA 0).FreeSpace/1GB),2)
$freed = [math]::Round($endFree - $startFree, 2)

Write-Host "`n=== MEGACLEAN 4X COMPLETE ===" -ForegroundColor Magenta
Write-Host "Time: $elapsed | Freed: ${freed}GB | C: Now ${endFree}GB free" -ForegroundColor Cyan
Write-Host ""
