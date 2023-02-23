{ pkgs ? import <nixpkgs> {}
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

  disnixtests = pkgs.callPackage ./tests/disnix/keycloak.nix {};
}
