{
  lib,
  ...
}:
{
  imports = [
    ./browser.nix
    ./editor.nix
    ./shell
  ];

  jstos.userModules = [
    (
      { config, ... }:
      {
        options.shell.enable = lib.mkOption {
          type = lib.types.bool;
          default = config.enable;
          defaultText = lib.literalExpression "config.jstos.users.<name>.enable";
          description = ''
            Whether to enable shell defaults.
          '';
        };
      }
    )
  ];
}
