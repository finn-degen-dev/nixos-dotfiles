{ pkgs, ... }:

let
  usdb-syncer-wheel = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/31/71/2a87def5224221d49f18c2633c01e8a5f129158f482ad7d30d5d3a120b35/usdb_syncer-0.26.0-py3-none-any.whl";
    sha256 = "da35773848cfbba2dee4c825a94be7b86bee6761cdc45015208a181803128915";
  };

  usdb-syncer-patched-wheel = pkgs.runCommand "usdb-syncer-patched-wheel" {
    nativeBuildInputs = [ pkgs.unzip pkgs.zip pkgs.python312 ];
  } ''
    mkdir -p work $out
    unzip -q ${usdb-syncer-wheel} -d work
    cp ${../usdb-syncer/usdb_eu.py} work/usdb_syncer/usdb_eu.py
    python3 ${../usdb-syncer/patch.py} work
    (cd work && zip -qr $out/usdb_syncer-0.26.0+eu4-py3-none-any.whl .)
  '';

  usdb-syncer-fhs = pkgs.buildFHSEnv {
    name = "usdb-syncer-fhs";
    targetPkgs = pkgs: (pkgs.appimageTools.defaultFhsEnvArgs.targetPkgs pkgs) ++ (with pkgs; [
      uv
      ffmpeg
      yt-dlp
      zstd
      zlib
      glib
      stdenv.cc.cc.lib
      dbus
      alsa-lib
      libpulseaudio
      portaudio
      libsecret
      mesa
      libGL
      fontconfig
      freetype
      wayland
      libxkbcommon
      libx11
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxtst
      libxcb
      libxcb-util
      libxcb-image
      libxcb-keysyms
      libxcb-render-util
      libxcb-wm
      libxcb-cursor
    ]);

    runScript = "uvx --with 'PySide6<6.8.0' --python 3.12 --from ${usdb-syncer-patched-wheel}/usdb_syncer-0.26.0+eu4-py3-none-any.whl usdb_syncer";
  };

  usdb-syncer-bin = pkgs.writeShellScriptBin "usdb-syncer" ''
    export QT_QPA_PLATFORM="wayland;xcb"
    exec ${usdb-syncer-fhs}/bin/usdb-syncer-fhs "$@"
  '';
in
{
  home.packages = with pkgs; [
    usdb-syncer-bin
    uv
    yt-dlp
    ffmpeg
  ];

  xdg.desktopEntries.usdb-syncer = {
    name = "USDB Syncer";
    genericName = "Karaoke Song Downloader";
    comment = "Download and sync UltraStar karaoke songs from USDB";
    exec = "usdb-syncer";
    icon = "usdb-syncer";
    terminal = false;
    categories = [ "AudioVideo" "Audio" ];
  };
}
