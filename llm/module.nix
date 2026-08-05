{
  config,
  jstos-llm,
  lib,
  pkgs,
  ...
}:
let
  config' = config;
  llmPkgs = jstos-llm.pkgs;

  cfgs = map (jstos: jstos.llm) (builtins.attrValues config.jstos.users);
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
              Requires `OPENROUTER_API_KEY` in `~/.config/goose/secrets.yaml`.
            '';
          };

          webSearch = lib.mkOption {
            type = lib.types.enum [
              "paid"
              "system"
              "direct"
            ];
            default = config.webSearch;
            defaultText = lib.literalExpression "config.jstos.users.<name>.webSearch";
            description = ''
              See `config.jstos.users.<name>.webSearch`.
              `paid` requires a Kagi Session Link token in `.kagi_session_token`.
            '';
          };
        };
      }
    )
  ];

  jstos.system.webSearch.enable = lib.mkIf (lib.any (
    cfg: cfg.enable && cfg.webSearch == "system"
  ) cfgs) true;
  services.searx.settings.search.formats =
    lib.mkIf (lib.any (cfg: cfg.enable && cfg.webSearch == "system") cfgs)
      [
        "html"
        "json"
      ];

  home-manager.users = lib.mapAttrs (
    user: jstos:
    let
      cfg = jstos.llm;
    in
    { lib, ... }:
    lib.mkIf cfg.enable {
      # In a future version,
      # environment variables can go in the config.
      home.packages = [
        (pkgs.symlinkJoin {
          name = "goose-cli-wrapped";
          paths = [ pkgs.goose-cli ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/goose ${
              builtins.concatStringsSep " " (
                lib.mapAttrsToList
                  (
                    name: value:
                    ''--set ${name} "${
                      if builtins.isBool value then (if value then "true" else "false") else builtins.toString value
                    }"''
                  )
                  {
                    GOOSE_SHOW_FULL_OUTPUT = true; # Don't truncate tool args.
                    GOOSE_DISABLE_SESSION_NAMING = true;
                    GOOSE_CLI_SHOW_THINKING = 1;
                    GOOSE_RANDOM_THINKING_MESSAGES = false;
                    GOOSE_NO_CODE_TRUNCATION = true;

                    GOOSE_CONTEXT_LIMIT = 1048576;
                  }
              )
            }
          '';
        })
      ];
      # Goose needs to write to its config file
      # for some features.
      home.activation.gooseConfig =
        let
          config = (pkgs.formats.yaml { }).generate "config.yaml" {
            GOOSE_TELEMETRY_ENABLED = false;

            # In a future version,
            # we may be able to define more than one model.
            GOOSE_PROVIDER = "openrouter";
            GOOSE_MODEL = "~deepseek/deepseek-v4-flash-latest";
            OPENROUTER_PARAMETERS = {
              reasoning.enabled = true;
              models = [
                "deepseek/deepseek-v4-flash-0731"
                "deepseek/deepseek-v4-flash"
              ];
            };

            # If builtins are not listed,
            # they will be enabled by default.
            extensions = {
              chatrecall = {
                enabled = false;
                type = "platform";
                name = "chatrecall";
                description = "Search past conversations and load session summaries for contextual memory";
                display_name = "Chat Recall";
                bundled = true;
                available_tools = [ ];
              };
              summon = {
                enabled = false;
                type = "platform";
                name = "summon";
                description = "Load knowledge and delegate tasks to subagents";
                display_name = "Summon";
                bundled = true;
                available_tools = [ ];
              };
              code_execution = {
                enabled = false;
                type = "platform";
                name = "code_execution";
                description = "Goose will make extension calls through code execution, saving tokens";
                display_name = "Code Mode";
                bundled = true;
                available_tools = [ ];
              };
              developer = {
                enabled = false;
                type = "platform";
                name = "developer";
                description = "Write and edit files, and execute shell commands";
                display_name = "Developer";
                bundled = true;
                available_tools = [ ];
              };
              tom = {
                enabled = false;
                type = "platform";
                name = "tom";
                description = "Inject custom context into every turn via GOOSE_MOIM_MESSAGE_TEXT and GOOSE_MOIM_MESSAGE_FILE environment variables";
                display_name = "Top Of Mind";
                bundled = true;
                available_tools = [ ];
              };
              analyze = {
                enabled = false;
                type = "platform";
                name = "analyze";
                description = "Analyze code structure with tree-sitter = directory overviews, file details, symbol call graphs";
                display_name = "Analyze";
                bundled = true;
                available_tools = [ ];
              };
              extensionmanager = {
                enabled = false;
                type = "platform";
                name = "Extension Manager";
                description = "Enable extension management tools for discovering, enabling, and disabling extensions";
                display_name = "Extension Manager";
                bundled = true;
                available_tools = [ ];
              };
              apps = {
                enabled = false;
                type = "platform";
                name = "apps";
                description = "Create and manage custom Goose apps through chat. Apps are HTML/CSS/JavaScript and run in sandboxed windows.";
                display_name = "Apps";
                bundled = true;
                available_tools = [ ];
              };
              todo = {
                enabled = false;
                type = "platform";
                name = "todo";
                description = "Enable a todo list for goose so it can keep track of what it is doing";
                display_name = "Todo";
                bundled = true;
                available_tools = [ ];
              };
              summarize = {
                enabled = false;
                type = "platform";
                name = "summarize";
                description = "Load files/directories and get an LLM summary in a single call";
                display_name = "Summarize";
                bundled = true;
                available_tools = [ ];
              };
            }
            // {
              fetch = {
                enabled = true;
                type = "stdio";
                name = "fetch";
                cmd = lib.getExe (
                  pkgs.mcp-server-fetch.overrideAttrs (
                    {
                      nativeBuildInputs ? [ ],
                      postFixup ? "",
                      ...
                    }:
                    {
                      nativeBuildInputs = nativeBuildInputs ++ [ pkgs.makeWrapper ];
                      postFixup = postFixup + ''
                        wrapProgram $out/bin/mcp-server-fetch \
                          --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nodejs ]} \
                      '';
                    }
                  )
                );
                args = [
                  "--ignore-robots-txt"
                  # The default user agent identifies the fetcher as a bot,
                  # which can result in it getting blocked.
                  "--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
                ];
                timeout = 30;
              };
            }
            // (
              if cfg.webSearch == "paid" then
                {
                  kagi = {
                    enabled = true;
                    type = "stdio";
                    name = "kagi";
                    cmd = lib.getExe (
                      llmPkgs.kagi-ken-mcp.overrideAttrs (
                        {
                          patches ? [ ],
                          ...
                        }:
                        {
                          patches = patches ++ [ ./patches/kagi-ken-mcp/simplify-search.patch ];
                        }
                      )
                    );
                    args = [ ];
                    timeout = 15;
                    available_tools = [ "search" ];
                  };
                }
              else if cfg.webSearch == "system" then
                {
                  searxng = {
                    enabled = true;
                    type = "stdio";
                    name = "searxng";
                    cmd = lib.getExe llmPkgs.mcp-searxng;
                    args = [ ];
                    envs = {
                      SEARXNG_URL = config'.services.searx.settings.server.base_url;
                      SEARXNG_LITE_TOOLS = true; # LLMs tend to do better with smaller context and simpler tools.
                      SEARXNG_MAX_RESULTS = 10; # This is what the LLM would usually ask for if it could.
                    };
                    timeout = 15;
                    available_tools = [ "searxng_web_search" ];
                  };
                }
              else
                {
                  websearch = {
                    enabled = true;
                    type = "stdio";
                    name = "websearch";
                    cmd = lib.getExe llmPkgs.open-websearch;
                    args = [ ];
                    envs = {
                      MODE = "stdio";
                      SEARCH_MODE = "request"; # We don't install Playwright for the `playwright` mode.
                      DEFAULT_SEARCH_ENGINE = "startpage";
                      ALLOWED_SEARCH_ENGINES = lib.concatStringsSep "," [
                        # "bing" # Fails due to bot detection in `request` mode.
                        "baidu"
                        "csdn"
                        "duckduckgo"
                        # "exa" # Does not appear to be working.
                        "brave" # Sometimes returns 429 Too Many Requests
                        # "juejin" # This breaks the MCP server.
                        "startpage"
                        "sogou"
                      ];
                    };
                    timeout = 15;
                    available_tools = [ "search" ];
                  };
                }
            );
          };
        in
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p "$HOME/.config/goose"
          cp -f ${config} "$HOME/.config/goose/config.yaml"
        '';
      # The default prompt is verbose and unnecessary.
      xdg.configFile."goose/prompts/system.md".text = ''
        {% if moim_system_prompt_block is defined %}
        {{ moim_system_prompt_block }}
        {% endif %}
      '';
    }
  ) config.jstos.users;
}
