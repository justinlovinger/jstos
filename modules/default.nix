{
  config,
  lib,
  pkgs,
  ...
}:
let
  options.jstos = {
    enable = lib.mkEnableOption "JstOS";

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
in
{
  imports = [
    ./device.nix
    ./system
    ./users
  ];

  inherit options;

  config = {
    environment.systemPackages = lib.mkIf config.jstos.documentation.enable [
      (
        let
          eval = pkgs.lib.evalModules {
            specialArgs = { inherit pkgs; };
            modules = [
              { _module.check = false; }
              {
                # Options from `./users`, and from extensions, get pulled in through `userModules`.
                imports = [
                  ./device.nix
                  ./system
                ];
                inherit options;
              }
            ];
          };
          optionsDocs = pkgs.nixosOptionsDoc {
            inherit (eval) options;
            documentType = "nixos";
          };
        in
        pkgs.runCommand "jstos-manpage"
          {
            nativeBuildInputs = [
              pkgs.buildPackages.installShellFiles
              pkgs.nixos-render-docs
            ];
            allowedReferences = [ "out" ];
          }
          ''
            mkdir -p $out/share/man/man5
            mkdir -p $out/share/man/man1
            nixos-render-docs -j $NIX_BUILD_CORES options manpage \
              --revision "" \
              --header "${builtins.toFile "jstos-configuration-nix-header.5" ''
                .TH "JSTOS-CONFIGURATION\&.NIX" "5" "01/01/1980" "JstOS"
                .\" disable hyphenation
                .nh
                .\" disable justification (adjust text to left margin only)
                .ad l
                .\" enable line breaks after slashes
                .cflags 4 /
                .SH "NAME"
                \fIjstos\-configuration\&.nix\fP \- JstOS configuration specification
                .SH "DESCRIPTION"
                .sp
                The following options are added to NixOS\&.
                .SH "OPTIONS"
                .PP
                You can use the following options in
                home\-configuration\&.nix:
                .PP
              ''}" \
              --footer ${builtins.toFile "jstos-configuration-nix-footer.5" ''
                .SH "AUTHORS"
                .PP
                Justin Lovinger
              ''} \
              ${optionsDocs.optionsJSON}/share/doc/nixos/options.json \
              $out/share/man/man5/jstos-configuration.nix.5
          ''
      )
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
        xdg.userDirs.setSessionVariables = true;
      }
    ) config.jstos.users;
  };
}
