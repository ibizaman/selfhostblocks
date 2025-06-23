{ config, pkgs, lib, ... }:

let
  cfg = config.shb.nginx;

  contracts = pkgs.callPackage ../contracts {};

  fqdn = c: "${c.subdomain}.${c.domain}";

  vhostConfig = lib.types.submodule {
    options = {
      subdomain = lib.mkOption {
        type = lib.types.str;
        description = "Subdomain which must be protected.";
        example = "subdomain";
      };

      domain = lib.mkOption {
        type = lib.types.str;
        description = "Domain of the subdomain.";
        example = "mydomain.com";
      };

      ssl = lib.mkOption {
        description = "Path to SSL files";
        type = lib.types.nullOr contracts.ssl.certs;
        default = null;
      };

      upstream = lib.mkOption {
        type = lib.types.str;
        description = "Upstream url to be protected.";
        example = "http://127.0.0.1:1234";
      };

      authEndpoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = "Optional auth endpoint for SSO.";
        default = null;
        example = "https://authelia.example.com";
      };

      autheliaRules = lib.mkOption {
        type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
        default = [];
        description = "Authelia rule configuration";
        example = lib.literalExpression ''[{
        policy = "two_factor";
        subject = ["group:service_user"];
        }]'';
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra config to add to the root / location. Strings separated by newlines.";
      };
    };
  };
in
{
  options.shb.nginx = {
    accessLog = lib.mkOption {
      type = lib.types.bool;
      description = "Log all requests";
      default = false;
      example = true;
    };

    debugLog = lib.mkOption {
      type = lib.types.bool;
      description = "Verbose debug of internal. This will print what servers were matched and why.";
      default = false;
      example = true;
    };

    vhosts = lib.mkOption {
      description = "Endpoints to be protected by authelia.";
      type = lib.types.listOf vhostConfig;
      default = [];
    };
  };

  config = {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.nginx.enable = true;
    services.nginx.logError = lib.mkIf cfg.debugLog "stderr warn";
    services.nginx.appendHttpConfig = lib.mkIf cfg.accessLog ''
        log_format apm
          '{'
          '"remote_addr":"$remote_addr",'
          '"remote_user":"$remote_user",'
          '"time_local":"$time_local",'
          '"request":"$request",'
          '"request_length":"$request_length",'
          '"server_name":"$server_name",'
          '"status":"$status",'
          '"bytes_sent":"$bytes_sent",'
          '"body_bytes_sent":"$body_bytes_sent",'
          '"referrer":"$http_referrer",'
          '"user_agent":"$http_user_agent",'
          '"gzip_ration":"$gzip_ratio",'
          '"post":"$request_body",'
          '"upstream_addr":"$upstream_addr",'
          '"upstream_status":"$upstream_status",'
          '"request_time":"$request_time",'
          '"upstream_response_time":"$upstream_response_time",'
          '"upstream_connect_time":"$upstream_connect_time",'
          '"upstream_header_time":"$upstream_header_time"'
          '}';

        access_log syslog:server=unix:/dev/log apm;
      '';

    services.nginx.virtualHosts =
      let
        vhostCfg = c: {
          ${fqdn c} = {
            forceSSL = !(isNull c.ssl);
            sslCertificate = lib.mkIf (!(isNull c.ssl)) c.ssl.paths.cert;
            sslCertificateKey = lib.mkIf (!(isNull c.ssl)) c.ssl.paths.key;

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

              proxy_pass ${c.upstream};
            ''
            + c.extraConfig
            + lib.optionalString (c.authEndpoint != null) ''
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
              error_page 401 =302 ${c.authEndpoint}?rd=$redirect;
              error_page 403 = ${c.authEndpoint}/error/403;
            '';

            # Virtual endpoint created by nginx to forward auth requests.
            locations."/authelia".extraConfig = lib.mkIf (!(isNull c.authEndpoint)) ''
              internal;
              proxy_pass ${c.authEndpoint}/api/verify;

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
      in
        lib.mkMerge (map vhostCfg cfg.vhosts);

    shb.authelia.rules =
      let
        authConfig = c: map (r: r // { domain = fqdn c; }) c.autheliaRules;
      in
        lib.flatten (map authConfig cfg.vhosts);

    security.acme.defaults.reloadServices = [
      "nginx.service"
    ];
  };
}
