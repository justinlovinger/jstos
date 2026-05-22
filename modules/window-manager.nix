{
  config,
  jstos-pkgs,
  lib,
  pkgs,
  ...
}:
let
  config' = config;

  cfgs = map (jstos: jstos.windowManager) (lib.attrValues config.jstos.users);
in
{
  jstos.userModules = [
    (
      { name, config, ... }:
      {
        options.windowManager = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default =
              config.enable && config'.jstos.device.has.regularUsage && config'.jstos.device.has.display;
            defaultText = lib.literalExpression "config.jstos.users.<name>.enable && config.jstos.device.has.regularUsage && config.jstos.device.has.display";
            description = ''
              Whether to enable the window manager.
            '';
          };

          bindings = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule (
                { config, ... }:
                {
                  options =
                    let
                      modeOptions = enableDefault: defaultToNormal: {
                        enable = lib.mkOption {
                          type = lib.types.bool;
                          default = enableDefault;
                          description = ''
                            Whether the binding is enabled in this mode.
                          '';
                        };
                        command = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = if defaultToNormal then config.normal.command else null;
                          example = "spawn alacritty";
                          description = ''
                            `riverctl` command to run when binding is pressed in this mode.
                          '';
                        };
                        repeat = lib.mkOption {
                          type = lib.types.bool;
                          default = if defaultToNormal then config.normal.repeat else false;
                          description = ''
                            Whether to repeat the command when binding is held in this mode.
                          '';
                        };
                      };
                    in
                    {
                      normal = modeOptions true false;
                      mouse = modeOptions true true;
                      locked = modeOptions false true;
                    };
                }
              )
            );
            description = ''
              Mapping of key bindings to commands.
              Keys should be in the form of River bindings.
            '';
          };

          swapCapsEsc = lib.mkOption {
            type = lib.types.bool;
            default = true;
            example = false;
            description = ''
              Swap behavior of Caps Lock and Esc.
            '';
          };

          status = {
            battery = {
              show = lib.mkOption {
                type = lib.types.bool;
                default = config'.jstos.device.has.battery;
                defaultText = lib.literalExpression "config.jstos.device.has.battery";
                description = ''
                  Whether to enable showing battery status.
                '';
              };
              path = lib.mkOption {
                type = lib.types.path;
                default = "/sys/class/power_supply/BAT%d/uevent";
                description = ''
                  Path to battery `uevent`.
                '';
              };
            };
            ethernet = {
              show = lib.mkOption {
                type = lib.types.bool;
                default = config'.jstos.device.has.ethernet;
                defaultText = lib.literalExpression "config.jstos.device.has.battery";
                description = ''
                  Whether to enable showing ethernet status.
                '';
              };
              name = lib.mkOption {
                type = lib.types.str;
                default = "_first_";
                description = ''
                  Name of the ethernet interface.
                '';
              };
            };
            mobileData = {
              show = lib.mkOption {
                type = lib.types.bool;
                default = config'.jstos.device.has.mobileData;
                defaultText = lib.literalExpression "config.jstos.device.has.mobileData";
                description = ''
                  Whether to enable showing mobile data status.
                '';
              };
              name = lib.mkOption {
                type = lib.types.str;
                default = "wwu1i4";
                description = ''
                  Name of the mobile data interface.
                '';
              };
            };
            wifi = {
              show = lib.mkOption {
                type = lib.types.bool;
                default = config'.jstos.device.has.wifi;
                defaultText = lib.literalExpression "config.jstos.device.has.wifi";
                description = ''
                  Whether to enable showing wifi status.
                '';
              };
              name = lib.mkOption {
                type = lib.types.str;
                default = "_first_";
                description = ''
                  Name of the wifi interface.
                '';
              };
            };
          };
        };

        config.windowManager = {
          bindings =
            let
              normalBindings = {
                "Super+Shift return".normal.command = ''
                  spawn 'shell-window --working-directory="${homeManagerConfig.home.homeDirectory}"'
                '';
                "Super o".normal.command = "spawn '${lib.getExe pkgs.rofi} -modi drun -show drun ${rofiArgs}'";
                "Super+Control c".normal.command = "close";

                "Super return".normal.command = "zoom";
                "Super j".normal.command = "focus-view next";
                "Super k".normal.command = "focus-view previous";
                "Super+Shift j".normal.command = "swap next";
                "Super+Shift k".normal.command = "swap previous";

                "Super b".normal.command = "focus-output previous";
                "Super n".normal.command = "focus-output next";
                "Super+Shift b".normal.command = "send-to-output previous";
                "Super+Shift n".normal.command = "send-to-output next";

                # `flow` does not currently support moving tags.
                "Super y".normal.command =
                  "spawn '${lib.getExe' jstos-pkgs.flow "flow"} cycle-tags previous 32 --occupied'";
                "Super u".normal.command =
                  "spawn '${lib.getExe' jstos-pkgs.flow "flow"} cycle-tags next 32 --occupied'";
                "Super+Control y".normal.command =
                  "spawn '${lib.getExe' jstos-pkgs.flow "flow"} cycle-tags previous 32'";
                "Super+Control u".normal.command =
                  "spawn '${lib.getExe' jstos-pkgs.flow "flow"} cycle-tags next 32'";
                # "Super+Shift y".normal.command = "spawn '${lib.getExe' jstos-pkgs.flow "flow"} cycle-tags --move previous 32'";
                # "Super+Shift u".normal.command = "spawn '${lib.getExe' jstos-pkgs.flow "flow"} cycle-tags --move next 32'";

                "Super bracketleft".normal.command = "focus-previous-tags";
                "Super bracketright".normal.command = "focus-previous-tags";
                "Super+Shift bracketleft".normal.command = "send-to-previous-tags";
                "Super+Shift bracketright".normal.command = "send-to-previous-tags";
              }
              // (builtins.mapAttrs
                (_: value: {
                  normal = {
                    command = value.normal.command;
                    repeat = true;
                  };
                })
                {
                  "Super+Alt h".normal.command = "move left 10";
                  "Super+Alt j".normal.command = "move down 10";
                  "Super+Alt k".normal.command = "move up 10";
                  "Super+Alt l".normal.command = "move right 10";

                  "Super+Alt+Control h".normal.command = "move left 1";
                  "Super+Alt+Control j".normal.command = "move down 1";
                  "Super+Alt+Control k".normal.command = "move up 1";
                  "Super+Alt+Control l".normal.command = "move right 1";

                  "Super+Alt+Shift h".normal.command = "resize horizontal -10";
                  "Super+Alt+Shift j".normal.command = "resize vertical 10";
                  "Super+Alt+Shift k".normal.command = "resize vertical -10";
                  "Super+Alt+Shift l".normal.command = "resize horizontal 10";

                  "Super+Alt+Shift+Control h".normal.command = "resize horizontal -1";
                  "Super+Alt+Shift+Control j".normal.command = "resize vertical 1";
                  "Super+Alt+Shift+Control k".normal.command = "resize vertical -1";
                  "Super+Alt+Shift+Control l".normal.command = "resize horizontal 1";
                }
              )
              // {
                "Super+Alt left".normal.command = "snap left";
                "Super+Alt down".normal.command = "snap down";
                "Super+Alt up".normal.command = "snap up";
                "Super+Alt right".normal.command = "snap right";

                "Super h".normal.command = ''send-layout-cmd kile "mod-main-ratio -0.05"'';
                "Super l".normal.command = ''send-layout-cmd kile "mod-main-ratio +0.05"'';
                "Super+Shift h".normal.command = ''send-layout-cmd kile "mod-main-count +1"'';
                "Super+Shift l".normal.command = ''send-layout-cmd kile "mod-main-count -1"'';
                "Super+Control h".normal.command = ''send-layout-cmd kile "mod-main-index +1"'';
                "Super+Control l".normal.command = ''send-layout-cmd kile "mod-main-index -1"'';
                "Super semicolon".normal.command = "spawn ${layoutMenuScript}";

                "Super f".normal.command = "toggle-fullscreen";
                "Super space".normal.command = "toggle-float";

                "Super i".normal.command = rofimojiSpawn "";
                "Super+Shift i".normal.command = rofimojiSpawn "--files all";
                "Super+Control i".normal.command = rofimojiSpawn "--files math";

                "Super p".normal.command = "spawn ${grimshotMenuScript}";

                "Super v".normal.command = "spawn ${setVolumeScript}";
                "Super+Shift v".normal.command = "spawn '${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle'";

                # We should not need to specify the config,
                # but as of 2024-04-29,
                # we do.
                "Super m".normal.command =
                  "spawn '${lib.getExe pkgs.wl-kbptr} -c ${homeManagerConfig.xdg.configHome}/wl-kbptr/config -o modes=floating,click -o mode_floating.source=detect'";
                "Super+Shift m".normal.command = "enter-mode mouse";
              };

              layoutMenuScript = pkgs.writeShellScript "grimshot-menu.sh" ''
                function list_options {
                  ${lib.strings.concatStringsSep ";" (
                    map (x: ''echo "${x}"'') [
                      "owm"
                      "overview"
                      "monocle"
                    ]
                  )}
                }

                selected=$( list_options | ${lib.getExe pkgs.rofi} -dmenu -p "layout" ${rofiArgs} )

                if [ -n "$selected" ]; then
                  exec riverctl default-layout "$selected"
                fi
              '';

              grimshotMenuScript = pkgs.writeShellScript "grimshot-menu.sh" ''
                function list_options {
                  echo "active"
                  echo "area"
                  echo "output"
                  echo "screen"
                  echo "window"
                }

                selected=$( list_options | ${lib.getExe pkgs.rofi} -dmenu -p "grimshot" ${rofiArgs} )

                if [ -n "$selected" ]; then
                  ${lib.getExe' pkgs.coreutils "mkdir"} -p "${screenshotDir}"
                  exec ${lib.getExe pkgs.sway-contrib.grimshot} \
                    save \
                    "$selected" \
                    "${screenshotDir}/dated_$(${lib.getExe' pkgs.coreutils "date"} +"%Y_%m_%dt%H_%M_%S")-_.png"
                fi
              '';
              screenshotDir = "${homeManagerConfig.home.homeDirectory}/pictures/screenshots";

              setVolumeScript = pkgs.writeScript "set-volume.nu" ''
                #!${lib.getExe pkgs.nushell}
                let volume = (${wpctl} get-volume @DEFAULT_SINK@ | split row ' ' | get 1 | into float | $in * 100 | into int)
                let new_volume = (${lib.getExe pkgs.rofi} -dmenu -p $"󰕾 ($volume)" ${rofiArgs} | into int)
                if $new_volume <= 100 {
                  ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ $"($new_volume)%"
                }
              '';

              rofimojiSpawn =
                args: ''spawn "${lib.getExe pkgs.rofimoji} --skin-tone ask ${args} --selector-args='${rofiArgs}'"'';
              rofiArgs = "-sorting-method fzf -sort -monitor -1";

              commonBindings = builtins.mapAttrs (_: value: value // { locked.enable = true; }) {
                # Audio controls:
                "None XF86AudioMute".normal.command = "spawn '${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle'";
                "None XF86AudioLowerVolume".normal = {
                  command = "spawn '${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 1%-'";
                  repeat = true;
                };
                "None XF86AudioRaiseVolume".normal = {
                  command = "spawn '${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 1%+'";
                  repeat = true;
                };

                # Media player controls:
                # `XF86AudioMedia` is often used to toggle play/pause.
                "None XF86AudioMedia".normal.command = "spawn '${lib.getExe pkgs.playerctl} play-pause'";
                "None XF86AudioPlay".normal.command = "spawn '${lib.getExe pkgs.playerctl} play'";
                "None XF86AudioPause".normal.command = "spawn '${lib.getExe pkgs.playerctl} pause'";
                "None XF86AudioNext".normal.command = "spawn '${lib.getExe pkgs.playerctl} next'";
                "None XF86AudioPrev".normal.command = "spawn '${lib.getExe pkgs.playerctl} previous'";

                # Screen brightness controls:
                "None XF86MonBrightnessUp".normal = {
                  command = "spawn 'brillo -A 3 -u 10000'";
                  repeat = true;
                };
                "None XF86MonBrightnessDown".normal = {
                  command = "spawn 'brillo -U 3 -u 10000'";
                  repeat = true;
                };

                # We can add the following
                # when river supports toggling.
                # Alternatively,
                # we can manage toggle state ourselves.
                # # Touchpad controls:
                # "None XF86TouchpadToggle".normal.command = "spawn 'for i in $(riverctl list-inputs | rg 'pointer.*Touchpad'); do riverctl input $i events toggle; done'"
              };
              wpctl = "${pkgs.wireplumber}/bin/wpctl";

              tagBindings = {
                "Super grave".normal.command = "set-focused-tags ${allTagsMask}";
                "Super+Shift grave".normal.command = "set-view-tags ${allTagsMask}";
              }
              // lib.foldl' (x: acc: acc // x) { } (
                lib.lists.zipListsWith
                  (
                    {
                      mod,
                      key,
                    }:
                    tagMask: {
                      "Super${mod} ${key}".normal.command = "toggle-focused-tags ${tagMask}";
                      "Super${mod}+Shift ${key}".normal.command = "set-view-tags ${tagMask}";
                      "Super${mod}+Control ${key}".normal.command = "set-focused-tags ${tagMask}";
                      "Super${mod}+Shift+Control ${key}".normal.command = "toggle-view-tags ${tagMask}";
                    }
                  )
                  (
                    map (x: {
                      mod = "";
                      key = x;
                    }) tagKeys
                    ++ map (x: {
                      mod = "+Alt";
                      key = x;
                    }) tagKeys
                  )
                  (map (x: builtins.toString x) tagMasks)
              );
              tagKeys = (map (x: builtins.toString x) (lib.lists.range 1 9)) ++ [
                "0"
                "minus"
                "equal"
                "q"
                "w"
                "e"
                "r"
              ];
              allTagsMask = toString (lib.foldl' (x: acc: x + acc) 0 tagMasks);
              tagMasks = map (x: pow 2 x) (lib.lists.range 0 31);
              pow = x: n: pow_ x 1 n;
              pow_ =
                b: x: n:
                if n == 0 then x else pow_ b (b * x) (n - 1);

              # Some normal bindings don't work well without switching to normal mode first,
              # like those that require typing into a pop-up,
              # but fixing them for mouse mode isn't worthwhile.
              mouseBindings = (
                builtins.mapAttrs (_: value: value // { normal.enable = false; }) {
                  "None Escape".mouse.command = "enter-mode normal";

                  "None m".mouse.command =
                    "spawn 'riverctl enter-mode normal; ${lib.getExe pkgs.wl-kbptr} -c ${homeManagerConfig.xdg.configHome}/wl-kbptr/config -o modes=floating -o mode_floating.source=detect; riverctl enter-mode mouse'";
                }
                // (builtins.mapAttrs
                  (_: value: {
                    mouse = {
                      command = value.mouse.command;
                      repeat = true;
                    };
                  })
                  {
                    "None h".mouse.command = "spawn '${wlrctl} pointer move -10 0'";
                    "None j".mouse.command = "spawn '${wlrctl} pointer move 0 10'";
                    "None k".mouse.command = "spawn '${wlrctl} pointer move 0 -10'";
                    "None l".mouse.command = "spawn '${wlrctl} pointer move 10 0'";
                    "None y".mouse.command = "spawn '${wlrctl} pointer move -10 -10'";
                    "None u".mouse.command = "spawn '${wlrctl} pointer move 10 -10'";
                    "None b".mouse.command = "spawn '${wlrctl} pointer move -10 10'";
                    "None n".mouse.command = "spawn '${wlrctl} pointer move 10 10'";
                    "Control h".mouse.command = "spawn '${wlrctl} pointer move -1 0'";
                    "Control j".mouse.command = "spawn '${wlrctl} pointer move 0 1'";
                    "Control k".mouse.command = "spawn '${wlrctl} pointer move 0 -1'";
                    "Control l".mouse.command = "spawn '${wlrctl} pointer move 1 0'";
                    "Control y".mouse.command = "spawn '${wlrctl} pointer move -1 -1'";
                    "Control u".mouse.command = "spawn '${wlrctl} pointer move 1 -1'";
                    "Control b".mouse.command = "spawn '${wlrctl} pointer move -1 1'";
                    "Control n".mouse.command = "spawn '${wlrctl} pointer move 1 1'";

                    "None e".mouse.command = "spawn '${wlrctl} pointer scroll -10 0'";
                    "None d".mouse.command = "spawn '${wlrctl} pointer scroll 10 0'";
                    "None r".mouse.command = "spawn '${wlrctl} pointer scroll 0 -10'";
                    "None t".mouse.command = "spawn '${wlrctl} pointer scroll 0 10'";
                    "Control e".mouse.command = "spawn '${wlrctl} pointer scroll -1 0'";
                    "Control d".mouse.command = "spawn '${wlrctl} pointer scroll 1 0'";
                    "Control r".mouse.command = "spawn '${wlrctl} pointer scroll 0 -1'";
                    "Control t".mouse.command = "spawn '${wlrctl} pointer scroll 0 1'";

                    # These should keep click down until button is released
                    # instead of repeating,
                    # but `wlrctl` needs to support separate press and release first.
                    "None f".mouse.command = "spawn '${wlrctl} pointer click left'";
                    "None v".mouse.command = "spawn '${wlrctl} pointer click middle'";
                    "None g".mouse.command = "spawn '${wlrctl} pointer click right'";
                  }
                )
              );
              wlrctl = "${lib.getExe pkgs.wlrctl}";

              homeManagerConfig = config'.home-manager.users.${name};
            in
            builtins.mapAttrs (_: value: lib.mkDefault value) (
              normalBindings // commonBindings // tagBindings // mouseBindings
            );
        };
      }
    )
  ];

  programs.river-classic = lib.mkIf (lib.any (cfg: cfg.enable) cfgs) {
    enable = lib.mkDefault true;
    package = lib.mkDefault null;
    extraPackages = lib.mkDefault [ ];
  };

  # The status bar uses custom glyphs.
  fonts.packages = lib.mkIf (lib.any (cfg: cfg.enable) cfgs) [ pkgs.material-design-icons ];

  home-manager.users = lib.mapAttrs (
    user: jstos:
    let
      cfg = jstos.windowManager;
      colors = jstos.colors;
      riverColor = s: "0x${s}";
    in
    { config, ... }:
    lib.mkIf cfg.enable {
      home.packages = with pkgs; [ bibata-cursors ];

      programs.i3bar-river = {
        enable = true;
        settings = with colors.hex; {
          command = toString (lib.getExe config.programs.i3status.package);

          background = bg.normal;
          color = fg.normal;
          separator = bg.normal;
          tag_fg = fg.normal;
          tag_bg = bg.normal;
          tag_focused_bg = fg.faded;
          tag_focused_fg = bg.normal;
          tag_urgent_bg = bg.red;
          tag_urgent_fg = fg.normal;

          font = "monospace 8";
          height = 16;
          tags_padding = 6;

          position = "bottom";
          show_layout_name = false;

          wm.river.max_tag = 32;
        };
      };
      systemd.user.services.i3bar-river = {
        Unit = {
          Description = "Status bar";
          PartOf = config.wayland.systemd.target;
          Requires = config.wayland.systemd.target;
          After = config.wayland.systemd.target;
          X-Restart-Triggers = [
            config.xdg.configFile."i3bar-river/config.toml".source
            config.xdg.configFile."i3status/config".source
          ];
        };
        Install = {
          WantedBy = [ config.wayland.systemd.target ];
        };
        Service = {
          Type = "simple";
          Environment = "PATH=/bin"; # `i3bar-river` calls `sh` to run its `command`.
          ExecStart = toString (lib.getExe config.programs.i3bar-river.package);
          Restart = "always";
        };
      };

      programs.i3status = {
        enable = true;
        enableDefault = false;

        general = with colors.hex; {
          output_format = "i3bar";
          colors = true;
          color_good = fg.normal;
          color_degraded = fg.yellow;
          color_bad = fg.red;
          color_separator = bg.normal;
          interval = 1;
        };

        modules = {
          "ethernet ${cfg.status.ethernet.name}" = lib.mkIf cfg.status.ethernet.show {
            position = 1;
            settings = {
              format_up = "󰈁 %speed";
              format_down = "󰈂";
            };
          };

          "wireless ${cfg.status.wifi.name}" = lib.mkIf cfg.status.wifi.show {
            position = 2;
            settings = {
              format_up = "󰖩 %essid (%quality)";
              format_down = "󰖪";
            };
          };

          "wireless ${cfg.status.mobileData.name}" = lib.mkIf cfg.status.mobileData.show {
            position = 3;
            settings = {
              format_up = "󰒢";
              format_down = "󰞃";
            };
          };

          "disk /" = {
            position = 4;
            settings = {
              format = "󰋊 %avail";
            };
          };

          "battery all" = lib.mkIf cfg.status.battery.show {
            position = 5;
            settings = {
              format = "%status %percentage %remaining";
              format_down = "󱉝";
              status_chr = "󰂄";
              status_bat = "󰁾";
              status_unk = "󰂑";
              status_full = "󰁹";
              status_idle = "󰁹";
              integer_battery_capacity = true;
              path = cfg.status.battery.path;
              threshold_type = "percentage";
              low_threshold = 16;
            };
          };

          cpu_usage = {
            position = 6;
            settings = {
              format = "󰘚 %usage";
            };
          };

          memory = {
            position = 7;
            settings = {
              format = "󰍛 %available";
              threshold_degraded = "2G";
            };
          };

          "tztime local" = {
            position = 8;
            settings = {
              format = "%Y-%m-%d %H:%M:%S";
            };
          };

          "volume master" = {
            position = 9;
            settings = {
              format = "󰕾 %volume";
              format_muted = "󰖁 %volume";
            };
          };
        };
      };

      services.mako = {
        enable = true;
        settings = with colors.hex; {
          font = "monospace 14";
          background-color = bg.normal;
          text-color = fg.normal;
          border-size = 1;
          border-color = fg.normal;
          progress-color = bg.faded;
          layer = "overlay";
        };
      };

      programs.rofi = {
        enable = true;

        # See <https://github.com/davatorium/rofi/blob/next/doc/default_theme.rasi>
        # for configuration of theme.
        theme =
          let
            inherit (config.lib.formats.rasi) mkLiteral;
          in
          with colors.hex;
          {
            "*" = {
              background-color = mkLiteral bg.normal;
              border-color = mkLiteral bg.faded;
            };
            element = {
              padding = mkLiteral "2px";
              spacing = mkLiteral "5px";
              border = mkLiteral "0";
              cursor = mkLiteral "pointer";
            };
            "element normal.normal" = {
              background-color = mkLiteral bg.normal;
              text-color = mkLiteral fg.normal;
            };
            "element normal.urgent" = {
              background-color = mkLiteral bg.normal;
              text-color = mkLiteral fg.red;
            };
            "element normal.active" = {
              background-color = mkLiteral bg.normal;
              text-color = mkLiteral fg.blue;
            };
            "element selected.normal" = {
              background-color = mkLiteral fg.normal;
              text-color = mkLiteral bg.normal;
            };
            "element selected.urgent" = {
              background-color = mkLiteral fg.red;
              text-color = mkLiteral bg.normal;
            };
            "element selected.active" = {
              background-color = mkLiteral fg.blue;
              text-color = mkLiteral bg.normal;
            };
            "element alternate.normal" = {
              background-color = mkLiteral bg.faded;
              text-color = mkLiteral fg.normal;
            };
            "element alternate.urgent" = {
              background-color = mkLiteral bg.faded;
              text-color = mkLiteral fg.red;
            };
            "element alternate.active" = {
              background-color = mkLiteral bg.faded;
              text-color = mkLiteral fg.blue;
            };
            element-text = {
              background-color = mkLiteral "rgba ( 0, 0, 0, 0 % )";
              text-color = mkLiteral "inherit";
              highlight = mkLiteral "inherit";
              cursor = mkLiteral "inherit";
            };
            element-icon = {
              background-color = mkLiteral "rgba ( 0, 0, 0, 0 % )";
              size = mkLiteral "1.0000em";
              text-color = mkLiteral "inherit";
              cursor = mkLiteral "inherit";
            };
            window = {
              padding = mkLiteral "5";
              background-color = mkLiteral bg.normal;
              border = mkLiteral "1";
            };
            mainbox = {
              padding = mkLiteral "0";
              border = mkLiteral "0";
            };
            message = {
              padding = mkLiteral "2px";
              border-color = mkLiteral fg.normal;
              border = mkLiteral "2px solid 0px 0px";
            };
            textbox = {
              text-color = mkLiteral fg.normal;
            };
            listview = {
              padding = mkLiteral "2px 0px 0px";
              scrollbar = mkLiteral "true";
              border-color = mkLiteral fg.normal;
              spacing = mkLiteral "0";
              fixed-height = mkLiteral "0";
              border = mkLiteral "2px solid 0px 0px";
            };
            scrollbar = {
              width = mkLiteral "4px";
              padding = mkLiteral "0px 0px 0px 2px";
              handle-width = mkLiteral "8px";
              border = mkLiteral "0";
              handle-color = mkLiteral fg.normal;
            };
            sidebar = {
              border-color = mkLiteral fg.normal;
              border = mkLiteral "2px solid 0px 0px";
            };
            button = {
              spacing = mkLiteral "0";
              text-color = mkLiteral fg.normal;
              cursor = mkLiteral "pointer";
            };
            "button selected" = {
              background-color = mkLiteral fg.normal;
              text-color = mkLiteral bg.normal;
            };
            "num-filtered-rows, num-rows" = {
              text-color = mkLiteral fg.faded;
              expand = mkLiteral "false";
            };
            textbox-num-sep = {
              text-color = mkLiteral fg.faded;
              expand = mkLiteral "false";
              str = mkLiteral ''"/"'';
            };
            inputbar = {
              padding = mkLiteral "0px 2px";
              spacing = mkLiteral "0px";
              text-color = mkLiteral fg.normal;
              children = mkLiteral "[ prompt,textbox-prompt-colon,entry, num-filtered-rows, textbox-num-sep, num-rows, case-indicator ]";
            };
            case-indicator = {
              spacing = mkLiteral "0";
              text-color = mkLiteral fg.normal;
            };
            entry = {
              spacing = mkLiteral "0";
              text-color = mkLiteral fg.normal;
              placeholder-color = mkLiteral fg.faded;
              placeholder = mkLiteral ''"Type to filter"'';
              cursor = mkLiteral "text";
            };
            prompt = {
              spacing = mkLiteral "0";
              text-color = mkLiteral fg.normal;
            };
            textbox-prompt-colon = {
              margin = mkLiteral "0px 0.3000em 0.0000em 0.0000em";
              expand = mkLiteral "false";
              str = mkLiteral ''":"'';
              text-color = mkLiteral "inherit";
            };
          };
      };

      services.way-displays = {
        enable = true;
        settings = {
          AUTO_SCALE = false;
          CALLBACK_CMD = null;
        };
      };

      wayland.windowManager.river = {
        enable = true;

        settings =
          with colors.hexWithoutHash;
          {
            attach-mode = "top";

            background-color = riverColor bg.normal;

            # We would like to remove borders from floating windows,
            # but River does not support this
            # as of 2023-06-26.
            # `rule-add` may support this in the future.
            border-color-focused = riverColor fg.normal;
            border-color-unfocused = riverColor bg.faded;
            border-color-urgent = riverColor fg.red;
            border-width = 1;

            set-repeat = "50 300";

            hide-cursor.timeout = 4000;

            declare-mode = [
              "normal"
              "mouse"
              "locked"
            ];

            map =
              let
                bindingsFor =
                  mode: repeat:
                  builtins.mapAttrs (_: value: value.command) (
                    lib.filterAttrs (_: value: value.repeat == repeat) (
                      lib.filterAttrs (_: value: value.enable) (builtins.mapAttrs (_: value: value.${mode}) cfg.bindings)
                    )
                  );
              in
              {
                normal = bindingsFor "normal" false;
                mouse = bindingsFor "mouse" false;
                locked = bindingsFor "locked" false;
              }
              // {
                "-repeat" = {
                  normal = bindingsFor "normal" true;
                  mouse = bindingsFor "mouse" true;
                  locked = bindingsFor "locked" true;
                };
              };

            map-pointer.normal = {
              "Super BTN_LEFT" = "move-view";
              "Super BTN_RIGHT" = "resize-view";
              "Super BTN_MIDDLE" = "toggle-float";
            };

            xcursor-theme = "Bibata-Original-Classic";
          }
          // (if cfg.swapCapsEsc then { keyboard-layout = "-options caps:swapescape us"; } else { })
          // (
            # `way-displays` can detect lid closing and opening,
            # but it only disables the display
            # if another monitor is plugged in.
            if config.devices.display.laptop.name == null then
              { }
            else
              {
                map-switch = builtins.listToAttrs (
                  map
                    (mode: {
                      name = mode;
                      value = {
                        "lid close" =
                          "spawn '${lib.getExe pkgs.way-displays} -s DISABLED ${config.devices.display.laptop.name}'";
                        "lid open" =
                          "spawn '${lib.getExe pkgs.way-displays} -d DISABLED ${config.devices.display.laptop.name}'";
                      };
                    })
                    [
                      "normal"
                      "locked"
                    ]
                );
              }
          );

        extraConfig =
          let
            border = config.wayland.windowManager.river.settings.border-width;
          in
          ''
            for i in $(riverctl list-inputs | rg '^pointer.*'); do
              riverctl input $i accel-profile flat
            done
            for i in $(riverctl list-inputs | rg '^pointer.*Touchpad$'); do
              riverctl input $i accel-profile adaptive
              riverctl input $i disable-while-typing enabled
              riverctl input $i natural-scroll enabled
              riverctl input $i tap enabled
            done

            riverctl spawn '${lib.getExe' jstos-pkgs.owm "owm"} --overlap-borders-by ${builtins.toString border} --reading-order-weight=1'
            riverctl spawn '${lib.getExe' jstos-pkgs.owm "owm"} --namespace overview --overlap-borders-by ${builtins.toString border} --max-width "" --area-ratios 1 --center-main-weight 0'
            riverctl spawn '${lib.getExe' jstos-pkgs.owm "owm"} --namespace monocle --overlap-borders-by ${builtins.toString border} --min-width 9999 --min-height 9999 --max-width ""'
            riverctl default-layout owm
          '';

        extraSessionVariables = {
          # QT apps will not use Wayland by default.
          QT_QPA_PLATFORM = "wayland";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          # Some Java AWT applications,
          # such as Android Studio,
          # break without the following:
          _JAVA_AWT_WM_NONREPARENTING = "1";
        };
      };

      xdg.configFile."wl-kbptr/config".text = with colors.hex; ''
        [mode_tile]
        label_color=${fg.normal}
        label_select_color=${fg.faded}cc
        unselectable_bg_color=#0000
        selectable_bg_color=${bg.normal}55
        selectable_border_color=${fg.faded}cc

        [mode_floating]
        label_color=${fg.normal}
        label_select_color=${fg.faded}
        label_font_size=20 75% 100
        unselectable_bg_color=#0000
        selectable_bg_color=${bg.normal}aa
        selectable_border_color=${fg.faded}cc

        [mode_bisect]
        label_color=${fg.normal}
        label_font_size=20
        label_padding=12
        pointer_size=20
        pointer_color=${fg.normal}
        unselectable_bg_color=#0000
        even_area_bg_color=${bg.normal}55
        even_area_border_color=${fg.faded}cc
        odd_area_bg_color=${bg.normal}55
        odd_area_border_color=${fg.faded}cc
        history_border_color=${fg.faded}cc
      '';
    }
  ) config.jstos.users;
}
