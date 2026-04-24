{
  lib,
  ...
}:
{
  imports = [
    ./desktop
    ./filesystems.nix
    ./go-game
    ./shell
    ./system
  ];

  options.jstos.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { }));
    default = { };
    example = {
      john = {
        desktop = {
          windowManager.enable = true;
          terminal.enable = true;
        };
      };
    };
    description = "Mapping of users to JstOS options.";
  };
}
