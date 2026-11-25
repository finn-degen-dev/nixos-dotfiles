{ config, pkgs, lib, palette, ... }:
let
  dotfiles = config.boredvoidater.dotfilesPath;

  hypridle-battery-suspend = pkgs.writeShellScriptBin "hypridle-battery-suspend" ''
    for ps_dir in /sys/class/power_supply/*; do
      [ -d "$ps_dir" ] || continue
      [ -r "$ps_dir/online" ] || continue
      ps_type=$(cat "$ps_dir/type" 2>/dev/null || true)
      if [ "$ps_type" = "Mains" ] || [ -z "$ps_type" ]; then
        online=$(cat "$ps_dir/online" 2>/dev/null || echo 0)
        if [ "$online" = "1" ]; then
          exit 0
        fi
      fi
    done
    exec systemctl suspend
  '';
in
{
  home.packages = with pkgs; [
    swaybg
    waypaper
    wl-clipboard
    waybar
    hypridle
    hypridle-battery-suspend
  ];

  # Seed a writable waypaper config so waypaper can persist selections and sync to ReGreet
  home.activation.waypaperConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    WAYPAPER_DIR="${config.home.homeDirectory}/.config/waypaper"
    WAYPAPER_CONF="$WAYPAPER_DIR/config.ini"
    mkdir -p "$WAYPAPER_DIR"
    if [ ! -f "$WAYPAPER_CONF" ]; then
      cat > "$WAYPAPER_CONF" << 'EOF'
[Settings]
language = en
folder = ~/Pictures
monitors = All
wallpaper = ~/Pictures/wallpaper.jpg
show_path_in_tooltip = True
backend = swaybg
fill = fill
sort = name
color = ${palette.colors.base}
subfolders = True
all_subfolders = False
show_hidden = False
show_gifs_only = False
zen_mode = False
post_command = cp -f "$wallpaper" /var/lib/wallpaper/current && chmod 644 /var/lib/wallpaper/current
number_of_columns = 3
EOF
    fi
    if [ -d /var/lib/wallpaper ] && [ ! -e /var/lib/wallpaper/current ] && [ -f "${config.home.homeDirectory}/Pictures/wallpaper.jpg" ]; then
      cp -f "${config.home.homeDirectory}/Pictures/wallpaper.jpg" /var/lib/wallpaper/current
      chmod 644 /var/lib/wallpaper/current
    fi
  '';

  xdg.configFile.hypr = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/hypr";
  };

  xdg.configFile.waybar = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/waybar";
  };
}
