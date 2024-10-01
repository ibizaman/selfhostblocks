{ pkgs, lib, ... }:
let
  contracts = pkgs.callPackage ../. {};
in
{
  options.shb.contracts.secret = contracts.secret.mkOption {
    description = ''
      Contract for secrets between a requester module
      and a provider module.

      The requester communicates to the provider
      some properties the secret should have
      through the `request` options.

      The provider reads from the `request` options
      and creates the secret as requested.
      It then communicates to the requester where the secret can be found
      through the `result` options.
    '';
  };
}
