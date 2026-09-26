#!/usr/bin/env python3
"""
Audio Controller Helper for Quickshell
Queries available PipeWire / PulseAudio sinks and handles switching output devices.
"""
import json
import subprocess
import sys

def get_icon_for_sink(sink):
    props = sink.get("properties", {})
    name = sink.get("name", "").lower()
    desc = sink.get("description", "").lower()
    nick = props.get("node.nick", "").lower()
    icon_name = props.get("device.icon_name", "").lower()
    form_factor = props.get("device.form_factor", "").lower()
    bus = props.get("device.bus", "").lower()
    
    combined = f"{name} {desc} {nick} {icon_name} {form_factor} {bus}"
    
    if any(k in combined for k in ["headphone", "headset", "earphone", "earbuds", "buds", "airpods"]):
        return "headphones"
    if any(k in combined for k in ["bluez", "bluetooth"]):
        return "bluetooth"
    if any(k in combined for k in ["hdmi", "displayport", "dp", "video-display", "tv", "monitor"]):
        return "tv"
    if any(k in combined for k in ["speaker", "internal"]):
        return "speaker"
    return "volume_up"

def clean_display_name(sink):
    props = sink.get("properties", {})
    alias = props.get("device.alias")
    nick = props.get("node.nick")
    desc = sink.get("description", "")
    prod = props.get("device.product.name", "")
    name = sink.get("name", "")
    
    def is_valid(s):
        return bool(s and str(s).strip() and str(s).strip().lower() not in ["(null)", "null", "none"])

    # If it's Bluetooth, alias is almost always the cleanest friendly device name
    if is_valid(alias) and alias.lower() not in ["sof-soundwire", "hda intel", "alsa"]:
        return alias.replace("_", " ")

    # Prioritize friendly nick
    if is_valid(nick) and nick.lower() not in ["sof-soundwire", "hda intel", "alsa"]:
        if nick.lower() == "speaker":
            return "Built-in Speaker"
        return nick.replace("_", " ")
    
    # If description contains monitor/product info
    if is_valid(desc):
        if "hdmi" in desc.lower() or "displayport" in desc.lower():
            if is_valid(nick) and nick not in desc:
                return f"{nick} (HDMI)".replace("_", " ")
            clean_desc = desc
            for prefix in ["Core Ultra 200V Series Processors HD Audio ", "HDA Intel ", "HD Audio "]:
                clean_desc = clean_desc.replace(prefix, "")
            return clean_desc.replace("_", " ")
            
        if "speaker" in desc.lower():
            return "Built-in Speaker"

    if is_valid(prod):
        return prod.replace("_", " ")
        
    if is_valid(desc):
        return desc.replace("_", " ")
        
    if is_valid(name):
        return name.replace("_", " ")
        
    return ""

def ensure_bluetooth_cards_active():
    """
    Ensure any connected Bluetooth audio devices have an active audio profile.
    If PipeWire initialized a connected card with profile 'off', pactl list sinks
    will not show it until an audio profile (e.g. a2dp-sink) is activated.
    """
    try:
        raw_cards = subprocess.check_output(["pactl", "-f", "json", "list", "cards"], stderr=subprocess.DEVNULL)
        cards_data = json.loads(raw_cards.decode("utf-8"))
    except Exception:
        return
        
    for card in cards_data:
        card_name = card.get("name", "")
        if not card_name.startswith("bluez_card."):
            continue
            
        active_prof = card.get("active_profile", "")
        if active_prof == "off":
            profiles = card.get("profiles", {})
            best_profile = None
            best_prio = -1
            
            for prof_name, prof_info in profiles.items():
                if prof_name == "off":
                    continue
                if prof_info.get("sinks", 0) > 0 and prof_info.get("available", True):
                    prio = prof_info.get("priority", 0)
                    if "a2dp" in prof_name:
                        prio += 1000
                    if prio > best_prio:
                        best_prio = prio
                        best_profile = prof_name
                        
            if best_profile:
                try:
                    subprocess.run(["pactl", "set-card-profile", card_name, best_profile], stderr=subprocess.DEVNULL, timeout=2)
                except Exception:
                    pass

