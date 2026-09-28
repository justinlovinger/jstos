{
  inputs = {
    systems.url = "github:nix-systems/default";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      systems,
      nixpkgs,
      ...
    }@inputs:
    let
      pkgs = eachSystem (system: import nixpkgs { inherit system; });
      eachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    rec {
      packages = eachSystem (system: overlays.default pkgs.${system} pkgs.${system});

      overlays.default = final: prev: {
        kagi-ken-mcp = (import ./pkgs/kagi-ken-mcp.nix) final;
        mcp-searxng = (import ./pkgs/mcp-searxng.nix) final;
        open-websearch = (import ./pkgs/open-websearch.nix) final;

        # We should be able to remove this,
        # and `nixpkgs-unstable`,
        # in 26.11.
        goose-cli = inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system}.goose-cli;
      };

      nixosModules.default =
        {
          config,
          pkgs,
          ...
        }:
        {
          _module.args.jstos-llm.pkgs = overlays.default pkgs pkgs; # We want to use `pkgs` to reuse thunks.

          imports = [ ./module.nix ];
        };
    };
}
