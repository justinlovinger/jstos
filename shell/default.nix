{
  lib,
  ...
}:
{
  imports = [
    ./browser.nix
  ];

  options.jstos.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
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
    );
  };
}
