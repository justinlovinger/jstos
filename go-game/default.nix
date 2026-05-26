{
  config,
  lib,
  pkgs,
  ...
}:
let
  config' = config;

  sabaki = pkgs.appimageTools.wrapType2 {
    pname = "sabaki";
    version = "0.52.2";
    src = pkgs.fetchurl {
      url = "https://github.com/SabakiHQ/Sabaki/releases/download/v0.52.2/sabaki-v0.52.2-linux-x64.AppImage";
      hash = "sha256-wuCj5HvNZc2KOdc5O49upNToFDKiMMWexykctHi51EY=";
    };
    extraPkgs = pkgs: [ pkgs.xorg.libxshmfence ];
  };

  katagoSettingsFormat = {
    generate =
      let
        formatValue = v: if builtins.isBool v then (if v then "true" else "false") else builtins.toString v;
      in
      name: value:
      pkgs.writeText name (
        builtins.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${n} = ${formatValue v}") value)
      );
    type =
      with lib.types;
      attrsOf (oneOf [
        bool
        int
        float
        str
        path
      ]);
  };
in
{
  jstos.userModules = [
    (
      { config, ... }:
      {
        options.goGame = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default =
              config.enable
              && config'.jstos.device.has.regularUsage
              && config'.jstos.device.has.display
              && pkgs.stdenv.hostPlatform.isx86_64; # Sabaki can run on AArch64, but we would need to update the package to support it.
            defaultText = lib.literalExpression "config.jstos.users.<name>.enable && config.jstos.device.has.regularUsage && config.jstos.device.has.display && pkgs.stdenv.hostPlatform.isx86_64";
            description = ''
              Whether to enable Go (the game).
            '';
          };

          gnugo = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether to enable the GNU Go AI.
              '';
            };

            package = lib.mkPackageOption pkgs "GNU Go" { default = "gnugo"; };
          };

          katago = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether to enable the KataGo AI.
              '';
            };

            package = lib.mkPackageOption pkgs "KataGo" {
              default = "katago";
              extraDescription = "This has no effect if using remote KataGo.";
            };

            remote = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Use a remote sever for KataGo.
                  Other KataGo settings should match those on the remote server.
                '';
              };

              address = lib.mkOption {
                type = lib.types.str;
                example = "255.255.255.255";
                description = ''
                  Address of server.
                '';
              };
            };

            defaultSettings = lib.mkOption {
              type = lib.types.submodule {
                freeformType = katagoSettingsFormat.type;
              };
              default = { };
              description = ''
                Default settings for KataGo models.
                See <https://github.com/lightvector/KataGo/blob/master/cpp/configs/gtp_example.cfg> for available options.
              '';
            };

            models = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    file = lib.mkOption {
                      type = lib.types.path;
                      description = ''
                        Path to the KataGo network model.
                      '';
                    };
                    settings = lib.mkOption {
                      type = lib.types.nullOr (
                        lib.types.submodule {
                          freeformType = katagoSettingsFormat.type;
                        }
                      );
                      default = null;
                      description = ''
                        Settings for this KataGo model.
                        See <https://github.com/lightvector/KataGo/blob/master/cpp/configs/gtp_example.cfg> for available options.
                        If `null`,
                        uses default settings.
                      '';
                    };
                  };
                }
              );
              default = { };
              description = ''
                KataGo models.
              '';
            };
          };
        };

        config.goGame.katago = {
          defaultSettings = {
            logDir = lib.mkDefault "gtp_logs";
            logAllGTPCommunication = lib.mkDefault true;
            logSearchInfo = lib.mkDefault true;
            logToStderr = lib.mkDefault true;

            rules = lib.mkDefault "japanese";

            allowResignation = lib.mkDefault true;
            resignThreshold = lib.mkDefault (-0.90);
            resignConsecTurns = lib.mkDefault 3;

            maxVisits = lib.mkDefault 1;
            ponderingEnabled = lib.mkDefault false;
            maxTimePondering = lib.mkDefault 60.0;

            lagBuffer = lib.mkDefault 1.0;

            numSearchThreads = lib.mkDefault 6;

            searchFactorAfterOnePass = lib.mkDefault 0.50;
            searchFactorAfterTwoPass = lib.mkDefault 0.25;
            searchFactorWhenWinning = lib.mkDefault 0.40;
            searchFactorWhenWinningThreshold = lib.mkDefault 0.95;
          };

          models =
            let
              katagoHuman = pkgs.fetchurl {
                url = "https://media.katagotraining.org/uploaded/networks/models_extra/b18c384nbt-humanv0.bin.gz";
                hash = "sha256-Y3dG5E8O/gCtEkWlCqm78HFu/jZMQ5ZerZe9aDXYSrU=";
              };
            in
            (builtins.listToAttrs (
              map
                (
                  {
                    elo,
                    name,
                    hash,
                  }:
                  lib.nameValuePair "KataGo, ${elo} ELO" {
                    file = pkgs.fetchurl {
                      url = "https://media.katagotraining.org/uploaded/networks/models/kata1/${name}";
                      inherit hash;
                    };
                  }
                )
                [
                  {
                    elo = "13479.3";
                    name = "kata1-b40c256-s11840935168-d2898845681.bin.gz";
                    hash = "sha256-QXnJB/XohQ/z+p0dLU5ZDvfRZDq01L1zJOZRnI0FYrw=";
                  }
                  {
                    elo = "10026.9";
                    name = "kata1-b6c96-s175395328-d26788732.txt.gz";
                    hash = "sha256-SNZ1TePEdU+Vv2pcpAlXpJ5ekVqq7t4TOhe5zPj6X8s=";
                  }
                  {
                    elo = " 8050.4";
                    name = "kata1-b6c96-s46949632-d6822967.txt.gz";
                    hash = "sha256-mvWscJdu58T6iAH6quVUsYlgSmutNyJRYp3csVkqXxQ=";
                  }
                  {
                    elo = " 6049.8";
                    name = "kata1-b6c96-s29422336-d4533650.txt.gz";
                    hash = "sha256-/P8ut1N8plU4lx2CMvak01wAdWOgkwi8tVDOQnKdRUQ=";
                  }
                  {
                    elo = " 4189.8";
                    name = "kata1-b6c96-s19408128-d3280178.txt.gz";
                    hash = "sha256-OVL+SwJXmYLqIRvHtl8iojPJpdo3C858m4NebO3QDWs=";
                  }
                  {
                    elo = " 3121.4";
                    name = "kata1-b6c96-s14649344-d2727367.txt.gz";
                    hash = "sha256-sHnbChFmmM48sHNI+jm5Fy4XajVrb+L2cMVHHjKx+c4=";
                  }
                  {
                    elo = " 2556.0";
                    name = "kata1-b6c96-s12849664-d2510774.txt.gz";
                    hash = "sha256-P1ZPWMxgPm/bKDiuhwg5dINHvklXAM38hnQO8a54X6k=";
                  }
                  {
                    elo = " 2126.4";
                    name = "kata1-b6c96-s10014464-d2201128.txt.gz";
                    hash = "sha256-dgIGxoakgeg7u4WciwBiF3xHF3QsdsqB2LI/lgpUv6c=";
                  }
                  {
                    elo = " 1539.4";
                    name = "kata1-b6c96-s4136960-d1510003.txt.gz";
                    hash = "sha256-zxl/U1Q00R3FXKAwL3he2xgUFDPqbFTwTuVd0v+aovk=";
                  }
                  {
                    elo = " 1065.2";
                    name = "kata1-b6c96-s1995008-d1329786.txt.gz";
                    hash = "sha256-oF2uh/qrmmoVWc4zevMg3P6K9wCfJ4gf9u1tOCSEy+k=";
                  }
                  {
                    elo = "  480.0";
                    name = "kata1-b6c96-s1248000-d550347.txt.gz";
                    hash = "sha256-UyE8WWIUlykd+tNBW0RGWsguMCw/1gY4ECdYGDK+D1g=";
                  }
                ]
            ))
            // (builtins.listToAttrs (
              map (
                x:
                lib.nameValuePair "KataGo, Human-Like, Kyu ${lib.fixedWidthString 2 " " x}" {
                  file = katagoHuman;
                  settings = config.goGame.katago.defaultSettings // {
                    humanSLProfile = "rank_${x}k";
                  };
                }
              ) (map toString (lib.lists.range 1 20))
            ))
            // (builtins.listToAttrs (
              map (
                x:
                lib.nameValuePair "KataGo, Human-Like, Dan ${x}" {
                  file = katagoHuman;
                  settings = config.goGame.katago.defaultSettings // {
                    humanSLProfile = "rank_${x}d";
                  };
                }
              ) (map toString (lib.lists.range 1 9))
            ));
        };
      }
    )
  ];

  home-manager.users = lib.mapAttrs (
    user: jstos:
    let
      cfg = jstos.goGame;
    in
    { config, lib, ... }:
    let
      katagoConfigDir = ".katago";
      katagoRemote = pkgs.writeShellScriptBin "katago" ''
        ssh ${cfg.katago.remote.address} katago "$@"
      '';
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          home.packages = [ sabaki ];
        }

        (lib.mkIf cfg.gnugo.enable {
          home.packages = [ cfg.gnugo.package ];
        })

        (lib.mkIf cfg.katago.enable (
          if cfg.katago.remote.enable then
            {
              home.packages = [ katagoRemote ];
            }
          else
            {
              home.packages = [ cfg.katago.package ];
              home.file = {
                "${katagoConfigDir}/default_gtp.cfg".source =
                  katagoSettingsFormat.generate "default_gtp.cfg" cfg.katago.defaultSettings;
              };
            }
        ))

        (
          let
            engines =
              (
                if cfg.gnugo.enable then
                  (map (x: {
                    name = "GNU Go, Level ${toString x}";
                    path = "gnugo";
                    args = "--mode gtp --level ${toString x}";
                  }) (lib.lists.range 0 10))
                else
                  [ ]
              )
              ++ (
                let
                  # When using remote KataGo,
                  # the client needs to know paths
                  # but does not need them in the store.
                  outPath = drv: if cfg.katago.remote.enable then builtins.unsafeDiscardStringContext drv else drv;
                in
                if cfg.katago.enable then
                  (lib.mapAttrsToList (
                    name:
                    {
                      file,
                      settings,
                    }:
                    {
                      inherit name;
                      path = "katago";
                      args = lib.concatStringsSep " " (
                        [
                          "gtp"
                          "-model"
                          (outPath file)
                        ]
                        ++ (
                          if builtins.isNull settings then
                            [ ]
                          else
                            [
                              "-config"
                              (outPath (katagoSettingsFormat.generate "${name}.cfg" settings))
                            ]
                        )
                      );
                    }
                  ) cfg.katago.models)
                else
                  [ ]
              );

            settingsFile = "${config.xdg.configHome}/Sabaki/settings.json";
          in
          {
            home.activation.setSabakiEngines = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              $DRY_RUN_CMD ${(pkgs.writeScript "set-sabaki-engines.sh" ''
                #!${lib.getExe pkgs.nushell}
                if ("${settingsFile}" | path exists) {
                  open ${settingsFile} | update "engines.list" ${builtins.toJSON engines} | to json | save -f ${settingsFile}
                }
              '')}
            '';
          }
        )
      ]
    )
  ) config.jstos.users;
}