def get_sinks_status():
    ensure_bluetooth_cards_active()

    try:
        raw_sinks = subprocess.check_output(["pactl", "-f", "json", "list", "sinks"], stderr=subprocess.DEVNULL)
        sinks_data = json.loads(raw_sinks.decode("utf-8"))
    except Exception:
        sinks_data = []

    try:
        default_sink = subprocess.check_output(["pactl", "get-default-sink"], stderr=subprocess.DEVNULL).decode("utf-8").strip()
    except Exception:
        default_sink = ""

    result = []
    for s in sinks_data:
        name = s.get("name", "")
        props = s.get("properties", {})
        flags = s.get("flags", [])
        
        # 1. Filter out network discovery devices (RAOP / AirPlay zeroconf broadcasts)
        # unless it is already the active default sink selected by the user.
        is_net = (
            "NETWORK" in flags
            or props.get("node.network") == "true"
            or props.get("sess.media") == "raop"
            or name.startswith("raop_sink.")
            or name.startswith("tunnel_sink.")
        )
        if is_net and name != default_sink:
            continue
            
        # 2. Get cleaned display name and strictly filter out any (null) values
        display_name = clean_display_name(s)
        if not display_name or display_name.strip().lower() in ["(null)", "null", "none", ""]:
            continue
        if "(null)" in display_name.lower():
            continue

        desc = s.get("description", "")
        if desc and str(desc).strip().lower() in ["(null)", "null"]:
            desc = display_name

        # 3. Availability check:
        # For ALSA hardware sinks: check port availability
        ports = s.get("ports", [])
        if ports:
            is_available = any(p.get("availability") not in ("not available", "no") for p in ports)
        else:
            is_available = True
            
        # Default sink is always considered available
        if name == default_sink:
            is_available = True
            
        # Only include available sinks
        if not is_available:
            continue
            
        # Extract volume info
        vol_pct = 0
        v_dict = s.get("volume", {})
        if v_dict:
            first_ch = next(iter(v_dict.values()), {})
            if isinstance(first_ch, dict) and "value_percent" in first_ch:
                try:
                    vol_pct = int(first_ch["value_percent"].replace("%", "").strip())
                except ValueError:
                    vol_pct = 0

        item = {
            "id": s.get("index"),
            "name": name,
            "display_name": display_name,
            "description": desc,
            "icon": get_icon_for_sink(s),
            "is_default": (name == default_sink),
            "is_available": is_available,
            "volume_percent": vol_pct,
            "muted": s.get("mute", False)
        }
        result.append(item)

    return {
        "default_sink": default_sink,
        "sinks": result,
        "all_sinks": result
    }

def set_default_sink(sink_name):
    try:
        if "bluez" in sink_name:
            ensure_bluetooth_cards_active()

        subprocess.check_call(["pactl", "set-default-sink", sink_name])
        
        # Move all currently playing sink inputs to the new default sink
        try:
            raw_inputs = subprocess.check_output(["pactl", "-f", "json", "list", "sink-inputs"], stderr=subprocess.DEVNULL)
            inputs_data = json.loads(raw_inputs.decode("utf-8"))
            for inp in inputs_data:
                inp_idx = inp.get("index")
                if inp_idx is not None:
                    subprocess.run(["pactl", "move-sink-input", str(inp_idx), sink_name], stderr=subprocess.DEVNULL, timeout=1)
        except Exception:
            pass

        return {"success": True, "default_sink": sink_name}
    except Exception as e:
        return {"success": False, "error": str(e)}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] in ["status", "sinks"]:
        data = get_sinks_status()
        print(json.dumps(data))
    elif sys.argv[1] == "set-default" and len(sys.argv) >= 3:
        target = sys.argv[2]
        res = set_default_sink(target)
        print(json.dumps(res))
    else:
        print(json.dumps({"error": f"Unknown command: {sys.argv}"}))
