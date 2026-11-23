import os
import sys

conf_path = sys.argv[1]
label = sys.argv[2]
notify_bin = sys.argv[3]
cmd_val = f">/dev/null 2>&1 {notify_bin} '{label}' '%1: %2'"

os.makedirs(os.path.dirname(conf_path), exist_ok=True)
lines = []
if os.path.exists(conf_path):
    with open(conf_path, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()

out = []
seen_enabled = False
seen_active_current = False
seen_active_noncurrent = False
seen_inactive = False
seen_cmd = False

for line in lines:
    if line.startswith("desktop_notify_active="):
        continue
    elif line.startswith("desktop_notify_enabled="):
        out.append("desktop_notify_enabled=1")
        seen_enabled = True
    elif line.startswith("desktop_notify_active_current="):
        out.append("desktop_notify_active_current=1")
        seen_active_current = True
    elif line.startswith("desktop_notify_active_noncurrent="):
        out.append("desktop_notify_active_noncurrent=1")
        seen_active_noncurrent = True
    elif line.startswith("desktop_notify_inactive="):
        out.append("desktop_notify_inactive=1")
        seen_inactive = True
    elif line.startswith("desktop_notify_command="):
        out.append(f"desktop_notify_command={cmd_val}")
        seen_cmd = True
    else:
        out.append(line)

if not seen_enabled:
    out.append("desktop_notify_enabled=1")
if not seen_active_current:
    out.append("desktop_notify_active_current=1")
if not seen_active_noncurrent:
    out.append("desktop_notify_active_noncurrent=1")
if not seen_inactive:
    out.append("desktop_notify_inactive=1")
if not seen_cmd:
    out.append(f"desktop_notify_command={cmd_val}")

with open(conf_path, "w", encoding="utf-8") as f:
    f.write("\n".join(out) + "\n")
