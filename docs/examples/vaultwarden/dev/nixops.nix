{
  domain ? "dev.mydomain.com",
}:

{
  network = {
    storage.legacy = {};
  };

  machine1 = { system, pkgs, lib, ... }:
    with lib;
    let
      utils = pkgs.lib.callPackageWith pkgs ./../../../../utils.nix { };

      base = ((import ./../network.nix).machine1 {
        inherit system pkgs lib;
        inherit domain utils;
        secret = x: x;
      });

      vbox = (import ./../network.nix).virtualbox;

      mkPortMapping = {name, host, guest, protocol ? "tcp"}:
        ["--natpf1" "${name},${protocol},,${toString host},,${toString guest}"];
    in
      recursiveUpdate base {
        deployment.targetEnv = "virtualbox";
        deployment.virtualbox = {
          memorySize = 1024;
          vcpu = 2;
          headless = true;
          vmFlags = concatMap mkPortMapping vbox.portMappings;
        };
      };
}
