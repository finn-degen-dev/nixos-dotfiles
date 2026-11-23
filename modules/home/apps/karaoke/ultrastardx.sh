CONFIG_DIR="$HOME/.ultrastardx"
CONFIG_FILE="$CONFIG_DIR/config.ini"
PLAYLISTS_DIR="$CONFIG_DIR/playlists"
SONGS_DIR="/run/media/$USER/Karaoke/songs_ultrastar"
mkdir -p "$CONFIG_DIR" "$PLAYLISTS_DIR"

PIDS=()
cleanup() {
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

start_virtual_mic() {
  local cap_name="$1"
  local src_name="$2"
  local desc="$3"
  pw-loopback -c 1 -m '[ MONO ]' -l 10 \
    -i "node.name=$cap_name node.autoconnect=false" \
    -o "node.name=$src_name media.class=Audio/Source node.description=\"$desc\"" \
    >/dev/null 2>&1 &
  PIDS+=($!)
}

start_virtual_mic "singstar_blue_cap" "SingStar_Blue"  "SingStar Blue (Mic 1)"
start_virtual_mic "singstar_red_cap"  "SingStar_Red"   "SingStar Red (Mic 2)"
start_virtual_mic "dji_1_cap"         "DJI_Mic_1"      "DJI Mic 1"
start_virtual_mic "dji_2_cap"         "DJI_Mic_2"      "DJI Mic 2"
start_virtual_mic "logitech_1_cap"    "Logitech_Mic_1" "Logitech Mic 1"
start_virtual_mic "logitech_2_cap"    "Logitech_Mic_2" "Logitech Mic 2"

for _ in $(seq 1 30); do
  PORTS_IN=$(pw-link -i 2>/dev/null || true)
  if echo "$PORTS_IN" | grep -q "^singstar_blue_cap:input_MONO$" \
    && echo "$PORTS_IN" | grep -q "^singstar_red_cap:input_MONO$" \
    && echo "$PORTS_IN" | grep -q "^dji_1_cap:input_MONO$" \
    && echo "$PORTS_IN" | grep -q "^dji_2_cap:input_MONO$" \
    && echo "$PORTS_IN" | grep -q "^logitech_1_cap:input_MONO$" \
    && echo "$PORTS_IN" | grep -q "^logitech_2_cap:input_MONO$"; then
    break
  fi
  sleep 0.1
done

link_mics() {
  local links ports_out singstar_fl singstar_fr dji_fl dji_fr logi_ports src used1 used2
  links=$(pw-link -l 2>/dev/null || true)
  ports_out=$(pw-link -o 2>/dev/null || true)

  singstar_fl=$(echo "$ports_out" | grep -iE 'singstar|usbmic' | grep ':capture_FL$' | head -n 1 || true)
  singstar_fr=$(echo "$ports_out" | grep -iE 'singstar|usbmic' | grep ':capture_FR$' | head -n 1 || true)

  if [ -n "$singstar_fl" ] && ! echo "$links" | awk '/^singstar_blue_cap:input_MONO$/{f=1;next} f && /^[^[:space:]]/{f=0} f && /\|<-/{hit=1} END{exit !hit}'; then
    pw-link "$singstar_fl" "singstar_blue_cap:input_MONO" 2>/dev/null || true
  fi
  if [ -n "$singstar_fr" ] && ! echo "$links" | awk '/^singstar_red_cap:input_MONO$/{f=1;next} f && /^[^[:space:]]/{f=0} f && /\|<-/{hit=1} END{exit !hit}'; then
    pw-link "$singstar_fr" "singstar_red_cap:input_MONO" 2>/dev/null || true
  fi

  dji_fl=$(echo "$ports_out" | grep '^alsa_input\.usb-DJI_.*:capture_FL$' | head -n 1 || true)
  dji_fr=$(echo "$ports_out" | grep '^alsa_input\.usb-DJI_.*:capture_FR$' | head -n 1 || true)

  if [ -n "$dji_fl" ] && ! echo "$links" | awk '/^dji_1_cap:input_MONO$/{f=1;next} f && /^[^[:space:]]/{f=0} f && /\|<-/{hit=1} END{exit !hit}'; then
    pw-link "$dji_fl" "dji_1_cap:input_MONO" 2>/dev/null || true
  fi
  if [ -n "$dji_fr" ] && ! echo "$links" | awk '/^dji_2_cap:input_MONO$/{f=1;next} f && /^[^[:space:]]/{f=0} f && /\|<-/{hit=1} END{exit !hit}'; then
    pw-link "$dji_fr" "dji_2_cap:input_MONO" 2>/dev/null || true
  fi

  logi_ports=$(echo "$ports_out" | grep '^alsa_input\.usb-Logitech.*:capture_' || true)
  if [ -n "$logi_ports" ]; then
    used1=$(echo "$links" | awk '/^logitech_1_cap:input_MONO$/{f=1;next} f && /^[^[:space:]]/{f=0} f && /\|<-/{hit=1} END{exit !hit}' && echo 1 || echo 0)
    used2=$(echo "$links" | awk '/^logitech_2_cap:input_MONO$/{f=1;next} f && /^[^[:space:]]/{f=0} f && /\|<-/{hit=1} END{exit !hit}' && echo 1 || echo 0)

    while IFS= read -r src; do
      [ -z "$src" ] && continue
      if echo "$links" | awk -v p="$src" '$0==p{f=1;next} f && /^[^[:space:]]/{f=0} f && /\|->.*(logitech_1_cap|logitech_2_cap):input_MONO/{hit=1} END{exit !hit}'; then
        continue
      fi
      if [ "$used1" -eq 0 ]; then
        pw-link "$src" "logitech_1_cap:input_MONO" 2>/dev/null && used1=1 || true
      elif [ "$used2" -eq 0 ]; then
        pw-link "$src" "logitech_2_cap:input_MONO" 2>/dev/null && used2=1 || true
      fi
    done <<< "$logi_ports"
  fi
}

link_mics
(
  set +e
  while true; do
    sleep 0.5
    link_mics
  done
) &
PIDS+=($!)

if [ -d "$SONGS_DIR" ]; then
  find "$SONGS_DIR" -maxdepth 1 -type f -name "*.upl" 2>/dev/null | while read -r upl; do
    ln -sfn "$upl" "$PLAYLISTS_DIR/$(basename "$upl")"
  done
fi

if [ ! -f "$CONFIG_FILE" ]; then
  cat << EOF > "$CONFIG_FILE"
Theme=Modern
Skin=Blue
Color=Blue

[Directories]
SongDir1=$SONGS_DIR
EOF
else
  if ! grep -q "songs_ultrastar" "$CONFIG_FILE"; then
    if grep -q "\[Directories\]" "$CONFIG_FILE"; then
      sed -i "/\[Directories\]/a SongDir1=$SONGS_DIR" "$CONFIG_FILE"
    else
      printf "\n[Directories]\nSongDir1=%s\n" "$SONGS_DIR" >> "$CONFIG_FILE"
    fi
  fi

  sed -i 's/^Theme=Deluxe/Theme=Modern/' "$CONFIG_FILE" 2>/dev/null || true
fi

if [ -x /run/current-system/sw/bin/nvidia-offload ]; then
  /run/current-system/sw/bin/nvidia-offload "$ULTRASTARDX_BIN" "$@"
else
  "$ULTRASTARDX_BIN" "$@"
fi
