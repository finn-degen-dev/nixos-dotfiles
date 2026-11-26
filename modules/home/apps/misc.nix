{ pkgs, lib, ... }:

let
  localsend-wrapped = pkgs.symlinkJoin {
    name = "localsend";
    paths = [ pkgs.localsend ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in $out/bin/*; do
        if [ -e "$bin" ]; then
          target=$(readlink -f "$bin")
          rm -f "$bin"
          makeWrapper "$target" "$bin" \
            --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.zlib pkgs.stdenv.cc.cc.lib ]}"
        fi
      done
    '';
  };

  mkNvidiaOffload = { pkg, bins }:
    pkgs.symlinkJoin {
      name = "${pkg.pname or "app"}-nvidia";
      paths = [ pkg ];
      postBuild = ''
        ${lib.concatMapStringsSep "\n" (bin: ''
          if [ -e "$out/bin/${bin}" ]; then
            target=$(readlink -f "$out/bin/${bin}")
            rm -f "$out/bin/${bin}"
            {
              printf '#!%s -e\n' "${pkgs.runtimeShell}"
              printf '%s\n' \
                "unset __EGL_VENDOR_LIBRARY_FILENAMES" \
                "export __NV_PRIME_RENDER_OFFLOAD='1'" \
                "export __NV_PRIME_RENDER_OFFLOAD_PROVIDER='NVIDIA-G0'" \
                "export __GLX_VENDOR_LIBRARY_NAME='nvidia'" \
                "export __VK_LAYER_NV_optimus='NVIDIA_only'" \
                "export VK_LOADER_DRIVERS_SELECT='*nvidia*'" \
                'export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"'
              printf 'exec %q "$@"\n' "$target"
            } > "$out/bin/${bin}"
            chmod +x "$out/bin/${bin}"
          fi
        '') bins}
        if [ -d "$out/share/applications" ]; then
          for desktop in "$out/share/applications"/*.desktop; do
            [ -e "$desktop" ] || continue
            if [ -L "$desktop" ]; then
              cp --remove-destination "$(readlink -f "$desktop")" "$desktop"
            fi
            ${lib.concatMapStringsSep "\n" (bin: ''
              sed -i -E "s|^Exec=${pkg}/bin/${bin}|Exec=$out/bin/${bin}|g; s|^TryExec=${pkg}/bin/${bin}|TryExec=$out/bin/${bin}|g" "$desktop"
            '') bins}
          done
        fi
      '';
    };

  obs-nvidia = mkNvidiaOffload {
    pkg = pkgs.obs-studio;
    bins = [ "obs" ];
  };

  kdenlive-nvidia = mkNvidiaOffload {
    pkg = pkgs.kdePackages.kdenlive;
    bins = [ "kdenlive" ];
  };

  blender-nvidia = mkNvidiaOffload {
    pkg = pkgs.blender;
    bins = [ "blender" ];
  };

  downloads-to-trash = pkgs.writeShellApplication {
    name = "downloads-to-trash";
    runtimeInputs = [
      pkgs.trash-cli
      pkgs.findutils
      pkgs.coreutils
    ];
    text = ''
      DOWNLOADS_DIR="$HOME/Downloads"
      STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}"
      BOOT_ID_FILE="$STATE_DIR/downloads-trashed-boot-id"

      if [ -r /proc/sys/kernel/random/boot_id ]; then
        CUR_BOOT_ID="$(cat /proc/sys/kernel/random/boot_id)"
        if [ -f "$BOOT_ID_FILE" ] && [ "$(cat "$BOOT_ID_FILE")" = "$CUR_BOOT_ID" ]; then
          exit 0
        fi
      else
        CUR_BOOT_ID=""
      fi

      if [ -d "$DOWNLOADS_DIR" ]; then
        find "$DOWNLOADS_DIR" -mindepth 1 -maxdepth 1 -exec trash-put -- {} +
      fi

      if [ -n "$CUR_BOOT_ID" ]; then
        mkdir -p "$STATE_DIR"
        printf '%s\n' "$CUR_BOOT_ID" > "$BOOT_ID_FILE"
      fi
    '';
  };

  trash-auto-empty = pkgs.writeShellApplication {
    name = "trash-auto-empty";
    runtimeInputs = [ pkgs.trash-cli ];
    text = ''
      TRASH_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/Trash"
      if [ -d "$TRASH_DIR" ]; then
        exec trash-empty --trash-dir "$TRASH_DIR" -f 7
      fi
    '';
  };
in
{
  home.packages = with pkgs; [
    # Desktop & system utilities
    brightnessctl
    wireplumber
    lxappearance
    gnome-themes-extra
    gsettings-desktop-schemas
    pamixer
    xfconf
    bluetui
    xsel
    xclip
    grim
    slurp
    qt5.qtwayland
    wl-clicker
    zbar
    tesseract
    hyprpicker
    quickemu
    qemu-utils
    auto-editor
    trash-cli

    # Productivity, security & transfer
    obsidian
    localsend-wrapped
    bitwarden-desktop
    ente-auth
    repomix
    python3
    jq

    # Media, creative & audio/video
    mpv
    peek
    gifski
    aseprite
    tenacity
    gimp
    rawtherapee
    blender-nvidia
    kdenlive-nvidia
    obs-nvidia

    # Gaming & reverse engineering / SDR
    prismlauncher
    jdk17
    chiaki-ng
    steamcmd
    ghidra
    gqrx
    sdrpp
    rtl_433
  ];

  # Move Downloads contents to Trash once per boot (boot_id guard prevents mid-session rebuild triggers)
  systemd.user.services.downloads-to-trash = {
    Unit = {
      Description = "Move files in Downloads to Trash on boot";
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${downloads-to-trash}/bin/downloads-to-trash";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Permanently delete items in Trash older than 7 days (using DeletionDate from .trashinfo)
  systemd.user.services.trash-auto-empty = {
    Unit = {
      Description = "Delete trashed files older than 7 days";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${trash-auto-empty}/bin/trash-auto-empty";
    };
  };

  systemd.user.timers.trash-auto-empty = {
    Unit = {
      Description = "Schedule automatic Trash cleanup after 7 days";
    };
    Timer = {
      Unit = "trash-auto-empty.service";
      OnBootSec = "2min";
      OnUnitActiveSec = "24h";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  xdg.desktopEntries."org.kde.kdenlive" = {
    name = "Kdenlive";
    genericName = "Video Editor";
    comment = "Free and open-source video editor";
    exec = "kdenlive %u";
    icon = "kdenlive";
    terminal = false;
    categories = [ "AudioVideo" "Video" "AudioVideoEditing" ];
  };
}
