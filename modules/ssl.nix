{ config, pkgs, lib, ... }:

let
  cfg = config.shb.ssl;
in
{
  options.shb.ssl = {
    enable = lib.mkEnableOption "selfhostblocks.ssl";

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Sops file location";
      example = "secrets/haproxy.yaml";
    };

    domain = lib.mkOption {
      description = lib.mdDoc "Domain to serve sites under.";
      type = lib.types.str;
      example = "domain.com";
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
    users.groups.ngins = {};

    security.acme = {
      acceptTerms = true;
      certs."${cfg.domain}" = {
        extraDomainNames = ["*.${cfg.domain}"];
      };
      defaults = {
        email = cfg.adminEmail;
        dnsProvider = "linode";
        dnsResolver = "8.8.8.8";
        # For example, to use Linode to prove the dns challenge,
        # the content of the file should be the following, with
        # XXX replaced by your Linode API token.
        # LINODE_HTTP_TIMEOUT=10
        # LINODE_POLLING_INTERVAL=10
        # LINODE_PROPAGATION_TIMEOUT=240
        # LINODE_TOKEN=XXX
        credentialsFile = "/run/secrets/linode";
        enableDebugLogs = false;
      };
    };
    sops.secrets.linode = {
      inherit (cfg) sopsFile;
      restartUnits = [ "acme-${cfg.domain}.service" ];
    };
  };
}
