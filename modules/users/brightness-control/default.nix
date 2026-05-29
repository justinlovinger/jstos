{
  config,
  lib,
  pkgs,
  ...
}:
let
  config' = config;

  cfgs = map (jstos: jstos.brightnessControl) (lib.attrValues config.jstos.users);
in
lib.mkMerge [
  {
    jstos.userModules = [
      (
        { config, ... }:
        let
          cfg = config.brightnessControl;
        in
        {
          options.brightnessControl = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default =
                config.enable && config'.jstos.device.has.regularUsage && config'.jstos.device.has.builtInDisplay;
              defaultText = lib.literalExpression "config.jstos.users.<name>.enable && config.jstos.device.has.regularUsage && config.jstos.device.has.builtInDisplay";
              description = ''
                Whether to enable brightness controls.
              '';
            };

            adaptiveBrightness = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = config'.jstos.device.has.lightSensor;
                defaultText = lib.literalExpression "config.jstos.device.has.lightSensor";
                description = ''
                  Whether to enable adaptive brightness.
                '';
              };
              settings = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = { };
                example = {
                  min = 0;
                  max = 100;
                  knee = 100000;
                };
                description = ''
                  Arguments passed to `adaptive-brightness.nu`.
                  See `adaptive-brightness.nu` for options.
                '';
              };
            };
          };

          config.windowManager.bindings = lib.mkIf cfg.enable {
            "None XF86MonBrightnessUp".normal = {
              command = "spawn 'brillo -A 3 -u 10000'";
              repeat = true;
            };
            "None XF86MonBrightnessDown".normal = {
              command = "spawn 'brillo -U 3 -u 10000'";
              repeat = true;
            };
          };
        }
      )
    ];
  }

  (lib.mkIf (builtins.any (cfg: cfg.enable) cfgs) {
    hardware.brillo.enable = true;
    # Brillo can change brightness
    # with a given minimum brightness,
    # defaulting to 1%,
    # so we don't need to change brightness on boot.
    boot.systemd.clampBacklight = lib.mkDefault false;

    hardware.sensor.iio.enable = lib.mkIf (builtins.any (cfg: cfg.adaptiveBrightness.enable) cfgs) true;
    home-manager.users = lib.mapAttrs (
      user: jstos:
      let
        cfg = jstos.brightnessControl;
      in
      { config, ... }:
      lib.mkIf cfg.adaptiveBrightness.enable {
        systemd.user.services.adaptive-brightness = {
          Unit = {
            Description = "Adaptive brightness";
            PartOf = config.wayland.systemd.target;
            Requires = config.wayland.systemd.target;
            After = config.wayland.systemd.target;
          };
          Install = {
            WantedBy = [ config.wayland.systemd.target ];
          };
          Service = {
            Type = "exec";
            Environment = "PATH=${
              lib.makeBinPath [
                pkgs.brillo
                pkgs.iio-sensor-proxy
                pkgs.nushell
                pkgs.systemd
              ]
            }";
            ExecStart = "${./adaptive-brightness.nu} ${
              lib.cli.toCommandLineShellGNU { } cfg.adaptiveBrightness.settings
            }";
            Restart = "always";
          };
        };
      }
    ) config.jstos.users;
  })
]
