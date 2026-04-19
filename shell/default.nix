{
  config,
  lib,
  pkgs,
  ...
}:
let
  terminalWindow = pkgs.writeShellScriptBin "terminal-window" ''
    ${lib.getExe' pkgs.foot "footclient"} -E "$@"
  '';

  userCfgs = config.jstos.users;
in
{
  options.jstos = {
    users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { ... }:
          {
            options = {
              terminal.enable = lib.mkEnableOption "terminal";

              shell.remote = {
                client.enable = lib.mkEnableOption "remote shell client";
                server.enable = lib.mkEnableOption "remote shell server";

                address = lib.mkOption {
                  type = lib.types.str;
                  example = "255.255.255.255";
                  description = ''
                    Address of server.
                  '';
                };
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (lib.any (cfg: cfg.shell.remote.server.enable) (lib.attrValues userCfgs)) {
      programs.mosh.enable = true;
      environment.sessionVariables.MOSH_SERVER_NETWORK_TMOUT = "1209600"; # 2 weeks
    })

    {
      home-manager.users = lib.mapAttrs (
        user: cfg:
        {
          config,
          lib,
          pkgs,
          ...
        }:
        lib.mkMerge [
          (lib.mkIf cfg.terminal.enable (
            let
              shellWindow = pkgs.writeShellScriptBin "shell-window" ''
                exec ${lib.getExe terminalWindow} "$@" -e ${lib.getExe pkgs.zellij}
              '';
            in
            {
              home.packages = [
                shellWindow
                terminalWindow
              ];

              programs.foot = {
                enable = true;
                server.enable = true;
                settings = {
                  main.font = "monospace:size=14";
                  scrollback.lines = 0;
                  cursor.beam-thickness = 1;
                  colors =
                    with config.colors.hexWithoutHash;
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
            }
          ))

          (lib.mkIf (cfg.terminal.enable || cfg.shell.remote.server.enable) (
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

          (lib.mkIf cfg.shell.remote.client.enable (
            let
              moshWindow = pkgs.writeShellScriptBin "mosh-window" ''
                exec ${lib.getExe terminalWindow} -e ${lib.getExe moshWrapped} "$@"
              '';

              # We cannot specify the full path to `zellij`,
              # using `pkgs.zellij`,
              # for the remote machine.
              moshWrapped = pkgs.writeShellScriptBin "mosh" ''
                exec ${lib.getExe' pkgs.mosh "mosh"} "$@" -- zellij
              '';
            in
            {
              home.packages = [
                moshWindow
                moshWrapped
              ];
            }
          ))
        ]
      ) userCfgs;
    }
  ];
}
