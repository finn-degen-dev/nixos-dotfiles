{ pkgs, lib, palette, ... }:

let
  c = palette.colors;
in
{
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    name = palette.theme.cursor;
    package = pkgs.bibata-cursors;
    size = palette.theme.cursorSize;
  };

  gtk = {
    enable = true;
    theme = {
      name = palette.theme.gtk;
      package = pkgs.matcha-gtk-theme;
    };

    iconTheme = {
      name = palette.theme.icon;
      package = pkgs.papirus-icon-theme;
    };

    gtk3.extraConfig = { gtk-application-prefer-dark-theme = 1; };
    gtk4.extraConfig = { gtk-application-prefer-dark-theme = 1; };
    gtk4.theme = null;

    gtk3.extraCss = ''
      window.csd,
      window.solid-csd,
      decoration,
      decoration:backdrop {
        box-shadow: none;
        margin: 0;
        padding: 0;
        border: none;
      }

      dialog,
      messagedialog,
      dialog .dialog-vbox,
      messagedialog .dialog-vbox {
        background-color: ${c.mantle};
        color: ${c.text};
      }

      dialog headerbar,
      messagedialog headerbar {
        background-color: ${c.mantle};
        border-bottom: 1px solid ${c.border};
        color: ${c.text};
      }

      dialog entry,
      messagedialog entry {
        background-color: ${c.base};
        color: ${c.text};
        border: 1px solid ${c.border};
        border-radius: 8px;
        caret-color: ${c.accent};
      }

      dialog entry:focus,
      messagedialog entry:focus {
        border-color: ${c.accent};
        box-shadow: 0 0 0 1px ${c.accent};
      }

      dialog button,
      messagedialog button {
        background-color: ${c.surface0};
        color: ${c.text};
        border: 1px solid ${c.border};
        border-radius: 8px;
      }

      dialog button:hover,
      messagedialog button:hover {
        background-color: ${c.surface1};
        border-color: ${c.surface2};
      }

      dialog button.suggested-action,
      messagedialog button.suggested-action {
        background-color: ${c.accent};
        color: #ffffff;
        border-color: ${c.accent};
      }

      dialog button.suggested-action:hover,
      messagedialog button.suggested-action:hover {
        background-color: ${c.accentHover};
      }
    '';

    gtk4.extraCss = ''
      @define-color accent_color ${c.accent};
      @define-color accent_bg_color ${c.accent};
      @define-color accent_fg_color #ffffff;
      @define-color window_bg_color ${c.base};
      @define-color window_fg_color ${c.text};
      @define-color view_bg_color ${c.base};
      @define-color view_fg_color ${c.text};
      @define-color headerbar_bg_color ${c.mantle};
      @define-color headerbar_fg_color ${c.text};
      @define-color headerbar_border_color ${c.border};
      @define-color card_bg_color ${c.mantle};
      @define-color card_fg_color ${c.text};
      @define-color dialog_bg_color ${c.mantle};
      @define-color dialog_fg_color ${c.text};
      @define-color popover_bg_color ${c.mantle};
      @define-color popover_fg_color ${c.text};

      window.csd,
      window.solid-csd,
      decoration,
      decoration:backdrop {
        box-shadow: none;
        margin: 0;
        padding: 0;
        border: none;
      }

      window,
      dialog,
      alertdialog {
        background-color: ${c.mantle};
        color: ${c.text};
      }

      entry,
      passwordentry {
        background-color: ${c.base};
        color: ${c.text};
        border: 1px solid ${c.border};
        border-radius: 8px;
      }

      entry:focus-within,
      passwordentry:focus-within {
        border-color: ${c.accent};
        box-shadow: 0 0 0 1px ${c.accent};
      }

      button {
        background-color: ${c.surface0};
        color: ${c.text};
        border: 1px solid ${c.border};
        border-radius: 8px;
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
    '';
  };

  xdg.configFile."gtk-2.0/gtkfilechooser.ini".text = ''
    [Filechooser Settings]
    LocationMode=path-bar
    ShowHidden=false
    ShowSizeColumn=true
    SortColumn=modified
    SortOrder=descending
    StartupMode=recent
  '';

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = palette.theme.gtk;
      cursor-theme = palette.theme.cursor;
      icon-theme = palette.theme.icon;
    };
  };

  xresources.properties = {
    "Xcursor.theme" = palette.theme.cursor;
    "Xcursor.size" = palette.theme.cursorSize;
  };

  home.sessionVariables = {
    GTK_THEME = palette.theme.gtk;
    ICON_THEME = palette.theme.icon;
    CURSOR_THEME = palette.theme.cursor;
    CURSOR_SIZE = toString palette.theme.cursorSize;
    GTK2_RC_FILES = lib.mkForce "${pkgs.matcha-gtk-theme}/share/themes/${palette.theme.gtk}/gtk-2.0/gtkrc";
    GTK_USE_PORTAL = "1";
  };

  home.packages = with pkgs; [ xsettingsd ];

  xdg.configFile."xsettingsd/xsettingsd.conf".text = ''
    Net/ThemeName "${palette.theme.gtk}"
    Net/IconThemeName "${palette.theme.icon}"
    Gtk/CursorThemeName "${palette.theme.cursor}"
    Net/EnableEventSounds 1
    EnableInputFeedbackSounds 0
    Xft/Antialias 1
    Xft/Hinting 1
    Xft/HintStyle "hintslight"
    Xft/RGBA "rgb"
  '';

  xdg.configFile."autostart/xsettingsd.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=xsettingsd
    Exec=${pkgs.xsettingsd}/bin/xsettingsd
    Hidden=false
    NoDisplay=false
    X-GNOME-Autostart-enabled=true
  '';
}
