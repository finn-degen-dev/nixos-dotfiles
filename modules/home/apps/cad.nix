{ pkgs, ... }:

let
  seeed-library = pkgs.fetchFromGitHub {
    owner = "Seeed-Studio";
    repo = "OPL_Kicad_Library";
    rev = "b0035c5";
    sha256 = "sha256-p3Ay0Q6GIIwnFWGBXV3fZvgQ5iavaj27OIaijMZN//M=";
  };
in
{
  home.packages = with pkgs; [
    kicad
  ];

  xdg.dataFile."kicad/libraries/Seeed_OPL".source = seeed-library;
}
