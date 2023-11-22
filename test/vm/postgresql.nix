{ pkgs, lib, ... }:
let

in pkgs.nixosTest {
  name = "postgresql";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/blocks/postgresql.nix
    ];

    services.postgresql.enable = true;
  };

  testScript = { nodes, ... }: ''
  start_all()
  '';
}
