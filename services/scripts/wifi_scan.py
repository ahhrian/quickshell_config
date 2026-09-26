#!/usr/bin/env python3
import subprocess
import json
import sys

def scan():
    known = set()
    active_ssid = ''

    # 1. Active connection
    try:
        devs = subprocess.check_output(['nmcli', '-t', '-f', 'DEVICE,TYPE,STATE,CONNECTION', 'dev'], timeout=2).decode('utf-8', errors='ignore')
        for l in devs.splitlines():
            p = l.split(':')
            if len(p) >= 4 and p[1] == 'wifi' and 'connected' in p[2]:
                active_ssid = p[3].strip()
                break
    except Exception:
        pass

    # 2. Known saved profiles
    try:
        conns = subprocess.check_output(['nmcli', '-t', '-f', 'NAME,TYPE', 'connection', 'show'], timeout=3).decode('utf-8', errors='ignore')
        for line in conns.splitlines():
            parts = line.split(':')
            if len(parts) >= 2 and parts[1] == '802-11-wireless':
                known.add(parts[0].strip())
    except Exception:
        pass

    # 3. Available scan results
    nets = {}
    try:
        out = subprocess.check_output(['nmcli', '-t', '-f', 'IN-USE,SSID,SIGNAL,SECURITY', 'dev', 'wifi', 'list'], timeout=6).decode('utf-8', errors='ignore')
        for line in out.splitlines():
            parts = line.split(':')
            if len(parts) >= 4:
                in_use = (parts[0].strip() == '*') or (parts[1].strip() == active_ssid and bool(active_ssid))
                ssid = parts[1].strip()
                if not ssid:
                    continue
                if in_use:
                    active_ssid = ssid
                try:
                    sig = int(parts[2].strip())
                except:
                    sig = 0
                sec = parts[3].strip()
                secure = bool(sec and sec != '--')
                if ssid not in nets or sig > nets[ssid]['signal']:
                    nets[ssid] = {
                        'ssid': ssid,
                        'signal': sig,
                        'secure': secure,
                        'security': sec,
                        'connected': in_use,
                        'known': (ssid in known)
                    }
    except Exception:
        pass

    known_list = []
    for k in sorted(known):
        if k in nets:
            item = dict(nets[k])
            item['connected'] = (k == active_ssid)
            known_list.append(item)
        else:
            known_list.append({
                'ssid': k,
                'signal': 0,
                'secure': True,
                'security': 'WPA',
                'connected': (k == active_ssid),
                'known': True,
                'outOfRange': True
            })

    known_list.sort(key=lambda x: (not x['connected'], -x['signal']))
    available_list = [v for k, v in nets.items() if not v['known'] and not v['connected']]
    available_list.sort(key=lambda x: -x['signal'])

    res = {
        'known': known_list,
        'available': available_list[:30]
    }
    print(json.dumps(res))

if __name__ == '__main__':
    scan()
