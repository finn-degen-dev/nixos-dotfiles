{ pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.requests
    ps.feedparser
    ps.pandas
    ps.yt-dlp        # <-- provides Python's `import yt_dlp`
  ]);

  yt-radar-run = pkgs.writeShellApplication {
    name = "yt-radar-run";
    runtimeInputs = [
      pythonEnv
      pkgs.libnotify
      pkgs.coreutils
    ];
    text = ''
      SCRIPT="$HOME/Projects/yt-radar/yt_radar_de.py"
      if [ ! -f "$SCRIPT" ]; then
        echo "Error: Could not find $SCRIPT" >&2
        exit 1
      fi

      echo "Running DACH YouTube Radar..."
      ${pythonEnv}/bin/python3 "$SCRIPT"

      notify-send -i dialog-information "DACH YT Radar" "Morning brief ready in ~/Projects/yt-radar/reports/ & Gmail (aerc)"
    '';
  };
in
{
  home.packages = [ yt-radar-run ];

  systemd.user.services.yt-radar = {
    Unit = {
      Description = "Daily DACH YouTube Opportunity & Gap Radar";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${yt-radar-run}/bin/yt-radar-run";
      Nice = 19;
    };
  };

  systemd.user.timers.yt-radar = {
    Unit.Description = "Run DACH YouTube Radar every morning at 06:30";
    Timer = {
      OnCalendar = "*-*-* 06:30:00";
      Persistent = true;
      RandomizedDelaySec = "3min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
