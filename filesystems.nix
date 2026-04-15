{
  config,
  lib,
  pkgs,
  ...
}:
let
  syncCfgs = lib.filterAttrs (_: cfg: cfg.enable) (lib.mapAttrs (_: cfg: cfg.sync) userCfgs);
  snapshotCfgs = lib.filterAttrs (_: cfg: cfg.enable) (lib.mapAttrs (_: cfg: cfg.snapshot) userCfgs);
  userCfgs = lib.filterAttrs (_: cfg: cfg.enable) (
    lib.mapAttrs (_: cfg: cfg.filesystems.data) config.jstos.users
  );
in
{
  options.jstos.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options.filesystems.data = {
            enable = lib.mkEnableOption "data";

            sync = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Whether or not to sync the data directory
                  with the remote server.
                '';
              };
              address = lib.mkOption {
                type = lib.types.str;
                example = "255.255.255.255";
                description = ''
                  Address of server to sync to.
                '';
              };
            };

            snapshot = {
              enable = lib.mkEnableOption "snapshot data";
              root = lib.mkOption {
                type = lib.types.str;
                default = "/home/${name}/data";
                description = ''
                  Root path of filesystem to snapshot.
                '';
              };
            };
          };
        }
      )
    );
  };

  config = lib.mkMerge [
    (lib.mkIf (syncCfgs != { }) {
      # Unison needs many inotify watches.
      boot.kernel.sysctl."fs.inotify.max_user_watches" = "2147483647";

      home-manager.users = lib.mapAttrs (
        user: cfg:
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          home.packages = [ pkgs.unison ];
          services.unison = {
            enable = true;
            pairs = {
              data = {
                roots = [
                  "/home/${user}/data"
                  "ssh://${cfg.address}//home/${user}/data"
                ];
                stateDirectory = "${config.home.homeDirectory}/.unison"; # Home Manager uses a different default than upstream.
                commandOptions = {
                  # Unison doesn't sync most metadata by default.
                  group = "true";
                  owner = "true";
                  perms = "-1";
                  times = "true";
                  acl = "true";
                  xattrs = "true";

                  # `copyonconflict` combined with `prefer newer`
                  # allows conflicts to be automatically resolved safely.
                  copyonconflict = "true";
                  prefer = "newer";

                  # Locks get in the way of automatic restarts,
                  # and systemd already ensures only one Unison sync per pair runs at a time.
                  ignorelocks = "true";

                  # By default,
                  # Unison fails to notice when the remote server stopped sending.
                  # `TCPKeepAlive` is a legacy option that rarely works
                  # but is enabled by default.
                  sshargs = "-o TCPKeepAlive=no -o ServerAliveInterval=10";

                  # BTRFS snapshots should not be synced.
                  ignore = "BelowPath .snapshots";

                  # Unison generates _many_ `[... blob data]` messages
                  # without `terse`.
                  # They are verbose
                  # and of little value.
                  terse = "true";

                  # As of 2025-02-27,
                  # Unison may crash while logging.
                  silent = "true";
                };
              };
            };
          };

          # The Unison services take too long to restart.
          systemd.user.timers.unison-pair-data = lib.mkForce { };
          systemd.user.services.unison-pair-data = {
            Install.WantedBy = [ "default.target" ];
            Service =
              let
                timestampFile = ''$"($env.XDG_RUNTIME_DIR)/unison-pair-data-timestamp"'';
              in
              {
                Restart = "always";
                RestartSec = "1s";
                RestartSteps = 10;
                RestartMaxDelaySec = "5min";
                # Systemd doesn't automatically reset the restart delay
                # because Unison never exits sucessfully.
                # There's no easy wasy to tell if Unison is fully started,
                # so we use a timeout instead.
                ExecStartPost = pkgs.writeScript "reset-backoff-start.nu" ''
                  #!${lib.getExe pkgs.nushell}
                  date now | save -f ${timestampFile}
                '';
                ExecStopPost = pkgs.writeScript "reset-backoff.nu" ''
                  #!${lib.getExe pkgs.nushell}
                  try {
                    let start = (open ${timestampFile})
                    rm ${timestampFile}
                    if ((date now) - ($start | into datetime) > 60sec) {
                      ${lib.getExe' pkgs.systemd "systemctl"} --user reset-failed unison-pair-data
                    }
                  }
                '';

                # Syncing on a metered connection could be expensive.
                # See <https://github.com/jdorel/systemd-metered-connection-dependency/blob/4a083159e20b444ac44340884d9563244ba91f7e/check-metered-connection.sh>
                # for `check-metered-connection.sh`.
                # Technically,
                # this only stops the service from _starting_ while on a metered connection.
                # In practice,
                # the service should fail and restart
                # when the connection changes.
                # Note,
                # an exit code of 1 through 254 prevents restarts.
                ExecCondition = pkgs.writeShellScript "check-metered-connection.sh" ''
                  metered_status=$(${lib.getExe' pkgs.dbus "dbus-send"} --system --print-reply=literal \
                    --system --dest=org.freedesktop.NetworkManager \
                    /org/freedesktop/NetworkManager \
                    org.freedesktop.DBus.Properties.Get \
                    string:org.freedesktop.NetworkManager string:Metered \
                    | ${lib.getExe pkgs.gnugrep} -o ".$")

                  if [[ $metered_status =~ (1|3) ]]; then
                    exit 255
                  else
                    exit 0
                  fi
                '';
              };
          };
        }
      ) syncCfgs;
    })
    (lib.mkIf (snapshotCfgs != { }) {
      services.snapper = {
        configs = lib.mapAttrs' (
          user: cfg:
          lib.nameValuePair (user + "-data") {
            SUBVOLUME = cfg.root;
            ALLOW_USERS = [ user ];
            TIMELINE_CREATE = true;
            TIMELINE_CLEANUP = true;
            TIMELINE_MIN_AGE = 60 * 60 * 8; # Seconds. This limits frequent snapshots.
            TIMELINE_LIMIT_HOURLY = 24;
            TIMELINE_LIMIT_DAILY = 7;
            TIMELINE_LIMIT_WEEKLY = 4;
            TIMELINE_LIMIT_MONTHLY = 6;
            TIMELINE_LIMIT_YEARLY = 0;
          }
        ) snapshotCfgs;
        snapshotInterval = "*:0/5";
      };

      # Snapper is very verbose by default,
      # and there is no option to reduce that verbosity.
      systemd.services.snapperd.serviceConfig.ExecStart =
        lib.mkForce "${lib.getExe' pkgs.snapper "snapperd"} --logger-type none";
    })
  ];
}
