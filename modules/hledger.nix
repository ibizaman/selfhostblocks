{ config, pkgs, lib, ... }:

let
  cfg = config.shb.hledger;

  fqdn = "${cfg.subdomain}.${cfg.domain}";
in
{
  options.shb.hledger = {
    enable = lib.mkEnableOption "selfhostblocks.hledger";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which Authelia will be served.";
      example = "ha";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which Authelia will be served.";
      example = "mydomain.com";
    };

    port = lib.mkOption {
      type = lib.types.int;
      description = "HLedger port";
      default = 5000;
    };

    localNetworkIPRange = lib.mkOption {
      type = lib.types.str;
      description = "Local network range, to restrict access to the UI to only those IPs.";
      default = null;
      example = "192.168.1.1/24";
    };
  };

  config = lib.mkIf cfg.enable {
    services.hledger-web = {
      enable = true;
      baseUrl = fqdn;

      stateDir = "/var/lib/hledger";
      journalFiles = ["hledger.journal"];

      host = "127.0.0.1";
      port = cfg.port;

      capabilities.view = true;
      capabilities.add = true;
      capabilities.manage = true;
      extraOptions = [
        # https://hledger.org/1.30/hledger-web.html
        # "--capabilities-header=HLEDGER-CAP"
        "--forecast"
      ];
    };

    services.nginx = {
      enable = true;

      virtualHosts.${fqdn} = {
        forceSSL = true;
        sslCertificate = "/var/lib/acme/${cfg.domain}/cert.pem";
        sslCertificateKey = "/var/lib/acme/${cfg.domain}/key.pem";

        locations."/" = {
          proxyPass = "http://${toString config.services.hledger-web.host}:${toString config.services.hledger-web.port}";
          # proxyWebsockets = true;

          extraConfig = lib.mkIf (cfg.localNetworkIPRange != null) ''
          allow ${cfg.localNetworkIPRange};
          '';
        };
      };
    };

    shb.authelia.rules = [
      # {
      #   domain = fqdn;
      #   policy = "bypass";
      #   resources = [
      #     "^/api.*"
      #     "^/auth/token.*"
      #     "^/.external_auth=."
      #     "^/service_worker.js"
      #     "^/static/.*"
      #   ];
      # }
      {
        domain = fqdn;
        policy = "two_factor";
      }
    ];

    shb.backup.instances.hledger = {
      sourceDirectories = [
        config.services.hledger-web.stateDir
      ];
    };
  };
}
