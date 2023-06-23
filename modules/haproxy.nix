{ config, pkgs, lib, ... }:

let
  cfg = config.shb.reverseproxy;
in
{
  options.shb.reverseproxy = {
    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Sops file location";
      example = "secrets/haproxy.yaml";
    };

    domain = lib.mkOption {
      description = lib.mdDoc "Domain to serve sites under.";
      type = lib.types.str;
    };

    adminEmail = lib.mkOption {
      description = lib.mdDoc "Admin email in case certificate retrieval goes wrong.";
      type = lib.types.str;
    };

    sites = lib.mkOption {
      description = lib.mdDoc "Sites to serve through the reverse proxy.";
      type = lib.types.anything;
      default = {};
      example = {
        homeassistant = {
          frontend = {
            acl = {
              acl_homeassistant = "hdr_beg(host) ha.";
            };
            use_backend = "if acl_homeassistant";
          };
          backend = {
            servers = [
              {
                name = "homeassistant1";
                address = "127.0.0.1:8123";
                forwardfor = false;
                balance = "roundrobin";
                check = {
                  inter = "5s";
                  downinter = "15s";
                  fall = "3";
                  rise = "3";
                };
                httpcheck = "GET /";
              }
            ];
          };
        };
      };
    };
  };

  config = lib.mkIf (cfg.sites != {}) {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    security.acme = {
      acceptTerms = true;
      certs."${cfg.domain}" = {
        extraDomainNames = ["*.${cfg.domain}"];
      };
      defaults = {
        email = cfg.adminEmail;
        dnsProvider = "linode";
        dnsResolver = "8.8.8.8";
        group = config.services.haproxy.user;
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

    services.haproxy.enable = true;

    services.haproxy.config = let
      configcreator = pkgs.callPackage ./haproxy-configcreator.nix {};
    in configcreator.render ( configcreator.default {
      inherit (config.services.haproxy) user group;

      certPath = "/var/lib/acme/${cfg.domain}/full.pem";

      stats = {
        port = 8404;
        uri = "/stats";
        refresh = "10s";
        prometheusUri = "/metrics";
      };

      defaults = {
        default-server = "init-addr last,none";
      };

      inherit (cfg) sites;
    });
  };
}
