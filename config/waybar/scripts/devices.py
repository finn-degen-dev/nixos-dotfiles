#!/usr/bin/env python3
import html
import json
import os
import re
import select
import signal
import subprocess
import sys
from pathlib import Path

USER = os.environ.get("USER", "")
EXTRA_PATH = f"/run/current-system/sw/bin:/etc/profiles/per-user/{USER}/bin"
os.environ["PATH"] = f"{EXTRA_PATH}:{os.environ.get('PATH', '')}"

BAT_ICONS = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰁹"]
BAT_CHARGING = "󰂄"

ICON_BT_ON = "󰂯"
ICON_BT_CONN = "󰂱"
ICON_BT_OFF = "󰂲"
ICON_USB = "󰕓"
ICON_HEADPHONES = "󰋋"
ICON_HEADSET = "󰋎"
ICON_SPEAKER = "󰓃"
ICON_MIC = "󰍬"
ICON_MOUSE = "󰍽"
ICON_KEYBOARD = "󰌌"
ICON_GAMEPAD = "󰊗"
ICON_PHONE = "󰄜"
ICON_WATCH = "󰖉"
ICON_DRIVE = "󰋊"
ICON_SD = "󰑹"
ICON_PRINTER = "󰐪"
ICON_CAMERA = "󰄀"
ICON_ETHERNET = "󰈀"
ICON_CHIP = "󰘚"

GAMEPAD_VENDORS = {"054c", "045e", "057e", "2dc8", "0f0d", "0e6f", "20d6", "0738"}


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore").strip()
    except OSError:
        return ""


