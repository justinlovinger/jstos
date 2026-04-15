{
  inputs = {
    systems.url = "github:nix-systems/default";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      systems,
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

        # `mcp-server-fetch` in `mcp-servers-nix` is broken.
        mcp-server-fetch = (import ./pkgs/mcp-server-fetch.nix) final;

        duckduckgo-mcp-server = (import ./pkgs/duckduckgo-mcp-server.nix) final;
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

                    fetch = {
                      settings = {
                        command = lib.getExe llmPkgs.mcp-server-fetch;
                      };
                      tools = {
                        fetch.safe = lib.mkDefault true;
                      };
                    };

                    duckduckgo = {
                      settings = {
                        command = lib.getExe llmPkgs.duckduckgo-mcp-server;
                      };
                      tools = {
                        search.safe = lib.mkDefault true;
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
