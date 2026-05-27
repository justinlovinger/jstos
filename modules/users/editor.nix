{
  config,
  jstos,
  lib,
  pkgs,
  ...
}:
let
  inherit (jstos.lib) mimeTypes;

  config' = config;
in
{
  jstos.userModules = [
    (
      { config, ... }:
      {
        options.editor = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.enable && config'.jstos.device.has.regularUsage;
            defaultText = lib.literalExpression "config.jstos.users.<name>.enable && config.jstos.device.has.regularUsage";
            description = ''
              Whether to enable the editor.
            '';
          };

          default = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether this is the default editor.
            '';
          };
        };
      }
    )
  ];

  home-manager.users = lib.mapAttrs (
    user: jstos:
    let
      cfg = jstos.editor;
      colors = jstos.colors;
    in
    lib.mkMerge [
      (lib.mkIf cfg.enable {
        home.packages = with pkgs; [
          # We need Nix support without a development shell
          # so we can write development shells.
          nixfmt-rfc-style
          nil

          # Language servers for simple stable languages
          # should be easily accessible
          # without a development shell.
          typos-lsp # Spellchecking
          marksman # Markdown
          nodePackages.vscode-langservers-extracted # Includes markup language servers, like JSON.
          taplo # Toml
          texlab # LaTeX
          yaml-language-server
        ];

        programs.helix = {
          enable = true;

          languages = {
            language-server = {
              typos.command = "typos-lsp";

              rust-analyzer.config = {
                assist.preferSelf = true;
                cargo.features = "all";
                check.command = "clippy";
              };
            };
            language = [
              {
                name = "git-commit";
                language-servers = [ "typos" ];
              }
              {
                name = "markdown";
                formatter = {
                  command = "${lib.getExe pkgs.deno}";
                  args = [
                    "fmt"
                    "--prose-wrap"
                    "preserve"
                    "--ext"
                    "md"
                    "-"
                  ];
                };
                auto-format = true;
                language-servers = [
                  {
                    name = "marksman";
                    # Marksman sometimes crashes.
                    # Disabling `code-action` allows other language-servers to still perform code-actions.
                    except-features = [ "code-action" ];
                  }
                  "typos"
                ];
              }
              {
                name = "markdown.inline";
                language-servers = [ "typos" ];
              }
              {
                name = "email";
                language-id = "plaintext";
                scope = "text.email";
                file-types = [ { glob = "*/*@*.*/*"; } ];
                language-servers = [ "typos" ];
                roots = [ ];
                indent = {
                  tab-width = 2;
                  unit = "  ";
                };
              }
              {
                name = "plaintext";
                language-id = "plaintext";
                scope = "text.plain";
                file-types = [ "txt" ];
                language-servers = [ "typos" ];
                roots = [ ];
                indent = {
                  tab-width = 2;
                  unit = "  ";
                };
              }
              {
                name = "latex";
                language-servers = [
                  "texlab"
                  "typos"
                ];
              }
              {
                name = "nix";
                formatter.command = "nixfmt";
                auto-format = true;
              }
            ];
          };

          settings = {
            theme = lib.mkDefault "system";

            editor = {
              auto-pairs = false;
              cursor-shape.insert = "bar";
              idle-timeout = 100;
              end-of-line-diagnostics = "hint";
              inline-diagnostics = {
                cursor-line = "hint";
                other-lines = "hint";
              };
              line-number = "relative";
              lsp = {
                display-messages = true;
              };
              soft-wrap = {
                enable = true;
                wrap-indicator = "↳ ";
              };
              true-color = true; # As of 2023-01-02, true color detection fails over SSH.
              whitespace = {
                render = {
                  nbsp = "all";
                  newline = "all";
                  tab = "all";
                };
                characters.newline = "↵";
              };
            };
          };

          themes.system = with colors.hex; {
            # Uncolored scopes are specified
            # to reset in nested scopes.
            # As of 2023-03-07,
            # this fails for modifiers,
            # see <https://github.com/helix-editor/helix/issues/6210>.
            attribute = fg.normal;
            type = fg.normal;
            constructor = fg.normal;
            string = {
              fg = fg.normal;
              modifiers = [ "italic" ];
            };
            comment = fg.faded;
            variable = fg.normal;
            label = fg.normal;
            punctuation = fg.normal;
            keyword = {
              fg = fg.normal;
              modifiers = [ "bold" ];
            };
            operator = fg.normal;
            function = fg.normal;
            tag = fg.normal;
            namespace = fg.normal;

            markup = fg.normal;
            "markup.heading".modifiers = [ "bold" ];
            "markup.list" = fg.normal;
            "markup.bold".modifiers = [ "bold" ];
            "markup.italic".modifiers = [ "italic" ];
            "markup.link".modifiers = [ "underlined" ];
            "markup.quote" = fg.faded;
            "markup.raw" = fg.faded;
            # "markup.quote markup.raw" = fg.normal; # Unimplemented, see <https://github.com/helix-editor/helix/issues/6201>.

            # Ideally,
            # `diff.delta`
            # and `diff.plus`
            # would be differentiated
            # by symbol,
            # but this feature is not yet available,
            # see <https://github.com/helix-editor/helix/issues/6206>.
            diff = fg.faded;

            "ui.background".bg = bg.normal;
            "ui.linenr" = fg.faded;
            "ui.linenr.selected" = fg.normal;
            "ui.statusline" = {
              fg = fg.normal;
              bg = bg.normal;
            };
            "ui.statusline.inactive" = {
              fg = fg.faded;
              bg = bg.normal;
            };
            "ui.popup".bg = bg.faded;
            "ui.popup.info".bg = bg.normal;
            "ui.window".bg = bg.normal;
            "ui.help" = {
              fg = fg.normal;
              bg = bg.normal;
            };

            "ui.text" = fg.normal;
            "ui.text.focus" = fg.normal;
            "ui.virtual.ruler".bg = bg.faded;
            "ui.virtual.whitespace" = bg.faded;
            "ui.virtual.indent-guide" = fg.faded;
            "ui.virtual.wrap" = fg.faded;
            "ui.virtual.jump-label".bg = bg.faded;

            "ui.cursor.primary" = {
              fg = bg.normal;
              bg = fg.normal;
            };
            "ui.cursor.primary.insert" = {
              fg = bg.normal;
              bg = fg.normal;
            };
            "ui.cursor.primary.select".bg = fg.faded;
            "ui.cursor" = {
              fg = bg.normal;
              bg = fg.faded;
            };
            "ui.cursor.insert" = {
              fg = bg.normal;
              bg = fg.faded;
            };
            "ui.cursor.select" = {
              fg = bg.normal;
              bg = fg.faded;
            };
            "ui.cursor.match" = {
              bg = bg.faded;
              modifiers = [ "bold" ];
            };
            "ui.selection.primary".bg = bg.faded;
            "ui.selection".bg = bg.faded;

            "ui.menu" = {
              fg = fg.normal;
              bg = bg.faded;
            };
            "ui.menu.selected".modifiers = [ "reversed" ];

            diagnostic.underline = {
              color = fg.faded;
              style = "curl";
            };
            "diagnostic.error".underline.style = "curl";
            info = {
              fg = fg.faded;
              bg = bg.faded;
            };
            hint = {
              fg = fg.faded;
              bg = bg.faded;
            };
            debug = {
              fg = fg.faded;
              bg = bg.faded;
            };
            warning = {
              fg = fg.faded;
              bg = bg.faded;
            };
            error.bg = bg.faded;
          };
        };
      })

      (lib.mkIf (cfg.enable && cfg.default) {
        home.sessionVariables = {
          EDITOR = "hx";
          VISUAL = "hx";
        };

        xdg.mimeApps = {
          enable = true;

          defaultApplications =
            let
              editor = "Helix.desktop";
            in
            # This matches `message/*`, `text/*`, and others.
            builtins.listToAttrs (
              map (x: lib.nameValuePair x editor) (
                builtins.filter (
                  x:
                  !(
                    (lib.strings.hasPrefix "audio/" x)
                    || (lib.strings.hasPrefix "image/" x)
                    || (lib.strings.hasPrefix "video/" x)
                  )
                ) mimeTypes
              )
            )
            // {
              "application/javascript" = editor; # *.js
              "application/json" = editor; # *.json
              "application/x-shellscript" = editor;
              "application/x-spss-sav" = editor; # *.sav
              "application/x-wine-extension-ini" = editor;
              "application/x-yaml" = editor;
              "inode/x-empty" = editor;
              "message/rfc822" = "mshow.desktop";
              "text/csv" = editor;
              "text/english" = editor;
              "text/html" = editor;
              "text/markdown" = editor;
              "text/plain" = editor;
              "text/rust" = editor;
              "text/vnd.qt.linguist" = editor; # *.ts
              "text/x-c" = editor;
              "text/x-c++" = editor;
              "text/x-c++hdr" = editor;
              "text/x-c++src" = editor;
              "text/x-chdr" = editor;
              "text/x-csrc" = editor;
              "text/x-devicetree-source" = editor; # *.nix
              "text/x-diff" = editor;
              "text/x-haskell" = editor;
              "text/x-java" = editor;
              "text/x-log" = editor;
              "text/x-makefile" = editor;
              "text/x-moc" = editor;
              "text/x-pascal" = editor;
              "text/x-python" = editor;
              "text/x-script.python" = editor;
              "text/x-shellscript" = editor;
              "text/x-tcl" = editor;
              "text/x-tex" = editor;
            };
        };
      })
    ]
  ) config.jstos.users;
}
