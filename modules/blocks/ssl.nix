{ config, pkgs, lib, ... }:

let
  cfg = config.shb.ssl;
in
{
  options.shb.ssl = {
    enable = lib.mkEnableOption "selfhostblocks.ssl";

    domain = lib.mkOption {
      description = lib.mdDoc "Domain to serve sites under.";
      type = lib.types.str;
      example = "domain.com";
    };

    dnsProvider = lib.mkOption {
      description = lib.mdDoc "DNS provider.";
      type = lib.types.str;
      example = "linode";
    };

    credentialsFile = lib.mkOption {
      type = lib.types.path;
      description = ''Credentials file location for the chosen DNS provider.

      The content of this file must expose environment variables as written in the
      [documentation](https://go-acme.github.io/lego/dns/) of each DNS provider.

      For example, if the documentation says the credential must be located in the environment
      variable DNSPROVIDER_TOKEN, then the file content must be:

      DNSPROVIDER_TOKEN=xyz

      You can put non-secret environment variables here too or use shb.ssl.additionalcfg instead.
      '';
      example = "/run/secrets/ssl";
    };

    dnsResolver = lib.mkOption {
      description = lib.mdDoc "IP of a DNS server used to resolve hostnames.";
      type = lib.types.str;
      default = "8.8.8.8";
    };

    adminEmail = lib.mkOption {
      description = lib.mdDoc "Admin email in case certificate retrieval goes wrong.";
      type = lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${config.services.nginx.user} = {
      isSystemUser = true;
      group = "nginx";
      extraGroups = [ config.security.acme.defaults.group ];
    };
    users.groups.nginx = {};

    security.acme = {
      acceptTerms = true;
      certs."${cfg.domain}" = {
        extraDomainNames = ["*.${cfg.domain}"];
      };
      defaults = {
        email = cfg.adminEmail;
        inherit (cfg) dnsProvider dnsResolver;
        enableDebugLogs = false;
        credentialsFile = cfg.credentialsFile;
      };
    };
    sops.secrets.acme = {
      inherit (cfg) sopsFile;
      restartUnits = [ "acme-${cfg.domain}.service" ];
    };
  };
}
