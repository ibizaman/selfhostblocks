{ hostname
, userName
, userPackages
, systemPackages
, address
, gateway
, sshPublicKey
, allowedTCPPorts
}:

{
  imports =
    [ # Include the results of the hardware scan.
      ./machine1-hardware-configuration.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = hostname; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  networking.usePredictableInterfaceNames = false;
  networking.enableIPv6 = false;

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = {
  #   "eurosign:e";
  #   "caps:escape" # map caps to escape.
  # };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${userName} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ]; # Enable ‘sudo’ for the user.
    packages = userPackages;
    openssh.authorizedKeys.keys = [ sshPublicKey ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = systemPackages;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
    passwordAuthentication = false;
  };

  nix.trustedUsers = [
    "deployer"
  ];

  users.groups.deployer = {};
  users.users.deployer = {
    isSystemUser = true;
    group = "deployer";
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [ sshPublicKey ];
  };
  users.users."root" = {
    openssh.authorizedKeys.keys = [ sshPublicKey ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.longview = {
    enable = true;
    apiKeyFile = "/var/lib/longview/apiKeyFile";

    apacheStatusUrl = "";
    nginxStatusUrl = "";

    mysqlUser = "";
    mysqlPassword = "";
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = allowedTCPPorts;
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  networking.domain = "members.linode.com";
  networking.search = [ "members.linode.com" ];
  networking.resolvconf.extraOptions = [ "rotate" ];
  networking.nameservers = [
    "173.230.145.5"
    "173.230.147.5"
    "173.230.155.5"
    "173.255.212.5"
    "173.255.219.5"
    "173.255.241.5"
    "173.255.243.5"
    "173.255.244.5"
    "74.207.241.5"
    "74.207.242.5"
  ];

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?

}
