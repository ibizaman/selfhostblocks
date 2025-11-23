{ lib, shb, ... }:
{
  imports = [
    ../../../lib/module.nix
  ];

  options.shb.contracts.ssl = lib.mkOption {
    description = "Contract for SSL Certificate generator.";
    type = shb.contracts.ssl.certs;
  };
}
