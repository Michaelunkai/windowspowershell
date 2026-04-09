import os, json, time, base64, logging, subprocess
import websocket
import requests

logging.basicConfig(filename='tv-control.log', level=logging.INFO)
logger = logging.getLogger(__name__)

KEY_MAP = {
    'power': 'KEY_POWER', 'up': 'KEY_UP', 'down': 'KEY_DOWN', 'left': 'KEY_LEFT', 'right': 'KEY_RIGHT',
    'enter': 'KEY_ENTER', 'back': 'KEY_RETURN', 'home': 'KEY_HOME', 'menu': 'KEY_MENU',
    'vol_up': 'KEY_VOLUP', 'vol_down': 'KEY_VOLDOWN', 'mute': 'KEY_MUTE',
    'ch_up': 'KEY_CHUP', 'ch_down': 'KEY_CHDOWN',
    'play': 'KEY_PLAY', 'pause': 'KEY_PAUSE', 'stop': 'KEY_STOP', 'ff': 'KEY_FF', 'rew': 'KEY_REWIND',
    'hdmi1': 'KEY_HDMI1', 'hdmi2': 'KEY_HDMI2', 'source': 'KEY_SOURCE',
    'smart': 'KEY_SMARTHUB', 'info': 'KEY_INFO',
    'red': 'KEY_RED', 'green': 'KEY_GREEN', 'yellow': 'KEY_YELLOW', 'blue': 'KEY_BLUE',
}

class SamsungTV:
    def __init__(self, ip=None, port=8002):
        self.ip = ip or os.getenv('TV_IP') or self._discover_ip()
        self.port = port
        self.ws = None
        self._connect()

    def _discover_ip(self):
        # Try common Samsung TV IPs on subnet
        import socket
        for i in range(1, 255):
            ip = f'192.168.1.{i}'
            try:
                s = socket.socket()
                s.settimeout(0.1)
                s.connect((ip, 8002))
                s.close()
                return ip
            except: pass
        return '192.168.1.100'

    def _connect(self, retries=10):
        name_b64 = base64.b64encode(b'ClaudeController').decode()
        url = f'ws://{self.ip}:{self.port}/api/v2/channels/samsung.remote.control?name={name_b64}'
        for i in range(retries):
            try:
                self.ws = websocket.create_connection(url, timeout=5)
                logger.info(f'Connected to TV at {self.ip}')
                return
            except Exception as e:
                logger.warning(f'Connect attempt {i+1} failed: {e}')
                time.sleep(5)
        raise ConnectionError(f'Could not connect to TV at {self.ip}')

    def send_key(self, key_name):
        key = KEY_MAP.get(key_name.lower(), key_name)
        payload = json.dumps({'method': 'ms.remote.control', 'params': {'Cmd': 'Click', 'DataOfCmd': key, 'Option': 'false', 'TypeOfRemote': 'SendRemoteKey'}})
        for attempt in range(2):
            try:
                self.ws.send(payload)
                logger.info(f'Sent key: {key}')
                return True
            except Exception as e:
                logger.warning(f'send_key retry {attempt}: {e}')
                time.sleep(0.5)
                self._connect()
        return False

    def get_mac(self):
        try:
            out = subprocess.check_output(f'arp -a {self.ip}', shell=True).decode()
            for line in out.splitlines():
                if self.ip in line:
                    parts = line.split()
                    for p in parts:
                        if '-' in p and len(p) == 17:
                            return p
        except: pass
        return None

    def get_tv_info(self):
        try:
            r = requests.get(f'http://{self.ip}:8001/api/v2', timeout=5)
            return r.json() if r.status_code == 200 else {}
        except Exception as e:
            logger.error(f'get_tv_info error: {e}')
            return {}

    def wake_tv(self, mac=None):
        if mac is None:
            mac = self.get_mac()
        if mac is None:
            logger.error('No MAC address for WoL')
            return False
        try:
            import wakeonlan
            wakeonlan.send_magic_packet(mac)
            logger.info(f'WoL sent to {mac}')
            return True
        except Exception as e:
            logger.error(f'wake_tv error: {e}')
            return False

    def send_text(self, text):
        payload = json.dumps({'method': 'ms.remote.control', 'params': {'Cmd': text, 'DataOfCmd': 'base64', 'Option': 'false', 'TypeOfRemote': 'SendInputString'}})
        try:
            self.ws.send(payload)
            logger.info(f'Sent text: {text}')
            return True
        except Exception as e:
            logger.error(f'send_text error: {e}')
            return False

    def launch_app(self, app_name):
        from config import APP_IDS
        app_id = APP_IDS.get(app_name, app_name)
        try:
            r = requests.post(f'http://{self.ip}:8001/api/v2/applications/{app_id}', timeout=5)
            logger.info(f'Launch app {app_name}: {r.status_code}')
            return r.status_code == 200
        except Exception as e:
            logger.error(f'launch_app error: {e}')
            return False

    def close_app(self, app_name):
        from config import APP_IDS
        app_id = APP_IDS.get(app_name, app_name)
        try:
            r = requests.delete(f'http://{self.ip}:8001/api/v2/applications/{app_id}', timeout=5)
            return r.status_code == 200
        except Exception as e:
            logger.error(f'close_app error: {e}')
            return False

    def list_installed_apps(self):
        try:
            r = requests.get(f'http://{self.ip}:8001/api/v2/applications', timeout=5)
            return r.json() if r.status_code == 200 else []
        except Exception as e:
            logger.error(f'list_apps error: {e}')
            return []
