{ pkgs, ... }:

{
  systemd.user.services.flatpak-auto-update = {
    Unit = {
      Description = "Auto-update Flatpak applications in background";
      After = [ "network-online.target" "graphical-session.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.flatpak}/bin/flatpak update --system --noninteractive -y";
      Nice = 19;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
    };
  };

  systemd.user.timers.flatpak-auto-update = {
    Unit = {
      Description = "Schedule background Flatpak updates";
    };
    Timer = {
      Unit = "flatpak-auto-update.service";
      OnBootSec = "5min";
      OnUnitActiveSec = "24h";
      Persistent = true;
      RandomizedDelaySec = "10min";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
