{
  lib,
  ...
}:
{
  imports = [
    ./system.nix
    ./filesystems.nix
    ./shell
    ./terminal-browser
    ./window-manager
    ./go-game
  ];

  options.jstos = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { }));
    default = { };
    example = {
      john = {
        shell.enable = true;
        windowManager.enable = true;
      };
    };
    description = "Mapping of users to JstOS options.";
  };
}
