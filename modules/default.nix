{
  config,
  jstos-pkgs,
  lib,
  ...
}:
{
  imports = [
    ./colors.nix
    ./data.nix
    ./desktop
    ./shell
    ./system
  ];

  options.jstos = {
    enable = lib.mkEnableOption "JstOS defaults for this system and all JstOS users";

    documentation.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.jstos.enable;
      defaultText = lib.literalExpression "config.jstos.enable";
      description = ''
        Whether to enable documentation for JstOS.
      '';
    };

    userModules = lib.mkOption {
      type = lib.types.listOf lib.types.raw;
      default = [ ];
      description = ''
        Modules for all users.
        This is a convenience option for:

        ```
        options.jstos.users = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule (
              { ... }:
              {
                ...
              }
            )
          );
        };
        ```
      '';
    };

    users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule ({
          imports = config.jstos.userModules;

          options.enable = lib.mkOption {
            type = lib.types.bool;
            default = config.jstos.enable;
            defaultText = lib.literalExpression "config.jstos.enable";
            description = ''
              Whether to enable JstOS defaults for this user.
            '';
          };
        })
      );
      default = { };
      example = lib.literalExpression ''
        {
          john = {
            enable = true;
            desktop.dictation = true;
          };
        }
      '';
      description = "Mapping of users to JstOS options.";
    };
  };

  config = {
    environment.systemPackages = lib.mkIf config.jstos.documentation.enable [
      jstos-pkgs.jstos-manpage
    ];

    home-manager.users = lib.mapAttrs (
      user: cfg:
      lib.mkIf cfg.enable {
        # Other options may depend on these.
        home = {
          homeDirectory = "/home/${user}";
          stateVersion = "21.05";
          username = user;
        };
      }
    ) config.jstos.users;
  };
}
