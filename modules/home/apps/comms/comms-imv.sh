BEFORE_ADDRS=""
if command -v hyprctl >/dev/null 2>&1; then
  BEFORE_ADDRS=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class == "imv" or .class == "imv-wayland" or .initialClass == "imv" or .initialClass == "imv-wayland") | .address' || true)
fi

"$IMV_BIN" "$@" &
IMV_PID=$!

(
  if command -v hyprctl >/dev/null 2>&1; then
    ADDR=""
    for _ in $(seq 1 60); do
      CLIENTS_JSON=$(hyprctl clients -j 2>/dev/null || echo "[]")
      ADDR=$(printf '%s' "$CLIENTS_JSON" | jq -r --argjson pid "$IMV_PID" '.[] | select(.pid == $pid) | .address' | head -n 1)
      if [ -z "$ADDR" ] || [ "$ADDR" = "null" ]; then
        ADDR=$(printf '%s' "$CLIENTS_JSON" | jq -r --arg before "$BEFORE_ADDRS" '
          ($before | split("\n") | map(select(length > 0))) as $seen
          | .[]
          | select(.class == "imv" or .class == "imv-wayland" or .initialClass == "imv" or .initialClass == "imv-wayland")
          | select(.address as $a | ($seen | index($a)) | not)
          | .address
        ' | head -n 1)
      fi
      if [ -n "$ADDR" ] && [ "$ADDR" != "null" ]; then
        break
      fi
      sleep 0.05
    done
    if [ -n "$ADDR" ] && [ "$ADDR" != "null" ]; then
      hyprctl --batch "dispatch setfloating address:$ADDR ; dispatch movetoworkspacesilent special:comms,address:$ADDR" >/dev/null 2>&1
      sleep 0.05
      hyprctl --batch "dispatch focuswindow address:$ADDR ; dispatch resizewindowpixel exact 80% 80%,address:$ADDR ; dispatch centerwindow ; dispatch alterzorder top,address:$ADDR" >/dev/null 2>&1
    fi
  fi
) &

wait "$IMV_PID"
