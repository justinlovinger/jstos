{
  config,
  lib,
  pkgs,
  ...
}:
let
  osk = "${lib.getExe' pkgs.wvkbd "wvkbd-deskintl"}";
  oskState = ''$"($env.XDG_RUNTIME_DIR)/osk"'';

  userCfgs = lib.filterAttrs (_: cfg: cfg.enable) (
    lib.mapAttrs (_: cfg: cfg.desktop.osk) config.jstos.users
  );
in
{
  options.jstos.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }:
        let
          cfg = config.desktop.osk;
        in
        {
          options.desktop.osk = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether to enable the on-screen-keyboard.
              '';
            };

            binding = lib.mkOption {
              type = lib.types.str;
              example = "None XF86AudioRaiseVolume";
              description = ''
                Binding to toggle OSK.
              '';
            };

            command = lib.mkOption {
              type = lib.types.path;
              readOnly = true;
              default = pkgs.writeScript "toggle-osk" ''
                #!${lib.getExe pkgs.nushell}
                ${lib.getExe' pkgs.coreutils "kill"} -SIGRTMIN (open ${oskState})
              '';
              description = ''
                Command to run when the binding is pressed.
              '';
            };

            portrait.height = lib.mkOption {
              type = lib.types.int;
              default = 500;
              example = 600;
              description = ''
                Height of OSK in portrait mode.
              '';
            };
            landscape.height = lib.mkOption {
              type = lib.types.int;
              default = 300;
              example = 350;
              description = ''
                Height of OSK in landscape mode.
              '';
            };

            swipe = {
              enable = lib.mkEnableOption "swipe typing";

              wordList = lib.mkOption {
                type = lib.types.path;
                default = pkgs.runCommandLocal "words.txt" { } ''
                  ${lib.getExe' pkgs.coreutils "cut"} -f1 ${
                    pkgs.fetchurl {
                      url = "https://norvig.com/ngrams/count_1w.txt";
                      hash = "sha256-Ud8Vn9PeErIOQDwQj1JultvXI9nKvdXxeVXNwWBZ5pA=";
                    }
                  } > $out
                '';
                description = ''
                  Word list for SwipeGuess.
                '';
              };
            };
          };

          config.desktop.windowManager.bindings = lib.mkIf cfg.enable {
            ${cfg.binding} = {
              normal.command = "spawn ${cfg.command}";
              locked.enable = true;
            };
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
        systemd.user.services.osk = {
          Unit = {
            Description = "On-Screen-Keyboard Daemon";
            After = [ config.wayland.systemd.target ];
            PartOf = [ config.wayland.systemd.target ];
          };
          Install.WantedBy = [ config.wayland.systemd.target ];
          Service = {
            ExecStart =
              let
                oskCmd = "${osk} --hidden -H ${toString cfg.portrait.height} -L ${toString cfg.landscape.height}";
                completelyTypeWord = pkgs.writeShellApplication {
                  name = "completelyTypeWord.sh";
                  text = "${pkgs.swipe-guess.src}/completelyTypeWord.sh";
                  runtimeInputs = [ pkgs.wtype ];
                };
              in
              if cfg.swipe.enable then
                pkgs.writeShellScript "osk" ''
                  ${oskCmd} -O | ${lib.getExe pkgs.swipe-guess} ${cfg.swipe.wordList} | ${lib.getExe completelyTypeWord}
                ''
              else
                oskCmd;
            ExecStartPost = pkgs.writeScript "set-osk-pid" ''
              #!${lib.getExe pkgs.nushell}
              (open $"/sys/fs/cgroup(${lib.getExe' pkgs.systemd "systemctl"} --user show --property=ControlGroup --value osk.service)/cgroup.procs"
                  | lines
                  | where {|x| (${lib.getExe' pkgs.procps "ps"} --no-headers -o args $x | split row " " | get 0) == ${osk} }
                  | get 0
                  | save -f ${oskState})
            '';
            Restart = "always";
            StandardOutput = "journal";
          };
        };
      }
    ) userCfgs;
  };
}
