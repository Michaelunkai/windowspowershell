#!/usr/bin/env python3
import argparse
import sys
from samsung_tv import SamsungTV

def main():
    parser = argparse.ArgumentParser(description='Samsung TV Controller')
    sub = parser.add_subparsers(dest='cmd', required=True)

    key_p = sub.add_parser('key', help='Send remote key')
    key_p.add_argument('name', help='Key name (power/up/down/enter/vol_up/vol_down/mute/etc)')

    app_p = sub.add_parser('app', help='Launch app')
    app_p.add_argument('name', help='App name (Netflix/YouTube/Prime/Disney+/Plex/Browser)')

    text_p = sub.add_parser('text', help='Send text input')
    text_p.add_argument('content', help='Text to send')

    sub.add_parser('info', help='Get TV info')

    wake_p = sub.add_parser('wake', help='Wake TV via WoL')
    wake_p.add_argument('--mac', help='MAC address (auto-detected if omitted)')

    sub.add_parser('apps', help='List installed apps')

    args = parser.parse_args()
    tv = SamsungTV()

    if args.cmd == 'key':
        print('OK' if tv.send_key(args.name) else 'FAIL')
    elif args.cmd == 'app':
        print('OK' if tv.launch_app(args.name) else 'FAIL')
    elif args.cmd == 'text':
        print('OK' if tv.send_text(args.content) else 'FAIL')
    elif args.cmd == 'info':
        import json
        print(json.dumps(tv.get_tv_info(), indent=2))
    elif args.cmd == 'wake':
        print('OK' if tv.wake_tv(args.mac) else 'FAIL')
    elif args.cmd == 'apps':
        import json
        print(json.dumps(tv.list_installed_apps(), indent=2))

if __name__ == '__main__':
    main()
