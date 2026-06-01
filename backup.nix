{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkMerge [
  {
    jstos.userModules = [
      (
        {
          name,
          config,
          ...
        }:
        {
          options.backup = {
            home = {
              root = lib.mkOption {
                type = lib.types.str;
                default = "/home/${name}";
                description = ''
                  Root path of home directory.
                '';
              };

              snapshot = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = ''
                    Whether to take periodic snapshots
                    of the home directory.
                    This requires the home directory be on a filesystem supporting snapshots,
                    like BTRFS.
                    Ideally,
                    the home directory is the root of its filesystem.
                  '';
                };
                root = lib.mkOption {
                  type = lib.types.str;
                  default = config.backup.home.root;
                  defaultText = lib.literalExpression "config.jstos.users.<name>.backup.home.root";
                  description = ''
                    Root path of filesystem to snapshot.
                  '';
                };
              };
            };

            data = {
              root = lib.mkOption {
                type = lib.types.str;
                default = "/home/${name}/data";
                description = ''
                  Root path of data directory on this machine.
                '';
              };

              sync = {
                address = lib.mkOption {
                  type = lib.types.str;
                  example = "255.255.255.255";
                  description = ''
                    Address of server to sync to.
                  '';
                };
                root = lib.mkOption {
                  type = lib.types.str;
                  default = config.backup.data.root;
                  defaultText = lib.literalExpression "config.jstos.users.<name>.backup.data.root";
                  description = ''
                    Root path of data directory at `address`.
                  '';
                };
                client.enable = lib.mkEnableOption "syncing data directory with the server at `address`";
                server.enable = lib.mkEnableOption "syncing data directory with this machine";
              };

              snapshot = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = ''
                    Whether to take periodic snapshots
                    of the data directory.
                    This requires the data directory be on a filesystem supporting snapshots,
                    like BTRFS.
                    Ideally,
                    the data directory is the root of its filesystem.
                  '';
                };
                root = lib.mkOption {
                  type = lib.types.str;
                  default = config.backup.data.root;
                  defaultText = lib.literalExpression "config.jstos.users.<name>.backup.data.root";
                  description = ''
                    Root path of filesystem to snapshot.
                  '';
                };
              };
            };
          };
        }
      )
    ];
  }

  (
    let
      cfgs = map (jstos: jstos.backup) (builtins.attrValues config.jstos.users);
    in
    lib.mkIf (builtins.any (cfg: cfg.home.snapshot.enable || cfg.data.snapshot.enable) cfgs) {
      services.snapper.snapshotInterval = "*:0/5";

      # Snapper is very verbose by default,
      # and there is no option to reduce that verbosity.
      systemd.services.snapperd.serviceConfig.ExecStart =
        lib.mkForce "${lib.getExe' pkgs.snapper "snapperd"} --logger-type none";
    }
  )

  (
    let
      cfgs = lib.mapAttrs (_: jstos: jstos.backup.home.snapshot) config.jstos.users;
    in
    {
      services.snapper.configs = lib.mapAttrs' (
        user: cfg:
        lib.nameValuePair (user + "-home") {
          SUBVOLUME = cfg.root;
          ALLOW_USERS = [ user ];
          TIMELINE_CREATE = true;
          TIMELINE_CLEANUP = true;
          TIMELINE_MIN_AGE = 60 * 60 * 8; # Seconds. This limits frequent snapshots.
          TIMELINE_LIMIT_HOURLY = 24;
          TIMELINE_LIMIT_DAILY = 7;
          TIMELINE_LIMIT_WEEKLY = 0;
          TIMELINE_LIMIT_MONTHLY = 0;
          TIMELINE_LIMIT_YEARLY = 0;
        }
      ) (lib.filterAttrs (_: cfg: cfg.enable) cfgs);
    }
  )

  (
    let
      cfgs = lib.mapAttrs (_: jstos: jstos.backup.data.snapshot) config.jstos.users;
    in
    {
      services.snapper.configs = lib.mapAttrs' (
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
      ) (lib.filterAttrs (_: cfg: cfg.enable) cfgs);
    }
  )

  (
    let
      cfgs = map (jstos: jstos.backup.data.sync) (builtins.attrValues config.jstos.users);

      sshAliveInterval = 10;
    in
    lib.mkIf (builtins.any (cfg: cfg.client.enable || cfg.server.enable) cfgs) {
      # Unison needs many inotify watches.
      boot.kernel.sysctl."fs.inotify.max_user_watches" = "2147483647";

      # This is the other half of `unison.sshargs`.
      services.openssh.settings = lib.mkIf (builtins.any (cfg: cfg.server.enable) cfgs) {
        TCPKeepAlive = "no";
        ClientAliveInterval = sshAliveInterval;
      };

      home-manager.users = lib.mapAttrs (
        user: jstos:
        let
          cfg = jstos.backup.data.sync;
        in
        { config, ... }:
        lib.mkMerge [
          (lib.mkIf (cfg.client.enable || cfg.server.enable) {
            home.packages = [ pkgs.unison ];
          })

          (lib.mkIf cfg.client.enable {
            services.unison = {
              enable = true;
              pairs = {
                data = {
                  roots = [
                    jstos.backup.data.root
                    "ssh://${cfg.address}/${cfg.root}"
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
                    sshargs = "-o TCPKeepAlive=no -o ServerAliveInterval=${toString sshAliveInterval}";

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
          })
        ]
      ) config.jstos.users;
    }
  )
]
