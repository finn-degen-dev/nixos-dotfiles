{ pkgs, lib, ... }:

let
  # Reference google-chrome-stable directly instead of adding pkgs.google-chrome to
  # home.packages so Chrome itself stays hidden from $PATH and application launchers.
  mkChromeWebApp = { execName, url, extraFlags ? [ ], nvidiaOffload ? false }:
    let
      # Chrome under native Wayland falls back to the Intel iGPU on Optimus; XWayland enables GLX PRIME offload
      ozoneFlag = if nvidiaOffload then "--ozone-platform=x11" else "--ozone-platform-hint=auto";
    in
    pkgs.writeShellScriptBin execName ''
      DATA_DIR="$HOME/.local/share/webapps/${execName}"
      mkdir -p "$DATA_DIR"
      ${lib.optionalString nvidiaOffload ''
        unset __EGL_VENDOR_LIBRARY_FILENAMES
        export __NV_PRIME_RENDER_OFFLOAD=1
        export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export __VK_LAYER_NV_optimus=NVIDIA_only
        export VK_LOADER_DRIVERS_SELECT='*nvidia*'
        export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      ''}
      TARGET_URL="${url}"
      for arg in "$@"; do
        case "$arg" in
          https://*|http://*)
            TARGET_URL="$arg"
            break
            ;;
          notion://*)
            stripped="''${arg#notion://}"
            case "$stripped" in
              https://*|http://*) TARGET_URL="$stripped" ;;
              www.notion.so*|notion.so*|www.notion.com*|notion.com*) TARGET_URL="https://$stripped" ;;
              *) TARGET_URL="https://www.notion.so/''${stripped#/}" ;;
            esac
            break
            ;;
        esac
      done
      exec ${pkgs.google-chrome}/bin/google-chrome-stable \
        --app="$TARGET_URL" \
        --user-data-dir="$DATA_DIR" \
        --class="${execName}" \
        ${ozoneFlag} \
        --no-first-run \
        --no-default-browser-check \
        ${lib.escapeShellArgs extraFlags}
    '';

  control4freePkg = pkgs.writeShellScriptBin "control4free" ''
    DATA_DIR="$HOME/.local/share/webapps/control4free"
    CONF_DIR="$HOME/.config/control4free"
    CONF_FILE="$CONF_DIR/url"
    mkdir -p "$DATA_DIR" "$CONF_DIR"

    normalize_c4f_url() {
      local raw="$1"
      raw="$(printf '%s' "$raw" | ${pkgs.coreutils}/bin/tr -d '[:space:]')"
      [ -z "$raw" ] && return 1
      case "$raw" in
        http://*|https://*) ;;
        *) raw="http://$raw" ;;
      esac
      local scheme="''${raw%%://*}"
      local rest="''${raw#*://}"
      local hostport="''${rest%%/*}"
      local path=""
      case "$rest" in
        */*) path="/''${rest#*/}" ;;
      esac
      case "$hostport" in
        *:*) ;;
        *) hostport="$hostport:4264" ;;
      esac
      printf '%s://%s%s\n' "$scheme" "$hostport" "$path"
    }

    SET_IP=0
    ARG_URL=""
    for arg in "$@"; do
      case "$arg" in
        --set-ip|--config)
          SET_IP=1
          ;;
        -*)
          ;;
        *)
          ARG_URL="$arg"
          ;;
      esac
    done

    TARGET_URL=""
    if [ -n "$ARG_URL" ]; then
      TARGET_URL="$(normalize_c4f_url "$ARG_URL" || true)"
      [ -n "$TARGET_URL" ] && printf '%s\n' "$TARGET_URL" > "$CONF_FILE"
    elif [ "$SET_IP" -eq 0 ] && [ -s "$CONF_FILE" ]; then
      TARGET_URL="$(normalize_c4f_url "$(cat "$CONF_FILE")" || true)"
    fi

    if [ -z "$TARGET_URL" ] || [ "$SET_IP" -eq 1 ]; then
      DEFAULT_VAL=""
      [ -s "$CONF_FILE" ] && DEFAULT_VAL="$(cat "$CONF_FILE")"
      INPUT="$(${pkgs.zenity}/bin/zenity --entry \
        --title="Control4Free" \
        --text="Enter your PS4 IP address or URL (port 4264 is added automatically):" \
        --entry-text="''${DEFAULT_VAL:-192.168.1.}" 2>/dev/null || true)"
      TARGET_URL="$(normalize_c4f_url "$INPUT" || true)"
      [ -z "$TARGET_URL" ] && exit 0
      printf '%s\n' "$TARGET_URL" > "$CONF_FILE"
    fi

    ORIGIN="$(printf '%s' "$TARGET_URL" | ${pkgs.gnused}/bin/sed -E 's#^(https?://[^/]+).*#\1#')"

    exec ${pkgs.google-chrome}/bin/google-chrome-stable \
      --app="$TARGET_URL" \
      --user-data-dir="$DATA_DIR" \
      --class="control4free" \
      --ozone-platform-hint=auto \
      --no-first-run \
      --no-default-browser-check \
      --unsafely-treat-insecure-origin-as-secure="$ORIGIN"
  '';

  webApps = {
    xbox-live = {
      name = "Xbox Live";
      genericName = "Xbox Cloud Gaming";
      comment = "Xbox Cloud Gaming web app";
      url = "https://www.xbox.com/play";
      categories = [ "Game" ];
    };

    teams = {
      name = "Microsoft Teams";
      genericName = "Team Collaboration";
      comment = "Microsoft Teams web app";
      url = "https://teams.microsoft.com";
      categories = [ "Network" "InstantMessaging" ];
    };

    onshape = {
      name = "Onshape";
      genericName = "Cloud CAD";
      comment = "Onshape 3D CAD web app";
      url = "https://cad.onshape.com";
      categories = [ "Graphics" "Engineering" "3DGraphics" ];
      nvidiaOffload = true;
      extraFlags = [
        "--enable-webgl"
        "--ignore-gpu-blocklist"
      ];
    };

    notion = {
      name = "Notion";
      genericName = "Notes & Workspace";
      comment = "Connected workspace for notes, docs, and projects";
      url = "https://www.notion.so";
      categories = [ "Office" "Utility" "TextEditor" ];
      mimeType = [ "x-scheme-handler/notion" ];
    };

    aistudio = {
      name = "Google AI Studio";
      genericName = "AI Prototyping Studio";
      comment = "Google AI Studio web app";
      url = "https://aistudio.google.com";
      categories = [ "Development" "Utility" ];
    };

    control4free = {
      name = "Control4Free";
      genericName = "PS4 Virtual DualShock";
      comment = "Control4Free virtual PS4 DualShock 4 web app";
      pkg = control4freePkg;
      categories = [ "Game" "Utility" ];
    };
  };

  builtApps = lib.mapAttrs (execName: app: {
    pkg =
      if app ? pkg then
        app.pkg
      else
        mkChromeWebApp {
          inherit execName;
          url = app.url;
          extraFlags = app.extraFlags or [ ];
          nvidiaOffload = app.nvidiaOffload or false;
        };
    desktopEntry = {
      inherit (app) name genericName comment categories;
      exec = if (app.mimeType or [ ]) != [ ] then "${execName} %U" else execName;
      icon = execName;
      terminal = false;
      settings = {
        StartupWMClass = execName;
      };
    } // lib.optionalAttrs (app ? mimeType) {
      inherit (app) mimeType;
    };
  }) webApps;
in
{
  home.packages = map (app: app.pkg) (builtins.attrValues builtApps);

  xdg.desktopEntries = lib.mapAttrs (_: app: app.desktopEntry) builtApps;
}
