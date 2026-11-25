#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Power Mode
# @raycast.mode silent

# Optional parameters:
# @raycast.packageName System
# @raycast.icon 󰌪

# Documentation:
# @raycast.description Switch between Power Saver, Balanced, Performance, and Wall-Plugged modes
# @raycast.author BoredVoidAter

export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$PATH"

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/power-mode"
WATCH_DIR="${XDG_RUNTIME_DIR:-/tmp}/waybar-watches"
NO_TURBO_FILE="/sys/devices/system/cpu/intel_pstate/no_turbo"
mkdir -p "$STATE_DIR"

get_profile() {
  if command -v powerprofilesctl >/dev/null 2>&1; then
    powerprofilesctl get 2>/dev/null || echo "balanced"
  else
    echo "balanced"
  fi
}

get_effective_mode() {
  if [ -f "$STATE_DIR/mode" ] && [ "$(cat "$STATE_DIR/mode" 2>/dev/null)" = "wall-plugged" ]; then
    echo "wall-plugged"
  else
    get_profile
  fi
}

is_ac_online() {
  local ps_dir ps_type online
  for ps_dir in /sys/class/power_supply/*; do
    [ -d "$ps_dir" ] || continue
    [ -r "$ps_dir/online" ] || continue
    ps_type=$(cat "$ps_dir/type" 2>/dev/null || true)
    if [ "$ps_type" = "Mains" ] || [ -z "$ps_type" ]; then
      online=$(cat "$ps_dir/online" 2>/dev/null || echo 0)
      if [ "$online" = "1" ]; then
        return 0
      fi
    fi
  done
  return 1
}

get_bat_info() {
  local bat_dir cap status
  for bat_dir in /sys/class/power_supply/BAT*; do
    [ -d "$bat_dir" ] || continue
    cap=$(cat "$bat_dir/capacity" 2>/dev/null || true)
    status=$(cat "$bat_dir/status" 2>/dev/null || true)
    printf '%s|%s\n' "$cap" "$status"
    return 0
  done
  printf '|\n'
}

get_kbd_backlight_dev() {
  command -v brightnessctl >/dev/null 2>&1 || return 0
  brightnessctl -l -c leds 2>/dev/null | awk -F"'" '/kbd_backlight/{print $2; exit}'
}

signal_pid_file() {
  local pid_file="$1"
  local pid
  [ -r "$pid_file" ] || return 0
  pid=$(cat "$pid_file" 2>/dev/null || true)
  if [ -n "$pid" ] && [ "$pid" != "$$" ]; then
    kill -USR1 "$pid" 2>/dev/null || true
  fi
}

notify_watchers() {
  signal_pid_file "$WATCH_DIR/power.pid"
  signal_pid_file "$WATCH_DIR/bt.pid"
  signal_pid_file "$WATCH_DIR/usb.pid"
  pkill -RTMIN+8 waybar 2>/dev/null || true
}

enter_power_saver_extras() {
  local prev_mode="$1"
  local cur_bright kbd_dev cur_kbd cur_turbo

  if [ "$prev_mode" != "power-saver" ] && command -v brightnessctl >/dev/null 2>&1; then
    cur_bright=$(brightnessctl -m 2>/dev/null | awk -F, '{print $4}' | tr -d '%')
    if [ -n "$cur_bright" ] && [ "$cur_bright" -gt 35 ]; then
      echo "$cur_bright" > "$STATE_DIR/prev_brightness"
      brightnessctl -q set 35% 2>/dev/null || true
    fi
  fi

  if [ "$prev_mode" != "power-saver" ]; then
    kbd_dev=$(get_kbd_backlight_dev)
    if [ -n "$kbd_dev" ]; then
      cur_kbd=$(brightnessctl -d "$kbd_dev" g 2>/dev/null || true)
      if [ -n "$cur_kbd" ] && [ "$cur_kbd" -gt 0 ] 2>/dev/null; then
        echo "$cur_kbd" > "$STATE_DIR/prev_kbd_brightness"
        brightnessctl -q -d "$kbd_dev" set 0 2>/dev/null || true
      fi
    fi

    if [ -w "$NO_TURBO_FILE" ]; then
      cur_turbo=$(cat "$NO_TURBO_FILE" 2>/dev/null || echo 0)
      echo "$cur_turbo" > "$STATE_DIR/prev_no_turbo"
      printf "1" > "$NO_TURBO_FILE" 2>/dev/null || true
    fi

    if command -v bluetoothctl >/dev/null 2>&1; then
      if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        if [ -z "$(bluetoothctl devices Connected 2>/dev/null)" ]; then
          echo "1" > "$STATE_DIR/prev_bt_powered"
          bluetoothctl power off >/dev/null 2>&1 || true
        fi
      fi
    fi
  fi
}

leave_power_saver_extras() {
  local prev_mode="$1"
  local prev_bright kbd_dev prev_kbd prev_turbo

  if [ "$prev_mode" = "power-saver" ] && [ -f "$STATE_DIR/prev_brightness" ] && command -v brightnessctl >/dev/null 2>&1; then
    prev_bright=$(cat "$STATE_DIR/prev_brightness")
    rm -f "$STATE_DIR/prev_brightness"
    if [ -n "$prev_bright" ]; then
      brightnessctl -q set "${prev_bright}%" 2>/dev/null || true
    fi
  fi

  if [ -f "$STATE_DIR/prev_kbd_brightness" ]; then
    prev_kbd=$(cat "$STATE_DIR/prev_kbd_brightness" 2>/dev/null || true)
    rm -f "$STATE_DIR/prev_kbd_brightness"
    kbd_dev=$(get_kbd_backlight_dev)
    if [ -n "$kbd_dev" ] && [ -n "$prev_kbd" ]; then
      brightnessctl -q -d "$kbd_dev" set "$prev_kbd" 2>/dev/null || true
    fi
  fi

  if [ -w "$NO_TURBO_FILE" ]; then
    if [ -f "$STATE_DIR/prev_no_turbo" ]; then
      prev_turbo=$(cat "$STATE_DIR/prev_no_turbo" 2>/dev/null || echo 0)
      rm -f "$STATE_DIR/prev_no_turbo"
      printf "%s" "$prev_turbo" > "$NO_TURBO_FILE" 2>/dev/null || true
    elif [ "$prev_mode" = "power-saver" ]; then
      printf "0" > "$NO_TURBO_FILE" 2>/dev/null || true
    fi
  fi

  if [ -f "$STATE_DIR/prev_bt_powered" ]; then
    rm -f "$STATE_DIR/prev_bt_powered"
    if command -v rfkill >/dev/null 2>&1; then
      rfkill unblock bluetooth >/dev/null 2>&1 || true
    fi
    if command -v bluetoothctl >/dev/null 2>&1; then
      bluetoothctl power on >/dev/null 2>&1 || true
    fi
  fi
}

set_charge_bypass() {
  local enable="$1"
  local bat_dir behav start_f end_f cons_f cap target_end cur_start cur_end

  if [ "$enable" = "1" ]; then
    for bat_dir in /sys/class/power_supply/BAT*; do
      [ -d "$bat_dir" ] || continue
      behav="$bat_dir/charge_behaviour"
      if [ -w "$behav" ] && grep -q "inhibit-charge" "$behav" 2>/dev/null; then
        printf "inhibit-charge" > "$behav" 2>/dev/null || true
      fi

      start_f="$bat_dir/charge_control_start_threshold"
      end_f="$bat_dir/charge_control_end_threshold"
      if [ -w "$end_f" ]; then
        cur_end=$(cat "$end_f" 2>/dev/null || echo 100)
        [ -f "$STATE_DIR/prev_end_threshold" ] || echo "$cur_end" > "$STATE_DIR/prev_end_threshold"

        cap=$(cat "$bat_dir/capacity" 2>/dev/null || echo 80)
        if [ "$cap" -ge 80 ] 2>/dev/null; then
          target_end=80
        elif [ "$cap" -ge 60 ] 2>/dev/null; then
          target_end="$cap"
        else
          target_end=60
        fi

        if [ -w "$start_f" ]; then
          cur_start=$(cat "$start_f" 2>/dev/null || echo 0)
          [ -f "$STATE_DIR/prev_start_threshold" ] || echo "$cur_start" > "$STATE_DIR/prev_start_threshold"
          if [ "$cur_start" -ge "$target_end" ] 2>/dev/null; then
            printf "%s" "$((target_end - 5))" > "$start_f" 2>/dev/null || true
          fi
        fi
        printf "%s" "$target_end" > "$end_f" 2>/dev/null || true
      fi
    done

    for cons_f in /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode; do
      [ -w "$cons_f" ] || continue
      printf "1" > "$cons_f" 2>/dev/null || true
    done
  else
    for bat_dir in /sys/class/power_supply/BAT*; do
      [ -d "$bat_dir" ] || continue
      behav="$bat_dir/charge_behaviour"
      if [ -w "$behav" ] && grep -q "auto" "$behav" 2>/dev/null; then
        printf "auto" > "$behav" 2>/dev/null || true
      fi

      start_f="$bat_dir/charge_control_start_threshold"
      end_f="$bat_dir/charge_control_end_threshold"
      if [ -w "$end_f" ]; then
        cur_end=100
        if [ -f "$STATE_DIR/prev_end_threshold" ]; then
          cur_end=$(cat "$STATE_DIR/prev_end_threshold" 2>/dev/null || echo 100)
          rm -f "$STATE_DIR/prev_end_threshold"
        fi
        printf "%s" "$cur_end" > "$end_f" 2>/dev/null || true
      fi
      if [ -w "$start_f" ] && [ -f "$STATE_DIR/prev_start_threshold" ]; then
        cur_start=$(cat "$STATE_DIR/prev_start_threshold" 2>/dev/null || echo 0)
        rm -f "$STATE_DIR/prev_start_threshold"
        printf "%s" "$cur_start" > "$start_f" 2>/dev/null || true
      fi
    done

    for cons_f in /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode; do
      [ -w "$cons_f" ] || continue
      printf "0" > "$cons_f" 2>/dev/null || true
    done
  fi
}

set_internal_refresh() {
  local target_hz="$1"
  command -v hyprctl >/dev/null 2>&1 || return 0
  command -v jq >/dev/null 2>&1 || return 0

  local mon_json
  mon_json=$(hyprctl monitors -j 2>/dev/null | jq -c '.[] | select(.name | test("^(eDP|LVDS|DSI)"))' | head -n 1)
  [ -z "$mon_json" ] && return 0

  local name mirror_of width height pos_x pos_y scale
  name=$(echo "$mon_json" | jq -r '.name')
  mirror_of=$(echo "$mon_json" | jq -r '.mirrorOf // "none"')
  [ "$mirror_of" != "none" ] && return 0

  width=$(echo "$mon_json" | jq -r '.width')
  height=$(echo "$mon_json" | jq -r '.height')
  pos_x=$(echo "$mon_json" | jq -r '.x')
  pos_y=$(echo "$mon_json" | jq -r '.y')
  scale=$(echo "$mon_json" | jq -r '.scale')

  if [ "$target_hz" = "60" ]; then
    local has_60
    has_60=$(echo "$mon_json" | jq -r --arg res "${width}x${height}@60" '[.availableModes[] | select(startswith($res))] | length')
    if [ "${has_60:-0}" -gt 0 ]; then
      hyprctl eval "hl.monitor({ output = '${name}', mode = '${width}x${height}@60', position = '${pos_x}x${pos_y}', scale = ${scale} })" >/dev/null 2>&1
    fi
  else
    hyprctl eval "hl.monitor({ output = '${name}', mode = 'preferred', position = '${pos_x}x${pos_y}', scale = ${scale} })" >/dev/null 2>&1
  fi
}

apply_mode() {
  local target="$1"
  local current
  current=$(get_effective_mode)

  if [ "$target" = "wall-plugged" ]; then
    rm -f "$STATE_DIR/manual_override"
    echo "wall-plugged" > "$STATE_DIR/mode"
    echo "wall-plugged" > "$STATE_DIR/effective_mode"
    if command -v powerprofilesctl >/dev/null 2>&1; then
      powerprofilesctl set balanced 2>/dev/null || true
    fi
    set_charge_bypass 1
    if command -v hyprctl >/dev/null 2>&1; then
      hyprctl eval 'hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true } }, animations = { enabled = true } })' >/dev/null 2>&1
    fi
    set_internal_refresh "preferred"
    leave_power_saver_extras "$current"

    notify-send -i ac-adapter "Power Mode" "Wall-Plugged active (AC power, battery charging paused where supported)"
    notify_watchers
    return 0
  fi

  rm -f "$STATE_DIR/mode"
  echo "$target" > "$STATE_DIR/effective_mode"
  if is_ac_online; then
    local bat_info cap
    bat_info=$(get_bat_info)
    cap="${bat_info%%|*}"
    if [ -n "$cap" ] && [ "$cap" -ge 100 ] 2>/dev/null; then
      touch "$STATE_DIR/manual_override"
    fi
  fi

  set_charge_bypass 0

  if command -v powerprofilesctl >/dev/null 2>&1; then
    powerprofilesctl set "$target" 2>/dev/null || true
  fi

  case "$target" in
    power-saver)
      if command -v hyprctl >/dev/null 2>&1; then
        hyprctl eval 'hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } }, animations = { enabled = false } })' >/dev/null 2>&1
      fi
      set_internal_refresh "60"
      enter_power_saver_extras "$current"

      notify-send -i battery-low "Power Saving Mode" "Enabled (power-saver, 60Hz, effects off, no turbo)"
      ;;

    balanced|performance)
      if command -v hyprctl >/dev/null 2>&1; then
        hyprctl eval 'hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true } }, animations = { enabled = true } })' >/dev/null 2>&1
      fi
      set_internal_refresh "preferred"
      leave_power_saver_extras "$current"

      if [ "$target" = "performance" ]; then
        notify-send -i battery-full-charged "Power Mode" "Performance enabled"
      else
        notify-send -i battery-good "Power Mode" "Balanced mode restored"
      fi
      ;;
  esac

  notify_watchers
}

check_auto_wall_plugged() {
  local current bat_info cap status prev
  current=$(get_effective_mode)
  bat_info=$(get_bat_info)
  cap="${bat_info%%|*}"
  status="${bat_info#*|}"

  if is_ac_online; then
    if [ -n "$cap" ] && [ "$cap" -lt 100 ] 2>/dev/null; then
      rm -f "$STATE_DIR/manual_override"
    fi

    if [ "$current" != "wall-plugged" ] && [ ! -f "$STATE_DIR/manual_override" ] && [ -n "$cap" ] && [ "$cap" -ge 100 ] 2>/dev/null; then
      if [ "$status" = "Full" ] || [ "$status" = "Charging" ] || [ "$status" = "Not charging" ]; then
        echo "$current" > "$STATE_DIR/prev_mode"
        apply_mode "wall-plugged"
      fi
    fi
  else
    rm -f "$STATE_DIR/manual_override"
    if [ "$current" = "wall-plugged" ]; then
      prev="balanced"
      if [ -f "$STATE_DIR/prev_mode" ]; then
        prev=$(cat "$STATE_DIR/prev_mode" 2>/dev/null || echo "balanced")
        rm -f "$STATE_DIR/prev_mode"
      fi
      [ "$prev" = "wall-plugged" ] && prev="balanced"
      apply_mode "$prev"
    fi
  fi
}

print_status_json() {
  check_auto_wall_plugged
  local mode
  mode=$(get_effective_mode)
  printf '%s\n' "$mode" > "$STATE_DIR/effective_mode"
  case "$mode" in
    wall-plugged)
      printf '{"text":"󰚥","class":"wall-plugged","tooltip":"Power Mode: Wall-Plugged (AC Power / Battery Protected)"}\n'
      ;;
    power-saver)
      printf '{"text":"󰌪","class":"power-saver","tooltip":"Power Mode: Power Saver (Click to toggle)"}\n'
      ;;
    performance)
      printf '{"text":"󱐋","class":"performance","tooltip":"Power Mode: Performance (Click to toggle)"}\n'
      ;;
    *)
      printf '{"text":"󰗑","class":"balanced","tooltip":"Power Mode: Balanced (Click to toggle)"}\n'
      ;;
  esac
}

watch_status() {
  mkdir -p "$WATCH_DIR"
  local pid_file="$WATCH_DIR/power.pid"
  printf '%s\n' "$$" > "$pid_file"

  local wake_pid=""
  trap 'if [ -n "$wake_pid" ]; then kill "$wake_pid" 2>/dev/null || true; fi' USR1
  trap 'if [ -n "$wake_pid" ]; then kill "$wake_pid" 2>/dev/null || true; fi; [ "$(cat "$pid_file" 2>/dev/null || true)" = "$$" ] && rm -f "$pid_file"; exit 0' INT TERM

  local last_json="" cur_json mode delay
  while true; do
    cur_json=$(print_status_json)
    if [ "$cur_json" != "$last_json" ]; then
      printf '%s\n' "$cur_json"
      last_json="$cur_json"
    fi
    mode=$(get_effective_mode)
    if [ "$mode" = "power-saver" ]; then
      delay=60
    else
      delay=5
    fi
    sleep "$delay" &
    wake_pid=$!
    wait "$wake_pid" 2>/dev/null || true
    wake_pid=""
  done
}

case "${1:-}" in
  --status)
    print_status_json
    exit 0
    ;;
  --watch-status)
    watch_status
    exit 0
    ;;
  --toggle)
    if [ "$(get_effective_mode)" = "power-saver" ]; then
      apply_mode "balanced"
    else
      apply_mode "power-saver"
    fi
    exit 0
    ;;
  power-saver|balanced|performance|wall-plugged)
    apply_mode "$1"
    exit 0
    ;;
esac

CURRENT=$(get_effective_mode)
OPT_WALL="󰚥  Wall-Plugged (AC power, pause battery charging)"
OPT_SAVER="󰌪  Power Saver (60Hz, no blur/animations/turbo)"
OPT_BALANCED="󰗑  Balanced (Default)"
OPT_PERF="󱐋  Performance (Max power)"

CHOICE=$(printf "%s\n%s\n%s\n%s\n" \
  "$OPT_WALL" \
  "$OPT_SAVER" \
  "$OPT_BALANCED" \
  "$OPT_PERF" | \
  vicinae dmenu --placeholder "Current Power Mode: $CURRENT")

[ -z "$CHOICE" ] && exit 0

case "$CHOICE" in
  *"Wall-Plugged"*)
    if ! is_ac_online; then
      notify-send -u normal -i dialog-warning "Power Mode" "Connect AC power to enable Wall-Plugged mode"
      exit 0
    fi
    echo "$CURRENT" > "$STATE_DIR/prev_mode"
    apply_mode "wall-plugged"
    ;;
  *"Power Saver"*) apply_mode "power-saver" ;;
  *"Balanced"*) apply_mode "balanced" ;;
  *"Performance"*) apply_mode "performance" ;;
esac
