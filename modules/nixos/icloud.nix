{ config, pkgs, lib, meta, ... }:

let
  cfg = config.services.icloud-drive;
in
{
  options.services.icloud-drive = {
    enable = lib.mkEnableOption "iCloud Drive integration via rclone (uses main password + 2FA)";
    mountPoint = lib.mkOption {
      type = lib.types.path;
      default = "/mnt/icloud-drive";
      description = "Mount point for iCloud Drive";
    };
    readOnly = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Mount read-only (rclone iCloud is experimental)";
    };
    mountUser = lib.mkOption {
      type = lib.types.str;
      default = meta.username;
      description = "User for mount point ownership and user service";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      rclone
      fuse3
      (writeShellScriptBin "icloud-mount" ''
        #!/bin/sh
        MOUNT_POINT="${cfg.mountPoint}"
        mkdir -p "$MOUNT_POINT"
        if mountpoint -q "$MOUNT_POINT"; then
          echo "Already mounted at $MOUNT_POINT"
        else
          echo "Mounting iCloud Drive at $MOUNT_POINT..."
          ${pkgs.rclone}/bin/rclone mount icloud: "$MOUNT_POINT" \
            --vfs-cache-mode full \
            --vfs-cache-max-size 1G \
            --daemon
          sleep 2
          if mountpoint -q "$MOUNT_POINT"; then
            echo "Mounted successfully!"
            echo "Access in Thunar: $MOUNT_POINT"
          else
            echo "Mount failed. Run: icloud-config"
          fi
        fi
      '')
      (writeShellScriptBin "icloud-unmount" ''
        #!/bin/sh
        MOUNT_POINT="${cfg.mountPoint}"
        ${pkgs.rclone}/bin/rclone unmount "$MOUNT_POINT"
        echo "Unmounted iCloud Drive"
      '')
      (writeShellScriptBin "icloud-config" ''
        #!/bin/sh
        echo "Configuring iCloud remote 'icloud'..."
        echo "Use your MAIN Apple ID password (not app-specific) + 2FA code"
        ${pkgs.rclone}/bin/rclone config
      '')
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.mountPoint} 0755 ${config.users.users.${cfg.mountUser}.name} ${config.users.users.${cfg.mountUser}.group} - -"
    ];

    systemd.user.services.icloud-drive = {
      description = "iCloud Drive FUSE mount via rclone (user service)";
      documentation = [ "https://rclone.org/icloud/" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "notify";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${cfg.mountPoint}";
        ExecStart = ''
          ${pkgs.rclone}/bin/rclone mount icloud: ${cfg.mountPoint} \
            --vfs-cache-mode full \
            --vfs-cache-max-size 1G \
            --vfs-cache-max-age 24h \
            --vfs-read-chunk-size 16M \
            --vfs-read-chunk-size-limit 256M \
            --dir-cache-time 24h \
            --poll-interval 30s \
            --umask 022 \
            ${lib.optionalString cfg.readOnly "--read-only"} \
            --log-level INFO
        '';
        ExecStop = "${pkgs.rclone}/bin/rclone unmount ${cfg.mountPoint}";
        Restart = "on-failure";
        RestartSec = 10;
      };
      wantedBy = [ "default.target" ];
    };
  };
}
