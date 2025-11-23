{ lib, shb, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) submodule;
in
{
  imports = [
    ../../../lib/module.nix
  ];

  options.shb.contracts.databasebackup = mkOption {
    description = ''
      Contract for database backup between a requester module
      and a provider module.

      The requester communicates to the provider
      how to backup the database
      through the `request` options.

      The provider reads from the `request` options
      and backs up the database as requested.
      It communicates to the requester what script is used
      to backup and restore the database
      through the `result` options.
    '';

    type = submodule {
      options = shb.contracts.databasebackup.contract;
    };
  };
}
