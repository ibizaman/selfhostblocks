{ config, pkgs, lib, ... }:

let
  cfg = config.shb.deluge;

  fqdn = "${cfg.subdomain}.${cfg.domain}";
in
{
  options.shb.deluge = {
    enable = lib.mkEnableOption "selfhostblocks.deluge";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which deluge will be served.";
      example = "ha";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which deluge will be served.";
      example = "mydomain.com";
    };

    daemonPort = lib.mkOption {
      type = lib.types.int;
      description = "Deluge daemon port";
      default = 58846;
    };

    daemonListenPorts = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      description = "Deluge daemon listen ports";
      default = [ 6881 6889 ];
    };

    webPort = lib.mkOption {
      type = lib.types.int;
      description = "Deluge web port";
      default = 8112;
    };

    proxyPort = lib.mkOption {
      description = lib.mdDoc "If not null, sets up a deluge to forward all traffic to the Proxy listening at that port.";
      type = lib.types.nullOr lib.types.int;
      default = null;
    };

    downloadLocation = lib.mkOption {
      type = lib.types.str;
      description = "Folder where torrents gets downloaded";
      example = "/srv/torrents";
    };

    oidcEndpoint = lib.mkOption {
      type = lib.types.str;
      description = "OIDC endpoint for SSO";
      example = "https://authelia.example.com";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Sops file location.";
      example = "secrets/torrent.yaml";
    };

    additionalPlugins = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      description = "Location of additional plugins.";
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    services.deluge = {
      enable = true;
      declarative = true;
      openFirewall = true;
      config = {
        download_location = cfg.downloadLocation;
        max_upload_speed = -1.0;
        allow_remote = true;
        daemon_port = cfg.daemonPort;
        listen_ports = cfg.daemonListenPorts;
        proxy = lib.optionalAttrs (cfg.proxyPort != null) {
          force_proxy = true;
          hostname = "127.0.0.1";
          port = cfg.proxyPort;
          proxy_hostnames = true;
          proxy_peer_connections = true;
          proxy_tracker_connections = true;
          type = 4; # HTTP
        };
      };
      authFile = "/run/secrets/deluge/auth";

      web.enable = true;
      web.port = cfg.webPort;
    };

    
    systemd.tmpfiles.rules = lib.attrsets.mapAttrsToList (name: path:
      "L+ ${config.services.deluge.dataDir}/.config/deluge/plugins/${name} - - - - ${path}"
    ) cfg.additionalPlugins;

    sops.secrets."deluge/auth" = {
      inherit (cfg) sopsFile;
      mode = "0440";
      owner = config.services.deluge.user;
      group = config.services.deluge.group;
      restartUnits = [ "deluged.service" "delugeweb.service" ];
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

          proxy_pass http://127.0.0.1:${toString config.services.deluge.web.port};
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
      {
        domain = fqdn;
        policy = "two_factor";
        subject = ["group:deluge_user"];
      }
    ];

    users.groups.deluge = {
      members = [ "backup" ];
    };

    shb.backup.instances.deluge = {
      sourceDirectories = [
        config.services.deluge.dataDir
      ];
    };
  };
}
