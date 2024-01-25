{ config, pkgs, ... }:

let
  targetUser = "nixos";
  targetPort = 2222;
in
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
  # Needed to avoid getting into not available disk space in /boot.
  boot.loader.grub.configurationLimit = 1;
  # The NixOS /nix/.rw-store mountpoint is backed by tmpfs which uses memory. We need to increase
  # the available disk space to install home-assistant.
  virtualisation.vmVariant.virtualisation.memorySize = 8192;
  virtualisation.vmVariantWithBootLoader.virtualisation.memorySize = 8192;

  # Options above are needed to deploy in a VM.

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # We need to create the user we will deploy with.
  users.users.${targetUser} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    initialPassword = "nixos";
    # With this option, you don't need to use ssh-copy-id to copy the public ssh key to the VM.
    openssh.authorizedKeys.keyFiles = [
      ./sshkey.pub
    ];
  };

  # The user we're deploying with must be able to run sudo without password.
  security.sudo.extraRules = [
    { users = [ targetUser ];
      commands = [
        { command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Needed to allow the user we're deploying with to write to the nix store.
  nix.settings.trusted-users = [
    targetUser
  ];

  # We need to enable the ssh daemon to be able to deploy.
  services.openssh = {
    enable = true;
    ports = [ targetPort ];
    permitRootLogin = "no";
    passwordAuthentication = false;
  };
}
