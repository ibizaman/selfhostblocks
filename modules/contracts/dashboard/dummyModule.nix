{ lib, shb, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) submodule;
in
{
  imports = [
    ../../../lib/module.nix
  ];

  options.shb.contracts.dashboard = mkOption {
    description = ''
      Contract for user-facing services that want to 
      be displayed on a dashboard.

      The requester communicates to the provider
      how to access the service
      through the `request` options.

      The provider reads from the `request` options
      and configures what is necessary on its side
      to show the service and check its availability.
      It does not communicate back to the requester.
    '';

    type = submodule {
      options = shb.contracts.dashboard.contract;
    };
  };
}
