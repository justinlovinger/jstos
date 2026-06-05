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
      default =
        config.jstos.enable
        && config.jstos.device.has.regularUsage
        && config.jstos.device.has.inPersonUsage;
      defaultText = lib.literalExpression "config.jstos.enable && config.jstos.device.has.regularUsage && config.jstos.device.has.inPersonUsage";
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
