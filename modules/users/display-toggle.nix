{
  config,
  lib,
  pkgs,
  ...
}:
let
  config' = config;

  cfgs = map (jstos: jstos.displayToggle) (lib.attrValues config.jstos.users);
in
lib.mkMerge [
  {
    jstos.userModules = [
      (
        { config, ... }:
        let
          cfg = config.displayToggle;

          disable = ''
            try { ${lib.getExe pkgs.way-displays} -s DISABLED "!^${cfg.name}$" }
            ${
              if cfg.disableTouch.enable then
                "try { ${lib.getExe' pkgs.river-classic "riverctl"} input ${cfg.disableTouch.input} events disabled }"
              else
                ""
            }
            ${
              if config.brightnessControl.adaptiveBrightness.enable then
                "try { ${lib.getExe' pkgs.systemd "systemctl"} --user stop adaptive-brightness.service }"
              else
                ""
            }
          '';
          enable = ''
            try { ${lib.getExe pkgs.way-displays} -d DISABLED "!^${cfg.name}$" }
            ${
              if cfg.disableTouch.enable then
                "try { ${lib.getExe' pkgs.river-classic "riverctl"} input ${cfg.disableTouch.input} events enabled }"
              else
                ""
            }
            ${
              if config.brightnessControl.adaptiveBrightness.enable then
                "try { ${lib.getExe' pkgs.systemd "systemctl"} --user start adaptive-brightness.service }"
              else
                ""
            }
          '';
        in
        {
          options.displayToggle = {
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

            key = {
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
                    ${disable}
                  } else {
                    ${enable}
                  }
                '';
                defaultText = lib.literalExpression "toggle-display.sh";
                description = ''
                  Command to run when the binding is pressed.
                '';
              };
            };

            onLidClose = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                example = false;
                description = ''
                  Whether to disable the display when the lid is closed,
                  instead of putting the device to sleep.
                '';
              };
            };
          };

          config.windowManager.bindings = {
            ${cfg.key.binding} = lib.mkIf cfg.key.enable {
              normal.command = "spawn ${cfg.key.command}";
              locked.enable = true;
            };

            "lid close" = lib.mkIf cfg.onLidClose.enable {
              normal.command = "spawn ${pkgs.writeScript "disable-display.sh" ''
                #!${lib.getExe pkgs.nushell}
                ${disable}
              ''}";
              locked.enable = true;
            };
            "lid open" = lib.mkIf cfg.onLidClose.enable {
              normal.command = "spawn ${pkgs.writeScript "enable-display.sh" ''
                #!${lib.getExe pkgs.nushell}
                ${enable}
              ''}";
              locked.enable = true;
            };
          };
        }
      )
    ];
  }

  (lib.mkIf (builtins.any (cfg: cfg.onLidClose.enable) cfgs) {
    # The default is to suspend the device.
    services.logind.settings.Login.HandleLidSwitch = "ignore";
  })
]
