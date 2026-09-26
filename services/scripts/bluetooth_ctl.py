#!/usr/bin/env python3
import sys
import os
import subprocess
import json
import re

ENV = os.environ.copy()
ENV["NO_COLOR"] = "1"
ENV["TERM"] = "dumb"

ANSI_REGEX = re.compile(r'\x1b\[[0-9;]*[a-zA-Z]')

def strip_ansi(text):
    if not text:
        return ""
    return ANSI_REGEX.sub('', text)

def run_bt(args, timeout=10):
    try:
        proc = subprocess.run(
            ["bluetoothctl"] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=ENV
        )
        return strip_ansi(proc.stdout)
    except Exception:
        return ""

def parse_device_type(icon_str, name_str):
    icon_str = (icon_str or "").lower()
    name_str = (name_str or "").lower()

    if "headset" in icon_str or "headphone" in icon_str:
        return "headphones"
    if "speaker" in icon_str or "audio-card" in icon_str or "audio" in icon_str:
        return "speaker"
    if "keyboard" in icon_str:
        return "keyboard"
    if "mouse" in icon_str or "gaming" in icon_str:
        return "mouse"
    if "phone" in icon_str:
        return "smartphone"
    if "computer" in icon_str:
        return "computer"

    # Name-based heuristic fallback
    if any(k in name_str for k in ["buds", "headphone", "earphone", "airpod", "headset", "wf-", "wh-"]):
        return "headphones"
    if any(k in name_str for k in ["speaker", "emberton", "soundbar", "jbl", "flip", "charge", "audio", "boom"]):
        return "speaker"
    if any(k in name_str for k in ["keyboard", "keys", "kb"]):
        return "keyboard"
    if any(k in name_str for k in ["mouse", "trackpad", "mx master"]):
        return "mouse"
    if any(k in name_str for k in ["phone", "iphone", "pixel", "galaxy"]):
        return "smartphone"

    return "bluetooth"

