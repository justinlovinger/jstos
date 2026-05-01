{
  config,
  lib,
  ...
}:
{
  imports = [
    ./colors.nix
    ./desktop
    ./filesystems.nix
    ./go-game
    ./shell
    ./system
  ];

  options.jstos = {
    enable = lib.mkEnableOption "JstOS defaults for this system and all JstOS users";

    users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule ({
          options.enable = lib.mkOption {
            type = lib.types.bool;
            default = config.jstos.enable;
            description = ''
              Whether to enable JstOS defaults for this user.
            '';
          };
        })
      );
      default = { };
      example = {
        john = {
          enable = true;
          desktop.dictation = true;
        };
      };
      description = "Mapping of users to JstOS options.";
    };
  };
}
