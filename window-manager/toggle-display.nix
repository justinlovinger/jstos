{
  lib,
  pkgs,
  ...
}:
{
  options.jstos.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, config, ... }:
        let
          toggleDisplay = pkgs.writeScript "toggle-display" ''
            #!${lib.getExe pkgs.nushell}
            if (${lib.getExe pkgs.way-displays} -y -g | from yaml | get STATE | get HEADS | where NAME == ${cfg.name} | get 0 | get CURRENT | get ENABLED) {
              ${lib.getExe pkgs.way-displays} -s DISABLED ${cfg.name}
              ${
                if cfg.disableTouch.enable then
                  "${lib.getExe' pkgs.river "riverctl"} input ${cfg.disableTouch.input} events disabled"
                else
                  ""
              }
            } else {
              ${lib.getExe pkgs.way-displays} -d DISABLED ${cfg.name}
              ${
                if cfg.disableTouch.enable then
                  "${lib.getExe' pkgs.river "riverctl"} input ${cfg.disableTouch.input} events enabled"
                else
                  ""
              }
            }
          '';
          cfg = config.windowManager.toggleDisplay;
        in
        {
          options.windowManager.toggleDisplay = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              example = "true";
              description = ''
                Whether to enable the toggle-display key.
              '';
            };

            binding = lib.mkOption {
              type = lib.types.str;
              example = "None XF86AudioRaiseVolume";
              description = ''
                Binding to toggle display.
              '';
            };

            name = lib.mkOption {
              type = lib.types.str;
              default = "eDP-1";
              example = "DP-1";
              description = ''
                Name of display to toggle,
                as provided by `way-displays`.
              '';
            };

            disableTouch = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                example = "false";
                description = ''
                  Whether to disable a touchscreen when display is off.
                '';
              };

              input = lib.mkOption {
                type = lib.types.str;
                default = "touch-*";
                example = "touch-10248-4117-FTS3528:00_2808:1015";
                description = ''
                  Name of touchscreen to disable when display is off.
                '';
              };
            };
          };

          config.windowManager.bindings = lib.mkIf cfg.enable {
            ${cfg.binding} = {
              normal.command = "spawn ${toggleDisplay}";
              locked.enable = true;
            };
          };
        }
      )
    );
  };
}
