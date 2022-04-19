{ distribution ? null
, services ? null
, system ? builtins.currentSystem
, pkgs ? import <nixpkgs> { inherit system; }
}:

let
  callPackage = pkgs.lib.callPackageWith (pkgs // self);

  self = {
    PostgresDB = callPackage ./PostgresDB {};
  };
in
self
