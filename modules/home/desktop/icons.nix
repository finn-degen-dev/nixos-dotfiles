{ pkgs, lib, ... }:

let
  iconDir = ../../../config/icons;
  entries = if builtins.pathExists iconDir then builtins.readDir iconDir else { };

  svgNames = map (lib.removeSuffix ".svg") (
    builtins.filter (name: entries.${name} == "regular" && lib.hasSuffix ".svg" name) (builtins.attrNames entries)
  );

  pngNames = map (lib.removeSuffix ".png") (
    builtins.filter (name: entries.${name} == "regular" && lib.hasSuffix ".png" name) (builtins.attrNames entries)
  );

  remoteSvgs = {
    notion = pkgs.fetchurl {
      url = "https://upload.wikimedia.org/wikipedia/commons/e/e9/Notion-logo.svg";
      curlOptsList = [ "-H" "User-Agent: Mozilla/5.0 (X11; Linux x86_64)" ];
      sha256 = "sha256-G1KhhdgWbZM59cFt1ReJ7jD0mmW01Ac4KQtgQj4zEWA=";
    };
  };

  mkSvgEntries = name: src:
    let
      png = pkgs.runCommand "${name}-icon.png" { } ''
        ${pkgs.resvg}/bin/resvg -w 512 -h 512 ${src} $out
      '';
    in
    [
      {
        name = "icons/hicolor/scalable/apps/${name}.svg";
        value.source = src;
      }
      {
        name = "icons/hicolor/512x512/apps/${name}.png";
        value.source = png;
      }
    ];

  svgDataFiles = lib.listToAttrs (
    (lib.concatMap (name: mkSvgEntries name (iconDir + "/${name}.svg")) svgNames)
    ++ (lib.concatLists (lib.mapAttrsToList mkSvgEntries remoteSvgs))
  );

  pngDataFiles = lib.listToAttrs (map (name: {
    name = "icons/hicolor/512x512/apps/${name}.png";
    value.source = iconDir + "/${name}.png";
  }) (lib.filter (n: !(builtins.elem n svgNames) && !(builtins.hasAttr n remoteSvgs)) pngNames));
in
{
  home.packages = with pkgs; [
    hicolor-icon-theme
  ];

  xdg.dataFile = svgDataFiles // pngDataFiles;
}
