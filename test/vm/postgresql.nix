{ pkgs, lib, ... }:
let

in pkgs.nixosTest {
  name = "postgresql";

  nodes.machine = { config, pkgs, ... }: {
    
  };

  testScript = { nodes, ... }: ''
  start_all()
  '';
}
