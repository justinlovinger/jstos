{
  inputs = {
    llm = {
      url = "path:./llm";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    systems.url = "github:nix-systems/default";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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
      packages = eachSystem (system: overlays.default pkgs.${system} pkgs.${system});

      overlays.default =
        final: prev:
        let
          system = final.stdenv.hostPlatform.system;
        in
        {
          flow = final.rustPlatform.buildRustPackage {
            pname = "flow";
            version = "latest";
            src = inputs.flow;
            cargoLock.lockFile = inputs.flow + "/Cargo.lock";
          };

          mimeTypes = builtins.attrNames (
            builtins.fromJSON (builtins.readFile (inputs.mime-db + "/db.json"))
          );

          owm = inputs.owm.packages.${system}.default;

          tag = inputs.tag.packages.${system}.tag;
          tag-organize = inputs.tag.packages.${system}.tag-organize;
          tag-view = inputs.tag.packages.${system}.tag-view;
        };

      nixosModules.default =
        { pkgs, ... }:
        {
          _module.args.jstos-pkgs = packages.${pkgs.stdenv.hostPlatform.system};

          imports = [
            ./default.nix

            inputs.llm.nixosModules.default

            inputs.home-manager.nixosModules.home-manager
            inputs.wayland-pipewire-idle-inhibit.nixosModules.default
            inputs.whisp-away.nixosModules.nixos
          ];

          home-manager.sharedModules = [
            inputs.wayland-pipewire-idle-inhibit.homeModules.default
            inputs.whisp-away.nixosModules.home-manager
          ];
        };
    };
}
