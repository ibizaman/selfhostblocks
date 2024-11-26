{ pkgs, lib, ... }:
let
  contracts = pkgs.callPackage ../. {};

  inherit (lib) mkOption;
  inherit (lib.types) submodule;
in
{
  options.shb.contracts.backup = mkOption {
    description = ''
      Contract for backing up files
      between a requester module and a provider module.

      The requester communicates to the provider
      what files to backup
      through the `request` options.

      The provider reads from the `request` options
      and backs up the requested files.
      It communicates to the requester what script is used
      to backup and restore the files
      through the `result` options.
    '';

    type = submodule {
      options = contracts.backup.contract;
    };
  };
}
