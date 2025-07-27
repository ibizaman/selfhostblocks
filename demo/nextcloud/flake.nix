{
  description = "Home Assistant example for Self Host Blocks";

  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = inputs@{ self, selfhostblocks, sops-nix }:
    let
      system = "x86_64-linux";
      nixpkgs' = selfhostblocks.lib.${system}.patchedNixpkgs;

      basic = { config, ... }: {
        imports = [
          ./configuration.nix
          selfhostblocks.nixosModules.x86_64-linux.default
          sops-nix.nixosModules.default
        ];

        sops.defaultSopsFile = ./secrets.yaml;

        shb.nextcloud = {
          enable = true;
          domain = "example.com";
          subdomain = "n";
          dataDir = "/var/lib/nextcloud";
          tracing = null;
          defaultPhoneRegion = "US";

          # This option is only needed because we do not access Nextcloud at the default port in the VM.
          port = 8080;

          adminPass.result = config.shb.sops.secret."nextcloud/adminpass".result;

          apps = {
            previewgenerator.enable = true;
          };
        };
        shb.sops.secret."nextcloud/adminpass".request = config.shb.nextcloud.adminPass.request;

        # Set to true for more debug info with `journalctl -f -u nginx`.
        shb.nginx.accessLog = true;
        shb.nginx.debugLog = false;
      };

      ldap = { config, ... }: {
        shb.lldap = {
          enable = true;
          domain = "example.com";
          subdomain = "ldap";
          ldapPort = 3890;
          webUIListenPort = 17170;
          dcdomain = "dc=example,dc=com";
          ldapUserPassword.result = config.shb.sops.secret."lldap/user_password".result;
          jwtSecret.result = config.shb.sops.secret."lldap/jwt_secret".result;
        };
        shb.sops.secret."lldap/user_password".request = config.shb.lldap.ldapUserPassword.request;
        shb.sops.secret."lldap/jwt_secret".request = config.shb.lldap.jwtSecret.request;

        shb.nextcloud.apps.ldap = {
          enable = true;
          host = "127.0.0.1";
          port = config.shb.lldap.ldapPort;
          dcdomain = config.shb.lldap.dcdomain;
          adminName = "admin";
          adminPassword.result = config.shb.sops.secret."nextcloud/ldap_admin_password".result;
          userGroup = "nextcloud_user";
        };
        shb.sops.secret."nextcloud/ldap_admin_password" = {
          request = config.shb.nextcloud.apps.ldap.adminPassword.request;
          settings.key = "lldap/user_password";
        };
      };

      sso = { config, lib, ... }: {
        shb.certs = {
          cas.selfsigned.myca = {
            name = "My CA";
          };
          certs.selfsigned = {
            n = {
              ca = config.shb.certs.cas.selfsigned.myca;
              domain = "*.example.com";
              group = "nginx";
            };
          };
        };
        shb.nextcloud = {
          port = lib.mkForce null;
          ssl = config.shb.certs.certs.selfsigned.n;
        };
        shb.lldap.ssl = config.shb.certs.certs.selfsigned.n;

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

        shb.authelia = {
          enable = true;
          domain = "example.com";
          subdomain = "auth";
          ssl = config.shb.certs.certs.selfsigned.n;
          ldapPort = config.shb.lldap.ldapPort;
          ldapHostname = "127.0.0.1";
          dcdomain = config.shb.lldap.dcdomain;

          secrets = {
            jwtSecret.result = config.shb.sops.secret."authelia/jwt_secret".result;
            ldapAdminPassword.result = config.shb.sops.secret."authelia/ldap_admin_password".result;
            sessionSecret.result = config.shb.sops.secret."authelia/session_secret".result;
            storageEncryptionKey.result = config.shb.sops.secret."authelia/storage_encryption_key".result;
            identityProvidersOIDCHMACSecret.result = config.shb.sops.secret."authelia/hmac_secret".result;
            identityProvidersOIDCIssuerPrivateKey.result = config.shb.sops.secret."authelia/private_key".result;
          };
        };
        shb.sops.secret."authelia/jwt_secret".request = config.shb.authelia.secrets.jwtSecret.request;
        shb.sops.secret."authelia/ldap_admin_password" = {
          request = config.shb.authelia.secrets.ldapAdminPassword.request;
          settings.key = "lldap/user_password";
        };
        shb.sops.secret."authelia/session_secret".request = config.shb.authelia.secrets.sessionSecret.request;
        shb.sops.secret."authelia/storage_encryption_key".request = config.shb.authelia.secrets.storageEncryptionKey.request;
        shb.sops.secret."authelia/hmac_secret".request = config.shb.authelia.secrets.identityProvidersOIDCHMACSecret.request;
        shb.sops.secret."authelia/private_key".request = config.shb.authelia.secrets.identityProvidersOIDCIssuerPrivateKey.request;

        shb.nextcloud.apps.sso = {
          enable = true;
          endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
          clientID = "nextcloud";
          fallbackDefaultAuth = true;

          secret.result = config.shb.sops.secret."nextcloud/sso/secret".result;
          secretForAuthelia.result = config.shb.sops.secret."authelia/nextcloud_sso_secret".result;
        };
        shb.sops.secret."nextcloud/sso/secret".request = config.shb.nextcloud.apps.sso.secret.request;
        shb.sops.secret."authelia/nextcloud_sso_secret" = {
          request = config.shb.nextcloud.apps.sso.secretForAuthelia.request;
          settings.key = "nextcloud/sso/secret";
        };
      };

      sopsConfig = {
        sops.age.keyFile = "/etc/sops/my_key";
        environment.etc."sops/my_key".source = ./keys.txt;
      };
    in
      {
        nixosConfigurations = {
          basic = nixpkgs'.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              sopsConfig
              basic
            ];
          };
          ldap = nixpkgs'.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              sopsConfig
              basic
              ldap
            ];
          };
          sso = nixpkgs'.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              sopsConfig
              basic
              ldap
              sso
            ];
          };
        };

        colmena = {
          meta = {
            nixpkgs = import nixpkgs' {
              system = "x86_64-linux";
            };
            specialArgs = inputs;
          };

          basic = { config, ... }: {
            imports = [
              basic
            ];

            deployment = {
              targetHost = "example";
              targetUser = "nixos";
              targetPort = 2222;
            };
          };

          ldap = { config, ... }: {
            imports = [
              basic
              ldap
            ];

            deployment = {
              targetHost = "example";
              targetUser = "nixos";
              targetPort = 2222;
            };
          };

          sso = { config, ... }: {
            imports = [
              basic
              ldap
              sso
            ];

            deployment = {
              targetHost = "example";
              targetUser = "nixos";
              targetPort = 2222;
            };
          };
        };
      };
}
