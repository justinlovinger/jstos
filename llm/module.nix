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
  users = builtins.attrNames (lib.filterAttrs (_: jstos: jstos.llm.enable) config.jstos.users);

  containerName = user: "${user}-llm";
  containerUser = "llm";

  # In a future version,
  # environment variables can go in the config.
  goose = pkgs.symlinkJoin {
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

              # We may be able to remove these once Goose knows about the model.
              GOOSE_CONTEXT_LIMIT = 1048576;
              GOOSE_MAX_TOKENS = 1048576;
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
              Pass files to and from the LLM using `~/llm`.
              Access the LLM container manually using `machinectl shell ${containerUser}@${containerName "USER"}`.
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

  containers = imapAttrs' (
    i: user: jstos:
    let
      cfg = jstos.llm;
      hostHome = config.users.users.${user}.home;
      containerHome = "/home/${containerUser}";
    in
    lib.nameValuePair (containerName user) (
      lib.mkIf cfg.enable {
        autoStart = true;
        ephemeral = true;

        privateNetwork = true;
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
    ) users
  );

  networking.nat = lib.mkIf (lib.any (cfg: cfg.enable) cfgs) {
    enable = true;
    internalInterfaces = map (user: "ve-${containerName user}") users;
    # We leave off `externalInterface` to select it automatically.
  };

  # The container will fail if bind mount locations don't already exist.
  systemd.tmpfiles.rules = lib.flatten (
    map (user: [
      "d ${config.users.users.${user}.home}/.config/goose 0755 ${user} users -"
      "d ${config.users.users.${user}.home}/.local/share/goose 0755 ${user} users -"
      "d ${config.users.users.${user}.home}/.local/state/goose 0755 ${user} users -"
      "d ${config.users.users.${user}.home}/llm 0755 ${user} users -"
    ]) users
  );

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
    '') users
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
      home.packages = [
        (pkgs.writeShellScriptBin "goose" ''
          machinectl --quiet shell ${containerUser}@${containerName user} ${lib.getExe pkgs.dash} -c 'cd ~/llm && exec ${lib.getExe' goose "goose"} "$@"' _ "$@"
        '')
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

            # Builtins not listed completely have default settings.
            # If a builtin is enabled by default,
            # it has to be listed completely to be disabled.
            extensions = {
              apps = {
                enabled = false;
                type = "platform";
                name = "apps";
                description = "Create and manage custom Goose apps through chat. Apps are HTML/CSS/JavaScript and run in sandboxed windows.";
                display_name = "Apps";
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
              summon = {
                enabled = false;
                type = "platform";
                name = "summon";
                description = "Load knowledge and delegate tasks to subagents";
                display_name = "Summon";
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
