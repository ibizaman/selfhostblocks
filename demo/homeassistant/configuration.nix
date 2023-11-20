{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  boot.loader.grub.enable = true;
  boot.kernelModules = [ "kvm-intel" ];
  system.stateVersion = "22.11";

  # Options above are generate by running nixos-generate-config on the VM.
  
  # Needed otherwise deploy will say system won't be able to boot.
  boot.loader.grub.device = "/dev/vdb";
  # The NixOS /nix/.rw-store mountpoint is backed by tmpfs which uses memory. We need to increase
  # the available disk space to install home-assistant.
  virtualisation.vmVariantWithBootLoader.virtualisation.memorySize = 8192;

  # Options above are needed to deploy in a VM.

  # As we intend to run this example using `nixos-rebuild build-vm`, we need to setup the user
  # ourselves, see https://nixos.wiki/wiki/NixOS:nixos-rebuild_build-vm
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    initialPassword = "nixos";
    # With this option, you don't need to use ssh-copy-id.
    openssh.authorizedKeys.keyFiles = [
      ./sshkey.pub
    ];
  };

  security.sudo.extraRules = [
    { users = [ "nixos" ];
      commands = [
        { command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [
    "nixos"
  ];

  services.openssh = {
    enable = true;
    ports = [ 2222 ];
    permitRootLogin = "no";
    passwordAuthentication = true;
  };
}
