{ pkgs, lib, ... }:
let
  contracts = pkgs.callPackage ../. {};
in
{
  options.shb.contracts.secret = lib.mkOption {
    description = "Contract for secrets.";
    type = contracts.secret;
  };
}
