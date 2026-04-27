{
  config,
  lib,
  ...
}:
{
  imports = [
    ./memory.nix
  ];

  options.jstos.system.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.jstos.enable;
    description = ''
      Whether to enable JstOS defaults for this system.
    '';
  };
}
