{
  description = "Nix-on-Droid configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-on-droid = {
      url = "<<FLAKE_URL>>";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { nix-on-droid, nixpkgs, ... }: {
    nixOnDroidConfigurations = {
      device = nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = import nixpkgs { system = "<<SYSTEM>>"; };
        modules = [ ./nix-on-droid.nix ];
      };
    };
  };
}
