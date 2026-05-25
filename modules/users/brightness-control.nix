{
  config,
  lib,
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
  })
]
