{
  config,
  lib,
  pkgs,
  ...
}:
{
  jstos.userModules = [
    (
      { config, ... }:
      {
        options.shell.browser = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.shell.enable;
            defaultText = lib.literalExpression "config.jstos.users.<name>.shell.enable";
            description = ''
              Whether to enable the shell browser.
            '';
          };
        };
      }
    )
  ];

  home-manager.users = lib.mapAttrs (
    user: jstos:
    let
      cfg = jstos.shell.browser;
    in
    lib.mkIf cfg.enable {
      home.packages = [
        pkgs.chawan
      ];

      xdg.configFile."chawan/config.toml".source = (pkgs.formats.toml { }).generate "config.toml" {
        buffer.scripting = true;
        display.color-mode = "true-color";
        # Note,
        # I could not get `cmd.buffer.CMD` working.
        page = {
          q = "";
          Q = "() => quit()";

          h = "n => pager.scrollLeft(n)";
          j = "n => pager.scrollDown(n)";
          k = "n => pager.scrollUp(n)";
          l = "n => pager.scrollRight(n)";

          u = "n => pager.halfPageUp(n)";
          d = "n => pager.halfPageDown(n)";

          H = "n => pager.cursorLeft(n)";
          J = "n => pager.cursorDown(n)";
          K = "n => pager.cursorUp(n)";
          L = "n => pager.cursorRight(n)";
        };
      };

      programs.nushell.extraConfig = lib.mkIf jstos.shell.enable ''
        def ? [...query: string] {
          cha $"https://lite.duckduckgo.com/lite?kp=-1&kd=-1&q=($query | str join ' ' | url encode --all)"
        }
      '';
    }
  ) config.jstos.users;

}
