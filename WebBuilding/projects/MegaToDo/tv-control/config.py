import os

TV_IP = os.getenv('TV_IP', '192.168.1.100')
TV_PORT = 8002  # WebSocket port
TV_REST_PORT = 8001

APP_IDS = {
    'Netflix': '11101200001',
    'YouTube': '111299001912',
    'Prime': '3201910019365',
    'Disney': '3201901017640',
    'Plex': '3201512006963',
    'Browser': 'org.tizen.browser',
}
