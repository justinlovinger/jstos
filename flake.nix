{
  inputs = {
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

  outputs = inputs: {
    nixosModules.default =
      { pkgs, ... }:
      let
        system = pkgs.stdenv.hostPlatform.system;
      in
      {
        _module.args.jstos-pkgs = {
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

        imports = [
          ./default.nix

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
