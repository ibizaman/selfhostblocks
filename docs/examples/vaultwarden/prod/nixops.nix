let
  hostname = "machine1";
  domain = "mydomain.com";
in
{
  machine1 = { system, pkgs, lib, ... }:
    let
      utils = pkgs.lib.callPackageWith pkgs ./utils.nix { };

      base = ((import ./network.nix).machine1 {
        inherit system pkgs lib;
        inherit domain utils;
      });

      vbox = (import ./network.nix).virtualbox;
    in
      lib.recursiveUpdate base rec {
        deployment.targetHost = hostname;
        imports = [
          (import ./machines/machine1-configuration.nix {
            inherit hostname;

            userName = "me";
            userPackages = with pkgs; [];
            systemPackages = with pkgs; [
              curl
              inetutils
              mtr
              sysstat
              tmux
              vim
            ];
            address = "45.79.76.142";
            gateway = "45.79.76.1";
            sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/UeAaMECJNLMZ23vLb3A3XT7OJDcpj2OWgXzt8+GLU me@laptop";
            allowedTCPPorts = vbox.guestPorts;
          })
        ];
      };
}
