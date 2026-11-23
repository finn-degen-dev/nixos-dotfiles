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
      hyprctl eval "hl.dispatch(hl.dsp.window.float({ action = 'set', window = 'address:${ADDR}' })) ; hl.dispatch(hl.dsp.window.move({ workspace = 'special:comms', window = 'address:${ADDR}', follow = false }))" >/dev/null 2>&1
      sleep 0.05
      hyprctl eval "hl.dispatch(hl.dsp.focus({ window = 'address:${ADDR}' })) ; local m = hl.get_active_monitor() ; if m then hl.dispatch(hl.dsp.window.resize({ x = math.floor((m.width / m.scale) * 0.8), y = math.floor((m.height / m.scale) * 0.8), relative = false, window = 'address:${ADDR}' })) end ; hl.dispatch(hl.dsp.window.center({ window = 'address:${ADDR}' })) ; hl.dispatch(hl.dsp.window.alter_zorder({ mode = 'top', window = 'address:${ADDR}' }))" >/dev/null 2>&1
    fi
  fi
) &

wait "$IMV_PID"
