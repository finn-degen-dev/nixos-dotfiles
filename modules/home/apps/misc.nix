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
    blender
    kdePackages.kdenlive
    obs-studio

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
