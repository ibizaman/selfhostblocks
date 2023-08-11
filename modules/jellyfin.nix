{ config, lib, pkgs, ...}:

let
  cfg = config.shb.jellyfin;

  fqdn = "${cfg.subdomain}.${cfg.domain}";

  template = file: newPath: replacements:
    let
      templatePath = newPath + ".template";

      sedPatterns = lib.strings.concatStringsSep " " (lib.attrsets.mapAttrsToList (from: to: "\"s|${from}|${to}|\"") replacements);
    in
      ''
      ln -fs ${file} ${templatePath}
      rm ${newPath} || :
      sed ${sedPatterns} ${templatePath} > ${newPath}
      '';
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

    ldapHost = lib.mkOption {
      type = lib.types.str;
      description = "host serving the LDAP server";
      example = "127.0.0.1";
    };

    ldapPort = lib.mkOption {
      type = lib.types.int;
      description = "port where the LDAP server is listening";
      example = 389;
    };

    dcdomain = lib.mkOption {
      type = lib.types.str;
      description = "dc domain for ldap";
      example = "dc=mydomain,dc=com";
    };

    oidcProvider = lib.mkOption {
      type = lib.types.str;
      description = "OIDC provider name";
      default = "Authelia";
    };

    oidcEndpoint = lib.mkOption {
      type = lib.types.str;
      description = "OIDC endpoint for SSO";
      example = "https://authelia.example.com";
    };

    oidcClientID = lib.mkOption {
      type = lib.types.str;
      description = "Client ID for the OIDC endpoint";
      default = "jellyfin";
    };

    oidcAdminUserGroup = lib.mkOption {
      type = lib.types.str;
      description = "OIDC admin group";
      default = "jellyfin_admin";
    };

    oidcUserGroup = lib.mkOption {
      type = lib.types.str;
      description = "OIDC user group";
      default = "jellyfin_user";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Sops file location";
      example = "secrets/jellyfin.yaml";
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
      forceSSL = true;
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

    sops.secrets."jellyfin/ldap_password" = {
      inherit (cfg) sopsFile;
      mode = "0440";
      owner = "jellyfin";
      group = "jellyfin";
      restartUnits = [ "jellyfin.service" ];
    };
    sops.secrets."jellyfin/sso_secret" = {
      inherit (cfg) sopsFile;
      mode = "0440";
      owner = "jellyfin";
      group = "jellyfin";
      restartUnits = [ "jellyfin.service" ];
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

    # LDAP config but you need to install the plugin by hand

    systemd.services.jellyfin.preStart =
      let
        ldapConfig = pkgs.writeText "LDAP-Auth.xml" ''
          <?xml version="1.0" encoding="utf-8"?>
          <PluginConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
            <LdapServer>${cfg.ldapHost}</LdapServer>
            <LdapPort>${builtins.toString cfg.ldapPort}</LdapPort>
            <UseSsl>false</UseSsl>
            <UseStartTls>false</UseStartTls>
            <SkipSslVerify>false</SkipSslVerify>
            <LdapBindUser>uid=admin,ou=people,${cfg.dcdomain}</LdapBindUser>
            <LdapBindPassword>%LDAP_PASSWORD%</LdapBindPassword>
            <LdapBaseDn>ou=people,${cfg.dcdomain}</LdapBaseDn>
            <LdapSearchFilter>(memberof=cn=jellyfin_user,ou=groups,${cfg.dcdomain})</LdapSearchFilter>
            <LdapAdminBaseDn>ou=people,${cfg.dcdomain}</LdapAdminBaseDn>
            <LdapAdminFilter>(memberof=cn=jellyfin_admin,ou=groups,${cfg.dcdomain})</LdapAdminFilter>
            <EnableLdapAdminFilterMemberUid>false</EnableLdapAdminFilterMemberUid>
            <LdapSearchAttributes>uid, cn, mail, displayName</LdapSearchAttributes>
            <LdapClientCertPath />
            <LdapClientKeyPath />
            <LdapRootCaPath />
            <CreateUsersFromLdap>true</CreateUsersFromLdap>
            <AllowPassChange>false</AllowPassChange>
            <LdapUsernameAttribute>uid</LdapUsernameAttribute>
            <LdapPasswordAttribute>userPassword</LdapPasswordAttribute>
            <EnableAllFolders>true</EnableAllFolders>
            <EnabledFolders />
            <PasswordResetUrl />
          </PluginConfiguration>
          '';

        ssoConfig = pkgs.writeText "SSO-Auth.xml" ''
          <?xml version="1.0" encoding="utf-8"?>
          <PluginConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
            <SamlConfigs />
            <OidConfigs>
              <item>
                <key>
                  <string>${cfg.oidcProvider}</string>
                </key>
                <value>
                  <PluginConfiguration>
                    <OidEndpoint>${cfg.oidcEndpoint}</OidEndpoint>
                    <OidClientId>${cfg.oidcClientID}</OidClientId>
                    <OidSecret>%SSO_SECRET%</OidSecret>
                    <Enabled>true</Enabled>
                    <EnableAuthorization>true</EnableAuthorization>
                    <EnableAllFolders>true</EnableAllFolders>
                    <EnabledFolders />
                    <AdminRoles>
                      <string>${cfg.oidcAdminUserGroup}</string>
                    </AdminRoles>
                    <Roles>
                      <string>${cfg.oidcUserGroup}</string>
                    </Roles>
                    <EnableFolderRoles>false</EnableFolderRoles>
                    <FolderRoleMappings />
                    <RoleClaim>groups</RoleClaim>
                    <OidScopes>
                      <string>groups</string>
                    </OidScopes>
                    <CanonicalLinks />
                  </PluginConfiguration>
                </value>
              </item>
            </OidConfigs>
          </PluginConfiguration>
        '';

        brandingConfig = pkgs.writeText "branding.xml" ''
          <?xml version="1.0" encoding="utf-8"?>
          <BrandingOptions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
            <LoginDisclaimer>&lt;a href="https://${cfg.subdomain}.${cfg.domain}/SSO/OID/p/${cfg.oidcProvider}" class="raised cancel block emby-button authentik-sso"&gt;
                Sign in with ${cfg.oidcProvider}&amp;nbsp;
                &lt;img alt="OpenID Connect (authentik)" title="OpenID Connect (authentik)" class="oauth-login-image" src="https://raw.githubusercontent.com/goauthentik/authentik/master/web/icons/icon.png"&gt;
              &lt;/a&gt;
              &lt;a href="https://${cfg.subdomain}.${cfg.domain}/SSOViews/linking" class="raised cancel block emby-button authentik-sso"&gt;
                Link ${cfg.oidcProvider} config&amp;nbsp;
              &lt;/a&gt;
              &lt;a href="${cfg.oidcEndpoint}" class="raised cancel block emby-button authentik-sso"&gt;
                ${cfg.oidcProvider} config&amp;nbsp;
              &lt;/a&gt;
            </LoginDisclaimer>
            <CustomCss>
              /* Hide this in lieu of authentik link */
              .emby-button.block.btnForgotPassword {
                 display: none;
              }

              /* Make links look like buttons */
              a.raised.emby-button {
                 padding: 0.9em 1em;
                 color: inherit !important;
              }

              /* Let disclaimer take full width */
              .disclaimerContainer {
                 display: block;
              }

              /* Optionally, apply some styling to the `.authentik-sso` class, probably let users configure this */
              .authentik-sso {
                 /* idk set a background image or something lol */
              }

              .oauth-login-image {
                  height: 24px;
                  position: absolute;
                  top: 12px;
              }
            </CustomCss>
            <SplashscreenEnabled>true</SplashscreenEnabled>
          </BrandingOptions>
        '';
      in
        template ldapConfig "/var/lib/jellyfin/plugins/configurations/LDAP-Auth.xml" {
          "%LDAP_PASSWORD%" = "$(cat /run/secrets/jellyfin/ldap_password)";
        }
        + template ssoConfig "/var/lib/jellyfin/plugins/configurations/SSO-Auth.xml" {
          "%SSO_SECRET%" = "$(cat /run/secrets/jellyfin/sso_secret)";
        }
        + template brandingConfig "/var/lib/jellyfin/config/branding.xml" {"%a%" = "%a%";};

    shb.authelia.oidcClients = [
      {
        id = cfg.oidcClientID;
        description = "Jellyfin";
        secret = "jbmVCAZluESWbOvbKQtHhjwcuaNjlMVaidMbJGKaHXHPOmwilCWYBFAQtrnohJzIhbuhWTBwhbDKLmdtyrLXeankWgXNspWCmJxzayHiHRvOPDbcsnquYReI";
        public = "false";
        authorization_policy = "one_factor";
        redirect_uris = [ "https://${cfg.subdomain}.${cfg.domain}/sso/OID/r/${cfg.oidcProvider}" ];
      }
    ];

    # For backup

    systemd.services.jellyfin.serviceConfig = {
      # Setup permissions needed for backups, as the backup user is member of the jellyfin group.
      UMask = lib.mkForce "0027";
      StateDirectoryMode = lib.mkForce "0750";
    };
  };
}
