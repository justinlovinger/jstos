{
  description = "An opinionated Linux distribution built in NixOS";

  inputs = {
    # Adding subflake inputs here is a workaround for <https://github.com/NixOS/nix/issues/15928>.
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm = {
      url = "path:./llm";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.mcp-servers-nix.follows = "mcp-servers-nix";
    };

    systems.url = "github:nix-systems/default";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    naersk = {
      url = "github:nix-community/naersk/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flow = {
      url = "github:stefur/flow/v0.2.1";
      flake = false;
    };

    mime-db = {
      # Ideally,
      # follow releases.
      # However,
      # Nix flakes can only follow branches
      # as of 2022-02-04.
      url = "github:jshttp/mime-db";
      flake = false;
    };

    owm = {
      url = "github:justinlovinger/owm";
      inputs = {
        systems.follows = "systems";
        nixpkgs.follows = "nixpkgs";
        naersk.follows = "naersk";
      };
    };

    tag = {
      url = "github:justinlovinger/tag";
      inputs = {
        systems.follows = "systems";
        nixpkgs.follows = "nixpkgs";
        naersk.follows = "naersk";
      };
    };

    wayland-pipewire-idle-inhibit = {
      url = "github:rafaelrc7/wayland-pipewire-idle-inhibit";
      inputs = {
        systems.follows = "systems";
        nixpkgs.follows = "nixpkgs";
      };
    };

    whisp-away = {
      url = "github:madjinn/whisp-away";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      lib = {
        mimeTypes = builtins.attrNames (
          builtins.fromJSON (builtins.readFile (inputs.mime-db + "/db.json"))
        );
      };

      packages = eachSystem (system: overlays.default pkgs.${system} pkgs.${system});

      overlays.default =
        pkgs: prev:
        let
          system = pkgs.stdenv.hostPlatform.system;
        in
        {
          flow = pkgs.rustPlatform.buildRustPackage {
            pname = "flow";
            version = "latest";
            src = inputs.flow;
            cargoLock.lockFile = inputs.flow + "/Cargo.lock";
          };

          owm = inputs.owm.packages.${system}.default;

          tag = inputs.tag.packages.${system}.tag;
          tag-organize = inputs.tag.packages.${system}.tag-organize;
          tag-view = inputs.tag.packages.${system}.tag-view;
        };

      nixosModules = rec {
        default = jstos;

        # JstOS and all extensions
        all = {
          imports = [
            jstos
            backup
            goGame
            llm
          ];
        };

        # JstOS core and general system and user configuration
        jstos =
          { pkgs, ... }:
          let
            system = pkgs.stdenv.hostPlatform.system;
          in
          {
            _module.args.jstos = {
              lib = lib;
              pkgs = packages.${system};
            };

            imports = [
              inputs.home-manager.nixosModules.home-manager
              inputs.wayland-pipewire-idle-inhibit.nixosModules.default
              inputs.whisp-away.nixosModules.nixos

              ./modules
            ];

            home-manager.sharedModules = [
              inputs.wayland-pipewire-idle-inhibit.homeModules.default
              inputs.whisp-away.nixosModules.home-manager
            ];
          };

        # Options to backup directories
        backup = {
          imports = [ ./backup.nix ];
        };

        # Options to enable playing the game Go
        goGame = {
          imports = [ ./go-game ];
        };

        # Options to enable a LLM
        llm = inputs.llm.nixosModules.default;
      };
    };
}
