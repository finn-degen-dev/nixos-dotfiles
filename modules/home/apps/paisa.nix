{ pkgs, lib, ... }:

let
  paisa-wrapped = pkgs.symlinkJoin {
    name = "paisa-wrapped-${pkgs.paisa.version or "custom"}";
    paths = [ pkgs.paisa ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/paisa
      makeWrapper ${pkgs.paisa}/bin/paisa $out/bin/paisa \
        --prefix PATH : "${lib.makeBinPath [ pkgs.ledger ]}"
    '';
  };

  paisa-app = pkgs.writeShellApplication {
    name = "paisa-app";
    runtimeInputs = [
      paisa-wrapped
      pkgs.curl
      pkgs.coreutils
    ];
    bashOptions = [ "nounset" "pipefail" ];
    text = ''
      URL="http://127.0.0.1:7500"
      DATA_DIR="$HOME/.local/share/webapps/paisa"
      LOG_FILE="''${XDG_RUNTIME_DIR:-/tmp}/paisa-serve.log"
      SERVER_PID=""

      cleanup() {
        if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
          kill "$SERVER_PID" 2>/dev/null || true
        fi
      }
      trap cleanup EXIT INT TERM

      # Start paisa serve on-demand only if not already listening
      if ! curl -fsS -o /dev/null "$URL" 2>/dev/null; then
        mkdir -p "$HOME/Documents/paisa"
        paisa serve >"$LOG_FILE" 2>&1 &
        SERVER_PID=$!

        for _ in $(seq 1 50); do
          if curl -fsS -o /dev/null "$URL" 2>/dev/null; then
            break
          fi
          if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            echo "paisa serve failed to start. Check $LOG_FILE" >&2
            exit 1
          fi
          sleep 0.1
        done
      fi

      mkdir -p "$DATA_DIR"
      ${pkgs.google-chrome}/bin/google-chrome-stable \
        --app="$URL" \
        --user-data-dir="$DATA_DIR" \
        --class="paisa" \
        --ozone-platform-hint=auto \
        --no-first-run \
        --no-default-browser-check \
        "$@"
    '';
  };
in
{
  home.packages = [
    paisa-wrapped
    pkgs.ledger
    paisa-app
  ];

  xdg.desktopEntries.paisa = {
    name = "Paisa";
    genericName = "Personal Finance Manager";
    comment = "Plain-text accounting dashboard";
    exec = "paisa-app";
    icon = "accessories-calculator"; # Or "paisa" if you drop config/icons/paisa.svg
    terminal = false;
    categories = [ "Office" "Finance" ];
    settings = {
      StartupWMClass = "paisa";
    };
  };
}
