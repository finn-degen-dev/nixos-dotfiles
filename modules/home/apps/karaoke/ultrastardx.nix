{ pkgs, ... }:

let
  ultrastar-deluxe-wrapper = pkgs.writeShellApplication {
    name = "ultrastardx";
    runtimeInputs = [
      pkgs.pipewire
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.findutils
      pkgs.coreutils
    ];
    runtimeEnv = {
      ULTRASTARDX_BIN = "${pkgs.ultrastardx}/bin/ultrastardx";
    };
    text = builtins.readFile ./ultrastardx.sh;
  };

  ultrastar-alias = pkgs.writeShellScriptBin "ultrastar" ''
    exec ${ultrastar-deluxe-wrapper}/bin/ultrastardx "$@"
  '';

  ultrastar-create-playlist = pkgs.writeShellApplication {
    name = "ultrastar-create-playlist";
    runtimeInputs = [ pkgs.gnused pkgs.findutils pkgs.coreutils ];
    text = ''
      if [ -z "''${1:-}" ]; then
        echo "Usage: ultrastar-create-playlist <song_directory>"
        echo "Example: ultrastar-create-playlist /run/media/$USER/Karaoke/songs_ultrastar"
        exit 1
      fi

      TARGET_DIR="$1"
      PLAYLIST_DIR="$HOME/.ultrastardx/playlists"
      mkdir -p "$PLAYLIST_DIR"

      echo "========================================="
      echo "Generating Playlists (.upl) for: $TARGET_DIR"
      echo "========================================="

      find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d "" DIR; do
        PLAYLIST_NAME=$(basename "$DIR")
        PLAYLIST_FILE="$TARGET_DIR/$PLAYLIST_NAME.upl"
        USER_PLAYLIST_FILE="$PLAYLIST_DIR/$PLAYLIST_NAME.upl"
        TEMP_PLAYLIST=$(mktemp)

        find "$DIR" -type f -iname "*.txt" -print0 | while IFS= read -r -d "" TXT; do
          ARTIST=$(sed -n 's/^#ARTIST:\(.*\)/\1/Ip' "$TXT" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || true)
          TITLE=$(sed -n 's/^#TITLE:\(.*\)/\1/Ip' "$TXT" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || true)

          if [ -n "$ARTIST" ] && [ -n "$TITLE" ]; then
            echo "$ARTIST : $TITLE" >> "$TEMP_PLAYLIST"
          fi
        done

        if [ -s "$TEMP_PLAYLIST" ]; then
          echo "#Name: $PLAYLIST_NAME" > "$PLAYLIST_FILE"
          cat "$TEMP_PLAYLIST" >> "$PLAYLIST_FILE"
          cp -f "$PLAYLIST_FILE" "$USER_PLAYLIST_FILE"
          echo "  -> Created '$PLAYLIST_NAME.upl' ($(wc -l < "$TEMP_PLAYLIST") songs)."
        fi

        rm -f "$TEMP_PLAYLIST"
      done

      echo "========================================="
      echo "Done! Playlists created and synced to UltraStar."
      echo "========================================="
    '';
  };
in
{
  home.packages = [
    ultrastar-deluxe-wrapper
    ultrastar-alias
    ultrastar-create-playlist
  ];

  home.file.".asoundrc".text = ''
    pcm.singstar_blue {
      type pipewire
      capture_node "SingStar_Blue"
      hint {
        show on
        description "SingStar Blue (Mic 1)"
      }
    }

    pcm.singstar_red {
      type pipewire
      capture_node "SingStar_Red"
      hint {
        show on
        description "SingStar Red (Mic 2)"
      }
    }

    pcm.dji_mic_1 {
      type pipewire
      capture_node "DJI_Mic_1"
      hint {
        show on
        description "DJI Mic 1 (Left)"
      }
    }

    pcm.dji_mic_2 {
      type pipewire
      capture_node "DJI_Mic_2"
      hint {
        show on
        description "DJI Mic 2 (Right)"
      }
    }

    pcm.logitech_mic_1 {
      type pipewire
      capture_node "Logitech_Mic_1"
      hint {
        show on
        description "Logitech Mic 1 (Persistent)"
      }
    }

    pcm.logitech_mic_2 {
      type pipewire
      capture_node "Logitech_Mic_2"
      hint {
        show on
        description "Logitech Mic 2 (Persistent)"
      }
    }
  '';

  xdg.desktopEntries.ultrastardx = {
    name = "UltraStar Deluxe";
    genericName = "Karaoke Game";
    comment = "Free and open source singing game (Native Linux Build with FFmpeg & PipeWire)";
    exec = "ultrastardx";
    icon = "ultrastardx";
    terminal = false;
    categories = [ "Game" "AudioVideo" "Audio" ];
    settings = {
      StartupWMClass = "ultrastardx";
    };
  };
}
