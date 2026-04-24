{
  config,
  lib,
  ...
}:
let
  userCfgs = lib.filterAttrs (_: cfg: cfg.enable) (
    lib.mapAttrs (_: cfg: cfg.shell.browser) config.jstos.users
  );
in
{
  options.jstos.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { ... }:
        {
          options.shell.browser = {
            enable = lib.mkEnableOption "shell browser";
          };
        }
      )
    );
  };

  config = {
    home-manager.users = lib.mapAttrs (
      user: cfg:
      {
        config,
        pkgs,
        ...
      }:
      {
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
      }
    ) userCfgs;
  };
}
