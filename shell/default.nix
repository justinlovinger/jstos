{
  lib,
  ...
}:
{
  imports = [
    ./browser.nix
  ];

  jstos.userModules = [
    (
      { config, ... }:
      {
        options.shell.enable = lib.mkOption {
          type = lib.types.bool;
          default = config.enable;
          description = ''
            Whether to enable shell defaults.
          '';
        };
      }
    )
  ];
}
