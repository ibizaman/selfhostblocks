{ pkgs, lib, ... }:
let
  contracts = pkgs.callPackage ../. {};

  inherit (lib) mkOption;
in
{
  options.shb.contracts.backup = mkOption {
    description = "Contract for backups.";
    type = contracts.backup.request;
  };
}
