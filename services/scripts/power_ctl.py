#!/usr/bin/env python3
"""Read and update Linux battery charge limits.

Status reads are unprivileged. Mutating commands are expected to be launched
through pkexec because power-supply sysfs attributes are root-owned.
"""

from __future__ import annotations

import glob
import json
import os
import re
import sys
from pathlib import Path


NUMERIC_PRESETS = (80, 85, 90, 95, 100)
FIXED_PRESETS = (80, 100)


def emit(payload: dict, exit_code: int = 0) -> None:
    print(json.dumps(payload, separators=(",", ":")))
    raise SystemExit(exit_code)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip()


def battery_directories() -> list[Path]:
    batteries: list[Path] = []
    for raw_path in sorted(glob.glob("/sys/class/power_supply/*")):
        path = Path(raw_path)
        try:
            if read_text(path / "type") == "Battery":
                batteries.append(path)
        except OSError:
            continue
    return batteries


def parse_charge_types(raw_value: str) -> tuple[list[str], str]:
    tokens = re.findall(r"\[[^]]+\]|\S+", raw_value)
    supported: list[str] = []
    active = ""

    for token in tokens:
        selected = token.startswith("[") and token.endswith("]")
        value = token.strip("[]").replace("_", " ")
        supported.append(value)
        if selected:
            active = value

    return supported, active


def discover() -> dict:
    batteries = battery_directories()

    # Hardware with numeric thresholds can implement every requested preset.
    for battery in batteries:
        end_path = battery / "charge_control_end_threshold"
        if not end_path.exists():
            continue
        try:
            current = int(read_text(end_path))
        except (OSError, ValueError):
            continue
        return {
            "supported": True,
            "mode": "numeric",
            "path": str(end_path),
            "start_path": str(battery / "charge_control_start_threshold"),
            "current_limit": current,
            "presets": list(NUMERIC_PRESETS),
            "detail": "Choose the maximum battery charge.",
            "active_type": "Custom",
        }

    # New kernels expose fixed firmware conservation modes through charge_types.
    for battery in batteries:
        charge_types_path = battery / "charge_types"
        if not charge_types_path.exists():
            continue
        try:
            supported, active = parse_charge_types(read_text(charge_types_path))
        except OSError:
            continue
        if "Long Life" not in supported:
            continue
        return {
            "supported": True,
            "mode": "fixed",
            "path": str(charge_types_path),
            "current_limit": 80 if active == "Long Life" else 100,
            "presets": list(FIXED_PRESETS),
            "detail": "Firmware conservation mode holds the battery around 75–80%.",
            "active_type": active,
            "normal_type": "Standard" if "Standard" in supported else "Fast",
        }

    # Compatibility path used by older ideapad_laptop kernels.
    legacy_paths = sorted(
        glob.glob("/sys/bus/platform/devices/VPC2004:*/conservation_mode")
        + glob.glob("/sys/bus/platform/drivers/ideapad_acpi/VPC2004:*/conservation_mode")
    )
    for raw_path in legacy_paths:
        path = Path(raw_path)
        try:
            enabled = read_text(path) == "1"
        except OSError:
            continue
        return {
            "supported": True,
            "mode": "fixed",
            "path": str(path),
            "current_limit": 80 if enabled else 100,
            "presets": list(FIXED_PRESETS),
            "detail": "Firmware conservation mode holds the battery around 75–80%.",
            "active_type": "Long Life" if enabled else "Standard",
        }

    return {
        "supported": False,
        "mode": "unsupported",
        "current_limit": 100,
        "presets": [],
        "detail": "This battery does not expose a Linux charge-limit control.",
        "active_type": "",
    }


def write_value(path: Path, value: str) -> None:
    with path.open("w", encoding="utf-8") as handle:
        handle.write(value + "\n")


def set_limit(limit: int) -> None:
    if limit not in NUMERIC_PRESETS:
        emit({"error": "Unsupported charge-limit preset."}, 2)
    if os.geteuid() != 0:
        emit({"error": "Administrator authentication is required."}, 77)

    status = discover()
    if not status["supported"]:
        emit({"error": status["detail"]}, 3)

    try:
        if status["mode"] == "numeric":
            end_path = Path(status["path"])
            start_path = Path(status["start_path"])

            # Some drivers reject an end threshold below the current start.
            if limit < 100 and start_path.exists():
                try:
                    current_start = int(read_text(start_path))
                    if current_start >= limit:
                        write_value(start_path, str(max(0, limit - 5)))
                except (OSError, ValueError):
                    pass

            write_value(end_path, str(limit))
        else:
            if limit not in FIXED_PRESETS:
                emit({"error": "This laptop only supports its fixed 80% conservation mode."}, 4)

            path = Path(status["path"])
            if path.name == "charge_types":
                value = "Long_Life" if limit == 80 else status.get("normal_type", "Standard")
            else:
                value = "1" if limit == 80 else "0"
            write_value(path, value)
    except OSError as error:
        emit({"error": f"Could not update the charge limit: {error.strerror or error}"}, 5)

    updated = discover()
    updated["ok"] = True
    emit(updated)


def main() -> None:
    if len(sys.argv) == 2 and sys.argv[1] == "status":
        emit(discover())
    if len(sys.argv) == 3 and sys.argv[1] == "set-limit":
        try:
            limit = int(sys.argv[2])
        except ValueError:
            emit({"error": "Charge limit must be a number."}, 2)
        set_limit(limit)
    emit({"error": "Usage: power_ctl.py status | set-limit <percent>"}, 2)


if __name__ == "__main__":
    main()
