{ distribution ? null
, services ? null
, system ? builtins.currentSystem
, pkgs ? import <nixpkgs> { inherit system; }
, utils ? null
}:

let
  callPackage = pkgs.lib.callPackageWith (pkgs // self);

  self = rec {
    PostgresDB = callPackage ./postgresdb {};

    HaproxyConfig = callPackage ./haproxy/config.nix {inherit utils;};
    HaproxyService = callPackage ./haproxy/unit.nix {inherit utils;};
    mkHaproxySiteConfig = callPackage ./haproxy/siteconfig.nix {};

    CaddyConfig = callPackage ./caddy/config.nix {inherit utils;};
    CaddyService = callPackage ./caddy/unit.nix {inherit utils;};
    CaddySiteConfig = callPackage ./caddy/siteconfig.nix {inherit utils;};
    mkCaddySiteConfig = callPackage ./caddy/mksiteconfig.nix {inherit CaddySiteConfig;};

    NginxService = callPackage ./nginx/unit.nix {inherit utils;};
    NginxSiteConfig = callPackage ./nginx/siteconfig.nix {inherit utils;};
    mkNginxSiteConfig = callPackage ./nginx/mksiteconfig.nix {inherit NginxSiteConfig;};

    PHPConfig = callPackage ./php/config.nix {inherit utils;};

    PHPFPMConfig = callPackage ./php-fpm/config.nix {inherit utils;};
    PHPFPMService = callPackage ./php-fpm/unit.nix {inherit utils;};
    PHPFPMSiteConfig = callPackage ./php-fpm/siteconfig.nix {inherit utils;};
    mkPHPFPMSiteConfig = callPackage ./php-fpm/mksiteconfig.nix {inherit PHPFPMSiteConfig;};

    TtrssEnvironment = callPackage ./ttrss/environment.nix {};
    TtrssConfig = callPackage ./ttrss/config.nix {};
    TtrssUpdateService = callPackage ./ttrss/update.nix {inherit utils;};
    TtrssUpgradeDBService = callPackage ./ttrss/dbupgrade.nix {};
    TtrssPHPNormalizeHeaders = callPackage ./ttrss/normalize-headers.nix {inherit utils;};
  };
in
self
