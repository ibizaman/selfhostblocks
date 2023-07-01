{ config, pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = [ "kvm-intel" ];
  fileSystems."/" =
    { device = "/dev/vda";
      fsType = "ext4";
    };
  system.stateVersion = "22.11";

  # As we intend to run this example using `nixos-rebuild build-vm`, we need to setup the user
  # ourselves, see https://nixos.wiki/wiki/NixOS:nixos-rebuild_build-vm
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    initialPassword = "nixos";
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

  services.openssh.enable = true;
  services.openssh = {
    permitRootLogin = "no";
    passwordAuthentication = true;
  };
}
