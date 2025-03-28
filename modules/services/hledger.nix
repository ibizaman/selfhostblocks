{ config, pkgs, lib, ... }:

let
  cfg = config.shb.hledger;

  contracts = pkgs.callPackage ../contracts {};

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

    dataDir = lib.mkOption {
      description = "Folder where Hledger will store all its data.";
      type = lib.types.str;
      default = "/var/lib/hledger";
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
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

    authEndpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "OIDC endpoint for SSO";
      example = "https://authelia.example.com";
      default = null;
    };

    backup = lib.mkOption {
      description = ''
        Backup configuration.
      '';
      default = {};
      type = lib.types.submodule {
        options = contracts.backup.mkRequester {
          user = "hledger";
          sourceDirectories = [
            cfg.dataDir
          ];
        };
      };
    };

    extraArguments = lib.mkOption {
      description = "Extra arguments append to the hledger command.";
      default = ["--forecast"];
      type = lib.types.listOf lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    services.hledger-web = {
      enable = true;
      # Must be empty otherwise it repeats the fqdn, we get something like https://${fqdn}/${fqdn}/
      baseUrl = "";

      stateDir = cfg.dataDir;
      journalFiles = ["hledger.journal"];

      host = "127.0.0.1";
      port = cfg.port;

      allow = "edit";
      extraOptions = cfg.extraArguments;
    };

    systemd.services.hledger-web = {
      # If the hledger.journal file does not exist, hledger-web refuses to start, so we create an
      # empty one if it does not exist yet..
      preStart = ''
      test -f /var/lib/hledger/hledger.journal || touch /var/lib/hledger/hledger.journal
      '';
      serviceConfig.StateDirectory = "hledger";
    };

    shb.nginx.vhosts = [
      {
        inherit (cfg) subdomain domain authEndpoint ssl;
        upstream = "http://${toString config.services.hledger-web.host}:${toString config.services.hledger-web.port}";
        autheliaRules = [{
          domain = fqdn;
          policy = "two_factor";
          subject = ["group:hledger_user"];
        }];
      }
    ];
  };
}
