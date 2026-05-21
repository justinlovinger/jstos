{
  config,
  lib,
  pkgs,
  ...
}:
let
  config' = config;
in
{
  jstos.userModules = [
    (
      { config, ... }:
      let
        cfg = config.desktop.displayToggle;
      in
      {
        options.desktop.displayToggle = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default =
              config.enable && config'.jstos.device.has.regularUsage && config'.jstos.device.has.builtInDisplay;
            defaultText = lib.literalExpression "config.jstos.users.<name>.enable && config.jstos.device.has.regularUsage && config.jstos.device.has.builtInDisplay";
            description = ''
              Whether to enable the toggle-display key.
            '';
          };

          binding = lib.mkOption {
            type = lib.types.str;
            default = "None XF86AudioLowerVolume";
            description = ''
              Binding to toggle display.
            '';
          };

          command = lib.mkOption {
            type = lib.types.path;
            readOnly = true;
            default = pkgs.writeScript "toggle-display.sh" ''
              #!${lib.getExe pkgs.nushell}
              if (${lib.getExe pkgs.way-displays} -y -g | from yaml | get STATE | get HEADS | where NAME == ${cfg.name} | get 0 | get CURRENT | get ENABLED) {
                ${lib.getExe pkgs.way-displays} -s DISABLED ${cfg.name}
                ${
                  if cfg.disableTouch.enable then
                    "${lib.getExe' pkgs.river-classic "riverctl"} input ${cfg.disableTouch.input} events disabled"
                  else
                    ""
                }
              } else {
                ${lib.getExe pkgs.way-displays} -d DISABLED ${cfg.name}
                ${
                  if cfg.disableTouch.enable then
                    "${lib.getExe' pkgs.river-classic "riverctl"} input ${cfg.disableTouch.input} events enabled"
                  else
                    ""
                }
              }
            '';
            defaultText = lib.literalExpression "toggle-display.sh";
            description = ''
              Command to run when the binding is pressed.
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
              example = false;
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

        config.desktop.windowManager.bindings = lib.mkIf cfg.enable {
          ${cfg.binding} = {
            normal.command = "spawn ${cfg.command}";
            locked.enable = true;
          };
        };
      }
    )
  ];
}
