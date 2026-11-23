{ pkgs, ... }:

let
  uskmaker-runner = pkgs.writeShellApplication {
    name = "uskmaker-runner";
    text = builtins.readFile ./uskmaker-runner.sh;
  };

  uskmaker-fhs = pkgs.buildFHSEnv {
    name = "uskmaker-fhs";
    extraOutputsToInstall = [ "dev" "lib" ];
    targetPkgs = pkgs: (pkgs.appimageTools.defaultFhsEnvArgs.targetPkgs pkgs) ++ (with pkgs; [
      python312
      uv
      git
      git-lfs
      curl
      wget
      which
      procps
      coreutils
      gnused
      gnugrep
      cacert

      stdenv.cc
      stdenv.cc.cc.lib
      gcc
      binutils
      gnumake
      cmake
      pkg-config
      nodejs
      rustc
      cargo

      ffmpeg
      ffmpeg_7
      yt-dlp
      sox
      portaudio
      alsa-lib
      libpulseaudio

      gtk3
      webkitgtk_4_1
      libsoup_3
      librsvg
      glib
      cairo
      pango
      harfbuzz
      gdk-pixbuf
      atk
      openssl
      zlib
      dbus
      libayatana-appindicator

      mesa
      libGL
      libGLU
      libglvnd
      libdrm
      vulkan-loader
      ocl-icd
      cudatoolkit
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
      libxinerama
      libxscrnsaver
    ]);

    profile = ''
      export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/share/pkgconfig:''${PKG_CONFIG_PATH:-}"
      export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib:/usr/lib64:/usr/lib:''${LD_LIBRARY_PATH:-}"
      if [ -f "/etc/ssl/certs/ca-certificates.crt" ]; then
        export SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
      elif [ -f "/etc/ssl/certs/ca-bundle.crt" ]; then
        export SSL_CERT_FILE="/etc/ssl/certs/ca-bundle.crt"
      fi
      export REQUESTS_CA_BUNDLE="''${SSL_CERT_FILE:-}"
    '';

    runScript = "${uskmaker-runner}/bin/uskmaker-runner";
  };

  uskmaker-bin = pkgs.writeShellScriptBin "uskmaker" ''
    exec ${uskmaker-fhs}/bin/uskmaker-fhs "$@"
  '';

  uskmaker-alias = pkgs.writeShellScriptBin "ultrastar-karaoke-maker" ''
    exec ${uskmaker-bin}/bin/uskmaker "$@"
  '';

  uskmaker-setup-ai = pkgs.writeShellScriptBin "uskmaker-setup-ai" ''
    exec ${uskmaker-bin}/bin/uskmaker --setup-ai "$@"
  '';

  uskmaker-build = pkgs.writeShellScriptBin "uskmaker-build" ''
    exec ${uskmaker-bin}/bin/uskmaker --build "$@"
  '';
in
{
  home.packages = [
    uskmaker-bin
    uskmaker-alias
    uskmaker-setup-ai
    uskmaker-build
  ];

  xdg.desktopEntries.uskmaker = {
    name = "UltraStar Karaoke Maker";
    genericName = "AI Karaoke Package Generator";
    comment = "Generate UltraStar karaoke songs with forced alignment (Demucs + WhisperX on NVIDIA GPU)";
    exec = "uskmaker";
    icon = "uskmaker";
    terminal = false;
    categories = [ "AudioVideo" "Audio" ];
  };
}
