{ distribution ? null
, services ? null
, system ? builtins.currentSystem
, pkgs ? import <nixpkgs> { inherit system; }
}:

let
  callPackage = pkgs.lib.callPackageWith (pkgs // self);

  self = {
    PostgresDB = callPackage ./PostgresDB {};

    TtrssService = callPackage ./Ttrss {};
    TtrssUpdateService = callPackage ./Ttrss/update.nix {};
    TtrssUpgradeDBService = callPackage ./Ttrss/dbupgrade.nix {};
  };
in
self
