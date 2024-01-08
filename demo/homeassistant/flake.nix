{
  description = "Home Assistant example for Self Host Blocks";

  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = inputs@{ self, selfhostblocks, ... }: {
    colmena = {
      meta = {
        nixpkgs = import selfhostblocks.inputs.nixpkgs {
          system = "x86_64-linux";
        };
        specialArgs = inputs;
      };

      basic = { config, ... }: {
        imports = [
          ./configuration.nix
          selfhostblocks.inputs.sops-nix.nixosModules.default
          selfhostblocks.nixosModules.x86_64-linux.default
        ];

        # Used by colmena to know which target host to deploy to.
        deployment = {
          targetHost = "example";
          targetUser = "nixos";
          targetPort = 2222;
        };

        shb.home-assistant = {
          enable = true;
          domain = "example.com";
          subdomain = "ha";
          sopsFile = ./secrets.yaml;
        };

        nixpkgs.config.permittedInsecurePackages = [
          "openssl-1.1.1w"
        ];

        # Set to true for more debug info with `journalctl -f -u nginx`.
        shb.nginx.accessLog = false;
        shb.nginx.debugLog = false;
      };

      ldap = { config, ... }: {
        imports = [
          ./configuration.nix
          selfhostblocks.inputs.sops-nix.nixosModules.default
          selfhostblocks.nixosModules.x86_64-linux.default
        ];

        # Used by colmena to know which target host to deploy to.
        deployment = {
          targetHost = "example";
          targetUser = "nixos";
          targetPort = 2222;
        };

        shb.ldap = {
          enable = true;
          domain = "example.com";
          subdomain = "ldap";
          ldapPort = 3890;
          webUIListenPort = 17170;
          dcdomain = "dc=example,dc=com";
          ldapUserPasswordFile = config.sops.secrets."lldap/user_password".path;
          jwtSecretFile = config.sops.secrets."lldap/jwt_secret".path;
        };
        sops.secrets."lldap/user_password" = {
          sopsFile = ./secrets.yaml;
          mode = "0440";
          owner = "lldap";
          group = "lldap";
          restartUnits = [ "lldap.service" ];
        };
        sops.secrets."lldap/jwt_secret" = {
          sopsFile = ./secrets.yaml;
          mode = "0440";
          owner = "lldap";
          group = "lldap";
          restartUnits = [ "lldap.service" ];
        };

        shb.home-assistant = {
          enable = true;
          domain = "example.com";
          ldap = {
            enable = true;
            host = "127.0.0.1";
            port = config.shb.ldap.webUIListenPort;
            userGroup = "homeassistant_user";
          };
          subdomain = "ha";
          sopsFile = ./secrets.yaml;
        };

        nixpkgs.config.permittedInsecurePackages = [
          "openssl-1.1.1w"
        ];
      };
    };
  };
}