def get_status():
    # 1. Controller status
    show_out = run_bt(["show"])
    powered = "Powered: yes" in show_out
    discovering = "Discovering: yes" in show_out

    if not powered:
        return {
            "enabled": False,
            "discovering": discovering,
            "connected_count": 0,
            "primary_device": "",
            "paired": [],
            "available": []
        }

    # 2. Paired devices
    paired_out = run_bt(["devices", "Paired"])
    paired_macs = []
    paired_names = {}
    for raw_line in paired_out.strip().splitlines():
        line = strip_ansi(raw_line).strip()
        parts = line.split(" ", 2)
        if len(parts) >= 3 and parts[0] == "Device":
            mac = parts[1].strip()
            name = parts[2].strip()
            paired_macs.append(mac)
            paired_names[mac] = name

    # 3. Connected devices
    conn_out = run_bt(["devices", "Connected"])
    connected_macs = set()
    for raw_line in conn_out.strip().splitlines():
        line = strip_ansi(raw_line).strip()
        parts = line.split(" ", 2)
        if len(parts) >= 3 and parts[0] == "Device":
            connected_macs.add(parts[1].strip())

    # 4. All known/discovered devices
    all_out = run_bt(["devices"])
    all_devices = {}
    for raw_line in all_out.strip().splitlines():
        line = strip_ansi(raw_line).strip()
        parts = line.split(" ", 2)
        if len(parts) >= 3 and parts[0] == "Device":
            mac = parts[1].strip()
            name = parts[2].strip()
            all_devices[mac] = name

    # Collect info for paired devices
    paired_list = []

    for mac in paired_macs:
        info_text = run_bt(["info", mac])

        # Extract name / alias
        name = paired_names.get(mac, mac)
        alias_match = re.search(r"^\s*Alias:\s*(.+)$", info_text, re.MULTILINE)
        if alias_match:
            name = alias_match.group(1).strip()
        else:
            name_match = re.search(r"^\s*Name:\s*(.+)$", info_text, re.MULTILINE)
            if name_match:
                name = name_match.group(1).strip()

        # Extract icon
        icon_match = re.search(r"^\s*Icon:\s*(.+)$", info_text, re.MULTILINE)
        raw_icon = icon_match.group(1).strip() if icon_match else ""
        icon = parse_device_type(raw_icon, name)

        # Extract connected status
        connected = (mac in connected_macs) or ("Connected: yes" in info_text)

        # Extract battery if available
        battery = None
        battery_match = re.search(r"Battery Percentage:\s*.*\((\d+)\)", info_text)
        if battery_match:
            battery = int(battery_match.group(1))

        paired_list.append({
            "mac": mac,
            "name": name,
            "icon": icon,
            "connected": connected,
            "paired": True,
            "battery": battery
        })

    # Sort paired: connected first, then alphabetical
    paired_list.sort(key=lambda d: (not d["connected"], d["name"].lower()))

    # Determine primary device name
    connected_devices = [d for d in paired_list if d["connected"]]
    primary_device = ""
    if connected_devices:
        # Prioritize audio devices (headphones/speakers) for primary_device summary
        audio_devs = [d for d in connected_devices if d["icon"] in ["headphones", "speaker"]]
        main_dev = audio_devs[0] if audio_devs else connected_devices[0]
        if len(connected_devices) == 1:
            primary_device = main_dev["name"]
        else:
            primary_device = f"{main_dev['name']} (+{len(connected_devices) - 1})"

    # Collect available (unpaired) devices
    available_list = []
    for mac, name in all_devices.items():
        if mac in paired_macs:
            continue
        cleaned_name = name.strip() if name else mac
        icon = parse_device_type("", cleaned_name)
        available_list.append({
            "mac": mac,
            "name": cleaned_name,
            "icon": icon,
            "connected": False,
            "paired": False,
            "battery": None
        })

    # Sort available: devices with meaningful names first, then alphabetical
    def is_just_mac(n):
        return bool(re.match(r"^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$", n))

    available_list.sort(key=lambda d: (is_just_mac(d["name"]), d["name"].lower()))

    return {
        "enabled": True,
        "discovering": discovering,
        "connected_count": len(connected_devices),
        "primary_device": primary_device,
        "paired": paired_list,
        "available": available_list
    }

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "status":
        print(json.dumps(get_status()))
    elif cmd == "scan":
        # Scan for 5 seconds
        run_bt(["--timeout", "5", "scan", "on"], timeout=8)
        print(json.dumps(get_status()))
    elif cmd == "power":
        action = sys.argv[2] if len(sys.argv) > 2 else "on"
        run_bt(["power", action])
        print(json.dumps(get_status()))
    elif cmd == "connect":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Missing MAC address"}))
            return
        mac = sys.argv[2]
        out = run_bt(["connect", mac], timeout=15)
        success = "Connection successful" in out
        print(json.dumps({"success": success, "output": out.strip(), "mac": mac}))
    elif cmd == "disconnect":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Missing MAC address"}))
            return
        mac = sys.argv[2]
        out = run_bt(["disconnect", mac], timeout=10)
        success = "Successful disconnected" in out
        print(json.dumps({"success": success, "output": out.strip(), "mac": mac}))
    elif cmd == "pair":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Missing MAC address"}))
            return
        mac = sys.argv[2]
        p_out = run_bt(["pair", mac], timeout=20)
        t_out = run_bt(["trust", mac], timeout=5)
        c_out = run_bt(["connect", mac], timeout=15)
        success = "Pairing successful" in p_out or "Connection successful" in c_out
        print(json.dumps({
            "success": success,
            "output": f"{p_out}\n{c_out}".strip(),
            "mac": mac
        }))
    elif cmd == "remove":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Missing MAC address"}))
            return
        mac = sys.argv[2]
        out = run_bt(["remove", mac], timeout=10)
        success = "Device has been removed" in out
        print(json.dumps({"success": success, "output": out.strip(), "mac": mac}))
    else:
        print(json.dumps({"error": f"Unknown command: {cmd}"}))

if __name__ == "__main__":
    main()
