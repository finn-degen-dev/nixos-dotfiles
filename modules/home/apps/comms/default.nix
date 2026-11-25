{ config, lib, pkgs, ... }:

let
  nchat-record = pkgs.writeShellApplication {
    name = "nchat-record";
    runtimeInputs = [ pkgs.ffmpeg pkgs.opus-tools pkgs.coreutils pkgs.python3 ];
    text = ''
      OUT_FILE="''${1:-}"
      [ -n "$OUT_FILE" ] || exit 1
      exec python3 ${./nchat-record.py} "$OUT_FILE"
    '';
  };

  nchat-patched = pkgs.nchat-patched;

  # Wrap runtime tools outside nchat-patched so tweaking nchat-record or updating
  # ffmpeg/mpv/chafa never triggers a full C++/Go recompile of nchat.
  nchat-wrapped = pkgs.symlinkJoin {
    name = "nchat-wrapped-${nchat-patched.version or "custom"}";
    paths = [ nchat-patched ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/nchat
      makeWrapper ${nchat-patched}/bin/nchat $out/bin/nchat \
        --prefix PATH : "${lib.makeBinPath [ pkgs.chafa pkgs.ffmpeg pkgs.mpv nchat-record ]}"
    '';
  };

  concord-tui-fixed = pkgs.concord-tui-fixed;

  syncAercAccounts = pkgs.writeShellScript "sync-aerc-accounts" ''
    PW_PATH="${config.sops.secrets."gmail_app_password".path}"
    ADDR_PATH="${config.sops.secrets."gmail_address".path}"
    NAME_PATH="${config.sops.secrets."gmail_name".path}"
    CONF_PATH="$HOME/.config/aerc/accounts.conf"
    if [ -s "$PW_PATH" ] && [ -s "$ADDR_PATH" ] && [ -s "$NAME_PATH" ]; then
      ${pkgs.python3}/bin/python3 ${./gen-aerc-accounts.py} \
        "$PW_PATH" "$CONF_PATH" "$ADDR_PATH" "$NAME_PATH"
    fi
  '';

  comms-whatsapp = pkgs.writeShellApplication {
    name = "comms-whatsapp";
    runtimeInputs = [ pkgs.python3 nchat-wrapped pkgs.libnotify pkgs.coreutils ];
    bashOptions = [ "nounset" ];
    text = ''
      CONF_DIR="$HOME/.config/nchat-wa"
      UI_CONF="$CONF_DIR/ui.conf"
      mkdir -p "$CONF_DIR"

      ensure_notify_conf() {
        python3 ${./ensure-nchat-notify.py} "$UI_CONF" "WhatsApp" "${pkgs.libnotify}/bin/notify-send"
      }

      while true; do
        if [ ! -d "$CONF_DIR/profiles" ] || [ -z "$(ls -A "$CONF_DIR/profiles" 2>/dev/null)" ]; then
          clear
          echo "=== WhatsApp (nchat) ==="
          echo "No WhatsApp profile linked yet."
          echo "Press [Enter] to run setup (pick WhatsApp and scan the QR code)..."
          read -r _
          ensure_notify_conf
          nchat -d "$CONF_DIR" -s
          ensure_notify_conf
        else
          ensure_notify_conf
          nchat -d "$CONF_DIR"
          echo ""
          echo "[WhatsApp exited] Press [Enter] to reconnect..."
          read -r _
        fi
      done
    '';
  };

  comms-discord = pkgs.writeShellApplication {
    name = "comms-discord";
    runtimeInputs = [ concord-tui-fixed pkgs.ncurses ];
    bashOptions = [ "nounset" ];
    text = ''
      while true; do
        clear
        echo "=== Discord (concord) ==="
        echo "Status: IDLE (0% CPU / 0% network)"
        echo "Press [Enter] to connect (quit concord to return to idle)..."
        read -r _
        concord
      done
    '';
  };

  comms-gmail = pkgs.writeShellApplication {
    name = "comms-gmail";
    runtimeInputs = [ pkgs.aerc pkgs.ncurses ];
    bashOptions = [ "nounset" ];
    text = ''
      while true; do
        clear
        echo "=== Gmail (aerc) ==="
        echo "Status: IDLE (0% CPU / 0% network)"
        if [ ! -s "${config.sops.secrets."gmail_app_password".path}" ] || [ ! -s "${config.sops.secrets."gmail_address".path}" ] || [ ! -s "${config.sops.secrets."gmail_name".path}" ]; then
          echo "Warning: One or more SOPS secrets ('gmail_app_password', 'gmail_address', 'gmail_name') not found."
          echo "Run 'sops-edit' to add them, then rebuild with 'nrs'."
        fi
        echo "Press [Enter] to open aerc (press 'q' in aerc to return to idle)..."
        read -r _
        ${syncAercAccounts}
        aerc
      done
    '';
  };

  commsImv = pkgs.writeShellApplication {
    name = "imv";
    runtimeInputs = [ pkgs.jq pkgs.coreutils ];
    runtimeEnv = {
      IMV_BIN = "${pkgs.imv}/bin/imv";
    };
    bashOptions = [ ];
    text = builtins.readFile ./comms-imv.sh;
  };

  commsImvXdgData = pkgs.runCommand "comms-imv-xdg-data" { } ''
    mkdir -p $out/share/applications
    cat > $out/share/applications/imv.desktop <<EOF
[Desktop Entry]
Type=Application
Name=imv
Exec=${commsImv}/bin/imv %F
Terminal=false
NoDisplay=true
MimeType=image/bmp;image/gif;image/jpeg;image/png;image/tiff;image/webp;image/svg+xml;
EOF
  '';

  commsKittySession = pkgs.writeText "comms-kitty.session" ''
    new_tab WhatsApp
    launch ${comms-whatsapp}/bin/comms-whatsapp
    focus

    new_tab Discord
    launch ${comms-discord}/bin/comms-discord

    new_tab Gmail
    launch ${comms-gmail}/bin/comms-gmail
  '';

  comms-session = pkgs.writeShellScriptBin "comms-session" ''
    # Force xdg-open inside the comms overlay to use our local PATH/XDG_DATA_DIRS
    # instead of delegating to xdg-desktop-portal outside this environment.
    unset NIXOS_XDG_OPEN_USE_PORTAL
    export PATH="${commsImv}/bin:$PATH"
    export XDG_DATA_DIRS="${commsImvXdgData}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
    exec ${pkgs.kitty}/bin/kitty --class comms-scratchpad --session ${commsKittySession}
  '';

  comms-scratchpad = pkgs.writeShellScriptBin "comms-scratchpad" ''
    exec ${comms-session}/bin/comms-session
  '';
in
{
  home.packages = [
    nchat-wrapped
    nchat-record
    pkgs.chafa
    pkgs.ffmpeg
    concord-tui-fixed
    pkgs.aerc
    comms-whatsapp
    comms-discord
    comms-gmail
    comms-session
    comms-scratchpad
  ];

  sops.secrets."gmail_app_password" = {
    path = "${config.home.homeDirectory}/.config/aerc/.gmail-app-password";
  };

  sops.secrets."gmail_address" = {
    path = "${config.home.homeDirectory}/.config/aerc/.gmail-address";
  };

  sops.secrets."gmail_name" = {
    path = "${config.home.homeDirectory}/.config/aerc/.gmail-name";
  };

  # aerc refuses to read accounts.conf if permissions are looser than 0600,
  # so write it directly with mode 0600 rather than symlinking a 0444 nix store file.
  home.activation.aercAccounts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${syncAercAccounts}
  '';
}
