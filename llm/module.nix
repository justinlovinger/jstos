{
  config,
  lib,
  pkgs,
  ...
}:
let
  config' = config;

  cfgs = map (jstos: jstos.llm) (builtins.attrValues config.jstos.users);

  modelsOption = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          freeformType = settingsFormat.type;
          options.name = lib.mkOption {
            type = lib.types.str;
            default = name;
            internal = true; # Hide from documentation.
          };
        }
      )
    );
    default = { };
    description = ''
      Mapping of LLM model names to settings.
      Settings are based on AIChat model settings.
      `name` field in settings defaults to model name.
    '';
  };

  settingsFormat = pkgs.formats.yaml { };
in
{
  jstos.userModules = [
    (
      { config, ... }:
      {
        options.llm = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.enable && config'.jstos.device.has.regularUsage;
            defaultText = lib.literalExpression "config.jstos.users.<name>.enable && config.jstos.device.has.regularUsage";
            description = ''
              Whether to enable the LLM.
            '';
          };

          defaultModel = {
            provider = lib.mkOption {
              type = lib.types.str;
              defaultText = "Based on enabled providers.";
              description = ''
                Provider of the default model.
              '';
            };
            model = lib.mkOption {
              type = lib.types.str;
              defaultText = "Based on enabled providers.";
              description = ''
                Name of the default model.
              '';
            };
          };

          mcpServers = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, ... }:
                {
                  options = {
                    settings = lib.mkOption {
                      inherit (settingsFormat) type;
                      description = ''
                        Settings for this MCP server,
                        based on AIChat MCP server settings.
                        Name defaults to name of this attribute.
                      '';
                    };
                    tools = lib.mkOption {
                      type = lib.types.attrsOf (
                        lib.types.submodule (
                          { ... }:
                          {
                            options = {
                              safe = lib.mkOption {
                                type = lib.types.bool;
                                default = false;
                                description = ''
                                  Whether this tool can run without user intervention.
                                '';
                              };
                            };
                          }
                        )
                      );
                      description = ''
                        Tools exposed by this MCP server.
                        Name should match the name of the tool.
                      '';
                    };
                  };

                  config = {
                    settings.name = lib.mkDefault name;
                  };
                }
              )
            );
            description = ''
              MCP servers available to LLMs.
              MCP servers provide tools.
            '';
          };

          local = {
            enable = lib.mkEnableOption "local models";
            models = modelsOption;
          };

          openrouter = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether to enable OpenRouter.
              '';
            };

            models = modelsOption;
          };
        };

        config.llm = {
          defaultModel = lib.mkIf config.llm.openrouter.enable {
            provider = lib.mkDefault "openrouter";
            model = lib.mkDefault "deepseek/deepseek-v4-flash";
          };

          openrouter.models = {
            "deepseek/deepseek-v4-flash" = {
              max_input_tokens = 1048576;
              supports_reasoning = true;
              supports_function_calling = true;
              patch.body = {
                reasoning.enabled = lib.mkDefault true;
                models = [
                  "deepseek/deepseek-v3.2"
                ];
              };
            };
            "deepseek/deepseek-v4-pro" = {
              max_input_tokens = 1048576;
              supports_reasoning = true;
              supports_function_calling = true;
              patch.body = {
                reasoning.enabled = lib.mkDefault true;
                models = [
                  "deepseek/deepseek-v4-flash"
                  "deepseek/deepseek-v3.2"
                ];
              };
            };
          };
        };
      }
    )
  ];

  services.ollama.enable = lib.any (cfg: cfg.enable && cfg.local.enable) cfgs;

  home-manager.users = lib.mapAttrs (
    user: jstos:
    let
      cfg = jstos.llm;
    in
    {
      programs.aichat = {
        enable = true;

        # Upstream does not support MCP yet.
        # Rust packages do not support overriding source.
        package = pkgs.rustPlatform.buildRustPackage {
          pname = "aichat";
          version = "0.30.0";

          src = pkgs.fetchFromGitHub {
            owner = "subpop";
            repo = "aichat";
            rev = "0892fbbc3ef7dc59c930555f224c75333000b646"; # add_mcp_support
            hash = "sha256-zvHwFXJjLYmIlUzPtSvScdZmS74ovwtEyoYLLV46PWM=";
          };

          cargoHash = "sha256-Qb1Gl3BuswSYyFrXzVUrgr5jCJjvdv5WvRmWVZiwSs8=";

          nativeBuildInputs = [
            pkgs.pkg-config
            pkgs.installShellFiles
          ];

          postInstall = ''
            installShellCompletion ./scripts/completions/aichat.{bash,fish,zsh}
          '';

          nativeInstallCheckInputs = [
            pkgs.versionCheckHook
          ];
          versionCheckProgramArg = "--version";
          doInstallCheck = true;
        };

        settings =
          let
            toolName = server: tool: "mcp__${server}__${tool}";
          in
          {
            model = "${
              if cfg.defaultModel.provider == "local" then "ollama" else cfg.defaultModel.provider
            }:${cfg.defaultModel.model}";

            # Reducing randomness results in better correctness.
            # Note that setting temperature to 0 can result in loops on thinking models.
            temperature = lib.mkDefault 0;
            top_p = lib.mkDefault 0;

            save = lib.mkDefault false;
            keybindings = lib.mkDefault "vi";
            wrap = lib.mkDefault "no";

            # By default,
            # AIChat destroys context frequently.
            compress_threshold = lib.mkDefault 0;

            highlight = lib.mkDefault false;

            function_calling = lib.mkDefault true;

            mapping_tools =
              let
                tools = lib.mapAttrs (
                  server:
                  { tools, ... }:
                  lib.concatStringsSep "," (map (tool: toolName server tool) (builtins.attrNames tools))
                ) cfg.mcpServers;
              in
              tools
              // rec {
                search = lib.concatStringsSep "," (
                  with tools;
                  [
                    time
                    open-websearch
                  ]
                );
                dev = lib.concatStringsSep "," (
                  with tools;
                  [
                    search
                    shell
                    filesystem
                    git
                  ]
                );
              };
            use_tools = lib.mkDefault "search";

            tool_call_permission = lib.mkDefault "ask";
            verbose_tool_calls = lib.mkDefault true;
            tool_permissions.allowed = lib.flatten (
              lib.mapAttrsToList (
                server:
                { tools, ... }:
                map (tool: toolName server tool) (
                  builtins.attrNames (lib.filterAttrs (_: { safe, ... }: safe) tools)
                )
              ) cfg.mcpServers
            );

            mcp_servers = map ({ settings, ... }: settings) (builtins.attrValues cfg.mcpServers);

            clients = [
              (lib.mkIf cfg.local.enable {
                type = "openai-compatible";
                name = "ollama";
                api_base = "http://localhost:11434/v1";
                models = builtins.attrValues cfg.local.models;
              })

              (lib.mkIf cfg.openrouter.enable {
                type = "openai-compatible";
                name = "openrouter";
                api_base = "https://openrouter.ai/api/v1";
                models = builtins.attrValues cfg.openrouter.models;
              })
            ];
          };
      };
    }
  ) config.jstos.users;
}
