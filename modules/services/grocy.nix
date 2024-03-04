{ config, pkgs, lib, ... }:

let
  cfg = config.shb.grocy;

  contracts = pkgs.callPackage ../contracts {};

  fqdn = "${cfg.subdomain}.${cfg.domain}";
in
{
  options.shb.grocy = {
    enable = lib.mkEnableOption "selfhostblocks.grocy";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which grocy will be served.";
      example = "grocy";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which grocy will be served.";
      example = "mydomain.com";
    };

    dataDir = lib.mkOption {
      description = "Folder where Grocy will store all its data.";
      type = lib.types.str;
      default = "/var/lib/grocy";
    };

    currency = lib.mkOption {
      type = lib.types.str;
      description = "ISO 4217 code for the currency to display.";
      default = "USD";
      example = "NOK";
    };

    culture = lib.mkOption {
      type = lib.types.enum [ "de" "en" "da" "en_GB" "es" "fr" "hu" "it" "nl" "no" "pl" "pt_BR" "ru" "sk_SK" "sv_SE" "tr" ];
      default = "en";
      description = lib.mdDoc ''
        Display language of the frontend.
      '';
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };

    extraServiceConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Extra configuration given to the systemd service file.";
      default = {};
      example = lib.literalExpression ''
      {
        MemoryHigh = "512M";
        MemoryMax = "900M";
      }
      '';
    };

    logLevel = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["critical" "error" "warning" "info" "debug"]);
      description = "Enable logging.";
      default = false;
      example = true;
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [{

    services.grocy = {
      enable = true;
      hostName = fqdn;
      nginx.enableSSL = !(isNull cfg.ssl);
      dataDir = cfg.dataDir;
      settings.currency = cfg.currency;
      settings.culture = cfg.culture;
    };

    services.phpfpm.pools.grocy.group = lib.mkForce "grocy";

    users.groups.grocy = {};
    users.users.grocy.group = lib.mkForce "grocy";

    services.nginx.virtualHosts."${fqdn}" = {
      enableACME = lib.mkForce false;
      sslCertificate = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.cert;
      sslCertificateKey = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.key;
    };

    # We backup the whole grocy directory and set permissions for the backup user accordingly.
    users.groups.grocy.members = [ "backup" ];
    users.groups.media.members = [ "backup" ];
    shb.backup.instances.grocy = {
      sourceDirectories = [
        config.services.grocy.dataDir
      ];
    };
  } {
    systemd.services.grocyd.serviceConfig = cfg.extraServiceConfig;
  }]);
}
