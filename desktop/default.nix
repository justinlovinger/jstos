{
  lib,
  ...
}:
{
  imports = [
    ./dictation.nix
    ./display-toggle.nix
    ./idle.nix
    ./map.nix
    ./osk.nix
    ./terminal.nix
    ./window-manager.nix
  ];

  jstos.userModules = [
    (
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
  ];
}
