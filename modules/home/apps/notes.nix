{ pkgs, ... }:

let
  ramble = pkgs.writeShellApplication {
    name = "ramble";
    runtimeInputs = [
      pkgs.ffmpeg
      pkgs.whisper-cpp
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.gnused
      pkgs.coreutils
    ];
    text = ''
      LANG="''${RAMBLE_LANG:-de}"
      MODEL="''${RAMBLE_MODEL:-small}"
      NOTES_DIR="''${RAMBLE_DIR:-$HOME/Notes}"
      MODEL_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/whisper"
      EDIT=1
      TARGET=""

      usage() {
        cat <<'EOF'
      Usage: ramble [options] [slug|path.md]

      Record a voice ramble, transcribe offline with whisper.cpp, copy to clipboard,
      append/save as Markdown, and open in Neovim.

      Options:
        -l, --lang <code|auto>   Whisper language (default: de, or $RAMBLE_LANG)
        -m, --model <name>       GGML model name (default: small, or $RAMBLE_MODEL)
            --no-edit            Do not open the Markdown file in Neovim
        -h, --help               Show this help
      EOF
      }

      while [ "$#" -gt 0 ]; do
        case "$1" in
          -l|--lang)
            LANG="''${2:?Missing language argument}"
            shift 2
            ;;
          -m|--model)
            MODEL="''${2:?Missing model argument}"
            shift 2
            ;;
          --no-edit)
            EDIT=0
            shift
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
          *)
            TARGET="$1"
            shift
            ;;
        esac
      done

      if [ -z "$TARGET" ]; then
        OUT_FILE="$NOTES_DIR/rambles/$(date +%Y-%m-%d_%H-%M-%S).md"
      elif [[ "$TARGET" == */* || "$TARGET" == *.md ]]; then
        OUT_FILE="$TARGET"
      else
        SLUG="$(printf '%s' "$TARGET" | tr ' ' '-' | tr -cd '[:alnum:]_-')"
        OUT_FILE="$NOTES_DIR/rambles/$(date +%Y-%m-%d)_''${SLUG:-ramble}.md"
      fi

      MODEL_PATH="$MODEL_DIR/ggml-''${MODEL}.bin"
      if [ ! -s "$MODEL_PATH" ]; then
        mkdir -p "$MODEL_DIR"
        echo "Downloading Whisper model '$MODEL' to $MODEL_DIR..."
        whisper-cpp-download-ggml-model "$MODEL" "$MODEL_DIR"
      fi

      TMP_DIR="$(mktemp -d)"
      WAV_FILE="$TMP_DIR/ramble.wav"
      OUT_BASE="$TMP_DIR/transcript"
      REC_PID=""

      cleanup() {
        if [ -n "$REC_PID" ] && kill -0 "$REC_PID" 2>/dev/null; then
          kill -INT "$REC_PID" 2>/dev/null || true
          wait "$REC_PID" 2>/dev/null || true
        fi
        rm -rf "$TMP_DIR"
      }
      trap cleanup EXIT

      ffmpeg -y -nostdin -v error \
        -f pulse -i default \
        -ac 1 -ar 16000 \
        -f wav "$WAV_FILE" &
      REC_PID=$!

      sleep 0.2
      if ! kill -0 "$REC_PID" 2>/dev/null; then
        echo "Failed to start microphone recording via PipeWire/PulseAudio." >&2
        exit 1
      fi

      ACTION="save"
      START_TS="$(date +%s)"
      printf "\n"
      while kill -0 "$REC_PID" 2>/dev/null; do
        ELAPSED=$(( $(date +%s) - START_TS ))
        printf "\r  ● Recording (%s)  %02d:%02d   [Enter/Space] Transcribe   [q] Cancel " \
          "$LANG" $(( ELAPSED / 60 )) $(( ELAPSED % 60 ))
        KEY=""
        if IFS= read -rsn1 -t 0.25 KEY; then
          case "$KEY" in
            ""|" ")
              ACTION="save"
              break
              ;;
            q|Q|$'\e')
              ACTION="cancel"
              break
              ;;
          esac
        fi
      done
      printf "\n"

      if kill -0 "$REC_PID" 2>/dev/null; then
        kill -INT "$REC_PID" 2>/dev/null || true
        wait "$REC_PID" 2>/dev/null || true
      fi
      REC_PID=""

      if [ "$ACTION" != "save" ]; then
        echo "Cancelled."
        exit 0
      fi

      if [ ! -s "$WAV_FILE" ]; then
        echo "No audio was captured." >&2
        exit 1
      fi

      echo "Transcribing with ggml-$MODEL ($LANG)..."
      whisper-cli \
        -m "$MODEL_PATH" \
        -l "$LANG" \
        -f "$WAV_FILE" \
        -otxt \
        -of "$OUT_BASE" \
        -nt \
        -np

      TXT_FILE="''${OUT_BASE}.txt"
      if [ ! -s "$TXT_FILE" ]; then
        echo "Transcription produced no text." >&2
        exit 1
      fi

      mkdir -p "$(dirname "$OUT_FILE")"
      HEADER="## Ramble $(date '+%Y-%m-%d %H:%M')"
      if [ -s "$OUT_FILE" ]; then
        printf "\n%s\n\n" "$HEADER" >> "$OUT_FILE"
      else
        printf "# %s\n\n%s\n\n" "$(basename "$OUT_FILE" .md)" "$HEADER" > "$OUT_FILE"
      fi

      sed -e 's/^[[:space:]]*//' -e '/^$/d' "$TXT_FILE" >> "$OUT_FILE"

      if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
        sed -e 's/^[[:space:]]*//' -e '/^$/d' "$TXT_FILE" | wl-copy
      fi

      notify-send -i audio-input-microphone "Ramble saved" "$OUT_FILE (copied to clipboard)" || true
      echo "Saved to $OUT_FILE (and copied transcript to clipboard)."

      rm -rf "$TMP_DIR"
      trap - EXIT

      if [ "$EDIT" -eq 1 ]; then
        exec nvim "$OUT_FILE"
      fi
    '';
  };
in
{
  home.packages = [
    ramble
    pkgs.whisper-cpp
  ];
}
