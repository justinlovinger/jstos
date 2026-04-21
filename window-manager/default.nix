{
  config,
  lib,
  pkgs,
  ...
}:
let
  userCfgs = lib.filterAttrs (_: cfg: cfg.enable) (
    lib.mapAttrs (_: cfg: cfg.windowManager) config.jstos.users
  );
  config' = config;
in
{
  options.jstos.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, config, ... }:
        {
          options.windowManager = {
            enable = lib.mkEnableOption "Window Manager";

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
              example = "false";
              description = ''
                Swap behavior of Caps Lock and Esc.
              '';
            };

            osk = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                example = "true";
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

            toggleDisplay = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                example = "true";
                description = ''
                  Whether to enable the toggle-display key.
                '';
              };

              binding = lib.mkOption {
                type = lib.types.str;
                example = "None XF86AudioRaiseVolume";
                description = ''
                  Binding to toggle display.
                '';
              };

              name = lib.mkOption {
                type = lib.types.str;
                default = "eDP-1";
                example = "DP-1";
                description = ''
                  Name of display to toggle,
                  as provided by `way-displays`.
                '';
              };

              disableTouch = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  example = "false";
                  description = ''
                    Whether to disable a touchscreen when display is off.
                  '';
                };

                input = lib.mkOption {
                  type = lib.types.str;
                  default = "touch-*";
                  example = "touch-10248-4117-FTS3528:00_2808:1015";
                  description = ''
                    Name of touchscreen to disable when display is off.
                  '';
                };
              };
            };

            idle = {
              enable = lib.mkEnableOption "idle timeouts";

              displays = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = ''
                    Whether or not to blank displays.
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
                enable = lib.mkEnableOption "lock";

                timeout = lib.mkOption {
                  type = lib.types.int;
                  default = config.windowManager.idle.displays.timeout + 15;
                  description = ''
                    Idle seconds before session is locked.
                  '';
                };

                afterSleep = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = ''
                    Whether or not to lock if system sleeps for `lock.timeout`.
                  '';
                };

                command = lib.mkOption {
                  type = lib.types.str;
                  default =
                    with config.home-manager.users.${name}.colors.hexWithoutHash;
                    lib.concatStringsSep " " [
                      "${lib.getExe pkgs.swaylock}"

                      "--indicator-radius 100"

                      # Use system colors.
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
                enable = lib.mkEnableOption "suspend";

                timeout = lib.mkOption {
                  type = lib.types.int;
                  default = config.windowManager.idle.displays.timeout + 30;
                  description = ''
                    Idle seconds before machine suspends.
                  '';
                };
              };
            };

            dictation = {
              enable = lib.mkEnableOption "dictation";

              binding = lib.mkOption {
                type = lib.types.str;
                default = "Super d";
                description = ''
                  Binding to use dictation.
                '';
              };
            };
          };

          config.windowManager = {
            bindings =
              let
                normalBindings =
                  (
                    let
                      remoteCfg = config.shell.remote;
                    in
                    if remoteCfg.client.enable then
                      {
                        "Super+Control+Shift return".normal.command = "spawn 'mosh-window ${remoteCfg.address}'";
                      }
                    else
                      { }
                  )
                  // {
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
                      "spawn '${lib.getExe' pkgs.flow "flow"} cycle-tags previous 32 --occupied'";
                    "Super u".normal.command = "spawn '${lib.getExe' pkgs.flow "flow"} cycle-tags next 32 --occupied'";
                    "Super+Control y".normal.command = "spawn '${lib.getExe' pkgs.flow "flow"} cycle-tags previous 32'";
                    "Super+Control u".normal.command = "spawn '${lib.getExe' pkgs.flow "flow"} cycle-tags next 32'";
                    # "Super+Shift y".normal.command = "spawn '${lib.getExe' pkgs.flow "flow"} cycle-tags --move previous 32'";
                    # "Super+Shift u".normal.command = "spawn '${lib.getExe' pkgs.flow "flow"} cycle-tags --move next 32'";

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
    );
  };

  config = {
    programs.river-classic = lib.mkIf (lib.any (cfg: cfg.enable) (lib.attrValues userCfgs)) {
      enable = lib.mkDefault true;
      package = lib.mkDefault null;
      extraPackages = lib.mkDefault [ ];
    };

    home-manager.users = lib.mapAttrs (
      user: cfg:
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        modes = [
          "locked"
          "normal"
          "mouse"
        ];
      in
      lib.mkMerge [
        (
          let
            riverColor = s: "0x${s}";
          in
          {
            home.packages = with pkgs; [ bibata-cursors ];

            programs.i3bar-river = {
              enable = true;
              settings = with config.colors.hex; {
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

            services.mako = {
              enable = true;
              settings = with config.colors.hex; {
                font = "monospace 14";
                background-color = bg.normal;
                text-color = fg.normal;
                border-size = 1;
                border-color = fg.normal;
                progress-color = bg.faded;
                layer = "overlay";
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
                with config.colors.hexWithoutHash;
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

                  declare-mode = modes;
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

                  riverctl spawn '${lib.getExe' pkgs.owm "owm"} --overlap-borders-by ${builtins.toString border} --reading-order-weight=1'
                  riverctl spawn '${lib.getExe' pkgs.owm "owm"} --namespace overview --overlap-borders-by ${builtins.toString border} --max-width "" --area-ratios 1 --center-main-weight 0'
                  riverctl spawn '${lib.getExe' pkgs.owm "owm"} --namespace monocle --overlap-borders-by ${builtins.toString border} --min-width 9999 --min-height 9999 --max-width ""'
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

            xdg.configFile."wl-kbptr/config".text = with config.colors.hex; ''
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
        )

        (
          let
            cfg_ = cfg.osk;
            osk = "${lib.getExe' pkgs.wvkbd "wvkbd-deskintl"}";
            oskState = ''$"($env.XDG_RUNTIME_DIR)/osk"'';
          in
          lib.mkIf cfg_.enable {
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
                    oskCmd = "${osk} --hidden -H ${toString cfg_.portrait.height} -L ${toString cfg_.landscape.height}";
                    completelyTypeWord = pkgs.writeShellApplication {
                      name = "completelyTypeWord.sh";
                      text = "${pkgs.swipe-guess.src}/completelyTypeWord.sh";
                      runtimeInputs = [ pkgs.wtype ];
                    };
                  in
                  if cfg_.swipe.enable then
                    pkgs.writeShellScript "osk" ''
                      ${oskCmd} -O | ${lib.getExe pkgs.swipe-guess} ${cfg_.swipe.wordList} | ${lib.getExe completelyTypeWord}
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
            wayland.windowManager.river.settings.map =
              let
                oskMappings = {
                  ${cfg_.binding} = lib.mkForce "spawn ${toggleOsk}";
                };
                toggleOsk = pkgs.writeScript "toggle-osk" ''
                  #!${lib.getExe pkgs.nushell}
                  ${lib.getExe' pkgs.coreutils "kill"} -SIGRTMIN (open ${oskState})
                '';
              in
              builtins.listToAttrs (map (name: lib.nameValuePair name oskMappings) modes)
              // {
                "-repeat" = builtins.listToAttrs (
                  map (
                    name:
                    lib.nameValuePair name {
                      ${cfg_.binding} = lib.mkForce null;
                    }
                  ) modes
                );
              };
          }
        )

        (
          let
            cfg_ = cfg.toggleDisplay;
          in
          lib.mkIf cfg_.enable {
            wayland.windowManager.river.settings.map =
              let
                displayMappings = {
                  ${cfg_.binding} = lib.mkForce "spawn ${toggleDisplay}";
                };
                toggleDisplay = pkgs.writeScript "toggle-display" ''
                  #!${lib.getExe pkgs.nushell}
                  if (${lib.getExe pkgs.way-displays} -y -g | from yaml | get STATE | get HEADS | where NAME == ${cfg_.name} | get 0 | get CURRENT | get ENABLED) {
                    ${lib.getExe pkgs.way-displays} -s DISABLED ${cfg_.name}
                    ${
                      if cfg.toggleDisplay.disableTouch.enable then
                        "${lib.getExe' pkgs.river "riverctl"} input ${cfg_.disableTouch.input} events disabled"
                      else
                        ""
                    }
                  } else {
                    ${lib.getExe pkgs.way-displays} -d DISABLED ${cfg_.name}
                    ${
                      if cfg.toggleDisplay.disableTouch.enable then
                        "${lib.getExe' pkgs.river "riverctl"} input ${cfg_.disableTouch.input} events enabled"
                      else
                        ""
                    }
                  }
                '';
              in
              builtins.listToAttrs (map (name: lib.nameValuePair name displayMappings) modes)
              // {
                "-repeat" = builtins.listToAttrs (
                  map (
                    name:
                    lib.nameValuePair name {
                      ${cfg_.binding} = lib.mkForce null;
                    }
                  ) modes
                );
              };
          }
        )

        (
          let
            cfg_ = cfg.idle;

            lockCommand = "systemctl --user start lock.service";
            lockScript = pkgs.writeShellScript "lock.sh" ''
              # Reduce screen blank timeout
              # for lockscreen.
              ${lib.getExe pkgs.swayidle} -w \
                timeout 15 '${disableAll lockDisplaysState}' \
                resume '${enableAll lockDisplaysState}' &
              swayidle_pid=$!

              ${cfg_.lock.command}
              swaylock_ret=$?

              ${enableAll lockDisplaysState}
              kill $swayidle_pid
              exit $swaylock_ret
            '';

            lockBeforeSleepScript = pkgs.writeShellScript "lock-before-sleep.sh" ''
              ${lib.getExe' pkgs.coreutils "date"} +%s > "${timestampFile}"
            '';
            lockAfterSleepScript = pkgs.writeShellScript "lock-after-sleep.sh" ''
              read -r before < "${timestampFile}"
              current=$( ${lib.getExe' pkgs.coreutils "date"} +%s )
              elapsed=$(( current - before ))

              if (( elapsed > ${toString cfg_.lock.timeout} )); then
                exec ${lockCommand}
              fi
            '';
            timestampFile = "$XDG_RUNTIME_DIR/lock-after-sleep-timestamp";

            disableAll =
              state:
              pkgs.writeScript "disable-all" ''
                #!${lib.getExe pkgs.nushell}
                let displays = (${lib.getExe pkgs.way-displays} -y -g | from yaml | get STATE | get HEADS | where CURRENT.ENABLED | get NAME)
                $displays | save -f ${state}
                $displays | each {|o| try { ${lib.getExe pkgs.way-displays} -s DISABLED $o } } | ignore
              '';
            enableAll =
              state:
              pkgs.writeScript "enable-all" ''
                #!${lib.getExe pkgs.nushell}
                open ${state} | lines | each {|o| try { ${lib.getExe pkgs.way-displays} -d DISABLED $o } } | ignore
                rm ${state}
              '';

            displaysState = ''$"($env.XDG_RUNTIME_DIR)/idle-displays"'';
            lockDisplaysState = ''$"($env.XDG_RUNTIME_DIR)/lock-idle-displays"'';
          in
          # As of 2025-04-30,
          # `services.swayidle` doesn't accept paths for commands.
          lib.mkIf cfg_.enable (
            lib.mkMerge [
              {
                services.swayidle = {
                  enable = true;
                };
                services.wayland-pipewire-idle-inhibit.enable = true;
              }
              (lib.mkIf cfg_.displays.enable {
                services.swayidle.timeouts = [
                  {
                    timeout = cfg_.displays.timeout;
                    command = builtins.toString (disableAll displaysState);
                    resumeCommand = builtins.toString (enableAll displaysState);
                  }
                ];
              })
              (lib.mkIf cfg_.lock.enable (
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
                          timeout = cfg_.lock.timeout;
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

                  (lib.mkIf cfg_.lock.afterSleep {
                    services.swayidle.events = [
                      {
                        event = "before-sleep";
                        command = builtins.toString lockBeforeSleepScript;
                      }
                      {
                        event = "after-resume";
                        command = builtins.toString lockAfterSleepScript;
                      }
                    ];
                  })
                ]
              ))
              (lib.mkIf cfg_.suspend.enable {
                services.swayidle.timeouts = [
                  {
                    timeout = cfg_.suspend.timeout;
                    command = "${lib.getExe' pkgs.systemd "systemctl"} suspend";
                  }
                ];
              })
            ]
          )
        )

        (
          let
            cfg_ = cfg.dictation;
          in
          lib.mkIf cfg_.enable {
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

            wayland.windowManager.river.settings.map =
              let
                dictationBindings = {
                  ${cfg_.binding} = lib.mkForce "spawn ${toggleDictation}";
                };
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
              in
              builtins.listToAttrs (map (name: lib.nameValuePair name dictationBindings) modes)
              // {
                "-repeat" = builtins.listToAttrs (
                  map (
                    name:
                    lib.nameValuePair name {
                      ${cfg_.binding} = lib.mkForce null;
                    }
                  ) modes
                );
              };
          }
        )
      ]
    ) userCfgs;
  };
}
