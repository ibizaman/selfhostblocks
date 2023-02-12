{ distribution ? null
, services ? null
, system ? builtins.currentSystem
, pkgs ? import <nixpkgs> { inherit system; }
, utils ? null
}:

let
  callPackage = pkgs.lib.callPackageWith (pkgs // customPkgs);

  customPkgs = rec {
    mkPostgresDB = callPackage ./postgresdb {};

    mkHaproxyService = callPackage ./haproxy/unit.nix {inherit utils;};

    CaddyConfig = callPackage ./caddy/config.nix {inherit utils;};
    CaddyService = callPackage ./caddy/unit.nix {inherit utils;};
    CaddySiteConfig = callPackage ./caddy/siteconfig.nix {inherit utils;};
    mkCaddySiteConfig = callPackage ./caddy/mksiteconfig.nix {inherit CaddySiteConfig;};

    mkNginxService = callPackage ./nginx/unit.nix {inherit utils;};

    mkPHPFPMService = callPackage ./php-fpm/unit.nix {inherit utils;};

    mkKeycloakService = callPackage ./keycloak/unit.nix {inherit utils;};
    mkOauth2Proxy = callPackage ./oauth2-proxy/unit.nix {inherit utils;};

    mkKeycloakHaproxyService = callPackage ./keycloak-haproxy/unit.nix {inherit utils;};

    mkKeycloakCliService = callPackage ./keycloak-cli-config/unit.nix {inherit utils;};

    ttrss = callPackage ./ttrss {inherit utils customPkgs;};
    vaultwarden = callPackage ./vaultwarden {inherit utils customPkgs;};
  };
in
customPkgs
