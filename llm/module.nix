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
  enabledUsersList = builtins.attrNames (
    lib.filterAttrs (_: jstos: jstos.llm.enable) config.jstos.users
  );

  containerHome = "/home/${containerUser}";
  containerName = user: "${user}-llm";
  containerUser = "llm";

  goose-dev = pkgs.writeShellScriptBin "goose-dev" ''
    exec ${lib.getExe' goose "goose"} session --with-builtin analyze,developer,todo,tom "$@"
  '';
  # In a future version,
  # environment variables can go in the config.
  goose = pkgs.symlinkJoin {
    name = "goose-cli-wrapped";
    paths = [ llmPkgs.goose-cli ];
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
              # As of writing,
              # Goose won't read this option from the config,
              # for some reason.
              GOOSE_NO_CODE_TRUNCATION = true;
            }
        )
      }
    '';
  };

  imapAttrs' =
    f: set:
    let
      names = builtins.attrNames set;
    in
    lib.listToAttrs (lib.imap0 (i: name: f i name set.${name}) names);
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

              Run the LLM using `goose`.
              Run the LLM with development tools enabled using `goose-dev`.
              Pass files to and from the LLM using `~/llm`.
              Access the LLM container manually using `machinectl shell ${containerUser}@${containerName "USER"}`.

              If you run into permission denied errors,
              you may need to set `users.users.<name>.uid`.
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
              `system` relaxes network security in the container.
            '';
          };
        };
      }
    )
  ];

  containers = imapAttrs' (
    i: user: jstos:
    let
      cfg = jstos.llm;
      hostHome = config.users.users.${user}.home;
    in
    lib.nameValuePair (containerName user) (
      lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            autoStart = true;
            ephemeral = true;

            privateNetwork = cfg.webSearch != "system"; # The container can't reach the systems search engine if using a private network.
            hostAddress = "10.231.${toString (136 + i)}.1";
            localAddress = "10.231.${toString (136 + i)}.2";

            bindMounts =
              builtins.listToAttrs (
                map
                  (
                    path:
                    lib.nameValuePair "${containerHome}/${path}" {
                      hostPath = "${hostHome}/${path}";
                      isReadOnly = false;
                    }
                  )
                  [
                    ".config/goose"
                    ".local/share/goose"
                    ".local/state/goose"
                    "llm"
                  ]
              )
              // (
                if cfg.webSearch == "paid" then
                  {
                    "${containerHome}/.kagi_session_token" = {
                      hostPath = "${hostHome}/.kagi_session_token";
                      isReadOnly = true;
                    };
                  }
                else
                  { }
              );

            config = {
              # The bind mounts don't set the correct user for intermediary directories.
              systemd.tmpfiles.rules = [
                "d ${containerHome}/.config 0755 ${containerUser} users -"
                "d ${containerHome}/.local 0755 ${containerUser} users -"
                "d ${containerHome}/.local/share 0755 ${containerUser} users -"
                "d ${containerHome}/.local/state 0755 ${containerUser} users -"
              ];

              # Containers don't have the same Nixpkgs as the host by default
              # if using flakes.
              nix.settings.experimental-features = "nix-command flakes";
              nix.nixPath = [ "nixpkgs=${pkgs.path}" ];
              nix.registry.nixpkgs.to = {
                type = "path";
                path = pkgs.path;
              };

              users.users.${containerUser} = {
                isNormalUser = true;
                home = containerHome;
                uid = config.users.users.${user}.uid;
              };

              environment.systemPackages = [
                goose
                goose-dev
              ]
              ++ (with pkgs; [
                git
                jq
              ]);

              # The container is ephemeral.
              # The only state is Goose,
              # which shouldn't matter for this.
              system.stateVersion = config.system.nixos.release;
            };
          }
          (lib.mkIf jstos.editor.enable {
            bindMounts = {
              "${containerHome}/.config/helix" = {
                hostPath = "${hostHome}/.config/helix";
                isReadOnly = true;
              };
            };
            config = {
              environment = {
                systemPackages = [ pkgs.helix ];
                variables = lib.mkIf jstos.editor.default {
                  EDITOR = "hx";
                  VISUAL = "hx";
                };
              };
            };
          })
        ]
      )
    )
  ) config.jstos.users;
  # Waiting for `network.target` isn't enough.
  # Without this,
  # the container needs to be restarted after the network is online.
  systemd.services = builtins.listToAttrs (
    map (
      user:
      lib.nameValuePair "container@${containerName user}" {
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
      }
    ) enabledUsersList
  );

  networking.nat = lib.mkIf (lib.any (cfg: cfg.enable) cfgs) {
    enable = true;
    internalInterfaces = map (user: "ve-${containerName user}") enabledUsersList;
    # We leave off `externalInterface` to select it automatically.
  };

  # The container will fail if bind mount locations don't already exist.
  systemd.tmpfiles.rules = lib.flatten (
    map (user: [
      "d ${config.users.users.${user}.home}/.config/goose 0755 ${user} users -"
      "d ${config.users.users.${user}.home}/.local/share/goose 0755 ${user} users -"
      "d ${config.users.users.${user}.home}/.local/state/goose 0755 ${user} users -"
      "d ${config.users.users.${user}.home}/llm 0755 ${user} users -"
    ]) enabledUsersList
  );

  security.polkit.enable = lib.mkIf (lib.any (cfg: cfg.enable) cfgs) true;
  security.polkit.extraConfig = lib.mkMerge (
    map (user: ''
      polkit.addRule(function(action, subject) {
        if (
          action.id == "org.freedesktop.machine1.shell"
          && subject.user == "${user}"
          && action.lookup("user") == "${containerUser}"
          && action.lookup("machine") == "${containerName user}"
        ) {
          return polkit.Result.YES;
        }
      });
    '') enabledUsersList
  );

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
      home.packages =
        let
          containerWrap = cmd: ''
            machinectl --quiet shell ${containerUser}@${containerName user} ${lib.getExe pkgs.dash} -l -c 'cd ~/llm && exec ${cmd} "$@"' _ "$@"
          '';
        in
        [
          (pkgs.writeShellScriptBin "goose" (containerWrap (lib.getExe' goose "goose")))
          (pkgs.writeShellScriptBin "goose-dev" (containerWrap (lib.getExe' goose-dev "goose-dev")))
        ];
      # Goose needs to write to its config file
      # for some features.
      home.activation.gooseConfig =
        let
          config = (pkgs.formats.yaml { }).generate "config.yaml" {
            active_provider = "openrouter";
            providers = {
              openrouter = {
                enabled = true;
                model = "deepseek/deepseek-v4.1-flash-1017";
                configured = true;
              };
            };
            GOOSE_CONTEXT_LIMIT = 1048576;
            GOOSE_MAX_TOKENS = 1048576;
            OPENROUTER_PARAMETERS = {
              reasoning.enabled = true;
              models = [
                "deepseek/deepseek-v4.1-flash"
                "deepseek/deepseek-v4-flash-0731"
                "deepseek/deepseek-v4-flash"
              ];
            };

            GOOSE_TELEMETRY_ENABLED = false;

            GOOSE_CLI_SHOW_THINKING = true;
            GOOSE_DISABLE_SESSION_NAMING = true;
            GOOSE_SHOW_FULL_OUTPUT = true; # Don't truncate tool args.
            RANDOM_THINKING_MESSAGES = false; # The documentation erronously names this `GOOSE_RANDOM_THINKING_MESSAGES`.

            # Builtins not listed completely have default settings.
            # If a builtin is enabled by default,
            # it has to be listed completely to be disabled.
            extensions = {
              analyze = {
                enabled = false;
                type = "platform";
                name = "analyze";
                description = "Analyze code structure with tree-sitter: directory overviews, file details, symbol call graphs";
                display_name = "Analyze";
                bundled = true;
              };
              apps = {
                enabled = false;
                type = "platform";
                name = "apps";
                description = "Create and manage custom Goose apps through chat. Apps are HTML/CSS/JavaScript and run in sandboxed windows.";
                display_name = "Apps";
                bundled = true;
              };
              chatrecall = {
                enabled = false;
                type = "platform";
                name = "chatrecall";
                description = "Search past conversations and load session summaries for contextual memory";
                display_name = "Chat Recall";
                bundled = true;
              };
              code_execution = {
                enabled = false;
                type = "platform";
                name = "code_execution";
                description = "Goose will make extension calls through code execution, saving tokens";
                display_name = "Code Mode";
                bundled = true;
              };
              developer = {
                enabled = false;
                type = "platform";
                name = "developer";
                description = "Write and edit files, and execute shell commands";
                display_name = "Developer";
                bundled = true;
              };
              extensionmanager = {
                enabled = false;
                type = "platform";
                name = "Extension Manager";
                description = "Enable extension management tools for discovering, enabling, and disabling extensions";
                display_name = "Extension Manager";
                bundled = true;
              };
              orchestrator = {
                enabled = false;
                type = "platform";
                name = "orchestrator";
                description = "Manage agent sessions: list, view, start, send messages, interrupt, and stop agents";
                display_name = "Orchestrator";
                bundled = true;
              };
              summarize = {
                enabled = false;
                type = "platform";
                name = "summarize";
                description = "Load files/directories and get an LLM summary in a single call";
                display_name = "Summarize";
                bundled = true;
              };
              scheduler = {
                enabled = false;
                type = "platform";
                name = "scheduler";
                description = "Create and manage scheduled recipe execution";
                display_name = "Scheduler";
                bundled = true;
              };
              skills = {
                enabled = false;
                type = "platform";
                name = "skills";
                description = "Discover and provide skill instructions from filesystem and builtins";
                display_name = "Skills";
                bundled = true;
              };
              summon = {
                enabled = false;
                type = "platform";
                name = "summon";
                description = "Load knowledge and delegate tasks to subagents";
                display_name = "Summon";
                bundled = true;
              };
              todo = {
                enabled = false;
                type = "platform";
                name = "todo";
                description = "Enable a todo list for goose so it can keep track of what it is doing";
                display_name = "Todo";
                bundled = true;
              };
              tom = {
                enabled = false;
                type = "platform";
                name = "tom";
                description = "Inject custom context into every turn via GOOSE_MOIM_MESSAGE_TEXT and GOOSE_MOIM_MESSAGE_FILE environment variables";
                display_name = "Top Of Mind";
                bundled = true;
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
                      SEARXNG_LITE_TOOLS = "true"; # LLMs tend to do better with smaller context and simpler tools.
                      SEARXNG_MAX_RESULTS = "10"; # This is what the LLM would usually ask for if it could.
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
                      DEFAULT_SEARCH_ENGINE = "duckduckgo";
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
      # The block about extensions is needed to discover Skills.
      xdg.configFile."goose/prompts/system.md".text = ''
        {% if moim_system_prompt_block is defined %}
        {{ moim_system_prompt_block }}
        {% endif %}

        You are in a sandbox. You may manipulate it freely, but you cannot access the users system. You may request files from the user. The user sees files in `${containerHome}/llm/`.

        You are on NixOS with flakes enabled. Use Nix flakes to pin dependencies and `nix develop` to use pinned dependencies.

        {% if include_extensions and not code_execution_mode %}
        # Extensions

        {% if (extensions is defined) and extensions %}
        The currently active extensions are below.
        {% for extension in extensions %}

        ## {{extension.name}}

        {% if extension.has_resources %}
        {{extension.name}} supports resources.
        {% endif %}
        {% if extension.instructions %}### Instructions
        {{extension.instructions}}{% endif %}
        {% endfor %}
        {% else %}
        No extensions are defined.
        {% endif %}
        {% endif %}
      '';
    }
  ) config.jstos.users;
}
