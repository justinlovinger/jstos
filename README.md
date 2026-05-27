# JstOS

An opinionated Linux distribution built in NixOS.

## Installation

A NixOS installation is required.

Add JstOS to your NixOS configuration flake:

```nix
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

Enable JstOS by setting `jstos.enable = true`
or enable only documentation by setting `jstos.documentation.enable = true`.
See `man jstos-configuration.nix` for options
after documentation is enabled.
Note,
only options for enabled extensions are shown.
See below for information on extensions.

Sensible defaults can be enabled by setting `jstos.enable = true`
and configuring `jstos.device`.
For most machines,
set one of `jstos.device.is.desktop`,
`jstos.device.is.laptop`,
or `jstos.device.is.mobile`.
More complex defaults can be set by combining fields.
For example,
a server used as a remote desktop can be configured as:

```nix
jstos.device = {
  is.desktop = true;
  is.server = true;
  has.display = false;
};
```

Note,
due to technical limitations of NixOS,
users must be defined explicitly in JstOS,
even if no user-specific options are customized.
For example,
`jstos.users.john = { };`.

All together,
a machine can be mostly simply configured like:

```nix
jstos = {
  enable = true;
  device.is.desktop = true;
  users.john = { };
};
```

Enabling individual options
without configuring the entire system as JstOS
is also possible.
Just enable the options
without setting `jstos.enable = true`.

### Extensions

Additional options are available as extensions
under the `nixosModules` output of the flake.
Available extensions are documented in comments in `flake.nix`,
until a better method exists.
Extensions must be imported separately,
such as:

```nix
# ...

nixosConfigurations.HOSTNAME = inputs.nixpkgs.lib.nixosSystem {
  # ...
  modules = [
    # ...
    inputs.jstos.nixosModules.jstos
    inputs.jstos.nixosModules.data
    inputs.jstos.nixosModules.go-game
    inputs.jstos.nixosModules.llm
  ];
};
```

Alternatively,
`inputs.jstos.nixosModules.all` can be imported to include JstOS and all extensions.
