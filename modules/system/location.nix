{
  config,
  lib,
  ...
}:
let
  cfg = config.jstos.system.location;
in
{
  options.jstos.system.location = {
    enable = lib.mkOption {
      type = lib.types.bool;
      # Note,
      # we assume if a device doesn't have a display
      # it isn't used in person
      # and therefore doesn't need location services.
      default =
        config.jstos.enable && config.jstos.device.has.regularUsage && config.jstos.device.has.display;
      defaultText = lib.literalExpression "config.jstos.enable && config.jstos.device.has.regularUsage && config.jstos.device.has.display";
      description = ''
        Whether to enable location services.
      '';
    };

    compass.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.jstos.device.has.compass;
      defaultText = lib.literalExpression "config.jstos.device.has.compass";
      description = ''
        Whether to enable compass for location services.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.geoclue2.enable = true;
    hardware.sensor.iio.enable = lib.mkIf cfg.compass.enable true;
  };
}
