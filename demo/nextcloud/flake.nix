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

        shb.nextcloud = {
          enable = true;
          domain = "example.com";
          subdomain = "n";
          dataDir = "/var/lib/nextcloud";
          tracing = null;

          # This option is only needed because we do not access Nextcloud at the default port in the VM.
          externalFqdn = "n.example.com:8080";

          adminPassFile = config.sops.secrets."nextcloud/adminpass".path;

          apps = {
            previewgenerator.enable = true;
          };
        };

        # Secret needed for services.nextcloud.config.adminpassFile.
        sops.secrets."nextcloud/adminpass" = {
          sopsFile = ./secrets.yaml;
          mode = "0440";
          owner = "nextcloud";
          group = "nextcloud";
          restartUnits = [ "phpfpm-nextcloud.service" ];
        };

        # Set to true for more debug info with `journalctl -f -u nginx`.
        shb.nginx.accessLog = true;
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

        shb.nextcloud = {
          enable = true;
          domain = "example.com";
          subdomain = "n";
          dataDir = "/var/lib/nextcloud";
          tracing = null;

          # This option is only needed because we do not access Nextcloud at the default port in the VM.
          externalFqdn = "n.example.com:8080";

          adminPassFile = config.sops.secrets."nextcloud/adminpass".path;

          apps = {
            previewgenerator.enable = true;
            ldap = {
              enable = true;
              host = "127.0.0.1";
              port = config.shb.ldap.ldapPort;
              dcdomain = config.shb.ldap.dcdomain;
              adminName = "admin";
              adminPasswordFile = config.sops.secrets."nextcloud/ldap_admin_password".path;
              userGroup = "nextcloud_user";
            };
          };
        };

        # Secret needed for services.nextcloud.config.adminpassFile.
        sops.secrets."nextcloud/adminpass" = {
          sopsFile = ./secrets.yaml;
          mode = "0440";
          owner = "nextcloud";
          group = "nextcloud";
          restartUnits = [ "phpfpm-nextcloud.service" ];
        };
        # Secret needed for LDAP app.
        sops.secrets."nextcloud/ldap_admin_password" = {
          sopsFile = ./secrets.yaml;
          key = "lldap/user_password";
          mode = "0400";
          owner = "nextcloud";
          group = "nextcloud";
          restartUnits = [ "nextcloud-setup.service" ];
        };

        # Set to true for more debug info with `journalctl -f -u nginx`.
        shb.nginx.accessLog = true;
        shb.nginx.debugLog = false;
      };
    };
  };
}
