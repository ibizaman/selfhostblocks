{ config, pkgs, lib, ... }:

let
  cfg = config.shb.ssl;
in
{
  options.shb.ssl = {
    enable = lib.mkEnableOption "selfhostblocks.ssl";

    domain = lib.mkOption {
      description = "Domain to ask a wildcard certificate for.";
      type = lib.types.str;
      example = "domain.com";
    };

    dnsProvider = lib.mkOption {
      description = "DNS provider to use. See https://go-acme.github.io/lego/dns/ for the list of supported providers.";
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

    additionalCfg = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = ''Additional environment variables used to configure the DNS provider.

      For secrets, use shb.ssl.credentialsFile instead.

      See the chose provider's [documentation](https://go-acme.github.io/lego/dns/) for available
      options.
      '';
      example = lib.literalExpression ''{
        DNSPROVIDER_TIMEOUT = "10";
        DNSPROVIDER_PROPAGATION_TIMEOUT = "240";
      }'';
    };

    dnsResolver = lib.mkOption {
      description = "IP of a DNS server used to resolve hostnames.";
      type = lib.types.str;
      default = "8.8.8.8";
    };

    adminEmail = lib.mkOption {
      description = "Admin email in case certificate retrieval goes wrong.";
      type = lib.types.str;
    };

    debug = lib.mkOption {
      description = "Enable debug logging";
      type = lib.types.bool;
      default = false;
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
        credentialsFile = cfg.credentialsFile;
        enableDebugLogs = cfg.debug;
      };
    };

    systemd.services."acme-${cfg.domain}".environment = cfg.additionalCfg;
  };
}
