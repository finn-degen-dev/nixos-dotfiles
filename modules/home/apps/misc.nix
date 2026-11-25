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
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        ${lib.concatMapStringsSep "\n" (bin: ''
          if [ -e "$out/bin/${bin}" ]; then
            target=$(readlink -f "$out/bin/${bin}")
            rm -f "$out/bin/${bin}"
            makeWrapper "$target" "$out/bin/${bin}" \
              --unset __EGL_VENDOR_LIBRARY_FILENAMES \
              --set __NV_PRIME_RENDER_OFFLOAD 1 \
              --set __NV_PRIME_RENDER_OFFLOAD_PROVIDER NVIDIA-G0 \
              --set __GLX_VENDOR_LIBRARY_NAME nvidia \
              --set __VK_LAYER_NV_optimus NVIDIA_only \
              --set VK_LOADER_DRIVERS_SELECT '*nvidia*' \
              --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib"
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

  # Automatically prune files in Downloads older than 7 days
  systemd.user.tmpfiles.rules = [
    "e %h/Downloads - - - 7d"
  ];

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
