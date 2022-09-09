{ distribution ? null
, services ? null
, system ? builtins.currentSystem
, pkgs ? import <nixpkgs> { inherit system; }
, utils ? null
}:

let
  callPackage = pkgs.lib.callPackageWith (pkgs // self);

  self = {
    PostgresDB = callPackage ./PostgresDB {};

    TtrssEnvironment = callPackage ./Ttrss/environment.nix {};
    TtrssConfig = callPackage ./Ttrss/config.nix {};
    TtrssUpdateService = callPackage ./Ttrss/update.nix {inherit utils;};
    TtrssUpgradeDBService = callPackage ./Ttrss/dbupgrade.nix {};
  };
in
self
