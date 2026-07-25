{
  lib,
  ...
}:
{
  imports = [
    ./brightness-control
    ./colors.nix
    ./dictation.nix
    ./display-toggle.nix
    ./editor.nix
    ./idle.nix
    ./map.nix
    ./osk.nix
    ./shell
    ./shell-browser.nix
    ./terminal.nix
    ./window-manager.nix
  ];

  jstos.userModules = [
    (
      { config, ... }:
      {
        options.webSearch = lib.mkOption {
          type = lib.types.enum [
            "paid"
            "system"
            "direct"
          ];
          default = "system";
          description = ''
            Default web search method to use across the user.
          '';
        };
      }
    )
  ];
}
