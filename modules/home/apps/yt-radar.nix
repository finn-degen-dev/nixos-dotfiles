{ pkgs, lib, ... }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.requests
    ps.feedparser
    ps.pandas
  ]);

  yt-radar-run = pkgs.writeShellApplication {
    name = "yt-radar-run";
    runtimeInputs = [ pythonEnv pkgs.yt-dlp pkgs.libnotify pkgs.coreutils ];
    text = ''
      SCRIPT="$HOME/Projects/yt-radar/yt_radar_de.py"
      if [ ! -f "$SCRIPT" ]; then
        echo "Missing $SCRIPT" >&2
        exit 1
      fi
      python3 "$SCRIPT"
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
      Persistent = true; # Runs automatically after waking laptop if missed
      RandomizedDelaySec = "3min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
