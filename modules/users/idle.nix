{
  config,
  lib,
  pkgs,
  ...
}:
let
  config' = config;
in
{
  jstos.userModules = [
    (
      { config, ... }:
      {
        options.idle = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.enable && (config'.jstos.device.has.display || !config'.jstos.device.is.server);
            defaultText = lib.literalExpression "config.jstos.users.<name>.enable && (config.jstos.device.has.display || !config.jstos.device.is.server)";
            description = ''
              Whether to enable idle timeouts.
            '';
          };

          displays = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = config'.jstos.device.has.display;
              defaultText = lib.literalExpression "config.jstos.device.has.display";
              description = ''
                Whether to enable blanking displays.
              '';
            };

            timeout = lib.mkOption {
              type = lib.types.int;
              default = 300;
              description = ''
                Idle seconds before display is blanked.
              '';
            };
          };

          lock = {
            # Without an OSK on the lockscreen,
            # users cannot unlock without a physical keyboard.
            enable = lib.mkOption {
              type = lib.types.bool;
              default = config'.jstos.device.has.display && config'.jstos.device.has.keyboard;
              defaultText = lib.literalExpression "config.jstos.device.has.display && config.jstos.device.has.keyboard";
              description = ''
                Whether to enable locking.
              '';
            };

            timeout = lib.mkOption {
              type = lib.types.int;
              default = config.idle.displays.timeout + 15;
              defaultText = lib.literalExpression "config.jstos.users.<name>.idle.displays.timeout + 15";
              description = ''
                Idle seconds before session is locked.
              '';
            };

            afterSuspend = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether or not to lock if system suspends for `lock.timeout`.
              '';
            };

            command = lib.mkOption {
              type = lib.types.str;
              default =
                with config.colors.hexWithoutHash;
                lib.concatStringsSep " " [
                  "${lib.getExe pkgs.swaylock}"

                  "--indicator-radius 100"

                  "--color ${bg.normal}"

                  "--key-hl-color ${fg.normal}"
                  "--bs-hl-color ${fg.normal}"
                  "--caps-lock-key-hl-color ${fg.yellow}"
                  "--caps-lock-bs-hl-color ${fg.yellow}"

                  "--inside-color ${bg.normal}"
                  "--inside-clear-color ${bg.normal}"
                  "--inside-caps-lock-color ${bg.normal}"
                  "--inside-ver-color ${bg.normal}"
                  "--inside-wrong-color ${bg.normal}"

                  "--layout-bg-color ${bg.normal}"
                  "--layout-border-color ${fg.normal}"
                  "--layout-text-color ${fg.normal}"

                  "--line-color ${fg.normal}"
                  "--line-clear-color ${fg.normal}"
                  "--line-caps-lock-color ${fg.yellow}"
                  "--line-ver-color ${fg.blue}"
                  "--line-wrong-color ${fg.red}"

                  "--ring-color ${bg.normal}"
                  "--ring-clear-color ${bg.normal}"
                  "--ring-caps-lock-color ${bg.normal}"
                  "--ring-ver-color ${fg.blue}"
                  "--ring-wrong-color ${fg.red}"

                  "--separator-color ${bg.normal}"

                  "--text-color ${fg.normal}"
                  "--text-clear-color ${fg.normal}"
                  "--text-caps-lock-color ${fg.normal}"
                  "--text-ver-color ${fg.normal}"
                  "--text-wrong-color ${fg.normal}"
                ];
              defaultText = lib.literalExpression "swaylock";
              description = ''
                Command to lock session.

                Note,
                `swaylock` must run without `-f`,
                so post-lock commands wait
                for lock to end.
              '';
            };
          };

          suspend = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = !config'.jstos.device.is.server;
              defaultText = lib.literalExpression "!config.jstos.device.is.server";
              description = ''
                Whether to enable suspending.
              '';
            };

            timeout = lib.mkOption {
              type = lib.types.int;
              default = config.idle.displays.timeout + 30;
              defaultText = lib.literalExpression "config.jstos.users.<name>.idle.displays.timeout + 30";
              description = ''
                Idle seconds before machine suspends.
              '';
            };
          };
        };
      }
    )
  ];

  home-manager.users = lib.mapAttrs (
    user: jstos:
    let
      cfg = jstos.idle;

      lockCommand = "${lib.getExe' pkgs.systemd "systemctl"} --user start lock.service";
      lockScript = pkgs.writeShellScript "lock.sh" ''
        # Reduce screen blank timeout
        # for lockscreen.
        ${lib.getExe pkgs.swayidle} -w \
          timeout 15 '${disableAll lockDisplaysState}' \
          resume '${enableAll lockDisplaysState}' &
        swayidle_pid=$!

        ${cfg.lock.command}
        swaylock_ret=$?

        ${enableAll lockDisplaysState}
        kill $swayidle_pid
        exit $swaylock_ret
      '';

      lockBeforeSuspendScript = pkgs.writeShellScript "lock-before-suspend.sh" ''
        ${lib.getExe' pkgs.coreutils "date"} +%s > "${timestampFile}"
      '';
      lockAfterSuspendScript = pkgs.writeShellScript "lock-after-suspend.sh" ''
        read -r before < "${timestampFile}"
        current=$( ${lib.getExe' pkgs.coreutils "date"} +%s )
        elapsed=$(( current - before ))

        if (( elapsed > ${toString cfg.lock.timeout} )); then
          exec ${lockCommand}
        fi
      '';
      timestampFile = "$XDG_RUNTIME_DIR/lock-after-suspend-timestamp";

      disableAll =
        state:
        pkgs.writeScript "disable-all" ''
          #!${lib.getExe pkgs.nushell}
          let displays = (${lib.getExe pkgs.way-displays} -y -g | from yaml | get STATE | get HEADS | where CURRENT.ENABLED | get NAME)
          $displays | save -f ${state}
          $displays | each {|o| try { ${lib.getExe pkgs.way-displays} -s DISABLED $o } } | ignore
          ${
            if jstos.brightnessControl.adaptiveBrightness.enable then
              "${lib.getExe' pkgs.systemd "systemctl"} --user stop adaptive-brightness.service"
            else
              ""
          }
        '';
      enableAll =
        state:
        pkgs.writeScript "enable-all" ''
          #!${lib.getExe pkgs.nushell}
          open ${state} | lines | each {|o| try { ${lib.getExe pkgs.way-displays} -d DISABLED $o } } | ignore
          rm ${state}
          ${
            if jstos.brightnessControl.adaptiveBrightness.enable then
              "${lib.getExe' pkgs.systemd "systemctl"} --user start adaptive-brightness.service"
            else
              ""
          }
        '';

      displaysState = ''$"($env.XDG_RUNTIME_DIR)/idle-displays"'';
      lockDisplaysState = ''$"($env.XDG_RUNTIME_DIR)/lock-idle-displays"'';
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          services.swayidle = {
            enable = true;
          };
          services.wayland-pipewire-idle-inhibit.enable = true;
        }

        (lib.mkIf cfg.displays.enable {
          services.swayidle.timeouts = [
            {
              timeout = cfg.displays.timeout;
              command = builtins.toString (disableAll displaysState);
              resumeCommand = builtins.toString (enableAll displaysState);
            }
          ];
        })

        (lib.mkIf cfg.lock.enable (
          lib.mkMerge [
            {
              services.swayidle = {
                events = [
                  {
                    event = "lock";
                    command = lockCommand;
                  }
                ];
                timeouts = [
                  {
                    timeout = cfg.lock.timeout;
                    command = lockCommand;
                  }
                ];
              };

              systemd.user.services.lock = {
                Unit = {
                  Description = "lock user session";
                  StartLimitIntervalSec = 0;
                };
                Service = {
                  ExecStart = toString lockScript;
                  Restart = "on-failure";
                };
              };
            }

            (lib.mkIf cfg.lock.afterSuspend {
              services.swayidle.events = [
                {
                  event = "before-sleep";
                  command = builtins.toString lockBeforeSuspendScript;
                }
                {
                  event = "after-resume";
                  command = builtins.toString lockAfterSuspendScript;
                }
              ];
            })
          ]
        ))

        (lib.mkIf cfg.suspend.enable {
          services.swayidle.timeouts = [
            {
              timeout = cfg.suspend.timeout;
              command = "${lib.getExe' pkgs.systemd "systemctl"} --user start suspend";
              resumeCommand = "${lib.getExe' pkgs.systemd "systemctl"} --user stop suspend";
            }
          ];

          systemd.user.services.suspend = {
            Unit.Description = "suspend";
            Service = {
              ExecStart = pkgs.writeScript "suspend" ''
                #!${lib.getExe pkgs.nushell}
                loop {
                  try { ${lib.getExe' pkgs.systemd "systemctl"} suspend }
                  sleep 1min
                }
              '';
            };
          };
        })
      ]
    )
  ) config.jstos.users;
}
