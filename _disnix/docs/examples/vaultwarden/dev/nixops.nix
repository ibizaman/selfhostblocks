{
  domain ? "dev.mydomain.com",
  sopsKeyFile ? "",
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
        imports = [
          <sops-nix/modules/sops>
        ];
        deployment.targetEnv = "virtualbox";
        deployment.virtualbox = {
          memorySize = 1024;
          vcpu = 2;
          headless = true;
          vmFlags = concatMap mkPortMapping vbox.portMappings;
        };

        # This will add secrets.yml to the nix store
        # You can avoid this by adding a string to the full path instead, i.e.
        # sops.defaultSopsFile = "/root/.sops/secrets/example.yaml";
        sops.defaultSopsFile = ../secrets/linode.yaml;
        # This will automatically import SSH keys as age keys
        sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        # This is using an age key that is expected to already be in the filesystem
        sops.age.keyFile = /. + sopsKeyFile;
        # This will generate a new key if the key specified above does not exist
        sops.age.generateKey = true;
        # This is the actual specification of the secrets.
        sops.secrets.linode = {};
      };
}
