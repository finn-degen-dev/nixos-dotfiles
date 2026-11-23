{ palette, ... }:

let
  c = palette.colors;
in
{
  programs.kitty = {
    enable = true;
    font = {
      name = palette.font.mono;
      size = palette.font.size;
    };
    settings = {
      background = c.base;
      foreground = c.text;
      cursor = c.text;
      cursor_text_color = c.base;
      selection_foreground = c.text;
      selection_background = c.surface1;
      color0 = c.surface0;
      color1 = c.red;
      color2 = c.green;
      color3 = c.yellow;
      color4 = c.blue;
      color5 = c.mauve;
      color6 = c.teal;
      color7 = c.text;
      color8 = c.overlay0;
      color9 = c.brightRed;
      color10 = c.brightGreen;
      color11 = c.brightYellow;
      color12 = c.brightBlue;
      color13 = c.brightMauve;
      color14 = c.brightTeal;
      color15 = c.white;
      window_padding_width = 12;
      background_opacity = "0.95";
      confirm_os_window_close = 0;
      enable_audio_bell = false;
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      tab_bar_min_tabs = 2;
      active_tab_foreground = "#ffffff";
      active_tab_background = c.accent;
      active_tab_font_style = "bold";
      inactive_tab_foreground = c.overlay1;
      inactive_tab_background = c.surface0;
      tab_bar_background = c.base;
    };
    keybindings = {
      "alt+1" = "goto_tab 1";
      "alt+2" = "goto_tab 2";
      "alt+3" = "goto_tab 3";
    };
  };
}
