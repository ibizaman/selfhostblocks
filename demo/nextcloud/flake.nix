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
          port = 8080;

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
          port = 8080;

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

      sso = { config, ... }: {
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

        shb.certs = {
          cas.selfsigned.myca = {
            name = "My CA";
          };
          certs.selfsigned = {
            n = {
              ca = config.shb.certs.cas.selfsigned.myca;
              domain = "*.example.com";
            };
          };
        };

        services.dnsmasq = {
          enable = true;
          settings = {
            domain-needed = true;
            # no-resolv = true;
            bogus-priv = true;
            address =
              map (hostname: "/${hostname}/127.0.0.1") [
                "example.com"
                "n.example.com"
                "ldap.example.com"
                "auth.example.com"
              ];
          };
        };

        shb.nextcloud = {
          enable = true;
          domain = "example.com";
          subdomain = "n";
          ssl = config.shb.certs.certs.selfsigned.n;
          dataDir = "/var/lib/nextcloud";
          tracing = null;

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
            sso = {
              enable = true;
              endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
              clientID = "nextcloud";
              fallbackDefaultAuth = true;

              secretFile = config.sops.secrets."nextcloud/sso/secret".path;
              secretFileForAuthelia = config.sops.secrets."authelia/nextcloud_sso_secret".path;
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
        sops.secrets."nextcloud/sso/secret" = {
          sopsFile = ./secrets.yaml;
          mode = "0400";
          owner = "nextcloud";
          restartUnits = [ "nextcloud-setup.service" ];
        };
        sops.secrets."authelia/nextcloud_sso_secret" = {
          sopsFile = ./secrets.yaml;
          key = "nextcloud/sso/secret";
          mode = "0400";
          owner = config.shb.authelia.autheliaUser;
        };

        # Set to true for more debug info with `journalctl -f -u nginx`.
        shb.nginx.accessLog = true;
        shb.nginx.debugLog = false;

        shb.ldap = {
          enable = true;
          domain = "example.com";
          subdomain = "ldap";
          ssl = config.shb.certs.certs.selfsigned.n;
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

        shb.authelia = {
          enable = true;
          domain = "example.com";
          subdomain = "auth";
          ssl = config.shb.certs.certs.selfsigned.n;

          ldapEndpoint = "ldap://127.0.0.1:${builtins.toString config.shb.ldap.ldapPort}";
          dcdomain = config.shb.ldap.dcdomain;

          secrets = {
            jwtSecretFile = config.sops.secrets."authelia/jwt_secret".path;
            ldapAdminPasswordFile = config.sops.secrets."authelia/ldap_admin_password".path;
            sessionSecretFile = config.sops.secrets."authelia/session_secret".path;
            storageEncryptionKeyFile = config.sops.secrets."authelia/storage_encryption_key".path;
            identityProvidersOIDCHMACSecretFile = config.sops.secrets."authelia/hmac_secret".path;
            identityProvidersOIDCIssuerPrivateKeyFile = config.sops.secrets."authelia/private_key".path;
          };
        };
        sops.secrets."authelia/jwt_secret" = {
          sopsFile = ./secrets.yaml;
          mode = "0400";
          owner = config.shb.authelia.autheliaUser;
          restartUnits = [ "authelia.service" ];
        };
        # Here we use the password defined in the lldap/user_password field in the secrets.yaml file
        # and sops-nix will write it to "/run/secrets/authelia/ldap_admin_password".
        sops.secrets."authelia/ldap_admin_password" = {
          sopsFile = ./secrets.yaml;
          key = "lldap/user_password";
          mode = "0400";
          owner = config.shb.authelia.autheliaUser;
          restartUnits = [ "authelia.service" ];
        };
        sops.secrets."authelia/session_secret" = {
          sopsFile = ./secrets.yaml;
          mode = "0400";
          owner = config.shb.authelia.autheliaUser;
          restartUnits = [ "authelia.service" ];
        };
        sops.secrets."authelia/storage_encryption_key" = {
          sopsFile = ./secrets.yaml;
          mode = "0400";
          owner = config.shb.authelia.autheliaUser;
          restartUnits = [ "authelia.service" ];
        };
        sops.secrets."authelia/hmac_secret" = {
          sopsFile = ./secrets.yaml;
          mode = "0400";
          owner = config.shb.authelia.autheliaUser;
          restartUnits = [ "authelia.service" ];
        };
        sops.secrets."authelia/private_key" = {
          sopsFile = ./secrets.yaml;
          mode = "0400";
          owner = config.shb.authelia.autheliaUser;
          restartUnits = [ "authelia.service" ];
        };
      };
    };
  };
}
