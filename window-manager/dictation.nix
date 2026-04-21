{
  config,
  lib,
  pkgs,
  ...
}:
let
  toggleDictation = pkgs.writeScript "toggle-dictation" ''
    #!${lib.getExe pkgs.nushell}
    let state = $"($env.XDG_RUNTIME_DIR)/dictation"
    if ($state | path exists) {
      rm $state
      whisp-away stop
    } else {
      whisp-away start
      touch $state
    }
  '';

  userCfgs = lib.filterAttrs (_: cfg: cfg.enable) (
    lib.mapAttrs (_: cfg: cfg.windowManager.dictation) config.jstos.users
  );
in
{
  options.jstos.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, config, ... }:
        {
          options.windowManager.dictation = {
            enable = lib.mkEnableOption "dictation";

            binding = lib.mkOption {
              type = lib.types.str;
              default = "Super d";
              description = ''
                Binding to use dictation.
              '';
            };
          };

          config.windowManager.bindings = lib.mkIf config.windowManager.dictation.enable {
            ${config.windowManager.dictation.binding}.normal.command = "spawn ${toggleDictation}";
          };
        }
      )
    );
  };

  config = {
    home-manager.users = lib.mapAttrs (
      user: cfg:
      {
        config,
        lib,
        pkgs,
        ...
      }:
      lib.mkIf cfg.enable {
        services.whisp-away.enable = true;

        systemd.user.services.whisp-away = {
          Unit = {
            Description = "whisp-away";
            PartOf = config.wayland.systemd.target;
            Requires = config.wayland.systemd.target;
            After = config.wayland.systemd.target;
            X-Restart-Triggers = [ config.xdg.configFile."whisp-away/config.json".source ];
          };
          Install = {
            WantedBy = [ config.wayland.systemd.target ];
          };
          Service = {
            Environment = "WHISPAWAY=${config.home.profileDirectory}/bin/whisp-away"; # WhispAway does not easily expose its package.
            ExecStart = toString (pkgs.writeShellScript "dictation-exec" "$WHISPAWAY daemon");
            Restart = "always";
          };
        };
      }
    ) userCfgs;
  };
}
