{ config, pkgs, meta, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./modules/nixos/core.nix
      ./modules/nixos/gpu.nix
      ./modules/nixos/desktop.nix
      ./modules/nixos/audio.nix
      ./modules/nixos/flatpak.nix
      ./modules/nixos/storage.nix
      ./modules/nixos/ios.nix
      ./modules/nixos/icloud.nix
    ];

  networking.hostName = meta.hostname;

  # iCloud Drive integration via rclone (main password + 2FA)
  services.icloud-drive = {
    enable = true;
    mountPoint = "/mnt/icloud-drive";
    readOnly = true;
    mountUser = meta.username;
  };

  system.stateVersion = meta.stateVersion;
}
