# Copyright (c) 2019-2022, see AUTHORS. Licensed under MIT License, see LICENSE.

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.environment;
in

{

  ###### interface

  options = {

    environment = {
      packages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "List of packages to be installed as user packages.";
      };

      path = mkOption {
        type = types.package;
        readOnly = true;
        internal = true;
        description = "Derivation for installing user packages.";
      };

      extraOutputsToInstall = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "doc" "info" "devdoc" ];
        description = "List of additional package outputs to be installed as user packages.";
      };
    };

  };


  ###### implementation

  config = {

    build.activation.installPackages = ''
      if [[ -e "${config.user.home}/.nix-profile/manifest.json" ]]; then
        # manual removal and installation as two non-atomical steps is required
        # because of https://github.com/NixOS/nix/issues/6349

        nix_previous="$(command -v nix)"

        # Do not parse the human-readable listing. Both the old array
        # manifest and the newer named manifest expose storePaths.
        nod_paths="$(nix profile list --json | ${pkgs.jq}/bin/jq -r '
          .elements[] | .storePaths[] | select(endswith("-nix-on-droid-path"))
        ')"

        while IFS= read -r nod_path; do
          if [[ -n "$nod_path" ]]; then
            $DRY_RUN_CMD "$nix_previous" profile remove $VERBOSE_ARG "$nod_path"
          fi
        done <<< "$nod_paths"

        $DRY_RUN_CMD "$nix_previous" profile install ${cfg.path}

        unset nix_previous nod_paths nod_path
      else
        $DRY_RUN_CMD nix-env --install ${cfg.path}
      fi
    '';

    environment = {
      packages = [
        (pkgs.callPackage ../../nix-on-droid { nix = config.nix.package; })
        pkgs.bashInteractive
        pkgs.cacert
        pkgs.coreutils
        pkgs.less # since nix tools really want a pager available, #27
        config.nix.package
      ];

      path = pkgs.buildEnv {
        name = "nix-on-droid-path";

        paths = cfg.packages;

        inherit (cfg) extraOutputsToInstall;

        meta = {
          description = "Environment of packages installed through Nix-on-Droid.";
        };
      };
    };

  };

}
