# Samsung TV UE50CU7100UXSQ PowerShell Control System

## Device Information

| Field           | Value                          |
|-----------------|-------------------------------|
| Model           | UE50CU7100UXSQ                |
| Serial Number   | 0KYH3HEW400178K               |
| Firmware        | T-KSU2ECDEUC-0080-2032.8      |
| UniqueID        | UN5IYNGNBQN4T                 |
| Default IP      | 192.168.1.100                 |
| REST API Port   | 8001                          |
| WebSocket Port  | 8002 (ws) / 8002 (wss)        |

## Architecture Overview

The control system uses two protocols:

- **REST API** on port 8001 for querying TV info, volume, and installed apps
- **WebSocket** on port 8002 for sending remote key commands

The TV must be on the same local network segment. The config file `tv-config.json` stores the current IP and authentication token. If the TV has a DHCP lease change, `tv-startup-check.ps1` scans the subnet automatically.

## File Inventory

| File                    | Purpose                                         |
|-------------------------|-------------------------------------------------|
| tv-config.json          | IP, port, UniqueID, Model, Token config         |
| tv-websocket.ps1        | Core remote key functions (basic ws://)         |
| tv-gaming-hook.ps1      | Auto HDMI switch + volume at gaming tier 200+   |
| tv-startup-check.ps1    | Startup IP validation and DHCP subnet scan      |
| discover-tv-apps.ps1    | Query and save installed app list via REST       |
| tv-startup-log.txt      | Log output from tv-startup-check.ps1            |

## Configuration File (tv-config.json)

```json
{
  "IP":       "192.168.1.100",
  "UniqueID": "UN5IYNGNBQN4T",
  "Model":    "UE50CU7100UXSQ",
  "Port":     8001,
  "WSPort":   8002
}
```

To update the IP manually:

```powershell
$cfg = Get-Content "C:\Users\micha\Documents\WindowsPowerShell\tv-config.json" -Raw | ConvertFrom-Json
$cfg.IP = "192.168.1.105"
$cfg | ConvertTo-Json -Depth 20 | Set-Content "C:\Users\micha\Documents\WindowsPowerShell\tv-config.json" -Encoding UTF8
```

## PowerShell Functions Reference

### tv-websocket.ps1

#### Get-TVConfig

Reads tv-config.json from the same directory as the script.

**Parameters:** None

**Example:**
```powershell
. .\tv-websocket.ps1
$config = Get-TVConfig
$config.IP
```

---

#### Get-TVPowerState

Returns 'On' if TCP port 8001 is reachable, otherwise 'Off'.

**Parameters:** None

**Example:**
```powershell
Get-TVPowerState
# Returns: On
```

---

#### Get-TVInfo

Queries the REST API at `http://<IP>:8001/api/v2` and returns model name, firmware version, and device ID.

**Parameters:** None

**Returns:** PSCustomObject with ModelName, FirmwareVersion, DeviceID

**Example:**
```powershell
Get-TVInfo
# ModelName       : UE50CU7100UXSQ
# FirmwareVersion : T-KSU2ECDEUC-0080-2032.8
# DeviceID        : UN5IYNGNBQN4T
```

---

#### Send-TVKey

Sends a single remote key via WebSocket on port 8002 using `ws://` (plain, not TLS).

**Parameters:**

| Parameter | Type   | Required | Description                         |
|-----------|--------|----------|-------------------------------------|
| KeyCode   | string | Yes      | Samsung remote key code, e.g. KEY_MUTE |

**Example:**
```powershell
Send-TVKey -KeyCode 'KEY_MUTE'
Send-TVKey -KeyCode 'KEY_VOLUP'
Send-TVKey -KeyCode 'KEY_POWER'
```

**Common Key Codes:**

| Key Code      | Action            |
|---------------|-------------------|
| KEY_POWER     | Power toggle      |
| KEY_MUTE      | Mute toggle       |
| KEY_VOLUP     | Volume up         |
| KEY_VOLDOWN   | Volume down       |
| KEY_CHUP      | Channel up        |
| KEY_CHDOWN    | Channel down      |
| KEY_HDMI1     | Switch to HDMI 1  |
| KEY_HDMI2     | Switch to HDMI 2  |
| KEY_HDMI3     | Switch to HDMI 3  |
| KEY_HDMI4     | Switch to HDMI 4  |
| KEY_TV        | Switch to TV      |
| KEY_ENTER     | Enter / OK        |
| KEY_UP        | D-pad up          |
| KEY_DOWN      | D-pad down        |
| KEY_LEFT      | D-pad left        |
| KEY_RIGHT     | D-pad right       |
| KEY_SLEEP     | Open sleep timer  |
| KEY_0 to KEY_9| Digit keys        |

---

#### Set-TVChannel

Sends individual digit key codes for each digit of the channel number with 300ms delay between digits.

**Parameters:**

| Parameter | Type | Required | Description              |
|-----------|------|----------|--------------------------|
| Number    | int  | Yes      | Channel number to tune to |

**Example:**
```powershell
Set-TVChannel -Number 12
Set-TVChannel -Number 305
```

---

#### Channel-Up

Sends KEY_CHUP to increment the channel.

**Parameters:** None

**Example:**
```powershell
Channel-Up
```

---

#### Channel-Down

Sends KEY_CHDOWN to decrement the channel.

**Parameters:** None

**Example:**
```powershell
Channel-Down
```

---

#### Set-TVSleepTimer

Opens the sleep timer menu and navigates to the desired duration using KEY_DOWN presses.

**Parameters:**

| Parameter | Type | Required | ValidateSet       | Description           |
|-----------|------|----------|-------------------|-----------------------|
| Minutes   | int  | Yes      | 30, 60, 90, 120   | Sleep timer duration  |

**Example:**
```powershell
Set-TVSleepTimer -Minutes 60
```

---

### tv-gaming-hook.ps1

#### Get-TVConfig (gaming hook version)

Same purpose as tv-websocket.ps1 version but uses `$PSScriptRoot` resolution. Falls back to a default config object if tv-config.json is missing.

---

#### Send-TVKeyCommand

Low-level function that sends a single key via WebSocket using `wss://` (TLS). Includes TLS certificate validation bypass for self-signed Samsung certs. Supports auth token appended as query parameter.

**Parameters:**

| Parameter   | Type   | Required | Description                                |
|-------------|--------|----------|--------------------------------------------|
| IP          | string | Yes      | TV IP address                              |
| Port        | int    | Yes      | WebSocket port (typically 8002)            |
| AppName     | string | Yes      | App identifier sent as Base64 in URL       |
| Token       | string | No       | Auth token from previous pairing session   |
| KeyCode     | string | Yes      | Samsung remote key code                    |

**Example:**
```powershell
Send-TVKeyCommand -IP "192.168.1.100" -Port 8002 -AppName "SamsungTVControl" -Token "" -KeyCode "KEY_HDMI1"
```

---

#### Send-TVAppCommand

Sends an arbitrary JSON payload over WebSocket. Used for app-launch and advanced commands.

**Parameters:**

| Parameter   | Type   | Required | Description                      |
|-------------|--------|----------|----------------------------------|
| IP          | string | Yes      | TV IP address                    |
| Port        | int    | Yes      | WebSocket port                   |
| AppName     | string | Yes      | App identifier (Base64-encoded)  |
| Token       | string | No       | Auth token                       |
| JsonPayload | string | Yes      | Full JSON string to send         |

**Example:**
```powershell
$payload = '{"method":"ms.channel.emit","params":{"event":"ed.apps.launch","to":"host","data":{"appId":"11101200001"}}}'
Send-TVAppCommand -IP "192.168.1.100" -Port 8002 -AppName "SamsungTVControl" -Token "" -JsonPayload $payload
```

---

#### Set-TVInput

Switches the active input source using a key code map.

**Parameters:**

| Parameter | Type   | Required | Default | Valid Values                       |
|-----------|--------|----------|---------|------------------------------------|
| InputName | string | No       | HDMI1   | HDMI1, HDMI2, HDMI3, HDMI4, TV    |

**Example:**
```powershell
Set-TVInput -InputName "HDMI1"
Set-TVInput -InputName "TV"
```

---

#### Set-TVVolume

Sets the TV volume. Tries REST API first (port 8001 POST). Falls back to WebSocket key sequence: 50x KEY_VOLDOWN then N x KEY_VOLUP.

**Parameters:**

| Parameter | Type | Required | Default | Description              |
|-----------|------|----------|---------|--------------------------|
| Level     | int  | No       | 30      | Target volume level 0-100 |

**Example:**
```powershell
Set-TVVolume -Level 30
Set-TVVolume -Level 0   # mute via volume
```

---

### tv-startup-check.ps1

Standalone script (not a module). Runs at startup to verify the TV is online. If the TV does not respond at the configured IP, it scans all local IPv4 subnets on port WSPort (8002) and auto-updates tv-config.json with the new IP.

**Invocation:**
```powershell
powershell -NoProfile -File "C:\Users\micha\Documents\WindowsPowerShell\tv-startup-check.ps1"
```

Logs all activity to `tv-startup-log.txt`.

#### Write-Log (internal)

Appends timestamped lines to tv-startup-log.txt and writes to host.

#### Test-TVOnline (internal)

TCP connect test with configurable timeout. Returns `$true` if the port is reachable within TimeoutMs.

**Parameters:**

| Parameter | Type   | Default | Description                  |
|-----------|--------|---------|------------------------------|
| Address   | string | -       | IP or hostname to test       |
| Port      | int    | -       | TCP port to connect to       |
| TimeoutMs | int    | 2000    | Connection timeout in ms     |

---

### discover-tv-apps.ps1

Standalone script. Queries `http://<tvIP>:8001/api/v2/applications` and saves the full response to `tv-apps-discovered.json`. On failure, writes a placeholder JSON with error details.

**Invocation:**
```powershell
powershell -NoProfile -File "C:\Users\micha\Documents\WindowsPowerShell\discover-tv-apps.ps1"
```

---

## AHK Keybindings

If AutoHotkey v2 is installed, you can bind common TV commands to hotkeys. The system uses AHK v2 (`v2\AutoHotkey64.exe`).

| Hotkey          | Action                             | PS Command              |
|-----------------|------------------------------------|-------------------------|
| Win+F1          | Mute toggle                        | Send-TVKey KEY_MUTE     |
| Win+F2          | Volume down                        | Send-TVKey KEY_VOLDOWN  |
| Win+F3          | Volume up                          | Send-TVKey KEY_VOLUP    |
| Win+F4          | Power toggle                       | Send-TVKey KEY_POWER    |
| Win+F5          | Switch to HDMI1 (gaming)           | Set-TVInput HDMI1       |
| Win+F6          | Switch to TV (broadcast)           | Set-TVInput TV          |
| Win+F7          | Channel up                         | Channel-Up              |
| Win+F8          | Channel down                       | Channel-Down            |
| Win+F9          | Sleep timer 60 min                 | Set-TVSleepTimer 60     |
| Win+NumPad0-9   | Direct channel digits              | Set-TVChannel N         |

Sample AHK v2 script stub (`tv-hotkeys.ahk`):

```ahk
#Requires AutoHotkey v2.0
RunPS(cmd) {
    Run('powershell -NoProfile -Command "' . cmd . '"', , 'Hide')
}
#F1:: RunPS('. C:\Users\micha\Documents\WindowsPowerShell\tv-websocket.ps1; Send-TVKey KEY_MUTE')
#F3:: RunPS('. C:\Users\micha\Documents\WindowsPowerShell\tv-websocket.ps1; Send-TVKey KEY_VOLUP')
#F2:: RunPS('. C:\Users\micha\Documents\WindowsPowerShell\tv-websocket.ps1; Send-TVKey KEY_VOLDOWN')
#F5:: RunPS('. C:\Users\micha\Documents\WindowsPowerShell\tv-gaming-hook.ps1; Set-TVInput -InputName HDMI1')
```

---

## Task Scheduler Setup

### Register tv-startup-check at Login

Run once as Administrator:

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument '-NoProfile -WindowStyle Hidden -File "C:\Users\micha\Documents\WindowsPowerShell\tv-startup-check.ps1"'
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName "TVStartupCheck" `
    -Action $action -Trigger $trigger -Settings $settings `
    -RunLevel Highest -Force
```

### Verify Task Is Registered

```powershell
Get-ScheduledTask -TaskName "TVStartupCheck"
```

### Run Task Manually

```powershell
Start-ScheduledTask -TaskName "TVStartupCheck"
```

### Remove Task

```powershell
Unregister-ScheduledTask -TaskName "TVStartupCheck" -Confirm:$false
```

---

## Gaming Hook Integration

`tv-gaming-hook.ps1` is called by `coolmax-oc.ps1` when the GPU OC tier reaches 200 or higher. It automatically:

1. Checks if the TV is reachable on port 8001
2. Switches input to HDMI1
3. Sets volume to 30

**Manual invocation for testing:**
```powershell
powershell -NoProfile -File "C:\Users\micha\Documents\WindowsPowerShell\tv-gaming-hook.ps1" -Tier 200
```

**Tier below 200 (no action):**
```powershell
powershell -NoProfile -File "C:\Users\micha\Documents\WindowsPowerShell\tv-gaming-hook.ps1" -Tier 150
# Output: Tier 150 is below 200 - no TV action taken
```

---

## Troubleshooting

### Token Expired

Samsung TVs issue a session token on first WebSocket pairing. The TV may display a pairing prompt on screen. If the token expires or is rejected:

1. Open tv-config.json and clear the Token field: `"Token": ""`
2. Run a command such as `Send-TVKey -KeyCode KEY_MUTE` -- the TV will show a pairing dialog
3. Accept the pairing on the TV remote or on-screen prompt
4. The new token will be returned in the WebSocket handshake response headers as `token=<value>`
5. Update tv-config.json: `"Token": "<new_token>"`

In `tv-gaming-hook.ps1`, the token is appended as a URL query parameter:
```
wss://192.168.1.100:8002/api/v2/channels/samsung.remote.control?name=<base64>&token=<token>
```

### IP Changed (DHCP Lease)

If the TV obtains a new IP from DHCP:

**Automatic fix:** `tv-startup-check.ps1` scans subnets at login and auto-updates tv-config.json.

**Manual fix:**
```powershell
# Find the TV by scanning port 8001 on your subnet
1..254 | ForEach-Object {
    $ip = "192.168.1.$_"
    if (Test-NetConnection -ComputerName $ip -Port 8001 -InformationLevel Quiet -WarningAction SilentlyContinue) {
        Write-Host "Found: $ip"
    }
}
```

Then update tv-config.json with the new IP.

To prevent repeated DHCP changes, assign a DHCP reservation in your router using the TV's MAC address.

### TLS Certificate Errors (wss://)

The gaming hook uses `wss://` (TLS WebSocket). Samsung TVs use self-signed certificates. The script bypasses validation with:

```powershell
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
```

If you see TLS handshake failures:
- Ensure you are running PowerShell 5.1 (not Core) -- the .NET 4.x stack handles TLS differently
- If using .NET 4.0 target, TLS 1.2 requires the numeric cast: `[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]3072`
- Add the cast before the WebSocket connect call

### TV Not Responding to WebSocket Commands

1. Confirm TV is powered on and network-connected
2. Run `Get-TVPowerState` to verify port 8001 is reachable
3. Check that the TV is in a state that allows remote commands (not in BIOS-style settings menus)
4. Try `Send-TVKey -KeyCode KEY_MUTE` -- if no response appears on TV, the pairing token may be stale
5. Some Samsung firmwares require the TV to be in "Smart Hub" mode for WebSocket control

### REST API Volume Set Fails

`Set-TVVolume` falls back to key sequences automatically. If both fail:
- Verify port 8001 is accessible: `Test-NetConnection 192.168.1.100 -Port 8001`
- Some firmware versions restrict the volume REST endpoint. Use the WebSocket key fallback path only by setting Level manually.

### App Discovery Returns Empty

If `discover-tv-apps.ps1` shows an error or empty app list:
- Check the TV's "Smart Hub" is initialized
- Some regional firmware versions do not expose the `/api/v2/applications` endpoint
- The placeholder error JSON is written to `tv-apps-discovered.json` for inspection

---

## Quick Reference

```powershell
# Dot-source the main module
. C:\Users\micha\Documents\WindowsPowerShell\tv-websocket.ps1

# Check power state
Get-TVPowerState

# Get device info
Get-TVInfo

# Mute
Send-TVKey -KeyCode KEY_MUTE

# Volume up / down
Send-TVKey -KeyCode KEY_VOLUP
Send-TVKey -KeyCode KEY_VOLDOWN

# Switch input
. C:\Users\micha\Documents\WindowsPowerShell\tv-gaming-hook.ps1
Set-TVInput -InputName HDMI1

# Set volume to 25
Set-TVVolume -Level 25

# Set channel 12
Set-TVChannel -Number 12

# Sleep timer 30 minutes
Set-TVSleepTimer -Minutes 30

# Run startup IP check manually
powershell -NoProfile -File C:\Users\micha\Documents\WindowsPowerShell\tv-startup-check.ps1
```
