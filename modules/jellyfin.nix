{ config, lib, pkgs, ...}:

let
  cfg = config.shb.jellyfin;

  fqdn = "${cfg.subdomain}.${cfg.domain}";
in
{
  options.shb.jellyfin = {
    enable = lib.mkEnableOption "shb jellyfin";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which home-assistant will be served.";
      example = "jellyfin";
    };

    domain = lib.mkOption {
      description = lib.mdDoc "Domain to serve sites under.";
      type = lib.types.str;
      example = "domain.com";
    };
  };

  config = lib.mkIf cfg.enable {
    services.jellyfin.enable = true;

    networking.firewall = {
      # from https://jellyfin.org/docs/general/networking/index.html, for auto-discovery
      allowedUDPPorts = [ 1900 7359 ];
    };

    users.groups = {
      media = {
        name = "media";
        members = [ "jellyfin" ];
      };
      jellyfin = {
        members = [ "backup" ];
      };
    };

    # Take advice from https://jellyfin.org/docs/general/networking/nginx/ and https://nixos.wiki/wiki/Plex
    services.nginx.virtualHosts."${fqdn}" = {
      addSSL = true;
      http2 = true;
      sslCertificate = "/var/lib/acme/${cfg.domain}/cert.pem";
      sslCertificateKey = "/var/lib/acme/${cfg.domain}/key.pem";
      extraConfig = ''
        # The default `client_max_body_size` is 1M, this might not be enough for some posters, etc.
        client_max_body_size 20M;

        # Some players don't reopen a socket and playback stops totally instead of resuming after an extended pause
        send_timeout 100m;

        # use a variable to store the upstream proxy
        # in this example we are using a hostname which is resolved via DNS
        # (if you aren't using DNS remove the resolver line and change the variable to point to an IP address e.g `set $jellyfin 127.0.0.1`)
        set $jellyfin 127.0.0.1;
        # resolver 127.0.0.1 valid=30;

        #include /etc/letsencrypt/options-ssl-nginx.conf;
        #ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
        #add_header Strict-Transport-Security "max-age=31536000" always;
        #ssl_trusted_certificate /etc/letsencrypt/live/DOMAIN_NAME/chain.pem;
        # Why this is important: https://blog.cloudflare.com/ocsp-stapling-how-cloudflare-just-made-ssl-30/
        ssl_stapling on;
        ssl_stapling_verify on;

        # Security / XSS Mitigation Headers
        # NOTE: X-Frame-Options may cause issues with the webOS app
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-XSS-Protection "0"; # Do NOT enable. This is obsolete/dangerous
        add_header X-Content-Type-Options "nosniff";

        # COOP/COEP. Disable if you use external plugins/images/assets
        add_header Cross-Origin-Opener-Policy "same-origin" always;
        add_header Cross-Origin-Embedder-Policy "require-corp" always;
        add_header Cross-Origin-Resource-Policy "same-origin" always;

        # Permissions policy. May cause issues on some clients
        add_header Permissions-Policy "accelerometer=(), ambient-light-sensor=(), battery=(), bluetooth=(), camera=(), clipboard-read=(), display-capture=(), document-domain=(), encrypted-media=(), gamepad=(), geolocation=(), gyroscope=(), hid=(), idle-detection=(), interest-cohort=(), keyboard-map=(), local-fonts=(), magnetometer=(), microphone=(), payment=(), publickey-credentials-get=(), serial=(), sync-xhr=(), usb=(), xr-spatial-tracking=()" always;

        # Tell browsers to use per-origin process isolation
        add_header Origin-Agent-Cluster "?1" always;


        # Content Security Policy
        # See: https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP
        # Enforces https content and restricts JS/CSS to origin
        # External Javascript (such as cast_sender.js for Chromecast) must be whitelisted.
        # NOTE: The default CSP headers may cause issues with the webOS app
        #add_header Content-Security-Policy "default-src https: data: blob: http://image.tmdb.org; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' https://www.gstatic.com/cv/js/sender/v1/cast_sender.js https://www.gstatic.com/eureka/clank/95/cast_sender.js https://www.gstatic.com/eureka/clank/96/cast_sender.js https://www.gstatic.com/eureka/clank/97/cast_sender.js https://www.youtube.com blob:; worker-src 'self' blob:; connect-src 'self'; object-src 'none'; frame-ancestors 'self'";

        # From Plex: Plex has A LOT of javascript, xml and html. This helps a lot, but if it causes playback issues with devices turn it off.
        gzip on;
        gzip_vary on;
        gzip_min_length 1000;
        gzip_proxied any;
        gzip_types text/plain text/css text/xml application/xml text/javascript application/x-javascript image/svg+xml;
        gzip_disable "MSIE [1-6]\.";

        location = / {
            return 302 http://$host/web/;
            #return 302 https://$host/web/;
        }

        location / {
            # Proxy main Jellyfin traffic
            proxy_pass http://$jellyfin:8096;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Protocol $scheme;
            proxy_set_header X-Forwarded-Host $http_host;

            # Disable buffering when the nginx proxy gets very resource heavy upon streaming
            proxy_buffering off;
        }

        # location block for /web - This is purely for aesthetics so /web/#!/ works instead of having to go to /web/index.html/#!/
        location = /web/ {
            # Proxy main Jellyfin traffic
            proxy_pass http://$jellyfin:8096/web/index.html;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Protocol $scheme;
            proxy_set_header X-Forwarded-Host $http_host;
        }

        location /socket {
            # Proxy Jellyfin Websockets traffic
            proxy_pass http://$jellyfin:8096;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Protocol $scheme;
            proxy_set_header X-Forwarded-Host $http_host;
        }
        '';
    };

    shb.backup.instances.jellyfin = {
      sourceDirectories = [
        "/var/lib/jellyfin"
      ];
    };

    services.prometheus.scrapeConfigs = [{
      job_name = "jellyfin";
      static_configs = [
        {
          targets = ["127.0.0.1:8096"];
        }
      ];
    }];

    systemd.services.jellyfin.serviceConfig = {
      # Setup permissions needed for backups, as the backup user is member of the jellyfin group.
      UMask = lib.mkForce "0027";
      StateDirectoryMode = lib.mkForce "0750";
    };
  };
}
