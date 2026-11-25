{ pkgs, config, meta, palette, ... }:

let
  c = palette.colors;
  powerSupplyPerms = pkgs.writeShellScript "power-supply-perms" ''
    for f in \
      /sys/class/power_supply/BAT*/charge_control_start_threshold \
      /sys/class/power_supply/BAT*/charge_control_end_threshold \
      /sys/class/power_supply/BAT*/charge_behaviour \
      /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode
    do
      if [ -e "$f" ]; then
        ${pkgs.coreutils}/bin/chgrp wheel "$f"
        ${pkgs.coreutils}/bin/chmod 664 "$f"
      fi
    done
  '';

  cleanupGvfsMounts = pkgs.writeShellScript "cleanup-gvfs-mounts" ''
    FUSERMOUNT=""
    for candidate in /run/wrappers/bin/fusermount3 /run/wrappers/bin/fusermount ${pkgs.fuse3}/bin/fusermount3; do
      if [ -x "$candidate" ]; then
        FUSERMOUNT="$candidate"
        break
      fi
    done

    is_mounted() {
      ${pkgs.gawk}/bin/awk -v mp="$1" '$2 == mp { found=1; exit } END { exit !found }' /proc/mounts
    }

    unmount_mp() {
      local mp="$1"
      if is_mounted "$mp" && [ -n "$FUSERMOUNT" ]; then
        "$FUSERMOUNT" -uz "$mp" 2>/dev/null || true
      fi
    }

    # Always remove legacy ~/.gvfs fallback mounts so Thunar never hits ENOTCONN in $HOME
    unmount_mp "$HOME/.gvfs"
    if ! is_mounted "$HOME/.gvfs"; then
      ${pkgs.coreutils}/bin/rmdir "$HOME/.gvfs" 2>/dev/null || true
    fi

    # Unmount disconnected $XDG_RUNTIME_DIR/gvfs so gvfsd-fuse does not fall back to ~/.gvfs
    RUNTIME_GVFS="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/gvfs"
    if is_mounted "$RUNTIME_GVFS"; then
      if ! ${pkgs.coreutils}/bin/stat "$RUNTIME_GVFS" >/dev/null 2>&1; then
        unmount_mp "$RUNTIME_GVFS"
      fi
    fi
  '';

  chromePolicy = builtins.toJSON {
    ExtensionInstallForcelist = [
      "ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx" # uBlock Origin Lite
      "hfjbmagddngcpeloejdejnfgbamkjaeg;https://clients2.google.com/service/update2/crx" # Vimium C
    ];
    URLBlocklist = [
      "youtube.com"
      "youtu.be"
      "reddit.com"
      "redd.it"
      "instagram.com"
      "tiktok.com"
      "x.com"
      "twitter.com"
      "twitch.tv"
    ];
    IncognitoModeAvailability = 1;
    BrowserGuestModeEnabled = false;
    BrowserAddPersonEnabled = false;
  };
in
{
  services.xserver = {
    enable = true;
    autoRepeatDelay = 200;
    autoRepeatInterval = 35;
    xkb.layout = "de";
  };

  services.displayManager.regreet = {
    enable = true;
    cageArgs = [ "-s" "-m" "last" ];
    theme = {
      name = palette.theme.gtk;
      package = pkgs.matcha-gtk-theme;
    };
    iconTheme = {
      name = palette.theme.icon;
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = palette.theme.cursor;
      package = pkgs.bibata-cursors;
    };
    font = {
      name = palette.font.mono;
      package = pkgs.nerd-fonts.jetbrains-mono;
      size = 12;
    };
    settings = {
      background = {
        path = "/var/lib/wallpaper/current";
        fit = "Cover";
      };
      GTK = {
        application_prefer_dark_theme = true;
      };
      appearance = {
        greeting_msg = "Welcome back";
      };
    };
    extraCss = ''
      window {
        background-color: ${c.base};
        color: ${c.text};
        font-family: "${palette.font.mono}";
      }

      frame.background {
        background-color: rgba(19, 20, 24, 0.88);
        border: 1px solid ${c.border};
        border-radius: 12px;
        padding: 16px;
      }

      label {
        color: ${c.text};
      }

      entry {
        background-color: ${c.base};
        color: ${c.text};
        border: 1px solid ${c.border};
        border-radius: 8px;
        padding: 8px 12px;
        caret-color: ${c.accent};
      }

      entry:focus {
        border-color: ${c.accent};
        box-shadow: 0 0 0 1px ${c.accent};
      }

      selection {
        background-color: ${c.accent};
        color: #ffffff;
      }

      button {
        background-color: ${c.surface0};
        color: ${c.text};
        border: 1px solid ${c.border};
        border-radius: 8px;
        padding: 6px 14px;
      }

      button:hover {
        background-color: ${c.surface1};
        border-color: ${c.surface2};
      }

      button.suggested-action {
        background-color: ${c.accent};
        color: #ffffff;
        border-color: ${c.accent};
      }

      button.suggested-action:hover {
        background-color: ${c.accentHover};
      }

      button.destructive-action {
        color: ${c.red};
      }

      popover contents,
      popover > contents {
        background-color: ${c.mantle};
        color: ${c.text};
        border: 1px solid ${c.border};
        border-radius: 10px;
      }
    '';
  };

  # World-readable directory so greeter can read the active wallpaper synced by waypaper
  systemd.tmpfiles.rules = [
    "d /var/lib/wallpaper 0755 ${config.users.users.${meta.username}.name} ${config.users.users.${meta.username}.group} - -"
    "z /sys/devices/system/cpu/intel_pstate/no_turbo 0664 root wheel - -"
  ];

  # Enforce webapp extensions and block distracting sites/profiles across all Chrome/Chromium webapp profiles
  environment.etc."opt/chrome/policies/managed/policies.json".text = chromePolicy;
  environment.etc."chromium/policies/managed/policies.json".text = chromePolicy;

  programs.hyprland.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  services.libinput.enable = true;
  services.joycond.enable = true;

  environment.variables = {
    XKB_DEFAULT_LAYOUT = "de";
  };

  services.udev.extraHwdb = ''
    evdev:input:*
     KEYBOARD_KEY_delay=200
  '';

  # Allow wheel users to toggle battery charge thresholds/bypass and rfkill wireless state
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ACTION=="add|change", RUN+="${powerSupplyPerms}"
    KERNEL=="rfkill", MODE="0664", GROUP="wheel", TAG+="uaccess"
  '';

  programs.thunar = {
    enable = true;
    plugins = with pkgs; [ thunar-archive-plugin thunar-volman ];
  };

  services.tumbler.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  programs.dconf.enable = true;

  systemd.user.services.gvfs-cleanup = {
    description = "Clean up stale GVfs FUSE mountpoints";
    wantedBy = [ "default.target" ];
    before = [ "gvfs-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = cleanupGvfsMounts;
    };
  };

  systemd.user.services.gvfs-daemon = {
    overrideStrategy = "asDropin";
    serviceConfig = {
      ExecStartPre = "-${cleanupGvfsMounts}";
      ExecStopPost = "-${cleanupGvfsMounts}";
    };
  };

  services.printing = {
    enable = true;
    drivers = [ pkgs.hplipWithPlugin ];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    file-roller
    qt5.qtgraphicaleffects
    system-config-printer
    (writeShellScriptBin "polkit-gnome-agent" ''
      exec ${polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 "$@"
    '')
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
  };

  security.polkit.enable = true;
}
