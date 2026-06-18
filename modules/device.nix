{
  config,
  lib,
  ...
}:
let
  is = config.jstos.device.is;
  has = config.jstos.device.has;
  isOption =
    name:
    lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether device is a ${name}.
      '';
    };
in
{
  options.jstos.device = {
    is = {
      desktop = isOption "desktop";
      laptop = isOption "laptop";
      mobile = isOption "mobile";
      server = isOption "server";
    };
    has = {
      battery = lib.mkOption {
        type = lib.types.bool;
        default = is.laptop || is.mobile;
        defaultText = lib.literalExpression "is.laptop || is.mobile";
        description = ''
          Whether device has a battery.
        '';
      };
      builtInDisplay = lib.mkOption {
        type = lib.types.bool;
        default = is.laptop || is.mobile;
        defaultText = lib.literalExpression "is.laptop || is.mobile";
        description = ''
          Whether device has a built-in display.
        '';
      };
      compass = lib.mkOption {
        type = lib.types.bool;
        default = is.mobile;
        defaultText = lib.literalExpression "is.mobile";
        description = ''
          Whether device has a compass.
        '';
      };
      display = lib.mkOption {
        type = lib.types.bool;
        default = is.desktop || is.laptop || is.mobile || has.builtInDisplay;
        defaultText = lib.literalExpression "is.desktop || is.laptop || is.mobile || has.builtInDisplay";
        description = ''
          Whether device has a display.
        '';
      };
      ethernet = lib.mkOption {
        type = lib.types.bool;
        default = is.desktop;
        defaultText = lib.literalExpression "is.desktop";
        description = ''
          Whether device has ethernet.
        '';
      };
      gps = lib.mkOption {
        type = lib.types.bool;
        default = is.mobile;
        defaultText = lib.literalExpression "is.mobile";
        description = ''
          Whether device has GPS.
        '';
      };
      inPersonUsage = lib.mkOption {
        type = lib.types.bool;
        default = has.display;
        defaultText = lib.literalExpression "has.display";
        description = ''
          Whether device has regular in-person usage.
        '';
      };
      keyboard = lib.mkOption {
        type = lib.types.bool;
        default = is.desktop || is.laptop;
        defaultText = lib.literalExpression "is.desktop || is.laptop";
        description = ''
          Whether device has a keyboard always available.
        '';
      };
      lightSensor = lib.mkOption {
        type = lib.types.bool;
        default = is.mobile;
        defaultText = lib.literalExpression "is.mobile";
        description = ''
          Whether device has a light sensor.
        '';
      };
      microphone = lib.mkOption {
        type = lib.types.bool;
        default = is.laptop || is.mobile;
        defaultText = lib.literalExpression "is.laptop || is.mobile";
        description = ''
          Whether device has a microphone always available.
        '';
      };
      mobileData = lib.mkOption {
        type = lib.types.bool;
        default = is.mobile;
        defaultText = lib.literalExpression "is.mobile";
        description = ''
          Whether device has mobile data.
        '';
      };
      regularUsage = lib.mkOption {
        type = lib.types.bool;
        default = is.desktop || is.laptop || is.mobile || has.inPersonUsage;
        defaultText = lib.literalExpression "is.desktop || is.laptop || is.mobile || has.inPersonUsage";
        description = ''
          Whether device has regular usage by a person,
          either in-person or remotely.
        '';
      };
      wifi = lib.mkOption {
        type = lib.types.bool;
        default = is.laptop || is.mobile;
        defaultText = lib.literalExpression "is.laptop || is.mobile";
        description = ''
          Whether device has wifi.
        '';
      };
    };
  };
}
