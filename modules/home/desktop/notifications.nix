{ pkgs, palette, ... }:

let
  c = palette.colors;
in
{
  services.mako = {
    enable = true;
    settings = {
      font = "${palette.font.mono} 11";
      background-color = "${c.mantle}ee";
      text-color = c.text;
      border-color = "#2c2d35";
      border-radius = 10;
      border-size = 1;
      padding = "12";
      default-timeout = 5000;
      layer = "overlay";
    };
  };

  home.packages = with pkgs; [
    libnotify
  ];
}
