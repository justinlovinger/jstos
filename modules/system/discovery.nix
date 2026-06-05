{
  config,
  lib,
  ...
}:
let
  cfg = config.jstos.system.discovery;
in
{
  options.jstos.system.discovery = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default =
        config.jstos.enable
        && config.jstos.device.has.regularUsage
        && config.jstos.device.has.inPersonUsage;
      defaultText = lib.literalExpression "config.jstos.enable && config.jstos.device.has.regularUsage && config.jstos.device.has.inPersonUsage";
      description = ''
        Whether to enable local discovery.
        Access local machines via `HOSTNAME.local`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };
  };
}
