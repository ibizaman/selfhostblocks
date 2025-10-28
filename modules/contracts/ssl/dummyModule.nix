{ pkgs, lib, ... }:
let
  contracts = pkgs.callPackage ../. { };
in
{
  options.shb.contracts.ssl = lib.mkOption {
    description = "Contract for SSL Certificate generator.";
    type = contracts.ssl.certs;
  };
}
