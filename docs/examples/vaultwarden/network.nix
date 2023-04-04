rec {
  machine1 = { system
           , pkgs
           , lib
           , utils
           , domain
           , secret
           , ... }:
    let
      customPkgs = (pkgs.callPackage (./../../..) {}).customPkgs {
        inherit system pkgs utils secret;
      };

      vaultwarden = customPkgs.vaultwarden {};
      keycloak = customPkgs.keycloak {};

      httpUser = "http";
      httpGroup = "http";
      httpRoot = "/usr/share/webapps";

      phpfpmUser = "phpfpm";
      phpfpmGroup = "phpfpm";
      phpfpmRoot = "/run/php-fpm";

      keycloakUser = "keycloak";
      keycloakGroup = "keycloak";

      caddyHttpPort = 10001;
      caddyHttpsPort = 10002;

      keycloaksecretsdir = "/run/keys/keycloakcliconfig";
      keycloakusers = [ "me" "friend" ];
    in
      rec {
        users.groups = {
          http = {
            name = httpGroup;
          };
          phpfpm = {
            name = phpfpmGroup;
          };
          keycloak = {
            name = keycloakGroup;
          };
          keycloakcli = {
            name = "keycloakcli";
          };
          "${vaultwarden.group}" = {
            name = "${vaultwarden.group}";
          };
        };
        users.users = {
          http = {
            name = httpUser;
            group = httpGroup;
            home = httpRoot;
            isSystemUser = true;
          };
          phpfpm = {
            name = phpfpmUser;
            group = phpfpmGroup;
            home = phpfpmRoot;
            isSystemUser = true;
          };
          keycloak = {
            name = keycloakUser;
            group = keycloakGroup;
            # home ?
            isSystemUser = true;
          };
          keycloakcli = {
            name = "keycloakcli";
            group = "keycloakcli";
            extraGroups = [ "keys" ];
            isSystemUser = true;
          };
          "${vaultwarden.user}" = {
            name = vaultwarden.user;
            group = vaultwarden.group;
            extraGroups = [ "keys" ];
            isSystemUser = true;
          };
        };

        # deployment.keys = {
        #   linode.text = ''
        #     LINODE_HTTP_TIMEOUT=10
        #     LINODE_POLLING_INTERVAL=10
        #     LINODE_PROPAGATION_TIMEOUT=240
        #     LINODE_TOKEN=383525f4d58919d43506e6ab43a549a6eda6491eccb8e384d43013f0bcf45d47
        #   '';

        #   keycloakdbpassword.text = ''
        #     KC_DB_PASSWORD="${secret "${domain}/keycloakdbpassword"}"
        #   '';

        #   keycloakinitialadmin.text = ''
        #     KEYCLOAK_ADMIN_PASSWORD="${secret "${domain}/${keycloak.subdomain}/admin"}"
        #   '';

        #   # This convention is for keycloak-cli-config
        #   "keycloak.password" = {
        #     destDir = keycloaksecretsdir;
        #     user = "keycloakcli";
        #     text = secret "${domain}/${keycloak.subdomain}/admin";
        #   };
        #   "keycloakusers" =
        #     let
        #       e = str: lib.strings.escape [''\''] (lib.strings.escape [''"''] str);
        #     in
        #       {
        #         user = "keycloakcli";
        #         text = lib.concatMapStringsSep "\n"
        #           (name: "KEYCLOAK_USERS_${lib.strings.toUpper name}_PASSWORD=${e (secret "${domain}/${keycloak.subdomain}/${name}")}")
        #           keycloakusers;
        #       };
        # }
        # // vaultwarden.deployKeys domain;

        security.acme = {
          acceptTerms = true;
          certs = {
            "${domain}" = {
              extraDomainNames = ["*.${domain}"];
            };
          };
          defaults = {
            group = httpGroup;
            email = "ibizapeanut@gmail.com";
            dnsProvider = "linode";
            dnsResolver = "8.8.8.8";
            credentialsFile = "/run/keys/linode";
            enableDebugLogs = true;
          };
        };

        services = {
          openssh = {
            enable = true;
          };

          disnix = {
            enable = true;
            # useWebServiceInterface = true;
          };

          dnsmasq = {
            enable = true;
            servers = [ "192.168.50.15" "192.168.50.1" ];
            extraConfig =
              let
                subdomains = [
                  "machine1"
                  keycloak.subdomain
                  vaultwarden.subdomain
                ];

                inherit domain;
              in (lib.concatMapStrings
                (subdomain: "address=/${subdomain}.${domain}/127.0.0.1\naddress=/${subdomain}/127.0.0.1\n")
                subdomains)
            ;
          };

          # tomcat.enable = false;

          postgresql = {
            enable = true;
            package = pkgs.postgresql_14;

            port = 5432;
            enableTCPIP = true;
            authentication = pkgs.lib.mkOverride 10 ''
            local all all trust
            host all all 127.0.0.1/32 trust
            host all all ::1/128 trust
          '';
          };
        };

        dysnomia = {
          enable = true;
          enableLegacyModules = false;
          extraContainerProperties = {
            system = {
              inherit domain;
            };
            postgresql-database = {
              service_name = "postgresql.service";
              port = builtins.toString services.postgresql.port;
            };
            keycloaksecrets = {
              rootdir = keycloaksecretsdir;
            };
          };
        };

        networking.firewall.allowedTCPPorts = [ services.postgresql.port ] ++ virtualbox.guestPorts;
      };

  virtualbox = rec {
    portMappings = [
      { name = "ssh";
        host = 22;
        guest = 22;
      }
      { name = "dns";
        host = 53;
        guest = 53;
      }
      { name = "https";
        host = 443;
        guest = 443;
      }
    ];

    hostPorts = map (x: x.host) portMappings;
    guestPorts = map (x: x.guest) portMappings;
  };
}
