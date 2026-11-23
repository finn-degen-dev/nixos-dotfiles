{ palette, ... }:

let
  c = palette.colors;
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        padding = {
          x = 12;
          y = 12;
        };
        opacity = 0.95;
      };

      font = {
        normal = {
          family = palette.font.mono;
          style = "Regular";
        };
        bold = {
          family = palette.font.mono;
          style = "Bold";
        };
        italic = {
          family = palette.font.mono;
          style = "Italic";
        };
        size = palette.font.size + 0.0;
      };

      colors = {
        primary = {
          background = c.base;
          foreground = c.text;
        };

        cursor = {
          text = c.base;
          cursor = c.text;
        };

        selection = {
          text = c.text;
          background = c.surface1;
        };

        normal = {
          black = c.surface0;
          red = c.red;
          green = c.green;
          yellow = c.yellow;
          blue = c.blue;
          magenta = c.mauve;
          cyan = c.teal;
          white = c.text;
        };

        bright = {
          black = c.overlay0;
          red = c.brightRed;
          green = c.brightGreen;
          yellow = c.brightYellow;
          blue = c.brightBlue;
          magenta = c.brightMauve;
          cyan = c.brightTeal;
          white = c.white;
        };
      };
    };
  };
}
