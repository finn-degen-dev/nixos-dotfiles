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

  # Wipes Downloads directory on shutdown/logout
  systemd.user.services.clean-downloads = {
    Unit = {
      Description = "Clean Downloads folder on logout/shutdown";
      DefaultDependencies = "no";
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "${pkgs.bash}/bin/bash -c 'rm -rf %h/Downloads/*'";
    };
    Install.WantedBy = [ "default.target" ];
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
