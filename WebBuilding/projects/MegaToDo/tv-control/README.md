# Samsung TV Control

Python-based CLI and REST API for controlling Samsung Smart TVs over the local network via WebSocket (Tizen remote control protocol) and Wake-on-LAN.

---

## Setup

### 1. Install dependencies

```bash
pip install -r requirements.txt
```

Dependencies: `websocket-client`, `requests`, `wakeonlan`, `fastapi`, `uvicorn`

### 2. Set TV IP address

**Option A - Environment variable (recommended):**

```bash
# Linux / macOS
export TV_IP=192.168.1.X

# Windows CMD
set TV_IP=192.168.1.X

# Windows PowerShell
$env:TV_IP = "192.168.1.X"
```

**Option B - Auto-scan subnet:**

If `TV_IP` is not set, the library auto-scans `192.168.1.1` through `192.168.1.254` on port `8002` and uses the first responding host. Falls back to `192.168.1.100` if nothing is found. Scanning takes several seconds.

### 3. Allow connection on TV

On first connect Samsung TVs show an on-screen prompt asking whether to allow the remote controller named **ClaudeController**. Accept it once and the pairing is remembered.

---

## CLI Usage

All commands are run via `tv.py`.

```bash
python tv.py <command> [arguments]
```

| Command | Example | Description |
|---|---|---|
| `key <name>` | `python tv.py key power` | Send a remote control key |
| `app <name>` | `python tv.py app Netflix` | Launch a built-in app |
| `text "<string>"` | `python tv.py text "hello"` | Send text input to the TV |
| `info` | `python tv.py info` | Print TV device info as JSON |
| `wake` | `python tv.py wake` | Wake TV via Wake-on-LAN (auto-detects MAC) |
| `wake --mac XX:XX:XX:XX:XX:XX` | `python tv.py wake --mac AA:BB:CC:DD:EE:FF` | Wake TV with explicit MAC address |
| `apps` | `python tv.py apps` | List all installed apps as JSON |

### Supported keys

Pass the short alias to `python tv.py key <name>`:

| Alias | Key sent | Description |
|---|---|---|
| `power` | KEY_POWER | Power toggle |
| `up` | KEY_UP | D-pad up |
| `down` | KEY_DOWN | D-pad down |
| `left` | KEY_LEFT | D-pad left |
| `right` | KEY_RIGHT | D-pad right |
| `enter` | KEY_ENTER | Select / confirm |
| `back` | KEY_RETURN | Back / return |
| `home` | KEY_HOME | Home screen |
| `menu` | KEY_MENU | Menu |
| `vol_up` | KEY_VOLUP | Volume up |
| `vol_down` | KEY_VOLDOWN | Volume down |
| `mute` | KEY_MUTE | Mute toggle |
| `ch_up` | KEY_CHUP | Channel up |
| `ch_down` | KEY_CHDOWN | Channel down |
| `play` | KEY_PLAY | Play |
| `pause` | KEY_PAUSE | Pause |
| `stop` | KEY_STOP | Stop |
| `ff` | KEY_FF | Fast forward |
| `rew` | KEY_REWIND | Rewind |
| `hdmi1` | KEY_HDMI1 | Switch to HDMI 1 |
| `hdmi2` | KEY_HDMI2 | Switch to HDMI 2 |
| `source` | KEY_SOURCE | Source picker |
| `smart` | KEY_SMARTHUB | Smart Hub |
| `info` | KEY_INFO | Info overlay |
| `red` | KEY_RED | Red colour button |
| `green` | KEY_GREEN | Green colour button |
| `yellow` | KEY_YELLOW | Yellow colour button |
| `blue` | KEY_BLUE | Blue colour button |

Any Samsung KEY_* string not listed above can be passed directly (e.g., `python tv.py key KEY_1`).

### Supported app names

| Name | App ID |
|---|---|
| Netflix | 11101200001 |
| YouTube | 111299001912 |
| Prime | 3201910019365 |
| Disney | 3201901017640 |
| Plex | 3201512006963 |
| Browser | org.tizen.browser |

---

## REST API

### Start the API server

```bash
python api_server.py
```

Server listens on `http://0.0.0.0:5555`. Interactive docs available at `http://localhost:5555/docs` (Swagger UI).

### Endpoints

| Method | Path | Request body | Response | Description |
|---|---|---|---|---|
| POST | `/key` | `{"key": "power"}` | `{"ok": true}` | Send a remote key (alias or raw KEY_* string) |
| POST | `/app` | `{"name": "Netflix"}` | `{"ok": true}` | Launch an app by name |
| POST | `/text` | `{"text": "hello"}` | `{"ok": true}` | Send text input to the TV |
| GET | `/info` | - | JSON object | Get TV device information |
| POST | `/wake` | `{"mac": "AA:BB:CC:DD:EE:FF"}` (optional) | `{"ok": true}` | Wake TV via WoL; MAC auto-detected if omitted |
| GET | `/apps` | - | JSON array | List all installed apps |

### Example curl calls

```bash
# Power toggle
curl -X POST http://localhost:5555/key -H "Content-Type: application/json" -d '{"key":"power"}'

# Launch Netflix
curl -X POST http://localhost:5555/app -H "Content-Type: application/json" -d '{"name":"Netflix"}'

# Send text
curl -X POST http://localhost:5555/text -H "Content-Type: application/json" -d '{"text":"hello"}'

# Get TV info
curl http://localhost:5555/info

# List apps
curl http://localhost:5555/apps

# Wake on LAN (auto MAC)
curl -X POST http://localhost:5555/wake -H "Content-Type: application/json" -d '{}'
```

---

## TV Discovery

The library connects on **WebSocket port 8002** and queries the REST API on **HTTP port 8001**.

Priority order for IP resolution:

1. Value passed directly to `SamsungTV(ip='...')` in code
2. `TV_IP` environment variable
3. Auto-scan `192.168.1.1`-`192.168.1.254` on port `8002` (timeout 0.1 s per host)
4. Fallback default `192.168.1.100`

### Discovered TV IP summary

| Setting | Value |
|---|---|
| Default fallback IP | 192.168.1.100 |
| WebSocket port | 8002 |
| REST API port | 8001 |
| Scan subnet | 192.168.1.0/24 |
| Controller name | ClaudeController |

Set `TV_IP` to your TV's actual LAN address to skip the scan and connect instantly.

---

## Logging

All connections, key presses, and errors are logged to `tv-control.log` in the working directory.

---

## Files

| File | Purpose |
|---|---|
| `tv.py` | CLI entry point |
| `api_server.py` | FastAPI REST server (port 5555) |
| `samsung_tv.py` | Core SamsungTV class: WebSocket, WoL, REST |
| `config.py` | IP/port defaults and app ID map |
| `requirements.txt` | Python dependencies |
