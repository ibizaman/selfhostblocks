{ pkgs, lib, ... }:
let
  contracts = pkgs.callPackage ../. {};
in
{
  options.shb.contracts.backup = lib.mkOption {
    description = "Contract for backups.";
    type = contracts.backup;
  };
}
