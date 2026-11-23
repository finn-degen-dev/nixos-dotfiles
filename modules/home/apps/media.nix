{ pkgs, lib, ytm-player, palette, ... }:

let
  c = palette.colors;
  ytmPkg = ytm-player.packages.${pkgs.stdenv.hostPlatform.system}.ytm-player-full;

  music-runner = pkgs.writeShellApplication {
    name = "music-runner";
    runtimeInputs = [ ytmPkg pkgs.coreutils ];
    bashOptions = [ "nounset" "pipefail" ];
    text = ''
      while true; do
        start_ts=$(date +%s)
        ytm
        status=$?
        elapsed=$(( $(date +%s) - start_ts ))
        if [ "$status" -eq 0 ] && [ "$elapsed" -ge 3 ]; then
          break
        fi
        echo ""
        echo "ytm exited with status $status (if this is your first run, you may need to authenticate)."
        echo "Press [s] to run 'ytm setup', [Enter] to retry, or close with Super+W..."
        read -r choice
        if [ "$choice" = "s" ] || [ "$choice" = "S" ]; then
          ytm setup
        fi
      done
    '';
  };

  music-scratchpad = pkgs.writeShellApplication {
    name = "music-scratchpad";
    runtimeInputs = [ pkgs.kitty music-runner ];
    text = ''
      exec kitty --class music-scratchpad -e music-runner
    '';
  };

  music-toggle = pkgs.writeShellApplication {
    name = "music-toggle";
    runtimeInputs = [ pkgs.jq pkgs.coreutils music-scratchpad ];
    bashOptions = [ "nounset" "pipefail" ];
    text = ''
      if ! hyprctl clients -j 2>/dev/null | jq -e '.[] | select(.class == "music-scratchpad")' >/dev/null 2>&1; then
        music-scratchpad >/dev/null 2>&1 &
        for _ in $(seq 1 40); do
          if hyprctl clients -j 2>/dev/null | jq -e '.[] | select(.class == "music-scratchpad")' >/dev/null 2>&1; then
            break
          fi
          sleep 0.1
        done
        if hyprctl monitors -j 2>/dev/null | jq -e '.[] | select(.focused == true and .specialWorkspace.name == "special:music")' >/dev/null 2>&1; then
          exit 0
        fi
      fi
      exec hyprctl dispatch 'hl.dsp.workspace.toggle_special("music")'
    '';
  };
in
{
  programs.imv = {
    enable = true;
    settings.options.background = lib.removePrefix "#" c.base;
  };

  programs.zathura = {
    enable = true;
    options = {
      default-bg = c.base;
      default-fg = c.text;
      statusbar-bg = c.mantle;
      statusbar-fg = c.overlay1;
      inputbar-bg = c.surface0;
      inputbar-fg = c.text;
    };
  };

  xdg.configFile."ytm-player/theme.toml".text = ''
    [colors]
    background = "${c.base}"
    foreground = "${c.text}"
    primary = "${c.accent}"
    secondary = "${c.subtext0}"
    accent = "${c.mauve}"
    success = "${c.green}"
    warning = "${c.yellow}"
    error = "${c.red}"
    surface = "${c.mantle}"
    border = "${c.border}"
    muted_text = "${c.overlay1}"
    text = "${c.text}"
    playback_bar_bg = "${c.mantle}"
    active_tab = "#ffffff"
    inactive_tab = "${c.overlay1}"
    selected_item = "${c.surface1}"
    progress_filled = "${c.accent}"
    progress_empty = "${c.surface1}"
    lyrics_played = "${c.overlay0}"
    lyrics_current = "${c.mauve}"
    lyrics_upcoming = "${c.text}"
  '';

  home.packages = with pkgs; [
    ytmPkg
    music-runner
    music-scratchpad
    music-toggle
    xarchiver
    playerctl
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "librewolf.desktop" ];
      "x-scheme-handler/http" = [ "librewolf.desktop" ];
      "x-scheme-handler/https" = [ "librewolf.desktop" ];
      "x-scheme-handler/about" = [ "librewolf.desktop" ];
      "x-scheme-handler/unknown" = [ "librewolf.desktop" ];

      "image/jpeg" = [ "imv.desktop" ];
      "image/png" = [ "imv.desktop" ];
      "image/gif" = [ "imv.desktop" ];
      "image/webp" = [ "imv.desktop" ];
      "image/tiff" = [ "imv.desktop" ];
      "image/bmp" = [ "imv.desktop" ];
      "image/svg+xml" = [ "imv.desktop" ];

      "video/mp4" = [ "mpv.desktop" ];
      "video/x-matroska" = [ "mpv.desktop" ];
      "video/webm" = [ "mpv.desktop" ];
      "video/x-msvideo" = [ "mpv.desktop" ];
      "video/quicktime" = [ "mpv.desktop" ];

      "audio/mpeg" = [ "mpv.desktop" ];
      "audio/ogg" = [ "mpv.desktop" ];
      "audio/x-wav" = [ "mpv.desktop" ];
      "audio/flac" = [ "mpv.desktop" ];

      "application/pdf" = [ "org.pwmt.zathura.desktop" ];
      "application/epub+zip" = [ "org.pwmt.zathura.desktop" ];

      "application/zip" = [ "xarchiver.desktop" ];
      "application/x-tar" = [ "xarchiver.desktop" ];
      "application/x-compressed-tar" = [ "xarchiver.desktop" ];
      "application/x-bzip-compressed-tar" = [ "xarchiver.desktop" ];
      "application/x-xz-compressed-tar" = [ "xarchiver.desktop" ];
      "application/x-7z-compressed" = [ "xarchiver.desktop" ];
      "application/vnd.rar" = [ "xarchiver.desktop" ];
    };
  };
}
