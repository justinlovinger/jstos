{
  config,
  lib,
  pkgs,
  ...
}:
let
  mepo = pkgs.runCommandLocal "mepo-with-better-location" { } ''
    cp -rs ${mepoWithoutUserpin} $out
    chmod -R u+w $out

    rm $out/bin/mepo
    ln -s ${mepoScript} $out/bin/mepo
  '';

  # Out of the box,
  # Mepo polls a push-based service for location data.
  # This script instead uses the push-based service to push location data.
  # See <https://gitlab.freedesktop.org/geoclue/geoclue/-/blob/master/demo/where-am-i.c>
  # for fields used in `parse`.
  # Note,
  # `pin_add` doesn't update an existing pin,
  # so we also update latitude and longitude.
  mepoScript = pkgs.writeScript "mepo" ''
    #!${lib.getExe pkgs.nushell}
    $env.LC_NUMERIC = "en_US.UTF-8" # Mepo expects `.` as decimal separator.
    ${pkgs.geoclue2-with-demo-agent}/libexec/geoclue-2.0/demos/where-am-i -t -1
      | lines
      | each {|line| if ($line | str starts-with "Timestamp:") { [$line, ""] } else { [$line] } } # Otherwise, `chunk-by` delays output.
      | flatten
      | chunk-by {|line| $line == ""}
      | each {to text}
      | parse --regex '(?s)\ANew location:\nLatitude: *(?P<lat>.*?)°\nLongitude: *(?P<lon>.*?)°\nAccuracy: *(?P<accuracy>.*?)(?:\nAltitude: *(?P<altitude>.*?))?(?:\Speed: *(?P<speed>.*?))?(?:\nHeading: *(?P<heading>.*?))?(?:\nDescription: *(?P<description>.*?))?(?:\nTimestamp: *(?P<timestamp>.*?) \([^\)]*\))?\n?\z'
      | each {|x|
          [
            {
              "cmd": "pin_add",
              "args": {
                "group": 0,
                "handle": "user_location",
                "lat": ($x.lat | into float),
                "lon": ($x.lon | into float),
              }
            },
          ] ++ ($x | items {|key, value|
            {
              "cmd": "pin_meta",
              "args": {
                "group": 0,
                "handle": "user_location",
                "key": $key,
                "value": ($value | default ""),
              }
            }
          })
        }
      | each {to json -r}
      | to text
      | ${lib.getExe' mepoWithoutUserpin "mepo"} -i
    # `where-am-i` doesn't always die when `mepo` dies.
    ps | where ppid == $nu.pid | get pid | each {|pid| kill --force $pid}
  '';

  # `$env.MEPO_USERPIN_ENABLED = 0` doesn't work,
  # and there is no way to remove a `bind_timer` or `shellpipe_async` from the user config.
  mepoWithoutUserpin = pkgs.mepo.overrideAttrs (
    {
      patches ? [ ],
      ...
    }:
    {
      patches = patches ++ [
        (builtins.toFile "fix-httpx.patch" ''
          diff --git a/src/config.json b/src/config.json
          index 147ba40..f7b772d 100644
          --- a/src/config.json
          +++ b/src/config.json
          @@ -204,9 +204,6 @@
             {"cmd": "bind_signal", "args": { "sig": "TERM", "exps": [{"cmd": "quit", "args": {}}]}},
             {"cmd": "bind_signal", "args": { "sig": "INT", "exps": [{"cmd": "quit", "args": {}}]}},

          -  {"cmd": "bind_timer", "args": { "secs": 20, "exps": [ {"cmd": "shellpipe_async", "args": {"shellcode":  "mepo_ui_menu_user_pin_updater.sh droppin"}} ]}},
          -  {"cmd": "shellpipe_async", "args": {"shellcode":  "mepo_ui_menu_user_pin_updater.sh droppin"}},
          -
             {"cmd": "bind_key", "args": { "mod": "c", "key": "s", "exps": [{"cmd": "filedump", "args": {"datatypes": "rp", "filepath": "$XDG_CACHE_HOME/mepo/savestate.json"}}]}},
             {"cmd": "bind_key", "args": { "mod": "c", "key": "l", "exps": [{"cmd": "fileload", "args": { "filepath": "$XDG_CACHE_HOME/mepo/savestate.json"}}]}},
        '')
      ];
    }
  );

  userCfgs = lib.filterAttrs (_: cfg: cfg.enable) (
    lib.mapAttrs (_: cfg: cfg.desktop.map) config.jstos.users
  );
in
{
  options.jstos.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule ({
        options.desktop.map = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether to enable the map.
            '';
          };
        };
      })
    );
  };

  config = {
    services.geoclue2.enable = lib.mkIf (builtins.any (cfg: cfg.enable) (
      builtins.attrValues userCfgs
    )) true;

    home-manager.users = lib.mapAttrs (user: cfg: {
      home.packages = [ mepo ];

      xdg.configFile."mepo/config.json".source = (pkgs.formats.json { }).generate "config.json" [
        # The existing `x` command doesn't work with the improved location service.
        {
          "cmd" = "bind_key";
          "args" = {
            "mod" = "_";
            "key" = "x";
            "exps" = [
              {
                "cmd" = "pin_activate";
                "args" = {
                  "group" = 0;
                  "handle" = "user_location";
                };
              }
              {
                "cmd" = "center_on_pin";
                "args" = { };
              }
            ];
          };
        }

        # Mepo is far more usable with autosaving and autoloading.
        {
          cmd = "fileload";
          args = {
            filepath = "$XDG_CACHE_HOME/mepo/savestate.json";
          };
        }
        # Autosaving is broken in 1.3.4.
        #
        # ```
        # {
        #   cmd = "bind_quit";
        #   args = {
        #     exps = [
        #       {
        #         cmd = "filedump";
        #         args = {
        #           datatypes = "rp";
        #           filepath = "$XDG_CACHE_HOME/mepo/savestate.json";
        #         };
        #       }
        #     ];
        #   };
        # }
        # ```
      ];
    }) userCfgs;
  };
}
