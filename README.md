# JstOS

An opinionated Linux distribution built in NixOS.

## Installation

A NixOS installation is required.

Add JstOS to your NixOS configuration flake:

```
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-CURRENT_STABLE;

    home-manager = {
      url = "github:nix-community/home-manager/release-CURRENT_STABLE";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jstos = {
      url = "github:justinlovinger/jstos";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # ...
  };

  outputs = inputs: {
    nixosConfigurations.HOSTNAME = inputs.nixpkgs.lib.nixosSystem {
      # ...
      modules = [
        # ...
        inputs.jstos.nixosModules.default
      ];
    };
  };
}
```

## Usage

Enable JstOS for the system and all users with `jstos.enable = true`,
including documentation.
Enable only documentation with `jstos.documentation.enable = true`.
See `man jstos-configuration.nix` for all options
after documentation is enabled.
