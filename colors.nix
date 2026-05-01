{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.jstos.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }:
        let
          colors = [
            "normal"
            "faded"
            "gray"
            "red"
            "orange"
            "yellow"
            "chartreuse"
            "green"
            "spring"
            "cyan"
            "azure"
            "blue"
            "violet"
            "magenta"
            "rose"
          ];

          hslOption =
            position: color:
            lib.mkOption {
              type = lib.types.submodule {
                options = {
                  h = lib.mkOption { type = lib.types.float; };
                  s = lib.mkOption { type = lib.types.float; };
                  l = lib.mkOption { type = lib.types.float; };
                };
              };
              description = ''
                ${
                  if position == "bg" then "Background" else "Foreground"
                } ${color} color in `{h = hhh.h; s = s.s; l = l.l;}` format.
              '';
            };

          rgbOption =
            position: color:
            lib.mkOption {
              type = lib.types.submodule {
                options = {
                  r = lib.mkOption { type = lib.types.int; };
                  g = lib.mkOption { type = lib.types.int; };
                  b = lib.mkOption { type = lib.types.int; };
                };
              };
              readOnly = true;
              default = hslToRgb cfg.hsl.${position}.${color};
              description = ''
                ${
                  if position == "bg" then "Background" else "Foreground"
                } ${color} color in `{r = rrr; g = ggg; b = bbb;}` format.
              '';
            };

          hexOption =
            position: color:
            lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              default = rgbToHex cfg.rgb.${position}.${color};
              description = ''
                ${if position == "bg" then "Background" else "Foreground"} ${color} color in `#rrggbb` format.
              '';
            };

          hexWithoutHashOption =
            position: color:
            lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              default = stripLeadingChar cfg.hex.${position}.${color};
              description = ''
                ${if position == "bg" then "Background" else "Foreground"} ${color} color in `rrggbb` format.
              '';
            };

          termOption =
            position: color:
            lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              default = (if position == "bg" then termBgColor else termFgColor) cfg.hex.${position}.${color};
              description = ''
                ${if position == "bg" then "Background" else "Foreground"} ${color} color in terminal format.
              '';
            };

          rgbToHex =
            {
              r,
              g,
              b,
            }:
            let
              intToHex =
                n:
                let
                  d1 = n / 16;
                  d2 = lib.mod n 16;
                  dtc =
                    d:
                    if d == 15 then
                      "f"
                    else if d == 14 then
                      "e"
                    else if d == 13 then
                      "d"
                    else if d == 12 then
                      "c"
                    else if d == 11 then
                      "b"
                    else if d == 10 then
                      "a"
                    else
                      toString d;
                in
                "${dtc d1}${dtc d2}";
            in
            "#${intToHex r}${intToHex g}${intToHex b}";

          hslToRgb =
            {
              h,
              s,
              l,
            }:
            let
              asInt = n: round (n * 255);
              # Equation from <https://en.wikipedia.org/wiki/HSL_and_HSV#HSL_to_RGB_alternative>.
              f =
                n:
                let
                  inherit (lib) min max;
                  k = fracmod (n + (h / 30)) 12;
                  a = s * (min l (1.0 - l));
                in
                if h == 0 then l else l - a * (max (-1.0) (min (k - 3.0) (min (9.0 - k) 1.0)));
              fracmod =
                n: base:
                let
                  decimalpart = n: n - (floor n);
                in
                (lib.mod (floor n) base) + (decimalpart n);
              r = f 0;
              g = f 8;
              b = f 4;
            in
            {
              r = asInt r;
              g = asInt g;
              b = asInt b;
            };

          round = n: floor (n + 0.5);

          floor = with lib.strings; n: toInt (builtins.head (splitString "." (toString n)));

          stripLeadingChar = s: (builtins.substring 1 ((builtins.stringLength s) - 1) s);

          termBgColor = c: "48;2;${termColor c}";
          termFgColor = c: "38;2;${termColor c}";
          termColor =
            c:
            let
              inherit (builtins) substring;
              hexToDecStr = h: toString (hexToDec h);
              hexToDec =
                h:
                let
                  h1 = substring 0 1 h;
                  h2 = substring 1 1 h;
                  htd =
                    h:
                    if h == "f" then
                      15
                    else if h == "e" then
                      14
                    else if h == "d" then
                      13
                    else if h == "c" then
                      12
                    else if h == "b" then
                      11
                    else if h == "a" then
                      10
                    else
                      lib.strings.toInt h;
                in
                (htd h1) * 16 + (htd h2);
            in
            "${hexToDecStr (substring 1 2 c)};${hexToDecStr (substring 3 2 c)};${hexToDecStr (substring 5 2 c)}";

          cfg = config.colors;
        in
        {
          options.colors = {
            hsl = {
              bg = lib.genAttrs colors (hslOption "bg");
              fg = lib.genAttrs colors (hslOption "fg");
            };
            rgb = {
              bg = lib.genAttrs colors (rgbOption "bg");
              fg = lib.genAttrs colors (rgbOption "fg");
            };
            hex = {
              bg = lib.genAttrs colors (hexOption "bg");
              fg = lib.genAttrs colors (hexOption "fg");
            };
            hexWithoutHash = {
              bg = lib.genAttrs colors (hexWithoutHashOption "bg");
              fg = lib.genAttrs colors (hexWithoutHashOption "fg");
            };
            term = {
              bg = lib.genAttrs colors (termOption "bg");
              fg = lib.genAttrs colors (termOption "fg");
            };
          };
        }
      )
    );
  };

  config = {
    home-manager.users = lib.mapAttrs (user: cfg: {
      # Color column script,
      # inspired by <https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/tools/screenshotTable.sh>.
      xdg.dataFile."color-columns.sh" = {
        executable = true;
        text = with cfg.colors.term; ''
          #!${lib.getExe pkgs.bash}
          text='gYw'

          printf "\n  bgNor   bgFad   bgGra   bgRed   bgGre   bgYel   bgBlu   bgMag   bgCya   bgRos   bgCha   bgOra   bgAzu   bgVio   bgSpr\n";
          for fg in "${fg.normal}" "${fg.faded}" "${fg.gray}" "${fg.red}" "${fg.green}" "${fg.yellow}" "${fg.blue}" "${fg.magenta}" "${fg.cyan}" "${fg.rose}" "${fg.chartreuse}" "${fg.orange}" "${fg.azure}" "${fg.violet}" "${fg.spring}"; do
            for bg in "${bg.normal}" "${bg.faded}" "${bg.gray}" "${bg.red}" "${bg.green}" "${bg.yellow}" "${bg.blue}" "${bg.magenta}" "${bg.cyan}" "${bg.rose}" "${bg.chartreuse}" "${bg.orange}" "${bg.azure}" "${bg.violet}" "${bg.spring}"; do
              printf "$EINS \033[''${fg};''${bg}m  $text  \033[0m";
            done
            echo;
          done
          echo
        '';
      };

      xdg.dataFile."colors.json".text = builtins.toJSON cfg.colors;
    }) config.jstos.users;
  };
}
