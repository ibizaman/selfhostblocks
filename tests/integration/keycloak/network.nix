rec {
  test1 = { system
          , pkgs
          , lib
          , ... }:
    let
      domain = "local";

      utils = pkgs.lib.callPackageWith pkgs ../../../utils.nix { };

      customPkgs = import ../../../all-packages.nix {
        inherit system pkgs utils;
      };
    in
      rec {
        users.groups = {
          keycloak = {
            name = "keycloak";
          };
        };
        users.users = {
          keycloak = {
            name = "keycloak";
            group = "keycloak";
            isSystemUser = true;
          };
        };

        # deployment.keys = {
        #   keycloakinitialadmin.text = ''
        #     KEYCLOAK_ADMIN_PASSWORD="${builtins.extraBuiltins.pass "keycloak.${domain}/admin"}"
        #   '';
        # };

        services = {
          openssh = {
            enable = true;
          };

          disnix = {
            enable = true;
            # useWebServiceInterface = true;
          };

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
          };
        };

        networking.firewall.allowedTCPPorts = [ services.postgresql.port ];
      };
}
