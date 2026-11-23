{ pkgs, ... }:

let
  kbm2pad = pkgs.writers.writePython3Bin "kbm2pad" {
    libraries = [ pkgs.python3Packages.evdev ];
    flakeIgnore = [ "E501" "E226" "W503" ];
  } (builtins.readFile ./kbm2pad.py);
in
{
  home.packages = [
    kbm2pad
  ];
}
