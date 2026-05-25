{
  config,
  jstos-pkgs,
  lib,
  ...
}:
{
  imports = [
    ./system
    ./users
  ];

  options.jstos = {
    enable = lib.mkEnableOption "JstOS";

    device =
      let
        is = config.jstos.device.is;
        has = config.jstos.device.has;
        isOption =
          name:
          lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether device is a ${name}.
            '';
          };
      in
      {
        is = {
          desktop = isOption "desktop";
          laptop = isOption "laptop";
          mobile = isOption "mobile";
          server = isOption "server";
        };
        has = {
          battery = lib.mkOption {
            type = lib.types.bool;
            default = is.laptop || is.mobile;
            defaultText = lib.literalExpression "is.laptop || is.mobile";
            description = ''
              Whether device has a battery.
            '';
          };
          builtInDisplay = lib.mkOption {
            type = lib.types.bool;
            default = is.laptop || is.mobile;
            defaultText = lib.literalExpression "is.laptop || is.mobile";
            description = ''
              Whether device has a built-in display.
            '';
          };
          display = lib.mkOption {
            type = lib.types.bool;
            default = is.desktop || is.laptop || is.mobile || has.builtInDisplay;
            defaultText = lib.literalExpression "is.desktop || is.laptop || is.mobile || has.builtInDisplay";
            description = ''
              Whether device has a display.
            '';
          };
          ethernet = lib.mkOption {
            type = lib.types.bool;
            default = is.desktop;
            defaultText = lib.literalExpression "is.desktop";
            description = ''
              Whether device has ethernet.
            '';
          };
          gps = lib.mkOption {
            type = lib.types.bool;
            default = is.mobile;
            defaultText = lib.literalExpression "is.mobile";
            description = ''
              Whether device has GPS.
            '';
          };
          keyboard = lib.mkOption {
            type = lib.types.bool;
            default = is.desktop || is.laptop;
            defaultText = lib.literalExpression "is.desktop || is.laptop";
            description = ''
              Whether device has a keyboard always available.
            '';
          };
          microphone = lib.mkOption {
            type = lib.types.bool;
            default = is.laptop || is.mobile;
            defaultText = lib.literalExpression "is.laptop || is.mobile";
            description = ''
              Whether device has a microphone always available.
            '';
          };
          mobileData = lib.mkOption {
            type = lib.types.bool;
            default = is.mobile;
            defaultText = lib.literalExpression "is.mobile";
            description = ''
              Whether device has mobile data.
            '';
          };
          regularUsage = lib.mkOption {
            type = lib.types.bool;
            default = is.desktop || is.laptop || is.mobile;
            defaultText = lib.literalExpression "is.desktop || is.laptop || is.mobile";
            description = ''
              Whether device has regular usage by a person,
              either physically or remotely.
            '';
          };
          wifi = lib.mkOption {
            type = lib.types.bool;
            default = is.laptop || is.mobile;
            defaultText = lib.literalExpression "is.laptop || is.mobile";
            description = ''
              Whether device has wifi.
            '';
          };
        };
      };

    documentation.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.jstos.enable && config.jstos.device.has.regularUsage;
      defaultText = lib.literalExpression "config.jstos.enable && config.jstos.device.has.regularUsage";
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
          john = { };
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