def parse_uevent(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in read_text(path).splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def run_cmd(args: list[str], timeout: float = 1.5) -> str:
    try:
        res = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return res.stdout if res.returncode == 0 else ""
    except Exception:
        return ""


def unwrap_dbus(val):
    if isinstance(val, dict) and "type" in val and "data" in val and len(val) == 2:
        return val["data"]
    return val


def format_size(num_bytes: int) -> str:
    val = float(num_bytes)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if val < 1000.0 or unit == "TB":
            if unit in ("B", "KB", "MB"):
                return f"{int(round(val))} {unit}"
            return f"{val:.1f} {unit}".replace(".0 ", " ")
        val /= 1000.0
    return f"{num_bytes} B"


def battery_bar_markup(pct: int, charging: bool = False) -> str:
    pct = max(0, min(100, int(round(pct))))
    if charging:
        icon = BAT_CHARGING
        color = "#3bb36a"
    else:
        idx = min(9, max(0, pct // 10))
        icon = BAT_ICONS[idx]
        if pct >= 60:
            color = "#3bb36a"
        elif pct >= 25:
            color = "#e6e6ea"
        elif pct >= 15:
            color = "#d4a34b"
        else:
            color = "#e05555"
    return f"<span foreground='{color}'>{icon}</span>"


def format_device_bar(icon: str, bat: tuple[int, bool] | None) -> str:
    if bat is None:
        return icon
    pct, charging = bat
    return f"{icon}\u2009{battery_bar_markup(pct, charging)}"


def format_bat_tooltip(bat: tuple[int, bool] | None) -> str:
    if bat is None:
        return ""
    pct, charging = bat
    suffix = " (Charging)" if charging else ""
    return f" — {pct}%{suffix}"


def get_sysfs_batteries() -> list[dict]:
    ps_root = Path("/sys/class/power_supply")
    if not ps_root.is_dir():
        return []

    batteries: list[dict] = []
    for entry in sorted(ps_root.iterdir()):
        if read_text(entry / "type") != "Battery":
            continue

        scope = read_text(entry / "scope")
        dev_link = entry / "device"
        dev_real = os.path.realpath(dev_link) if dev_link.exists() else ""

        if scope == "System":
            continue
        if not scope:
            if entry.name.startswith("BAT") or "PNP0C0A" in dev_real:
                continue

        cap_str = read_text(entry / "capacity")
        pct: int | None = int(cap_str) if cap_str.isdigit() else None
        if pct is None:
            lvl = read_text(entry / "capacity_level").lower()
            lvl_map = {"full": 100, "high": 75, "normal": 50, "low": 20, "critical": 5}
            pct = lvl_map.get(lvl)
        if pct is None:
            continue

        status = read_text(entry / "status")
        charging = status == "Charging"

        uevent = parse_uevent(entry / "uevent")
        dev_uevent = parse_uevent(entry / "device" / "uevent") if dev_link.exists() else {}
        uniq = (
            read_text(entry / "device" / "uniq")
            or dev_uevent.get("HID_UNIQ", "")
            or uevent.get("POWER_SUPPLY_SERIAL_NUMBER", "")
        ).lower()
        model = (
            read_text(entry / "model_name")
            or uevent.get("POWER_SUPPLY_MODEL_NAME", "")
            or dev_uevent.get("HID_NAME", "")
        ).strip()

        batteries.append(
            {
                "name": entry.name,
                "pct": pct,
                "charging": charging,
                "dev_real": dev_real,
                "uniq": uniq,
                "model": model,
            }
        )
    return batteries


def get_upower_batteries() -> list[dict]:
    raw = run_cmd(
        [
            "busctl",
            "--system",
            "--json=short",
            "call",
            "org.freedesktop.UPower",
            "/org/freedesktop/UPower",
            "org.freedesktop.UPower",
            "EnumerateDevices",
        ]
    )
    if not raw:
        return []

    try:
        parsed = json.loads(raw)
        paths = parsed.get("data", [[]])[0]
    except Exception:
        return []

    items: list[dict] = []
    for obj_path in paths:
        if any(k in obj_path for k in ("line_power", "battery_BAT", "DisplayDevice")):
            continue
        props_raw = run_cmd(
            [
                "busctl",
                "--system",
                "--json=short",
                "call",
                "org.freedesktop.UPower",
                obj_path,
                "org.freedesktop.DBus.Properties",
                "GetAll",
                "s",
                "org.freedesktop.UPower.Device",
            ]
        )
        if not props_raw:
            continue
        try:
            props = json.loads(props_raw).get("data", [{}])[0]
        except Exception:
            continue

        is_present = bool(unwrap_dbus(props.get("IsPresent", False)))
        pct = unwrap_dbus(props.get("Percentage"))
        if not is_present or pct is None:
            continue

        dev_type = int(unwrap_dbus(props.get("Type", 0)) or 0)
        state = int(unwrap_dbus(props.get("State", 0)) or 0)
        items.append(
            {
                "path": obj_path,
                "native_path": str(unwrap_dbus(props.get("NativePath", "")) or ""),
                "model": str(unwrap_dbus(props.get("Model", "")) or "").strip(),
                "serial": str(unwrap_dbus(props.get("Serial", "")) or "").strip().lower(),
                "pct": int(round(float(pct))),
                "charging": state in (1, 5),
                "type": dev_type,
            }
        )
    return items


def classify_bt_icon(bluez_icon: str, name: str) -> str:
    bi = bluez_icon.lower()
    nl = name.lower()

    if bi == "audio-headphones" or any(
        k in nl for k in ("headphone", "airpods", "buds", "wh-", "wf-", "quietcomfort", "momentum", "beats")
    ):
        return ICON_HEADPHONES
    if bi == "audio-headset" or any(k in nl for k in ("headset", "jabra", "arctis")):
        return ICON_HEADSET
    if bi in ("audio-card", "audio-speakers") or any(
        k in nl for k in ("speaker", "jbl", "soundcore", "boom", "sonos", "marshall")
    ):
        return ICON_SPEAKER
    if bi == "input-mouse" or any(
        k in nl for k in ("mouse", "mx master", "mx anywhere", "superlight", "viper", "basilisk")
    ):
        return ICON_MOUSE
    if bi == "input-keyboard" or any(k in nl for k in ("keyboard", "keychron", "hhkb", "nuphy", "mx keys")):
        return ICON_KEYBOARD
    if bi == "input-gaming" or any(
        k in nl for k in ("controller", "gamepad", "xbox", "dualshock", "dualsense", "joy-con", "8bitdo")
    ):
        return ICON_GAMEPAD
    if bi in ("phone", "modem") or any(k in nl for k in ("iphone", "pixel", "galaxy", "phone")):
        return ICON_PHONE
    if bi in ("watch", "wearable") or any(k in nl for k in ("watch", "garmin")):
        return ICON_WATCH
    if bi.startswith("camera"):
        return ICON_CAMERA
    if bi == "printer":
        return ICON_PRINTER
    return ICON_BT_CONN


def get_bluetooth_state(include_paired: bool = False) -> tuple[bool, list[dict]]:
    raw = run_cmd(
        [
            "busctl",
            "--system",
            "--json=short",
            "call",
            "org.bluez",
            "/",
            "org.freedesktop.DBus.ObjectManager",
            "GetManagedObjects",
        ]
    )
    if raw:
        try:
            objects = json.loads(raw).get("data", [{}])[0]
            powered = False
            devices: list[dict] = []
            for ifaces in objects.values():
                if "org.bluez.Adapter1" in ifaces:
                    adapter = ifaces["org.bluez.Adapter1"]
                    if bool(unwrap_dbus(adapter.get("Powered", False))):
                        powered = True
                if "org.bluez.Device1" in ifaces:
                    dev = ifaces["org.bluez.Device1"]
                    connected = bool(unwrap_dbus(dev.get("Connected", False)))
                    paired = bool(unwrap_dbus(dev.get("Paired", False)))
                    if not connected and not (include_paired and paired):
                        continue
                    addr = str(unwrap_dbus(dev.get("Address", "")) or "")
                    name = str(unwrap_dbus(dev.get("Alias", "")) or unwrap_dbus(dev.get("Name", "")) or addr)
                    icon_name = str(unwrap_dbus(dev.get("Icon", "")) or "")
                    bat_pct = None
                    if "org.bluez.Battery1" in ifaces:
                        pct_val = unwrap_dbus(ifaces["org.bluez.Battery1"].get("Percentage"))
                        if pct_val is not None:
                            bat_pct = int(pct_val)
                    devices.append(
                        {
                            "mac": addr.lower(),
                            "raw_mac": addr,
                            "name": name,
                            "icon": classify_bt_icon(icon_name, name),
                            "connected": connected,
                            "bat": (bat_pct, False) if bat_pct is not None else None,
                        }
                    )
            return powered, devices
        except Exception:
            pass

    show = run_cmd(["bluetoothctl", "show"])
    powered = "Powered: yes" in show
    devices = []
    if powered:
        cmd = ["bluetoothctl", "devices", "Paired" if include_paired else "Connected"]
        out = run_cmd(cmd)
        for line in out.splitlines():
            m = re.match(r"^Device\s+([0-9A-Fa-f:]{17})\s+(.*)$", line.strip())
            if not m:
                continue
            mac, name = m.group(1), m.group(2).strip()
            info = run_cmd(["bluetoothctl", "info", mac])
            connected = "Connected: yes" in info
            if not include_paired and not connected:
                continue
            icon_m = re.search(r"^\s*Icon:\s*(\S+)", info, re.M)
            bat_m = re.search(r"^\s*Battery Percentage:.*\((\d+)\)", info, re.M)
            icon_name = icon_m.group(1) if icon_m else ""
            bat_pct = int(bat_m.group(1)) if bat_m else None
            devices.append(
                {
                    "mac": mac.lower(),
                    "raw_mac": mac,
                    "name": name or mac,
                    "icon": classify_bt_icon(icon_name, name),
                    "connected": connected,
                    "bat": (bat_pct, False) if bat_pct is not None else None,
                }
            )
    return powered, devices


def enrich_bt_batteries(devices: list[dict], sys_bats: list[dict], up_bats: list[dict]) -> None:
    for dev in devices:
        mac = dev["mac"]
        if not mac:
            continue
        mac_under = mac.replace(":", "_")

        for sb in sys_bats:
            if sb["uniq"] == mac or mac in sb["dev_real"].lower() or mac_under in sb["dev_real"].lower():
                dev["bat"] = (sb["pct"], sb["charging"])
                break

        for ub in up_bats:
            if ub["serial"] == mac or mac_under in ub["native_path"].lower():
                if dev["bat"] is None or ub["charging"]:
                    dev["bat"] = (ub["pct"], ub["charging"])
                break


def classify_icon_from_upower_type(up_type: int, model: str) -> str:
    if up_type == 5:
        return ICON_MOUSE
    if up_type == 6:
        return ICON_KEYBOARD
    if up_type == 8:
        return ICON_PHONE
    if up_type == 12:
        return ICON_GAMEPAD
    if up_type in (17, 19):
        return ICON_HEADPHONES
    if up_type == 18:
        return ICON_SPEAKER
    ml = model.lower()
    if "mouse" in ml or "mx master" in ml or "superlight" in ml:
        return ICON_MOUSE
    if "keyboard" in ml or "mx keys" in ml:
        return ICON_KEYBOARD
    return ICON_USB


def classify_usb_icon(
    vendor: str,
    product_id: str,
    name: str,
    ifaces: list[tuple[str, str, str]],
) -> str:
    nl = name.lower()
    classes = {c for c, _, _ in ifaces}

    if vendor == "05ac" or any(
        k in nl for k in ("iphone", "ipad", "android", "pixel", "galaxy", "oneplus")
    ) or any(c == "ff" and sc == "42" for c, sc, _ in ifaces):
        return ICON_PHONE

    if vendor in GAMEPAD_VENDORS or any(
        k in nl for k in ("controller", "gamepad", "dualshock", "dualsense", "xbox", "joy-con", "8bitdo", "joystick")
    ):
        return ICON_GAMEPAD

    if "01" in classes:
        if any(k in nl for k in ("mic", "singstar", "yeti", "snowball", "rode", "shure", "fifine", "quadcast")):
            return ICON_MIC
        if any(k in nl for k in ("speaker", "soundbar")):
            return ICON_SPEAKER
        return ICON_HEADPHONES

    if "03" in classes:
        if any(k in nl for k in ("mouse", "trackball", "deathadder", "viper", "superlight", "mx master")) or any(
            c == "03" and p == "02" for c, _, p in ifaces
        ):
            return ICON_MOUSE
        if any(k in nl for k in ("keyboard", "keychron", "hhkb", "wooting", "ducky")) or any(
            c == "03" and p == "01" for c, _, p in ifaces
        ):
            return ICON_KEYBOARD
        return ICON_USB

    if "08" in classes:
        if any(k in nl for k in ("sd", "mmc", "card reader")):
            return ICON_SD
        return ICON_DRIVE

    if "07" in classes:
        return ICON_PRINTER

    if "0e" in classes or "06" in classes:
        return ICON_CAMERA

    if ("02" in classes and "0a" in classes) or any(
        k in nl for k in ("ethernet", "lan", "rtl815", "asix", "ax88")
    ):
        return ICON_ETHERNET

    if any(
        k in nl
        for k in (
            "cp210", "ch340", "ch341", "ftdi", "uart", "serial", "arduino", "esp32",
            "pico", "rp2040", "flipper", "rtl283", "sdr", "st-link", "j-link",
        )
    ):
        return ICON_CHIP

    return ICON_USB


def get_usb_devices(sys_bats: list[dict], up_bats: list[dict]) -> list[dict]:
    usb_root = Path("/sys/bus/usb/devices")
    if not usb_root.is_dir():
        return []

    devices: list[dict] = []
    for dev_dir in sorted(usb_root.iterdir()):
        bname = dev_dir.name
        if bname.startswith("usb") or ":" in bname:
            continue
        if not (dev_dir / "idVendor").is_file():
            continue

        dev_class = read_text(dev_dir / "bDeviceClass").lower()
        dev_sub = read_text(dev_dir / "bDeviceSubClass").lower()
        dev_proto = read_text(dev_dir / "bDeviceProtocol").lower()
        if dev_class == "09":
            continue

        removable = read_text(dev_dir / "removable").lower()
        if removable == "fixed":
            continue

        ifaces: list[tuple[str, str, str]] = []
        for child in dev_dir.iterdir():
            if child.is_dir() and child.name.startswith(f"{bname}:"):
                ic = read_text(child / "bInterfaceClass").lower()
                isc = read_text(child / "bInterfaceSubClass").lower()
                ip = read_text(child / "bInterfaceProtocol").lower()
                if ic:
                    ifaces.append((ic, isc, ip))

        # Skip Bluetooth adapters/radios (handled by the Bluetooth module)
        if (dev_class == "e0" and dev_sub == "01" and dev_proto == "01") or any(
            c == "e0" and sc == "01" and p == "01" for c, sc, p in ifaces
        ):
            continue

        vendor = read_text(dev_dir / "idVendor").lower()
        product_id = read_text(dev_dir / "idProduct").lower()
        manufacturer = read_text(dev_dir / "manufacturer")
        product = read_text(dev_dir / "product")
        serial = read_text(dev_dir / "serial").lower()

        if product and manufacturer and not product.lower().startswith(manufacturer.lower()):
            name = f"{manufacturer} {product}"
        else:
            name = product or manufacturer or f"USB {vendor}:{product_id}"

        usb_real = os.path.realpath(dev_dir)
        matched_sys = [
            sb for sb in sys_bats if sb["dev_real"] and sb["dev_real"].startswith(usb_real + "/")
        ]

        # Wireless USB dongles (e.g. Logitech Unifying/Bolt) may host multiple paired devices
        if len(matched_sys) > 1:
            for sb in matched_sys:
                sub_name = sb["model"] or name
                sub_icon = ICON_USB
                for ub in up_bats:
                    if sb["model"] and ub["model"] == sb["model"]:
                        sub_icon = classify_icon_from_upower_type(ub["type"], sub_name)
                        break
                if sub_icon == ICON_USB:
                    sub_icon = classify_usb_icon(vendor, product_id, sub_name, ifaces)
                devices.append(
                    {
                        "bus_id": bname,
                        "sysfs": str(dev_dir),
                        "vendor": vendor,
                        "product_id": product_id,
                        "name": sub_name,
                        "icon": sub_icon,
                        "bat": (sb["pct"], sb["charging"]),
                        "is_storage": False,
                        "is_usb": True,
                        "blk_name": None,
                    }
                )
            continue

        bat: tuple[int, bool] | None = None
        if len(matched_sys) == 1:
            sb = matched_sys[0]
            bat = (sb["pct"], sb["charging"])
            if sb["model"] and ("receiver" in name.lower() or "dongle" in name.lower()):
                name = sb["model"]
        else:
            for ub in up_bats:
                if (serial and ub["serial"] == serial) or (vendor == "05ac" and ub["type"] == 8):
                    bat = (ub["pct"], ub["charging"])
                    break

        icon = classify_usb_icon(vendor, product_id, name, ifaces)
        if len(matched_sys) == 1 and icon == ICON_USB:
            for ub in up_bats:
                if matched_sys[0]["model"] and ub["model"] == matched_sys[0]["model"]:
                    icon = classify_icon_from_upower_type(ub["type"], name)
                    break

        devices.append(
            {
                "bus_id": bname,
                "sysfs": str(dev_dir),
                "vendor": vendor,
                "product_id": product_id,
                "name": name,
                "icon": icon,
                "bat": bat,
                "is_storage": any(c == "08" for c, _, _ in ifaces),
                "is_usb": True,
                "blk_name": None,
            }
        )

    return devices


def get_sd_card_devices(usb_devices: list[dict]) -> list[dict]:
    sys_block = Path("/sys/class/block")
    if not sys_block.is_dir():
        return []

    usb_reals = [os.path.realpath(d["sysfs"]) for d in usb_devices if d.get("is_usb")]
    sd_cards: list[dict] = []

    for blk_dir in sorted(sys_block.iterdir()):
        if (blk_dir / "partition").exists():
            continue

        bname = blk_dir.name
        size_str_raw = read_text(blk_dir / "size")
        size_sectors = int(size_str_raw) if size_str_raw.isdigit() else 0
        if size_sectors <= 0:
            continue

        size_human = format_size(size_sectors * 512)

        if bname.startswith("mmcblk"):
            mmc_type = read_text(blk_dir / "device" / "type").upper()
            if mmc_type not in ("SD", "SDCOMBO"):
                continue
            sd_cards.append(
                {
                    "bus_id": bname,
                    "sysfs": str(blk_dir),
                    "vendor": "mmc",
                    "product_id": mmc_type.lower(),
                    "name": f"SD Card ({size_human})",
                    "icon": ICON_SD,
                    "bat": None,
                    "is_storage": True,
                    "is_usb": False,
                    "blk_name": bname,
                }
            )
        elif bname.startswith("sd") and read_text(blk_dir / "removable") == "1":
            dev_real = os.path.realpath(blk_dir / "device") if (blk_dir / "device").exists() else ""
            if "/usb" not in dev_real:
                continue
            if any(dev_real.startswith(ur + "/") for ur in usb_reals):
                continue

            model = read_text(blk_dir / "device" / "model")
            if not model or any(k in model.lower() for k in ("sd", "mmc", "card", "reader")):
                label = f"SD Card ({size_human})"
            else:
                label = f"{model} ({size_human})"

            sd_cards.append(
                {
                    "bus_id": bname,
                    "sysfs": str(blk_dir),
                    "vendor": "cardreader",
                    "product_id": bname,
                    "name": label,
                    "icon": ICON_SD,
                    "bat": None,
                    "is_storage": True,
                    "is_usb": True,
                    "blk_name": bname,
                }
            )

    return sd_cards


def get_storage_partitions(dev: dict) -> list[dict]:
    raw = run_cmd(["lsblk", "-J", "-o", "NAME,PATH,MOUNTPOINT,FSTYPE"])
    if not raw:
        return []

    try:
        block_devs = json.loads(raw).get("blockdevices", [])
    except Exception:
        return []

    target_disks: set[str] = set()
    if dev.get("blk_name"):
        target_disks.add(dev["blk_name"])
    else:
        usb_real = os.path.realpath(dev["sysfs"])
        sys_block = Path("/sys/class/block")
        if sys_block.is_dir():
            for blk_entry in sys_block.iterdir():
                if (blk_entry / "partition").exists():
                    continue
                if os.path.realpath(blk_entry).startswith(usb_real + "/"):
                    target_disks.add(blk_entry.name)

    parts: list[dict] = []
    for blk in block_devs:
        if blk.get("name") not in target_disks:
            continue
        children = blk.get("children") or []
        if children:
            for ch in children:
                if ch.get("path"):
                    parts.append(
                        {
                            "path": ch["path"],
                            "mountpoint": ch.get("mountpoint") or "",
                            "fstype": ch.get("fstype") or "",
                        }
                    )
        elif blk.get("path") and (blk.get("mountpoint") or blk.get("fstype")):
            parts.append(
                {
                    "path": blk["path"],
                    "mountpoint": blk.get("mountpoint") or "",
                    "fstype": blk.get("fstype") or "",
                }
            )
    return parts


def set_bluetooth_power(turn_on: bool) -> tuple[bool, str]:
    if turn_on:
        rfk = subprocess.run(
            ["rfkill", "unblock", "bluetooth"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
        res = subprocess.run(
            ["bluetoothctl", "power", "on"],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
        if res.returncode != 0:
            err = (res.stderr or res.stdout or "").strip()
            if "Blocked" in err or rfk.returncode != 0:
                return False, "Blocked by rfkill. Run 'nrs' to apply rfkill permissions."
            return False, err or "Failed to power on Bluetooth."
        return True, "Powered On"

    res = subprocess.run(
        ["bluetoothctl", "power", "off"],
        capture_output=True,
        text=True,
        timeout=3,
        check=False,
    )
    if res.returncode != 0:
        return False, (res.stderr or res.stdout or "Failed to power off Bluetooth.").strip()
    return True, "Powered Off"


def is_power_saver() -> bool:
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    mode = read_text(Path(runtime_dir) / "power-mode" / "effective_mode")
    if mode:
        return mode == "power-saver"
    epp = read_text(Path("/sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference"))
    return epp == "power"


def signal_waybar_watch(pid_name: str) -> None:
    runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp")
    pid_file = runtime_dir / "waybar-watches" / f"{pid_name}.pid"
    pid_str = read_text(pid_file)
    if pid_str.isdigit():
        try:
            os.kill(int(pid_str), signal.SIGUSR1)
            return
        except OSError:
            pass
    sig_num = "RTMIN+9" if pid_name == "bt" else "RTMIN+10"
    subprocess.run(["pkill", f"-{sig_num}", "waybar"], capture_output=True, timeout=2, check=False)


def build_bluetooth_payload() -> str:
    sys_bats = get_sysfs_batteries()
    up_bats = get_upower_batteries()
    powered, devices = get_bluetooth_state()
    enrich_bt_batteries(devices, sys_bats, up_bats)

    if not powered:
        return json.dumps(
            {
                "text": ICON_BT_OFF,
                "class": "off",
                "tooltip": "Bluetooth: Off\nClick: Menu • Right-click: Power On",
            }
        )

    if not devices:
        return json.dumps(
            {
                "text": ICON_BT_ON,
                "class": "idle",
                "tooltip": "Bluetooth: On (No devices connected)\nClick: Menu • Right-click: Power Off",
            }
        )

    text = "  ".join(format_device_bar(d["icon"], d["bat"]) for d in devices)
    lines = ["Bluetooth: Connected"]
    for d in devices:
        lines.append(f"{d['icon']} {html.escape(d['name'], quote=False)}{format_bat_tooltip(d['bat'])}")
    lines.append("Click: Menu • Right-click: Power Off")

    return json.dumps(
        {
            "text": text,
            "class": "connected",
            "tooltip": "\n".join(lines),
        }
    )


def build_usb_payload() -> str:
    sys_bats = get_sysfs_batteries()
    up_bats = get_upower_batteries()
    devices = get_usb_devices(sys_bats, up_bats)
    devices.extend(get_sd_card_devices(devices))

    if not devices:
        return json.dumps(
            {
                "text": "",
                "class": "empty",
                "tooltip": "No external USB or SD devices connected",
            }
        )

    text = "  ".join(format_device_bar(d["icon"], d["bat"]) for d in devices)
    lines = [f"External Devices ({len(devices)})"]
    for d in devices:
        lines.append(f"{d['icon']} {html.escape(d['name'], quote=False)}{format_bat_tooltip(d['bat'])}")
    lines.append("Click: Inspect / Open / Eject")

    return json.dumps(
        {
            "text": text,
            "class": "connected",
            "tooltip": "\n".join(lines),
        }
    )


def output_bluetooth() -> None:
    print(build_bluetooth_payload())


def output_usb() -> None:
    print(build_usb_payload())


def watch_loop(builder, pid_name: str, normal_interval: float, saver_interval: float = 60.0) -> None:
    runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp")
    watch_dir = runtime_dir / "waybar-watches"
    watch_dir.mkdir(parents=True, exist_ok=True)
    pid_file = watch_dir / f"{pid_name}.pid"
    pid_file.write_text(str(os.getpid()), encoding="utf-8")

    r_fd, w_fd = os.pipe()
    os.set_blocking(r_fd, False)
    os.set_blocking(w_fd, False)
    signal.set_wakeup_fd(w_fd, warn_on_full_buffer=False)
    signal.signal(signal.SIGUSR1, lambda _sig, _frame: None)

    running = True

    def stop_handler(_sig, _frame) -> None:
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, stop_handler)
    signal.signal(signal.SIGINT, stop_handler)

    last_payload: str | None = None
    try:
        while running:
            payload = builder()
            if payload != last_payload:
                print(payload, flush=True)
                last_payload = payload

            interval = saver_interval if is_power_saver() else normal_interval
            try:
                rlist, _, _ = select.select([r_fd], [], [], interval)
            except InterruptedError:
                rlist = []
            if rlist:
                try:
                    os.read(r_fd, 4096)
                except BlockingIOError:
                    pass
    finally:
        signal.set_wakeup_fd(-1)
        for fd in (r_fd, w_fd):
            try:
                os.close(fd)
            except OSError:
                pass
        try:
            if pid_file.exists() and pid_file.read_text(encoding="utf-8").strip() == str(os.getpid()):
                pid_file.unlink()
        except OSError:
            pass


def toggle_bluetooth() -> None:
    powered, _ = get_bluetooth_state()
    ok, msg = set_bluetooth_power(not powered)
    subprocess.run(
        [
            "notify-send",
            "-u",
            "normal" if ok else "critical",
            "-i",
            "bluetooth",
            "Bluetooth",
            msg,
        ],
        capture_output=True,
        timeout=2,
        check=False,
    )
    signal_waybar_watch("bt")


def bt_menu() -> None:
    sys_bats = get_sysfs_batteries()
    up_bats = get_upower_batteries()
    powered, devices = get_bluetooth_state(include_paired=True)
    enrich_bt_batteries(devices, sys_bats, up_bats)

    entries: list[tuple[str, str, dict | None]] = []
    if not powered:
        entries.append((f"{ICON_BT_ON}  Turn Bluetooth On", "power_on", None))
        entries.append(("󰂰  Open Bluetooth Manager (bluetui)", "tui", None))
    else:
        connected = [d for d in devices if d["connected"]]
        paired = [d for d in devices if not d["connected"]]
        for d in connected:
            bat_str = format_bat_tooltip(d["bat"])
            entries.append((f"{d['icon']}  {d['name']} (Connected{bat_str}) — Disconnect", "disconnect", d))
        for d in paired:
            entries.append((f"{d['icon']}  {d['name']} — Connect", "connect", d))
        entries.append(("󰂰  Pair / Manage Devices (bluetui)", "tui", None))
        entries.append((f"{ICON_BT_OFF}  Turn Bluetooth Off", "power_off", None))

    menu_input = "\n".join(label for label, _, _ in entries)
    choice = subprocess.run(
        ["vicinae", "dmenu", "--placeholder", f"Bluetooth: {'On' if powered else 'Off'}"],
        input=menu_input,
        capture_output=True,
        text=True,
        check=False,
    ).stdout.strip()
    if not choice:
        return

    for label, action, dev in entries:
        if label != choice:
            continue
        if action == "power_on":
            ok, msg = set_bluetooth_power(True)
            subprocess.run(
                ["notify-send", "-u", "normal" if ok else "critical", "-i", "bluetooth", "Bluetooth", msg],
                check=False,
            )
        elif action == "power_off":
            ok, msg = set_bluetooth_power(False)
            subprocess.run(
                ["notify-send", "-u", "normal" if ok else "critical", "-i", "bluetooth", "Bluetooth", msg],
                check=False,
            )
        elif action == "connect" and dev:
            res = subprocess.run(
                ["bluetoothctl", "connect", dev["raw_mac"]],
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
            )
            ok = res.returncode == 0
            subprocess.run(
                [
                    "notify-send",
                    "-u",
                    "normal" if ok else "critical",
                    "-i",
                    "bluetooth",
                    dev["name"],
                    "Connected" if ok else (res.stderr.strip() or res.stdout.strip() or "Connection failed"),
                ],
                check=False,
            )
        elif action == "disconnect" and dev:
            subprocess.run(
                ["bluetoothctl", "disconnect", dev["raw_mac"]],
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )
            subprocess.run(["notify-send", "-i", "bluetooth", dev["name"], "Disconnected"], check=False)
        elif action == "tui":
            subprocess.run(["alacritty", "-e", "bluetui"], check=False)
        break

    signal_waybar_watch("bt")


def usb_menu() -> None:
    sys_bats = get_sysfs_batteries()
    up_bats = get_upower_batteries()
    devices = get_usb_devices(sys_bats, up_bats)
    devices.extend(get_sd_card_devices(devices))

    if not devices:
        subprocess.run(
            ["notify-send", "-i", "drive-removable-media-usb", "External Devices", "No external USB or SD devices connected"],
            check=False,
        )
        return

    entries: list[tuple[str, dict, list[dict]]] = []
    for d in devices:
        parts = get_storage_partitions(d) if d["is_storage"] else []
        mounted_mps = [p["mountpoint"] for p in parts if p["mountpoint"]]
        bat_str = format_bat_tooltip(d["bat"])
        mount_str = f" [{', '.join(mounted_mps)}]" if mounted_mps else ""
        label = f"{d['icon']}  {d['name']}{bat_str}{mount_str}"
        entries.append((label, d, parts))

    menu_input = "\n".join(label for label, _, _ in entries)
    choice = subprocess.run(
        ["vicinae", "dmenu", "--placeholder", "Connected USB & SD Devices"],
        input=menu_input,
        capture_output=True,
        text=True,
        check=False,
    ).stdout.strip()
    if not choice:
        return

    for label, d, parts in entries:
        if label != choice:
            continue

        mounted = [p for p in parts if p["mountpoint"]]
        mountable = [p for p in parts if not p["mountpoint"] and p["fstype"]]

        if mounted:
            dev_node = mounted[0]["path"]
            mp = mounted[0]["mountpoint"]
            action = subprocess.run(
                ["vicinae", "dmenu", "--placeholder", d["name"]],
                input=f"Open in Thunar ({mp})\nSafely Eject ({dev_node})",
                capture_output=True,
                text=True,
                check=False,
            ).stdout.strip()
            if action.startswith("Open in Thunar"):
                subprocess.Popen(["thunar", mp], start_new_session=True)
            elif action.startswith("Safely Eject"):
                failed_err = ""
                for p in mounted:
                    unm = subprocess.run(
                        ["udisksctl", "unmount", "-b", p["path"]],
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    if unm.returncode != 0:
                        failed_err = unm.stderr.strip() or "Device is busy"
                        break
                if not failed_err:
                    if d.get("is_usb"):
                        subprocess.run(["udisksctl", "power-off", "-b", dev_node], capture_output=True, check=False)
                    subprocess.run(
                        ["notify-send", "-i", "drive-removable-media-usb", "Safely Ejected", f"Safe to remove {d['name']}"],
                        check=False,
                    )
                    signal_waybar_watch("usb")
                else:
                    subprocess.run(
                        ["notify-send", "-u", "critical", "Eject Failed", failed_err],
                        check=False,
                    )
        elif mountable:
            dev_node = mountable[0]["path"]
            action = subprocess.run(
                ["vicinae", "dmenu", "--placeholder", d["name"]],
                input=f"Mount & Open in Thunar ({dev_node})",
                capture_output=True,
                text=True,
                check=False,
            ).stdout.strip()
            if action.startswith("Mount"):
                mnt = subprocess.run(
                    ["udisksctl", "mount", "-b", dev_node],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                if mnt.returncode == 0:
                    new_parts = get_storage_partitions(d)
                    new_mp = next((p["mountpoint"] for p in new_parts if p["path"] == dev_node and p["mountpoint"]), "")
                    if new_mp:
                        subprocess.Popen(["thunar", new_mp], start_new_session=True)
                else:
                    subprocess.run(
                        ["notify-send", "-u", "critical", "Mount Failed", mnt.stderr.strip() or "Could not mount device"],
                        check=False,
                    )
        else:
            info = f"ID {d['vendor']}:{d['product_id']}{format_bat_tooltip(d['bat'])}"
            subprocess.run(
                ["notify-send", "-i", "drive-removable-media-usb", d["name"], info],
                check=False,
            )
        break


def main() -> None:
    arg = sys.argv[1] if len(sys.argv) > 1 else "--bluetooth"
    if arg == "--bluetooth":
        output_bluetooth()
    elif arg == "--usb":
        output_usb()
    elif arg == "--watch-bluetooth":
        watch_loop(build_bluetooth_payload, "bt", normal_interval=5.0, saver_interval=60.0)
    elif arg == "--watch-usb":
        watch_loop(build_usb_payload, "usb", normal_interval=3.0, saver_interval=60.0)
    elif arg == "--bt-toggle":
        toggle_bluetooth()
    elif arg == "--bt-menu":
        bt_menu()
    elif arg == "--usb-menu":
        usb_menu()


if __name__ == "__main__":
    main()
