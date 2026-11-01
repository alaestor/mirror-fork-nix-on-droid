{
  description = "Nix-on-Droid configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-on-droid.url = "<<FLAKE_URL>>";
    nix-on-droid.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nix-on-droid, nixpkgs, ... }: {
    nixOnDroidConfigurations = {
      default = nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = import nixpkgs { system = "<<SYSTEM>>"; };
        modules = [ ./nix-on-droid.nix ];
      };
    };
  };
}
