{
  lib,
  ...
}:
{
  imports = [
    ./dictation.nix
    ./idle.nix
    ./osk.nix
    ./display-toggle.nix
    ./window-manager.nix
    ./terminal.nix
  ];

  options.jstos.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }:
        {
          options.desktop.enable = lib.mkOption {
            type = lib.types.bool;
            default = config.enable;
            description = ''
              Whether to enable desktop defaults.
            '';
          };
        }
      )
    );
  };
}
