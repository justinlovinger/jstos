{
  config,
  jstos-pkgs,
  lib,
  pkgs,
  ...
}:
{
  jstos.userModules = [
    (
      { config, ... }:
      {
        options.shell.shell = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.shell.enable;
            defaultText = lib.literalExpression "config.jstos.users.<name>.shell.enable";
            description = ''
              Whether to enable the shell.
            '';
          };
        };
      }
    )
  ];

  home-manager.users = lib.mapAttrs (
    user: jstos:
    let
      cfg = jstos.shell.shell;
      colors = jstos.colors;
    in
    lib.mkIf cfg.enable {
      programs.dircolors = {
        enable = true;

        settings =
          with colors.term;
          rec {
            # Set-user-ID, set-group-ID, and capabilities are potential security risks.
            SETUID = fg.yellow; # `u+s`. File that runs as the user who made it, instead of the one who executes it.
            SETGID = fg.yellow; # `g+s`. File that runs as the group who made it, instead of the one who executes it.
            CAPABILITY = fg.yellow; # File that runs with one or more elevated permissions, regardless of who runs it.

            # Common special files should be easy to differentiate from regular files
            # without standing out _too_ much.
            LINK = "04";
            ORPHAN = "${LINK};${fg.red}"; # Broken links should be easy to differentiate.
            EXEC = "01";
            DIR = "03";
            OTHER_WRITABLE = "${DIR};${bg.faded}"; # Directory that is other-writable (`o+w`).

            SOCK = "${LINK};${bg.faded}";
            DOOR = "${LINK};${bg.faded}";
            BLK = bg.faded;
            CHR = bg.faded;

            # A sticky directory is one where files can only be deleted,
            # renamed,
            # or moved by their owner,
            # the directory owner,
            # or root.
            # Sticky directories have _more_ security.
            # They don't need to stand out more.
            STICKY_OTHER_WRITABLE = OTHER_WRITABLE; # Directory that is other-writable and sticky (`+t,o+w`).
            STICKY = DIR; # Directory that is sticky (`+t`).

            # Temporary files are less important.
            "*~" = fg.faded;
            ".bak" = fg.faded;
            ".org" = fg.faded;
            ".orig" = fg.faded;
            ".swp" = fg.faded;
            ".tmp" = fg.faded;
          }
          # Some files have colors by default.
          // (lib.listToAttrs (
            map
              (name: {
                inherit name;
                value = fg.normal;
              })
              [
                ".tar"
                ".tgz"
                ".arc"
                ".arj"
                ".taz"
                ".lha"
                ".lz4"
                ".lzh"
                ".lzma"
                ".tlz"
                ".txz"
                ".tzo"
                ".t7z"
                ".zip"
                ".z"
                ".dz"
                ".gz"
                ".lrz"
                ".lz"
                ".lzo"
                ".xz"
                ".zst"
                ".tzst"
                ".bz2"
                ".bz"
                ".tbz"
                ".tbz2"
                ".tz"
                ".deb"
                ".rpm"
                ".jar"
                ".war"
                ".ear"
                ".sar"
                ".rar"
                ".alz"
                ".ace"
                ".zoo"
                ".cpio"
                ".7z"
                ".rz"
                ".cab"
                ".wim"
                ".swm"
                ".dwm"
                ".esd"
                ".jpg"
                ".jpeg"
                ".mjpg"
                ".mjpeg"
                ".gif"
                ".bmp"
                ".pbm"
                ".pgm"
                ".ppm"
                ".tga"
                ".xbm"
                ".xpm"
                ".tif"
                ".tiff"
                ".png"
                ".svg"
                ".svgz"
                ".mng"
                ".pcx"
                ".mov"
                ".mpg"
                ".mpeg"
                ".m2v"
                ".mkv"
                ".webm"
                ".ogm"
                ".mp4"
                ".m4v"
                ".mp4v"
                ".vob"
                ".qt"
                ".nuv"
                ".wmv"
                ".asf"
                ".rm"
                ".rmvb"
                ".flc"
                ".avi"
                ".fli"
                ".flv"
                ".gl"
                ".dl"
                ".xcf"
                ".xwd"
                ".yuv"
                ".cgm"
                ".emf"
                ".ogv"
                ".ogx"
              ]
          ));
      };

      programs.fzf = rec {
        enable = true;
        defaultCommand = "${lib.getExe pkgs.fd} --strip-cwd-prefix --color always";
        defaultOptions = with colors.hex; [
          "--ansi" # Color text, instead of showing color codes
          "--bind=tab:down,shift-tab:up"
          "--color='${
            lib.concatStringsSep "," [
              "bg+:${bg.faded}"
              "fg:${fg.normal}"
              "fg+:${fg.normal}"
              "hl:${fg.yellow}"
              "hl+:${fg.orange}"
              "prompt:${fg.normal}"
              "info:${fg.faded}"
              "spinner:${fg.normal}"
              "header:${fg.normal}"
              "pointer:${fg.normal}"
              "marker:${fg.faded}"
              "border:${bg.faded}"
              "preview-fg:${fg.normal}"
            ]
          }'"
          "--cycle"
          "--height=50%"
          "--preview-window=right:wrap"
          "--reverse"
        ];
        changeDirWidgetCommand = "${lib.getExe pkgs.fd} --strip-cwd-prefix --type d --color always";
        fileWidgetCommand = defaultCommand;
      };

      home.packages = [
        pkgs.fd # Faster `find`
        jstos-pkgs.tag
        jstos-pkgs.tag-view

        (pkgs.writeShellScriptBin "o" ''
          # From `xdg-open`:
          get_key() {
            local file="$1"
            local key="$2"
            local desktop_entry=""

            IFS_="$IFS"
            IFS=""
            while read -r line
            do
              case "$line" in
                "[Desktop Entry]")
                  desktop_entry="y"
                ;;
                # Reset match flag for other groups
                "["*)
                  desktop_entry=""
                ;;
                "$key="*)
                  # Only match Desktop Entry group
                  if [[ -n "$desktop_entry" ]]
                  then
                    echo "$line" | ${lib.getExe' pkgs.coreutils "cut"} -d= -f 2-
                    break
                  fi
              esac
            done < "$file"
            IFS="$IFS_"
          }

          # Partially from `xdg-open`:
          find_desktop_file() {
            local xdg_user_dir="$XDG_DATA_HOME"
            [[ -n "$xdg_user_dir" ]] || xdg_user_dir="$HOME/.local/share"

            local xdg_system_dirs="$XDG_DATA_DIRS"
            [[ -n "$xdg_system_dirs" ]] || xdg_system_dirs=/usr/local/share/:/usr/share/

            for d in $(echo "$xdg_user_dir:$xdg_system_dirs" | sed 's/:/ /g'); do
              if [[ -d "$d" ]]; then
                f=$(${lib.getExe pkgs.fd} --glob "$1" "$d")
                if [[ -n "$f" ]]; then
                  echo "$f"
                  return 0
                fi
              fi
            done
            return 1
          }

          # `xdg-open` won't open with the proper default application,
          # unless it detects a display.
          # Even if the application is a terminal application.
          # We can trick it
          # by setting a fake display.
          if [[ $SSH_CONNECTION ]]; then
            export DISPLAY=null
            exec ${lib.getExe' pkgs.xdg-utils "xdg-open"} "$@"
          else
            # If not in an SSH session,
            # we can open applications in new windows.
            # Terminal applications need a new terminal
            # to open in a new window.
            if [[ -f "$1" ]]; then
              default=$(${lib.getExe' pkgs.xdg-utils "xdg-mime"} query default "$(${lib.getExe' pkgs.xdg-utils "xdg-mime"} query filetype "$1")")
              if [[ -n "$default" ]]; then
                default_file=$(find_desktop_file "$default")
                if [[ -n "$default_file" ]] && [[ "$(get_key "$default_file" "Terminal")" = "true" ]]; then
                  cmd=$(get_key "$default_file" "Exec" | ${lib.getExe' pkgs.coreutils "cut"} -d' ' -f1)
                  exec terminal-window --working-directory "$PWD" -T "$(dirs +0):$cmd $*" -e ${lib.getExe' pkgs.xdg-utils "xdg-open"} "$@" > /dev/null 2>&1 & disown
                  exit
                fi
              fi
            fi
            exec ${lib.getExe' pkgs.xdg-utils "xdg-open"} "$@" > /dev/null 2>&1 & disown
          fi
        '')

        # Script from <https://superuser.com/a/611582/1193811>.
        (pkgs.writeShellScriptBin "countdown" ''
          date1=$((`${lib.getExe' pkgs.coreutils "date"} +%s` + $1))
          while [ "$date1" -ge `${lib.getExe' pkgs.coreutils "date"} +%s` ]; do
            echo -ne "$(${lib.getExe' pkgs.coreutils "date"} -u --date @$(($date1 - `${lib.getExe' pkgs.coreutils "date"} +%s`)) +%H:%M:%S)\r"
            ${lib.getExe' pkgs.coreutils "sleep"} 0.1
          done
        '')
      ];

      # Nushell has poor compatability
      # as a login shell.
      programs.bash = {
        enable = true;
        # Home Manager uses our login shell
        # for its activation script,
        # so we need to ensure our login script only drops into Nushell
        # when running from an interactive shell.
        profileExtra = ''
          if [[ $- == *i* ]]; then
            export SHELL=nu
            if [ "$(tty)" = "/dev/tty1" ]; then
              exec river
            else
              exec nu
            fi
          fi
        '';
      };

      programs.starship = {
        enable = true;

        enableBashIntegration = false;
        enableZshIntegration = false;
        enableNushellIntegration = false; # As of 2023-06-01, Nushell integration is flawed.

        settings = with colors.hex; {
          format = lib.concatStrings [
            "["
            "$username"
            "$hostname"
            "$directory"
            "$nix_shell"
            "$cmd_duration"
            "$time"
            "$line_break"
            "$character"
            "](${fg.gray})"
          ];

          character = {
            success_symbol = "[→](${fg.gray})";
            error_symbol = "[x](${fg.gray})";
            vimcmd_symbol = "[←](${fg.gray})";
          };

          cmd_duration = {
            style = fg.gray;
          };

          directory = {
            style = fg.gray;
            read_only_style = fg.gray;
          };

          hostname = {
            ssh_symbol = "";
            style = fg.gray;
          };

          nix_shell = {
            symbol = "";
            style = fg.gray;
          };

          time = {
            disabled = false;
            style = fg.gray;
          };

          username = {
            style_root = fg.orange;
            style_user = fg.gray;
          };
        };
      };

      programs.nushell = {
        enable = true;

        # Dependencies must be `source`ed before dependents.
        extraConfig = ''
          source ${./find.nu}
          source ${./journal.nu}
        '';

        extraEnv = with colors.hex; ''
          $env.STARSHIP_SHELL = "nu"

          def create_left_prompt [] {
            $"(ansi reset)(starship prompt --cmd-duration $env.CMD_DURATION_MS $'--status=($env.LAST_EXIT_CODE)')"
          }

          $env.PROMPT_COMMAND = { create_left_prompt }
          $env.PROMPT_COMMAND_RIGHT = { "" }

          $env.PROMPT_INDICATOR = ""
          $env.PROMPT_INDICATOR_VI_INSERT = ""
          $env.PROMPT_INDICATOR_VI_NORMAL = ""
          $env.PROMPT_MULTILINE_INDICATOR = { $"(ansi reset)(ansi -e { fg: '${fg.gray}' })(': ')" }
        '';

        settings = {
          table = {
            mode = "light";
          };

          completions = {
            algorithm = "fuzzy";
            partial = false;
          };

          color_config = with colors.hex; {
            separator = "white";
            leading_trailing_space_bg = "{ attr: n }";
            header = "white";
            empty = "white";
            bool = "white";
            filesize = "white";
            date = "white";
            range = "white";
            float = "white";
            string = "white";
            nothing = "white";
            binary = "white";
            cellpath = "white";
            row_index = "white";
            record = "white";
            list = "white";
            block = "white";
            hints = fg.faded;

            shape_and = "white";
            shape_binary = "white";
            shape_block = "white";
            shape_bool = "white";
            shape_custom = "white";
            shape_datetime = "white";
            shape_directory = "white";
            shape_external = "white";
            shape_externalarg = "white";
            shape_filepath = "white";
            shape_flag = "white";
            shape_float = "white";
            shape_garbage = "{ attr: u }";
            shape_globpattern = "white";
            shape_int = "white";
            shape_internalcall = "white";
            shape_list = "white";
            shape_literal = "white";
            shape_matching_brackets = ''{ bg: "${bg.faded}" attr: b }'';
            shape_nothing = "white";
            shape_operator = "white";
            shape_or = "white";
            shape_pipe = "white";
            shape_range = "white";
            shape_record = "white";
            shape_redirection = "white";
            shape_signature = "white";
            shape_string = "{ attr: i }";
            shape_string_interpolation = "white";
            shape_table = "white";
            shape_variable = "white";
          };

          cursor_shape = {
            vi_insert = "line";
            vi_normal = "block";
          };

          edit_mode = "vi";

          show_banner = false;

          menus = [
            {
              name = "completion_menu";
              only_buffer_difference = false; # Default
              marker = "";
              type = {
                layout = "columnar"; # Default
                columns = 4; # Default
                col_width = 20; # Default
                col_padding = 2; # Default
              };
              style = with colors.hex; {
                text = fg.normal;
                selected_text = {
                  bg = bg.faded;
                  attr = "b";
                };
                description_text = fg.faded;
              };
            }
          ];

          keybindings = [
            {
              name = "kill_terminal";
              modifier = "control";
              keycode = "char_d";
              mode = [
                "emacs"
                "vi_normal"
                "vi_insert"
              ];
              event = null;
            }
            {
              name = "fuzzy_history";
              modifier = "control";
              keycode = "char_r";
              mode = [
                "emacs"
                "vi_normal"
                "vi_insert"
              ];
              event = {
                send = "ExecuteHostCommand";
                cmd = "commandline edit (history | get command | reverse | str trim | uniq | str join (char -i 0) | fzf --read0 --scheme=history --no-multi -q (commandline))";
              };
            }
            {
              name = "find_file";
              modifier = "control";
              keycode = "char_f";
              mode = [
                "emacs"
                "vi_normal"
                "vi_insert"
              ];
              event = {
                send = "ExecuteHostCommand";
                cmd = "find_file";
              };
            }
            {
              name = "find_tagged_file";
              modifier = "control";
              keycode = "char_t";
              mode = [
                "emacs"
                "vi_normal"
                "vi_insert"
              ];
              event = {
                send = "ExecuteHostCommand";
                cmd = "find_tagged_file";
              };
            }
            {
              name = "find_tagged_file_view";
              modifier = "control";
              keycode = "char_g";
              mode = [
                "emacs"
                "vi_normal"
                "vi_insert"
              ];
              event = {
                send = "ExecuteHostCommand";
                cmd = "find_tagged_file_view";
              };
            }
            {
              name = "open_file";
              modifier = "control";
              keycode = "char_e";
              mode = [
                "emacs"
                "vi_normal"
                "vi_insert"
              ];
              event = {
                send = "ExecuteHostCommand";
                cmd = "open_file";
              };
            }
          ];

          hooks = {
            pre_execution = [ ''{ print "" }'' ];
          };
        };

        shellAliases = {
          diff = "diff --color=always --unified=3";
        };
      };
    }
  ) config.jstos.users;
}
