{
  config,
  lib,
  pkgs,
  ...
}:
let
  config' = config;

  cfgs = map (jstos: jstos.terminal) (lib.attrValues config.jstos.users);
  serverEnabled = lib.any (cfg: cfg.remote.server.enable) cfgs;

  moshWindow = pkgs.writeShellScriptBin "mosh-window" ''
    exec ${lib.getExe terminalWindow} -e ${lib.getExe moshWrapped} "$@"
  '';

  # We cannot specify the full path to `zellij`,
  # using `pkgs.zellij`,
  # for the remote machine.
  moshWrapped = pkgs.writeShellScriptBin "mosh" ''
    exec ${lib.getExe' mosh "mosh"} "$@" -- zellij
  '';

  # Without a patch,
  # Mosh ignores cursor shape
  # in many situations.
  mosh = pkgs.mosh.overrideAttrs (
    {
      patches ? [ ],
      ...
    }:
    {
      patches = patches ++ [
        (pkgs.fetchpatch {
          url = "https://github.com/matheusfillipe/mosh/commit/c7740d43fe616889aa89ac82a1dd631ef54193b5.patch";
          hash = "sha256-ratfcw8gvvwhTpjCSdHPznEDp/jpBtx0Xavbx03pTDg=";
        })
      ];
    }
  );

  shellWindow = pkgs.writeShellScriptBin "shell-window" ''
    exec ${lib.getExe terminalWindow} "$@" -e ${lib.getExe pkgs.zellij}
  '';

  terminalWindow = pkgs.writeShellScriptBin "terminal-window" ''
    ${lib.getExe' pkgs.foot "footclient"} -E "$@"
  '';
in
{
  jstos.userModules = [
    (
      { config, ... }:
      {
        options.terminal = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default =
              config.enable && config'.jstos.device.has.regularUsage && config'.jstos.device.has.display;
            defaultText = lib.literalExpression "config.jstos.users.<name>.enable && config.jstos.device.has.regularUsage && config.jstos.device.has.display";
            description = ''
              Whether to enable the terminal.
            '';
          };

          default = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether this is the default terminal.
            '';
          };

          remote = {
            address = lib.mkOption {
              type = lib.types.str;
              example = "255.255.255.255";
              description = ''
                Address of server to remote to.
                Unneeded if client binding is disabled.
              '';
            };

            client = {
              enable = lib.mkEnableOption "remote shell client";
              binding = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = "Super+Control+Shift return";
                description = ''
                  Binding to open remote client to `address`.
                  Disable binding by setting to `null`.
                '';
              };
            };

            server.enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              example = true;
              description = ''
                Whether to enable remote shell server.
                This can be enabled without enabling the terminal itself.
                For optimal results,
                use the same terminal configuration on client and server.
              '';
            };
          };
        };

        config.windowManager.bindings =
          let
            remoteCfg = config.terminal.remote;
          in
          lib.mkIf (remoteCfg.client.enable && remoteCfg.client.binding != null) {
            ${remoteCfg.client.binding}.normal.command = "spawn '${moshWindow} ${remoteCfg.address}'";
          };
      }
    )
  ];

  programs.mosh = lib.mkIf serverEnabled {
    enable = true;
    package = mosh;
  };
  environment.sessionVariables.MOSH_SERVER_NETWORK_TMOUT = lib.mkIf serverEnabled "1209600"; # 2 weeks

  home-manager.users = lib.mapAttrs (
    user: jstos:
    let
      cfg = jstos.terminal;
      colors = jstos.colors;
    in
    { config, ... }:
    lib.mkMerge [
      (lib.mkIf cfg.enable ({
        home.packages = [
          shellWindow
          terminalWindow

          (lib.mkIf jstos.shell.enable (
            # As of 2022-12-12,
            # `nu -i -c` fails to automatically source `config.nu`,
            # <https://github.com/nushell/nushell/issues/7442>.
            pkgs.writeShellScriptBin "t" ''
              exec terminal-window --working-directory "$PWD" -T "$(dirs +0):$*" -e ${lib.getExe pkgs.nushell} --config ~/.config/nushell/config.nu --env-config ~/.config/nushell/env.nu -i -c "$*" > /dev/null 2>&1 & disown
            ''
          ))
        ];

        programs.foot = {
          enable = true;
          server.enable = true;
          settings = {
            main.font = "monospace:size=14";
            scrollback.lines = 0;
            cursor.beam-thickness = 1;
            colors =
              with colors.hexWithoutHash;
              {
                foreground = fg.normal;
                background = bg.normal;

                selection-foreground = bg.normal;
                selection-background = fg.normal;

                cursor = "${bg.normal} ${fg.normal}";

                regular0 = bg.normal;
                regular1 = fg.faded;
                regular2 = fg.faded;
                regular3 = fg.faded;
                regular4 = fg.faded;
                regular5 = fg.faded;
                regular6 = fg.faded;
                regular7 = fg.normal;

                bright0 = fg.gray;
                bright1 = fg.faded;
                bright2 = fg.faded;
                bright3 = fg.faded;
                bright4 = fg.faded;
                bright5 = fg.faded;
                bright6 = fg.faded;
                bright7 = fg.normal;

                dim0 = bg.normal;
                dim1 = bg.faded;
                dim2 = bg.faded;
                dim3 = bg.faded;
                dim4 = bg.faded;
                dim5 = bg.faded;
                dim6 = bg.faded;
                dim7 = bg.gray;
              }
              // lib.genAttrs (map builtins.toString (lib.lists.range 16 255)) (_: fg.faded);
          };
        };
      }))

      (lib.mkIf (cfg.enable || cfg.remote.server.enable) (
        let
          scrollbackConfigPath = "helix/scrollback-config.toml";
        in
        {
          home.packages = [ pkgs.zellij ];

          # As of 2023-07-02,
          # the Zellij Home Manager module is broken,
          # see <https://github.com/nix-community/home-manager/issues/4054>.
          xdg.configFile."zellij/config.kdl".text = ''
            keybinds clear-defaults=true {
              normal {
                bind "Ctrl s" { SwitchToMode "Scroll"; }
                bind "Ctrl Space" { EditScrollback; }
              }
              scroll {
                bind "Ctrl c" "Esc" "i" { ScrollToBottom; SwitchToMode "Normal"; }
                bind "e" "Space" { EditScrollback; ScrollToBottom; SwitchToMode "Normal"; }
                bind "/" { SwitchToMode "EnterSearch"; SearchInput 0; }
                bind "j" "Down" { ScrollDown; }
                bind "k" "Up" { ScrollUp; }
                bind "d" { HalfPageScrollDown; }
                bind "u" { HalfPageScrollUp; }
                bind "f" "PageDown" "Right" "l" { PageScrollDown; }
                bind "b" "PageUp" "Left" "h" { PageScrollUp; }
                bind "G" { ScrollToBottom; }
                bind "g" { ScrollToTop; }
              }
              entersearch {
                bind "Ctrl c" "i" { ScrollToBottom; SwitchToMode "Normal"; }
                bind "Esc" { SwitchToMode "Scroll"; }
                bind "Enter" { SwitchToMode "Search"; }
              }
              search {
                bind "Esc" { SwitchToMode "Scroll"; }
                bind "Ctrl c" "i" { ScrollToBottom; SwitchToMode "Normal"; }
                bind "j" "Down" { ScrollDown; }
                bind "k" "Up" { ScrollUp; }
                bind "d" { HalfPageScrollDown; }
                bind "u" { HalfPageScrollUp; }
                bind "f" "PageDown" "Right" "l" { PageScrollDown; }
                bind "b" "PageUp" "Left" "h" { PageScrollUp; }
                bind "G" { ScrollToBottom; }
                bind "g" { ScrollToTop; }
                bind "n" { Search "down"; }
                bind "N" { Search "up"; }
                bind "c" { SearchToggleOption "CaseSensitivity"; }
                bind "w" { SearchToggleOption "Wrap"; }
                bind "o" { SearchToggleOption "WholeWord"; }
              }
            }

            on_force_close "quit"
            simplified_ui true
            pane_frames false
            default_layout "bare"
            session_serialization false
            disable_session_metadata true
            show_startup_tips false

            default_shell "${pkgs.writeShellScript "login" ''
              if [[ $SHELL = "nu" ]]; then
                ${lib.getExe pkgs.nushell}
              else
                ${lib.getExe pkgs.bash} -l
              fi
            ''}"

            // Zellij often adds trailing spaces to empty lines,
            // see <https://github.com/zellij-org/zellij/issues/3152>.
            scrollback_editor "${pkgs.writeShellScript "edit-scrollback" ''
              ${lib.getExe pkgs.gnused} -i 's/ *$//' "$1"
              ${lib.getExe pkgs.helix} -c ${config.xdg.configHome}/${scrollbackConfigPath} +999999 "$1"
            ''}"
          '';
          xdg.configFile."zellij/layouts/bare.kdl".text = ''
            layout
          '';
          xdg.configFile.${scrollbackConfigPath}.source =
            let
              cfg = config.programs.helix.settings;
            in
            (pkgs.formats.toml { }).generate "helix-scrollback-config" (
              cfg
              // {
                editor = (if builtins.hasAttr "editor" cfg then cfg.editor else { }) // {
                  scrolloff = 0;
                  gutters = [ ];
                };
                keys.normal =
                  (if builtins.hasAttr "keys" cfg && builtins.hasAttr "normal" cfg.keys then cfg.keys.normal else { })
                  // {
                    esc = ":q";
                    i = ":q";
                    "C-c" = ":q";
                  };
              }
            );
        }
      ))

      (lib.mkIf cfg.remote.client.enable ({
        home.packages = [
          moshWindow
          moshWrapped
        ];
      }))

      (lib.mkIf (cfg.enable && cfg.default) ({
        home.packages = [
          (pkgs.makeDesktopItem {
            name = "term-dir-handler";
            type = "Application";
            exec = "shell-window --working-directory %F";
            desktopName = "Open Directory In Terminal";
            mimeTypes = [
              "inode/directory"
              "inode/mount-point"
            ];
            categories = [
              "System"
              "FileTools"
              "FileManager"
            ];
          })
        ];

        home.sessionVariables.TERMINAL = "shell-window";

        xdg.mimeApps = {
          enable = true;

          defaultApplications =
            let
              fileManager = "term-dir-handler.desktop";
            in
            {
              "inode/directory" = fileManager;
              "inode/mount-point" = fileManager;
            };
        };
      }))
    ]
  ) config.jstos.users;
}
