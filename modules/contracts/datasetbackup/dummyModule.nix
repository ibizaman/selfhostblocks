{ lib, shb, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) submodule;
in
{
  imports = [
    ../../../lib/module.nix
  ];

  options.shb.contracts.datasetbackup = mkOption {
    description = ''
      Contract for backing up ZFS datasets.

      The requester communicates to the provider
      the dataset to backup
      through the `request` options.

      The provider reads from the `request` options
      and backs up the requested dataset.
      It communicates to the requester what script is used
      to backup and restore the files
      through the `result` options.
    '';

    type = submodule {
      options = shb.contracts.datasetbackup.contract;
    };
  };
}
