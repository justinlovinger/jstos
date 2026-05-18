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
            };

          hexOption =
            position: color:
            lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              default = rgbToHex cfg.rgb.${position}.${color};
            };

          hexWithoutHashOption =
            position: color:
            lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              default = stripLeadingChar cfg.hex.${position}.${color};
            };

          termOption =
            position: color:
            lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              default = (if position == "bg" then termBgColor else termFgColor) cfg.hex.${position}.${color};
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
          options.colors = lib.mkOption {
            type = lib.types.submodule {
              options = {
                hsl = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      bg = lib.genAttrs colors (hslOption "bg");
                      fg = lib.genAttrs colors (hslOption "fg");
                    };
                  };
                  default = { };
                  defaultText = lib.literalExpression "A custom theme with high contract and an even spread of hues.";
                  visible = "shallow";
                  description = ''
                    Colors in `{h = hhh.h; s = s.s; l = l.l;}` format.
                  '';
                };
                rgb = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      bg = lib.genAttrs colors (rgbOption "bg");
                      fg = lib.genAttrs colors (rgbOption "fg");
                    };
                  };
                  readOnly = true;
                  default = { };
                  defaultText = lib.literalExpression "Derived from `config.jstos.users.<name>.colors.hsl`.";
                  visible = "shallow";
                  description = ''
                    Colors in `{r = rrr; g = ggg; b = bbb;}` format.
                  '';
                };
                hex = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      bg = lib.genAttrs colors (hexOption "bg");
                      fg = lib.genAttrs colors (hexOption "fg");
                    };
                  };
                  readOnly = true;
                  default = { };
                  defaultText = lib.literalExpression "Derived from `config.jstos.users.<name>.colors.hsl`.";
                  visible = "shallow";
                  description = ''
                    Colors in `#rrggbb` format.
                  '';
                };
                hexWithoutHash = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      bg = lib.genAttrs colors (hexWithoutHashOption "bg");
                      fg = lib.genAttrs colors (hexWithoutHashOption "fg");
                    };
                  };
                  readOnly = true;
                  default = { };
                  defaultText = lib.literalExpression "Derived from `config.jstos.users.<name>.colors.hsl`.";
                  visible = "shallow";
                  description = ''
                    Colors in `rrggbb` format.
                  '';
                };
                term = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      bg = lib.genAttrs colors (termOption "bg");
                      fg = lib.genAttrs colors (termOption "fg");
                    };
                  };
                  readOnly = true;
                  default = { };
                  defaultText = lib.literalExpression "Derived from `config.jstos.users.<name>.colors.hsl`.";
                  visible = "shallow";
                  description = ''
                    Colors in terminal code format.
                  '';
                };
              };
            };
            default = { };
            defaultText = lib.literalExpression "A custom theme with high contract and an even spread of hues.";
            description = ''
              Colors in various formats.
              Colors other than `hsl` are derived from `hsl`.
              Current colors are available in `~/.local/share/colors.json` and `~/.local/share/color-columns.sh`.

              Each color format is a set of the form,

              ```
              {
                bg = <colors>;
                fg = <colors>;
              }
              ```

              where `<colors>` is a set of the form,

              ```
              {
                normal = <format>;
                faded = <format>;
                gray = <format>;
                red = <format>;
                orange = <format>;
                yellow = <format>;
                chartreuse = <format>;
                green = <format>;
                spring = <format>;
                cyan = <format>;
                azure = <format>;
                blue = <format>;
                violet = <format>;
                magenta = <format>;
                rose = <format>;
              }
              ```

              and `<format>` is the color format of the set.
            '';
          };

          config.colors.hsl =
            let
              grayHue = 0.0;
              redHue = 360.0; # Technically also 0, but 0 makes it gray
              orangeHue = 30.0;
              yellowHue = 60.0;
              chartreuseHue = 90.0;
              greenHue = 120.0;
              springHue = 150.0;
              cyanHue = 180.0;
              azureHue = 210.0;
              blueHue = 240.0;
              violetHue = 270.0;
              magentaHue = 300.0;
              roseHue = 330.0;

              saturation = 0.75;

              bgLuminosity = 0.2;
              fgLuminosity = 0.725;

              adjust =
                r: y: x:
                x + r * (y - x);

              hsl = h: s: l: { inherit h s l; };
            in
            rec {
              # Adjust saturation
              # of colors
              # that the human eye is extra sensitive to.
              bg = {
                normal = lib.mkDefault (hsl grayHue 0.0 0.0);
                faded = lib.mkDefault bg.gray;
                gray = lib.mkDefault (hsl grayHue 0.0 bgLuminosity);
                red = lib.mkDefault (hsl redHue saturation bgLuminosity);
                orange = lib.mkDefault (hsl orangeHue (adjust 0.05 0.0 saturation) bgLuminosity);
                yellow = lib.mkDefault (hsl yellowHue saturation bgLuminosity);
                chartreuse = lib.mkDefault (hsl chartreuseHue (adjust 0.05 0.0 saturation) bgLuminosity);
                green = lib.mkDefault (hsl greenHue (adjust 0.1 0.0 saturation) bgLuminosity);
                spring = lib.mkDefault (hsl springHue (adjust 0.05 0.0 saturation) bgLuminosity);
                cyan = lib.mkDefault (hsl cyanHue saturation bgLuminosity);
                azure = lib.mkDefault (hsl azureHue saturation bgLuminosity);
                blue = lib.mkDefault (hsl blueHue (adjust 0.1 0.0 saturation) bgLuminosity);
                violet = lib.mkDefault (hsl violetHue (adjust 0.05 0.0 saturation) bgLuminosity);
                magenta = lib.mkDefault (hsl magentaHue (adjust 0.05 0.0 saturation) bgLuminosity);
                rose = lib.mkDefault (hsl roseHue saturation bgLuminosity);
              };
              fg = {
                normal = lib.mkDefault (hsl grayHue 0.0 1.0);
                faded = lib.mkDefault fg.gray;
                gray = lib.mkDefault (hsl grayHue 0.0 fgLuminosity);
                red = lib.mkDefault (hsl redHue saturation fgLuminosity);
                orange = lib.mkDefault (hsl orangeHue (adjust 0.05 0.0 saturation) fgLuminosity);
                yellow = lib.mkDefault (hsl yellowHue saturation (adjust 0.1 0.0 fgLuminosity)); # Differentiate from white
                chartreuse = lib.mkDefault (hsl chartreuseHue (adjust 0.05 0.0 saturation) fgLuminosity);
                green = lib.mkDefault (hsl greenHue (adjust 0.1 0.0 saturation) fgLuminosity);
                spring = lib.mkDefault (hsl springHue (adjust 0.05 0.0 saturation) fgLuminosity);
                cyan = lib.mkDefault (hsl cyanHue saturation fgLuminosity);
                azure = lib.mkDefault (hsl azureHue (adjust 0.05 0.0 saturation) fgLuminosity);
                blue = lib.mkDefault (hsl blueHue (adjust 0.1 0.0 saturation) fgLuminosity);
                violet = lib.mkDefault (hsl violetHue (adjust 0.05 0.0 saturation) fgLuminosity);
                magenta = lib.mkDefault (hsl magentaHue saturation fgLuminosity);
                rose = lib.mkDefault (hsl roseHue saturation fgLuminosity);
              };
            };
        }
      )
    );
  };

  config = {
    home-manager.users = lib.mapAttrs (user: jstos: {
      # Color column script,
      # inspired by <https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/tools/screenshotTable.sh>.
      xdg.dataFile."color-columns.sh" = {
        executable = true;
        text = with jstos.colors.term; ''
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

      xdg.dataFile."colors.json".text = builtins.toJSON jstos.colors;
    }) config.jstos.users;
  };
}
