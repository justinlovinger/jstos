{
  inputs = {
    systems.url = "github:nix-systems/default";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    {
      systems,
      nixpkgs,
      ...
    }:
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
      };

      nixosModules.default =
        {
          config,
          ...
        }:
        let
          system = config.nixpkgs.hostPlatform.system;
        in
        {
          _module.args.jstos-llm.pkgs = packages.${system};

          imports = [ ./module.nix ];
        };
    };
}
