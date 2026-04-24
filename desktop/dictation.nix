{
  config,
  lib,
  pkgs,
  ...
}:
let
  userCfgs = lib.filterAttrs (_: cfg: cfg.enable) (
    lib.mapAttrs (_: cfg: cfg.desktop.dictation) config.jstos.users
  );
in
{
  options.jstos.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, config, ... }:
        let
          cfg = config.desktop.dictation;
        in
        {
          options.desktop.dictation = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether to enable dictation.
              '';
            };

            binding = lib.mkOption {
              type = lib.types.str;
              default = "Super d";
              description = ''
                Binding to use dictation.
              '';
            };

            command = lib.mkOption {
              type = lib.types.path;
              readOnly = true;
              default = pkgs.writeScript "toggle-dictation" ''
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
              description = ''
                Command to run when the binding is pressed.
              '';
            };
          };

          config.desktop.windowManager.bindings = lib.mkIf cfg.enable {
            ${cfg.binding}.normal.command = "spawn ${cfg.command}";
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
