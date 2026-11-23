{ pkgs, ... }:

{
  services.usbmuxd.enable = true;

  environment.systemPackages = with pkgs; [
    libimobiledevice
    ifuse
    usbmuxd
    libplist
    ideviceinstaller
    idevicerestore
    libimobiledevice-glue
  ];
}
