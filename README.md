# Nix-on-Droid

[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png"
    alt="Get it on F-Droid"
    height="80">](https://f-droid.org/packages/com.termux.nix)

Nix package manager on Android, in a single-click installable package. This is
not full [NixOS](https://nixos.org/) running inside Android, but you get easy
access to [nixpkgs](https://github.com/NixOS/nixpkgs)' vast collection of
(precompiled!) software and the best package manager under the sun. It's
prototype-grade quality as of now, but hey, it works!

It does not require root, user namespaces support or disabling SELinux,
but it relies on `proot` and other hacks instead.
It uses [a fork](https://github.com/nix-community/nix-on-droid-app)
of [Termux-the-terminal-emulator app](https://github.com/termux/termux-app),
but has no relation to [Termux-the-distro](https://termux.com/).
Please do not pester Termux folks about Nix-on-Droid.

This repository contains:

1. Nix expressions that generate a bootstrap zipball,
   which is then used to install Nix package manager on Android
   along with the `nix-on-droid` executable.
2. A module system for configuring the local Nix-on-Droid installation directly
   on the device.

### This fork

This branch targets nixpkgs and Home Manager 26.05. The bootstrap has its own
locked nixpkgs input, also on 26.05. Consumer flakes must update their own inputs;
overriding this fork's inputs with 24.05 will still select the older packages.

Keep existing `system.stateVersion` and `home.stateVersion` values when upgrading.
They control compatibility defaults, not the package release.

When evaluating an aarch64 configuration on an x86_64 builder, pass
`bootstrapSystem = "x86_64-linux"` to `nixOnDroidConfiguration`. This builds the
static proot for aarch64 on the builder rather than requiring an aarch64 build
of its toolchain. The selected builder or binary cache must supply that output.

Before deploying an upgrade, build both bootstrap archives and the activation
checks. The activation checks include Home Manager and retain the older state
versions to exercise upgrades:

```sh
nix build --no-link .#bootstrapZip-aarch64 .#bootstrapZip-x86_64
nix build --no-link .#checks.x86_64-linux.activation-aarch64 \
  .#checks.x86_64-linux.activation-x86_64 .#checks.x86_64-linux.profile-update
```

These checks do not prove Android runtime compatibility. Test login, activation,
a second switch, and rollback on a disposable Android installation before
upgrading a primary device. Keep a backup outside the app's private storage;
clearing app data deletes the installation and its generations.
Building the aarch64 activation check from x86_64 requires an aarch64 builder
or binfmt emulation for the target-side build steps, even though proot itself
is cross-compiled.

It is only tested with aarch64 (64-bit ARM devices).
It also used to compile for i686 devices, but the developers don't own any
and nobody has reported whether it actually worked or not,
so it's no longer built unless a user shows up.
Sorry, it would not work on 32-bit ARM devices
and it's not an easy feat to pull off.


## Try it out

[Install it from F-Droid](https://f-droid.org/packages/com.termux.nix),
launch the app, press OK,
expect many hundreds megabytes of downloads to happen.


## Nix-on-Droid and the module system

### Config file

The Nix-on-Droid system can be managed through a custom config
file in `~/.config/nixpkgs/nix-on-droid.nix` as generated on first build,
for example:

```nix
{ pkgs, ... }:

{
  environment.packages = [ pkgs.vim ];
  system.stateVersion = "24.05";
}
```

An alternative location is `~/.config/nixpkgs/config.nix` with the key
`nix-on-droid`, for example:

```nix
{
  nix-on-droid =
    { pkgs, ... }:

    {
      environment.packages = [ pkgs.vim ];
      system.stateVersion = "24.05";
    };
}
```

See <https://nix-community.github.io/nix-on-droid/> for list of all available options.

### [`home-manager`](https://github.com/nix-community/home-manager) integration

To enable `home-manager` you simply need to follow the instructions already provided in the example `nix-on-droid.nix`:

1.  Add `home-manager` channel:
    ```sh
    nix-channel --add https://github.com/nix-community/home-manager/archive/release-26.05.tar.gz home-manager
    nix-channel --update
    ```
2.  Configure `home-manager`:
    ```nix
    { pkgs, ... }:

    {
      # Read Nix-on-Droid changelog before changing this value
      system.stateVersion = "24.05";

      # insert Nix-on-Droid config

      home-manager.config =
        { pkgs, ... }:
        {
          # Read home-manager changelog before changing this value
          home.stateVersion = "24.05";

          # insert home-manager config
        };

      # or if you have a separate home.nix already present:
      home-manager.config = ./home.nix;
    }
    ```

### `nix-on-droid` executable

This executable is responsible for activating new configurations:
Use `nix-on-droid switch` to activate the current configuration and
`nix-on-droid rollback` to rollback to the latest build.

For more information, please run `nix-on-droid help`.


## Build Nix-on-Droid on your own

The [terminal emulator part](https://github.com/nix-community/nix-on-droid-app)
is probably not interesting for you, just download and use a prebuilt one.
If you really want to rebuild it, you can just use Android Studio for that.

The zipball generation is probably what you are after.
Get an x86_64 computer with flake-enabled Nix.

> **tl;dr**: Use the deploy app like the following which executes all steps mentioned below:
>
> ```sh
> nix run ".#deploy" -- <public_url> <rsync_target>
> # or run the following for explanation of this script
> nix run ".#deploy"
> ```

Run

```sh
nix build ".#bootstrapZip-aarch64" --impure
```

Put the zip file from `result` on some HTTP server
and specify the parent directory URL during the installation.
To re-trigger the installation, you can use
'clear data' on the Android app (after backing stuff up, obviously).

If you want to change the Nix-on-Droid channel to your custom one,
you can do that either with `nix-channel` after the installation,
or by setting the environment variable `NIX_ON_DROID_CHANNEL_URL`.
Other environment variables are `NIXPKGS_CHANNEL_URL` an
`NIX_ON_DROID_FLAKE_URL`.

This fork builds `proot` statically against musl using the bootstrap nixpkgs
toolchain. It does not need the Android NDK or a hardcoded store path.
Existing installations need a remote builder or binary cache that supplies
the selected proot build; the bootstrap archive includes the binary for new
installations.

If you want to build that proot derivation (possibly to put it in your own cache):

```sh
# must run on a linux-x86_64 system (cross-compile only)
nix build ".#prootTermux-aarch64"
```

Obviously it's an annoyance if one wants to fork this repo and test something.
To minimize the hassle with this scenario, proot derivation is also bundled
with the bootstrap zipball. This way you only need your own binary cache
if you are planning to maintain a long-term fork that users can update from.
In case you only care about updates through wiping the data,
or are forking to submit a one-off pull request,
you shouldn't need a binary cache for that.

## Nix flakes

**Note:** Nix flake support is still experimental at the moment and subject to change.

### Examples / templates

A minimal example could look like the following:

```nix
{
  description = "Minimal example of Nix-on-Droid system config.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nix-on-droid = {
      url = "git+https://git.0x04.cc/alaestor/fork-nix-on-droid.git?ref=better-cross-compile-1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-on-droid }: {

    nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import nixpkgs { system = "aarch64-linux"; };
      modules = [ ./nix-on-droid.nix ];
    };

  };
}
```

For more examples and nix flake templates, see [`templates`](./templates) directory or explore with:

```sh
nix flake init --template 'git+https://git.0x04.cc/alaestor/fork-nix-on-droid.git?ref=better-cross-compile-1#advanced'
```

### Usage with `nix-on-droid`

Use `nix-on-droid switch --flake path/to/flake#device` to build and activate your configuration (`path/to/flake#device`
will expand to `.#nixOnDroidConfigurations.device`). If you run `nix-on-droid switch --flake path/to/flake`, the
`default` configuration will be used.

The CLI still evaluates configurations with `--impure`. Direct flake builds
do not need it for proot; bootstrap URL overrides supplied through environment
variables do require it.

## Testing

In the [./tests/on-device](./tests/on-device) directory, there is small set
of [bats](https://github.com/bats-core/bats-core) tests
that can be executed on a real or emulated android device.

To run the tests, execute

```sh
nix-on-droid on-device-test
```

**Note:** This currently requires a channel setup and should only be executed on
clean, disposable installations.

## Tips

* To grant the app access to the storage, use the toggle in the app settings
  (reachable from Android settings).
* If the terminal freezes, use 'Acquire wakelock' button in the notification
  and/or tone down your device's aggressive power saving measures.
* We have a [wiki](https://github.com/nix-community/nix-on-droid/wiki)
  with tips and success stories, you're encouraged to add yours as well.


## Technical overview

OK, real brief.

Developer's device:

1. `proot` for the target platform is cross-compiled statically against musl,
   (to fake file paths like `/nix/store`; think 'userspace `chroot`')
2. Target `nix` and bash are taken from nixpkgs
3. Target `nix` database is initialized
4. Support scripts and config files are built with `nix` and the Nix-on-Droid
   module system
5. From these, a bootstrap zipball is built and published on an HTTP server

User's device:

6. Android app is installed and launched, bootstrap URL is entered
7. Bootstrap zipball gets downloaded and unpacked
8. 'First boot' begins, Nix builds the environment
   (or, possibly, pulls it from Cachix)
9. Nix installs the environment (login scripts, config files, etc.)

You can refer to a
[NixCon 2019 presentation talk](https://nix-on-droid.unboiled.info/nixcon-2019-nix-on-droid.slides.pdf)
for a more extensive overview of the subject.


## Licensing and credits

Licensed under MIT License, see LICENSE.
Copyright (c) 2019-2021 Alexander Sosedkin and other contributors, see AUTHORS.

Two rewrites ago it was based off the official Nix install script
(https://nixos.org/nix/install),
presumably written by Eelco Dolstra.

Is deployed and used with [a fork](https://github.com/nix-community/nix-on-droid-app)
of [Termux-the-terminal-emulator app](https://github.com/termux/termux-app),
but has no relation to Termux-the-distro.

Previous project that did use Termux-the-distro:
https://github.com/t184256/nix-in-termux
