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

          mimeTypes = builtins.attrNames (
            builtins.fromJSON (builtins.readFile (inputs.mime-db + "/db.json"))
          );

          owm = inputs.owm.packages.${system}.default;

          tag = inputs.tag.packages.${system}.tag;
          tag-organize = inputs.tag.packages.${system}.tag-organize;
          tag-view = inputs.tag.packages.${system}.tag-view;

          jstos-manpage =
            let
              eval = pkgs.lib.evalModules {
                specialArgs = { inherit pkgs; };
                # Using `nixosModules.default` directly
                # pulls in options from dependencies.
                modules = [
                  { _module.check = false; }
                  ./modules
                  ./data.nix
                  ./go-game
                  ./llm/module.nix
                ];
              };
              optionsDocs = pkgs.nixosOptionsDoc {
                inherit (eval) options;
                documentType = "nixos";
              };

            in
            pkgs.runCommand "jstos-manpage"
              {
                nativeBuildInputs = [
                  pkgs.buildPackages.installShellFiles
                  pkgs.nixos-render-docs
                ];
                allowedReferences = [ "out" ];
              }
              ''
                mkdir -p $out/share/man/man5
                mkdir -p $out/share/man/man1
                nixos-render-docs -j $NIX_BUILD_CORES options manpage \
                  --revision "" \
                  --header "${builtins.toFile "jstos-configuration-nix-header.5" ''
                    .TH "JSTOS-CONFIGURATION\&.NIX" "5" "01/01/1980" "JstOS"
                    .\" disable hyphenation
                    .nh
                    .\" disable justification (adjust text to left margin only)
                    .ad l
                    .\" enable line breaks after slashes
                    .cflags 4 /
                    .SH "NAME"
                    \fIjstos\-configuration\&.nix\fP \- JstOS configuration specification
                    .SH "DESCRIPTION"
                    .sp
                    The following options are added to NixOS\&.
                    .SH "OPTIONS"
                    .PP
                    You can use the following options in
                    home\-configuration\&.nix:
                    .PP
                  ''}" \
                  --footer ${builtins.toFile "jstos-configuration-nix-footer.5" ''
                    .SH "AUTHORS"
                    .PP
                    Justin Lovinger
                  ''} \
                  ${optionsDocs.optionsJSON}/share/doc/nixos/options.json \
                  $out/share/man/man5/jstos-configuration.nix.5
              '';
        };

      nixosModules.default =
        { pkgs, ... }:
        let
          system = pkgs.stdenv.hostPlatform.system;
        in
        {
          _module.args.jstos-pkgs = packages.${system};

          imports = [
            ./modules
            ./data.nix
            ./go-game
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
