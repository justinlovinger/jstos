{
  lib,
  ...
}:
{
  imports = [
    ./system.nix
    ./filesystems.nix
    ./terminal
    ./terminal-browser
    ./window-manager
    ./go-game
  ];

  options.jstos.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: { }));
    default = { };
    example = {
      john = {
        terminal.enable = true;
        windowManager.enable = true;
      };
    };
    description = "Mapping of users to JstOS options.";
  };
}
