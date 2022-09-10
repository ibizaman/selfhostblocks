{ distribution ? null
, services ? null
, system ? builtins.currentSystem
, pkgs ? import <nixpkgs> { inherit system; }
, utils ? null
}:

let
  callPackage = pkgs.lib.callPackageWith (pkgs // self);

  self = {
    PostgresDB = callPackage ./PostgresDB {};

    CaddyConfig = callPackage ./caddy/config.nix {inherit utils;};
    CaddyService = callPackage ./caddy/unit.nix {inherit utils;};
    CaddySiteConfig = callPackage ./caddy/siteconfig.nix {inherit utils;};

    PHPFPMConfig = callPackage ./PHP-FPM/config.nix {inherit utils;};
    PHPFPMService = callPackage ./PHP-FPM/unit.nix {inherit utils;};
    PHPFPMSiteConfig = callPackage ./PHP-FPM/siteconfig.nix {inherit utils;};

    TtrssEnvironment = callPackage ./Ttrss/environment.nix {};
    TtrssConfig = callPackage ./Ttrss/config.nix {};
    TtrssUpdateService = callPackage ./Ttrss/update.nix {inherit utils;};
    TtrssUpgradeDBService = callPackage ./Ttrss/dbupgrade.nix {};
  };
in
self
