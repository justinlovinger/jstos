{
  inputs = {
    systems.url = "github:nix-systems/default";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      systems,
      nixpkgs,
      mcp-servers-nix,
      ...
    }:
    let
      pkgs = eachSystem (system: import nixpkgs { inherit system; });
      eachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    rec {
      packages = eachSystem (system: overlays.default pkgs.${system} pkgs.${system});

      overlays.default = final: prev: {
        mcp-shell-server = (import ./pkgs/mcp-shell-server.nix) final;

        open-websearch = (import ./pkgs/open-websearch.nix) final;
      };

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          system = config.nixpkgs.hostPlatform.system;
          mcpServersNixPkgs = mcp-servers-nix.packages.${system};
          llmPkgs = packages.${system};
        in
        {
          imports = [ ./module.nix ];

          options.jstos.users = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule (
                { ... }:
                {
                  config.llm.mcpServers = {
                    time = {
                      settings = {
                        command = lib.getExe mcpServersNixPkgs.mcp-server-time;
                      };
                      tools = {
                        get_current_time.safe = lib.mkDefault true;
                        convert_time.safe = lib.mkDefault true;
                      };
                    };

                    # The `read_*` tools can theoretically exfiltrate data
                    # if they are activated from a directory containing sensitive data.
                    # For example,
                    # a prompt injection could lead to an LLM reading a sensitive file
                    # and then fetching a URL
                    # with the contents of that file in the URL.
                    # If one wishes to mark the `read_*` tools as safe,
                    # they should avoid activating the filesystem MCP
                    # in a directory containing sensitive data.
                    filesystem = {
                      settings = {
                        command = lib.getExe mcpServersNixPkgs.mcp-server-filesystem;
                        args = [ "." ];
                      };
                      tools = {
                        "read_text_file" = { };
                        "read_media_file" = { };
                        "read_multiple_files" = { };
                        "list_directory".safe = lib.mkDefault true;
                        "list_directory_with_sizes".safe = lib.mkDefault true;
                        "directory_tree".safe = lib.mkDefault true;
                        "search_files".safe = lib.mkDefault true;
                        "get_file_info".safe = lib.mkDefault true;
                        "list_allowed_directories".safe = lib.mkDefault true;
                        "create_directory" = { };
                        "write_file" = { };
                        "edit_file" = { };
                        "move_file" = { };
                      };
                    };

                    git = {
                      settings = {
                        command = lib.getExe mcpServersNixPkgs.mcp-server-git;
                      };
                      tools = {
                        "git_status".safe = lib.mkDefault true;
                        "git_diff_unstaged".safe = lib.mkDefault true;
                        "git_diff_staged".safe = lib.mkDefault true;
                        "git_diff".safe = lib.mkDefault true;
                        "git_commit" = { };
                        "git_add" = { };
                        "git_reset" = { };
                        "git_log".safe = lib.mkDefault true;
                        "git_create_branch" = { };
                        "git_checkout" = { };
                        "git_show".safe = lib.mkDefault true;
                        "git_branch".safe = lib.mkDefault true;
                      };
                    };

                    shell = {
                      settings = {
                        command = lib.getExe llmPkgs.mcp-shell-server;
                        env = {
                          ALLOW_COMMANDS = "cargo";
                        };
                      };
                      tools = {
                        shell_execute = { };
                      };
                    };

                    open-websearch = {
                      settings = {
                        command = lib.getExe llmPkgs.open-websearch;
                        env = {
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
                      };
                      tools = {
                        search.safe = lib.mkDefault true;
                        fetchLinuxDoArticle.safe = lib.mkDefault true;
                        fetchCsdnArticle.safe = lib.mkDefault true;
                        fetchGithubReadme.safe = lib.mkDefault true;
                        # fetchJuejinArticle.safe = lib.mkDefault true; # No point when Juejin is disabled, see above.
                        fetchWebContent.safe = lib.mkDefault true;
                      };
                    };
                  };
                }
              )
            );
          };
        };
    };
}
