{ pkgs }:

let
  # Exercise the actual activation fragment without activating a system.
  fragment = (import ../modules/environment/path.nix {
    inherit pkgs;
    inherit (pkgs) lib;
    config = {
      user.home = "/profile-test-home";
      environment.path = "/nix/store/new-nix-on-droid-path";
    };
  }).config.build.activation.installPackages;
in
pkgs.runCommand "profile-update-test" { nativeBuildInputs = [ pkgs.jq ]; } ''
  export NOD_TEST_HOME="$TMPDIR/home"
  mkdir -p "$NOD_TEST_HOME/.nix-profile"
  touch "$NOD_TEST_HOME/.nix-profile/manifest.json"
  export calls="$TMPDIR/calls" manifest="$TMPDIR/manifest.json"

  cat > activation.sh <<'ACTIVATION'
  set -euo pipefail
  ${fragment}
  ACTIVATION
  substituteInPlace activation.sh --replace-fail '/profile-test-home' "$NOD_TEST_HOME"

  nix() {
    if [[ "''${NOD_FAIL_REMOVE:-}" == 1 && "$*" == 'profile remove '* ]]; then
      echo 'Simulated removal failure' >&2
      return 1
    fi
    case "$*" in
      'profile list --json') cat "$manifest" ;;
      'profile list') echo 'The human-readable format must not be parsed'; return 1 ;;
      *) printf '%s\n' "$*" >> "$calls" ;;
    esac
  }
  export -f nix
  export DRY_RUN_CMD="" VERBOSE_ARG=""

  # Nix 2.18 uses array elements; current Nix uses named elements.
  for elements in \
    '[{"storePaths":["/nix/store/old-nix-on-droid-path"]},{"storePaths":["/nix/store/keep-hello"]}]' \
    '{"nod":{"storePaths":["/nix/store/old-nix-on-droid-path"]},"hello":{"storePaths":["/nix/store/keep-hello"]}}'; do
    printf '{"elements":%s}\n' "$elements" > "$manifest"
    : > "$calls"
    bash activation.sh
    printf '%s\n' \
      'profile remove /nix/store/old-nix-on-droid-path' \
      'profile install /nix/store/new-nix-on-droid-path' > expected
    diff -u expected "$calls"

    # Dry runs must not remove or install anything.
    : > "$calls"
    DRY_RUN_CMD=echo bash activation.sh
    test ! -s "$calls"
  done

  # If removal fails, do not try to install a conflicting replacement.
  : > "$calls"
  if NOD_FAIL_REMOVE=1 bash activation.sh; then
    echo 'Failed removal unexpectedly succeeded' >&2
    exit 1
  fi
  test ! -s "$calls"

  # A profile with only unrelated packages needs no removal.
  echo '{"elements":{"hello":{"storePaths":["/nix/store/keep-hello"]}}}' > "$manifest"
  : > "$calls"
  bash activation.sh
  echo 'profile install /nix/store/new-nix-on-droid-path' > expected
  diff -u expected "$calls"

  # Invalid listings must fail before mutating the profile.
  echo invalid > "$manifest"
  : > "$calls"
  if bash activation.sh; then
    echo 'Invalid manifest unexpectedly succeeded' >&2
    exit 1
  fi
  test ! -s "$calls"

  # Legacy nix-env profiles must continue to use nix-env.
  rm "$NOD_TEST_HOME/.nix-profile/manifest.json"
  nix-env() { printf '%s\n' "nix-env $*" >> "$calls"; }
  export -f nix-env
  bash activation.sh
  echo 'nix-env --install /nix/store/new-nix-on-droid-path' > expected
  diff -u expected "$calls"
  touch "$out"
''
