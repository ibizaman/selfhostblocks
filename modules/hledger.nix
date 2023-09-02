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

    oidcEndpoint = lib.mkOption {
      type = lib.types.str;
      description = "OIDC endpoint for SSO";
      example = "https://authelia.example.com";
    };
  };

  config = lib.mkIf cfg.enable {
    services.hledger-web = {
      enable = true;
      # Must be empty otherwise it repeats the fqdn, we get something like https://${fqdn}/${fqdn}/
      baseUrl = "";

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

    systemd.services.hledger-web = {
      # If the hledger.journal file does not exist, hledger-web refuses to start, so we create an
      # empty one if it does not exist yet..
      preStart = ''
      test -f /var/lib/hledger/hledger.journal || touch /var/lib/hledger/hledger.journal
      '';
      serviceConfig.StateDirectory = "hledger";
    };

    services.nginx = {
      enable = true;

      virtualHosts.${fqdn} = {
        forceSSL = true;
        sslCertificate = "/var/lib/acme/${cfg.domain}/cert.pem";
        sslCertificateKey = "/var/lib/acme/${cfg.domain}/key.pem";

        # Taken from https://github.com/authelia/authelia/issues/178
        locations."/".extraConfig = ''
          add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
          add_header X-Content-Type-Options nosniff;
          add_header X-Frame-Options "SAMEORIGIN";
          add_header X-XSS-Protection "1; mode=block";
          add_header X-Robots-Tag "noindex, nofollow, nosnippet, noarchive";
          add_header X-Download-Options noopen;
          add_header X-Permitted-Cross-Domain-Policies none;

          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_cache_bypass $http_upgrade;

          auth_request /authelia;
          auth_request_set $user $upstream_http_remote_user;
          auth_request_set $groups $upstream_http_remote_groups;
          proxy_set_header X-Forwarded-User $user;
          proxy_set_header X-Forwarded-Groups $groups;
          # TODO: Are those needed?
          # auth_request_set $name $upstream_http_remote_name;
          # auth_request_set $email $upstream_http_remote_email;
          # proxy_set_header Remote-Name $name;
          # proxy_set_header Remote-Email $email;
          # TODO: Would be nice to have this working, I think.
          # set $new_cookie $http_cookie;
          # if ($http_cookie ~ "(.*)(?:^|;)\s*example\.com\.session\.id=[^;]+(.*)") {
          #     set $new_cookie $1$2;
          # }
          # proxy_set_header Cookie $new_cookie;

          auth_request_set $redirect $scheme://$http_host$request_uri;
          error_page 401 =302 ${cfg.oidcEndpoint}?rd=$redirect;
          error_page 403 = ${cfg.oidcEndpoint}/error/403;

          proxy_pass http://${toString config.services.hledger-web.host}:${toString config.services.hledger-web.port};
          '';

        # Virtual endpoint created by nginx to forward auth requests.
        locations."/authelia".extraConfig = ''
          internal;
          proxy_pass ${cfg.oidcEndpoint}/api/verify;

          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Original-URI $request_uri;
          proxy_set_header X-Original-URL $scheme://$host$request_uri;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header Content-Length "";
          proxy_pass_request_body off;
          # TODO: Would be nice to be able to enable this.
          # proxy_ssl_verify on;
          # proxy_ssl_trusted_certificate "/etc/ssl/certs/DST_Root_CA_X3.pem";
          proxy_ssl_protocols TLSv1.2;
          proxy_ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';
          proxy_ssl_verify_depth 2;
          proxy_ssl_server_name on;
        '';

      };
    };

    shb.authelia.rules = [
      # {
      #   domain = fqdn;
      #   policy = "bypass";
      #   resources = [
      #     "^/api.*"
      #   ];
      # }
      {
        domain = fqdn;
        policy = "two_factor";
        subject = ["group:hledger_user"];
      }
    ];

    shb.backup.instances.hledger = {
      sourceDirectories = [
        config.services.hledger-web.stateDir
      ];
    };
  };
}
