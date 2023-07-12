{ pkgs ? import (builtins.fetchGit {
  # Descriptive name to make the store path easier to identify
  name = "nixos-21.11-2023-03-15";
  url = "https://github.com/nixos/nixpkgs/";
  # Commit hash for nixos-unstable as of 2018-09-12
  # `git ls-remote https://github.com/nixos/nixpkgs nixos-unstable`
  ref = "refs/tags/21.11";
  rev = "506445d88e183bce80e47fc612c710eb592045ed";
}) {}
}:
let
  utils = pkgs.callPackage ./utils.nix {};
in
with builtins;
with pkgs.lib.attrsets;
with pkgs.lib.lists;
with pkgs.lib.strings;
rec {
  customPkgs = import ./all-packages.nix;

  tests = pkgs.callPackage ./tests { inherit utils; };

  runtests =
    let
      onlytests = filterAttrs (name: value: name != "override" && name != "overrideDerivation") tests;
      failingtests = filterAttrs (name: value: length value > 0) onlytests;
      formatFailure = failure: toString failure; # TODO: make this more pretty
      formattedFailureGroups = mapAttrsToList (name: failures: "${name}:\n${concatMapStringsSep "\n" formatFailure failures}") failingtests;
    in
      if length formattedFailureGroups == 0 then
        "no failing test"
      else
        concatStringsSep "\n" formattedFailureGroups;
}
