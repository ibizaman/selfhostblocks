{
  description = "Jellyfin example for Self Host Blocks";

  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs =
    inputs@{
      self,
      selfhostblocks,
      sops-nix,
    }:
    let
      system = "x86_64-linux";
      nixpkgs' = selfhostblocks.lib.${system}.patchedNixpkgs;

      basic =
        { config, pkgs, ... }:
        {
          imports = [
            ./configuration.nix
            selfhostblocks.nixosModules.jellyfin
            selfhostblocks.nixosModules.sops
            selfhostblocks.nixosModules.ssl
            sops-nix.nixosModules.default
          ];

          sops.defaultSopsFile = ./secrets.yaml;

          environment.systemPackages = [
            # To be able to inspect the jellyfin database.
            pkgs.sqlite
          ];

          # Jellyfin needs at least 2Gb in its data dir to accept to start.
          virtualisation.diskSize = 4096;

          shb.nginx.debugLog = true;
          shb.nginx.insecureAccessLogWithRequestBody = true;

          shb.certs = {
            cas.selfsigned.myca = {
              name = "My CA";
            };
            certs.selfsigned = {
              "example.com" = {
                ca = config.shb.certs.cas.selfsigned.myca;
                domain = "*.example.com";
                group = "nginx";
              };
            };
          };

          shb.jellyfin = {
            enable = true;
            domain = "example.com";
            subdomain = "j";
            ssl = config.shb.certs.certs.selfsigned."example.com";
            debug = true;

            admin = {
              username = "admin";
              password.result = config.shb.sops.secret."jellyfin/admin_password".result;
            };
          };
          shb.sops.secret."jellyfin/admin_password".request = config.shb.jellyfin.admin.password.request;
        };

      ldap =
        { config, ... }:
        {
          imports = [
            selfhostblocks.nixosModules.lldap
          ];

          shb.lldap = {
            enable = true;
            domain = "example.com";
            subdomain = "ldap";
            ssl = config.shb.certs.certs.selfsigned."example.com";
            debug = true;

            ldapPort = 3890;
            webUIListenPort = 17170;
            dcdomain = "dc=example,dc=com";
            ldapUserPassword.result = config.shb.sops.secret."lldap/user_password".result;
            jwtSecret.result = config.shb.sops.secret."lldap/jwt_secret".result;
          };
          shb.sops.secret."lldap/user_password".request = config.shb.lldap.ldapUserPassword.request;
          shb.sops.secret."lldap/jwt_secret".request = config.shb.lldap.jwtSecret.request;

          shb.jellyfin.ldap = {
            enable = true;
            host = "127.0.0.1";
            port = config.shb.lldap.ldapPort;
            dcdomain = config.shb.lldap.dcdomain;
            adminPassword.result = config.shb.sops.secret."jellyfin/ldap/admin_password".result;
          };
          shb.sops.secret."jellyfin/ldap/admin_password" = {
            request = config.shb.jellyfin.ldap.adminPassword.request;
            settings.key = "lldap/user_password";
          };

          shb.lldap.ensureGroups = {
            "${config.shb.jellyfin.ldap.userGroup}" = { };
            "${config.shb.jellyfin.ldap.adminGroup}" = { };
          };
          shb.lldap.ensureUsers = {
            alice = {
              email = "alice@example.com";
              displayName = "Alice";
              password.result = config.shb.sops.secret."users/alice/password".result;
              groups = [
                config.shb.jellyfin.ldap.userGroup
                config.shb.jellyfin.ldap.adminGroup
              ];
            };
          };
          shb.sops.secret."users/alice/password".request =
            config.shb.lldap.ensureUsers.alice.password.request;
        };

      sso =
        { config, ... }:
        {
          imports = [
            selfhostblocks.nixosModules.authelia
          ];

          shb.authelia = {
            enable = true;
            domain = "example.com";
            subdomain = "auth";
            ssl = config.shb.certs.certs.selfsigned."example.com";
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
          shb.sops.secret."authelia/session_secret".request =
            config.shb.authelia.secrets.sessionSecret.request;
          shb.sops.secret."authelia/storage_encryption_key".request =
            config.shb.authelia.secrets.storageEncryptionKey.request;
          shb.sops.secret."authelia/hmac_secret".request =
            config.shb.authelia.secrets.identityProvidersOIDCHMACSecret.request;
          shb.sops.secret."authelia/private_key".request =
            config.shb.authelia.secrets.identityProvidersOIDCIssuerPrivateKey.request;

          shb.jellyfin.sso = {
            enable = true;
            endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

            sharedSecret.result = config.shb.sops.secret."jellyfin/sso_secret".result;
            sharedSecretForAuthelia.result = config.shb.sops.secret."jellyfin/authelia/sso_secret".result;
          };
          shb.sops.secret."jellyfin/sso_secret".request = config.shb.jellyfin.sso.sharedSecret.request;
          shb.sops.secret."jellyfin/authelia/sso_secret" = {
            request = config.shb.jellyfin.sso.sharedSecretForAuthelia.request;
            settings.key = "jellyfin/sso_secret";
          };
        };

      sopsConfig = {
        sops.age.keyFile = "/etc/sops/my_key";
        environment.etc."sops/my_key".source = ./keys.txt;
      };
    in
    {
      nixosConfigurations = {
        basic = nixpkgs'.nixosSystem {
          system = "x86_64-linux";
          modules = [
            basic
            sopsConfig
          ];
        };

        ldap = nixpkgs'.nixosSystem {
          system = "x86_64-linux";
          modules = [
            basic
            ldap
            sopsConfig
          ];
        };

        sso = nixpkgs'.nixosSystem {
          system = "x86_64-linux";
          modules = [
            basic
            ldap
            sso
            sopsConfig
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

        basic =
          { config, ... }:
          {
            imports = [
              basic
            ];

            # Used by colmena to know which target host to deploy to.
            deployment = {
              targetHost = "example";
              targetUser = "nixos";
              targetPort = 2222;
            };
          };

        ldap =
          { config, ... }:
          {
            imports = [
              basic
              ldap
            ];

            # Used by colmena to know which target host to deploy to.
            deployment = {
              targetHost = "example";
              targetUser = "nixos";
              targetPort = 2222;
            };
          };

        sso =
          { config, ... }:
          {
            imports = [
              basic
              ldap
              sso
            ];

            # Used by colmena to know which target host to deploy to.
            deployment = {
              targetHost = "example";
              targetUser = "nixos";
              targetPort = 2222;
            };
          };
      };
    };
}
