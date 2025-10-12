{ config, lib, pkgs, ...}:

let
  inherit (lib) types;

  cfg = config.shb.jellyfin;

  contracts = pkgs.callPackage ../contracts {};

  fqdn = "${cfg.subdomain}.${cfg.domain}";

  jellyfin-cli = pkgs.buildDotnetModule rec {
    pname = "jellyfin-cli";
    version = "10.10.7";

    src = pkgs.fetchFromGitHub {
      owner = "ibizaman";
      repo = "jellyfin";
      rev = "0b1a5d929960f852dba90c1fc36f3a19dc094f8d";
      hash = "sha256-H9V65+886EYMn/xDEgmxvoEOrbZaI1wSfmkN9vAzGhw=";
    };

    propagatedBuildInputs = [ pkgs.sqlite ];

    projectFile = "Jellyfin.Cli/Jellyfin.Cli.csproj";
    executables = [ "jellyfin-cli" ];
    nugetDeps = "${pkgs.path}/pkgs/by-name/je/jellyfin/nuget-deps.json";
    runtimeDeps = [
      pkgs.jellyfin-ffmpeg
      pkgs.fontconfig
      pkgs.freetype
    ];
    dotnet-sdk = pkgs.dotnetCorePackages.sdk_8_0;
    dotnet-runtime = pkgs.dotnetCorePackages.aspnetcore_8_0;
    dotnetBuildFlags = [ "--no-self-contained" ];

    passthru.tests = {
      smoke-test = pkgs.nixosTests.jellyfin;
    };

    meta = with pkgs.lib; {
      description = "Free Software Media System";
      homepage = "https://jellyfin.org/";
      # https://github.com/jellyfin/jellyfin/issues/610#issuecomment-537625510
      license = licenses.gpl2Plus;
      maintainers = with maintainers; [
        nyanloutre
        minijackson
        purcell
        jojosch
      ];
      mainProgram = "jellyfin-cli";
      platforms = dotnet-runtime.meta.platforms;
    };
  };
in
{
  options.shb.jellyfin = {
    enable = lib.mkEnableOption "shb jellyfin";

    subdomain = lib.mkOption {
      type = types.str;
      description = "Subdomain under which home-assistant will be served.";
      example = "jellyfin";
    };

    domain = lib.mkOption {
      description = "Domain to serve sites under.";
      type = types.str;
      example = "domain.com";
    };

    port = lib.mkOption {
      description = "Listen on port.";
      type = types.port;
      default = 8096;
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = types.nullOr contracts.ssl.certs;
      default = null;
    };

    debug = lib.mkOption {
      description = "Enable debug logging";
      type = types.bool;
      default = false;
    };

    admin = lib.mkOption {
      description = "Default admin user info. Only needed if LDAP or SSO is not configured.";
      default = null;
      type = types.nullOr (types.submodule {
        options = {
          username = lib.mkOption {
            description = "Username of the default admin user.";
            type = types.str;
            default = "jellyfin";
          };
          password = lib.mkOption {
            description = "Password of the default admin user.";
            type = types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0440";
                owner = "jellyfin";
                group = "jellyfin";
                restartUnits = [ "jellyfin.service" ];
              };
            };
          };
        };
      });
    };

    ldap = lib.mkOption {
      description = "LDAP configuration.";
      default = {};
      type = types.submodule {
        options = {
          enable = lib.mkEnableOption "LDAP";

          host = lib.mkOption {
            type = types.str;
            description = "Host serving the LDAP server.";
            example = "127.0.0.1";
          };

          port = lib.mkOption {
            type = types.int;
            description = "Port where the LDAP server is listening.";
            example = 389;
          };

          dcdomain = lib.mkOption {
            type = types.str;
            description = "DC domain for LDAP.";
            example = "dc=mydomain,dc=com";
          };

          userGroup = lib.mkOption {
            type = types.str;
            description = "LDAP user group";
            default = "jellyfin_user";
          };

          adminGroup = lib.mkOption {
            type = types.str;
            description = "LDAP admin group";
            default = "jellyfin_admin";
          };

          adminPassword = lib.mkOption {
            description = "LDAP admin password.";
            type = types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0440";
                owner = "jellyfin";
                group = "jellyfin";
                restartUnits = [ "jellyfin.service" ];
              };
            };
          };
        };
      };
    };

    sso = lib.mkOption {
      description = "SSO configuration.";
      default = {};
      type = types.submodule {
        options = {
          enable = lib.mkEnableOption "SSO";

          provider = lib.mkOption {
            type = types.str;
            description = "OIDC provider name";
            default = "Authelia";
          };

          endpoint = lib.mkOption {
            type = types.str;
            description = "OIDC endpoint for SSO";
            example = "https://authelia.example.com";
          };

          clientID = lib.mkOption {
            type = types.str;
            description = "Client ID for the OIDC endpoint";
            default = "jellyfin";
          };

          adminUserGroup = lib.mkOption {
            type = types.str;
            description = "OIDC admin group";
            default = "jellyfin_admin";
          };

          userGroup = lib.mkOption {
            type = types.str;
            description = "OIDC user group";
            default = "jellyfin_user";
          };

          authorization_policy = lib.mkOption {
            type = types.enum [ "one_factor" "two_factor" ];
            description = "Require one factor (password) or two factor (device) authentication.";
            default = "one_factor";
          };

          sharedSecret = lib.mkOption {
            description = "OIDC shared secret for Jellyfin.";
            type = types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0440";
                owner = "jellyfin";
                group = "jellyfin";
                restartUnits = [ "jellyfin.service" ];
              };
            };
          };

          sharedSecretForAuthelia = lib.mkOption {
            description = "OIDC shared secret for Authelia.";
            type = types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0400";
                ownerText = "config.shb.authelia.autheliaUser";
                owner = config.shb.authelia.autheliaUser;
              };
            };
          };
        };
      };
    };

    backup = lib.mkOption {
      description = ''
        Backup configuration.
      '';
      default = {};
      type = types.submodule {
        options = contracts.backup.mkRequester {
          user = "jellyfin";
          sourceDirectories = [
            config.services.jellyfin.dataDir
          ];
          sourceDirectoriesText = ''[
            "services.jellyfin.dataDir"
          ]'';
        };
      };
    };
  };

  imports = [
    (lib.mkRenamedOptionModule [ "shb" "jellyfin" "adminPassword" ] [ "shb" "jellyfin" "admin" "password" ])
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (!cfg.ldap.enable && !cfg.sso.enable) -> cfg.admin != null;
        message = "Jellyfin admin user must be configured with shb.jellyfin.admin if LDAP or SSO integration are not configured.";
      }
    ];

    services.jellyfin.enable = true;

    networking.firewall = {
      # from https://jellyfin.org/docs/general/networking/index.html, for auto-discovery
      allowedUDPPorts = [ 1900 7359 ];
    };

    services.nginx.enable = true;

    # Take advice from https://jellyfin.org/docs/general/networking/nginx/ and https://nixos.wiki/wiki/Plex
    services.nginx.virtualHosts."${fqdn}" = {
      forceSSL = !(isNull cfg.ssl);
      sslCertificate = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.cert;
      sslCertificateKey = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.key;

      http2 = true;

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
            proxy_pass http://$jellyfin:${toString cfg.port};
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
            proxy_pass http://$jellyfin:${toString cfg.port}/web/index.html;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Protocol $scheme;
            proxy_set_header X-Forwarded-Host $http_host;
        }

        location /socket {
            # Proxy Jellyfin Websockets traffic
            proxy_pass http://$jellyfin:${toString cfg.port};
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

    services.prometheus.scrapeConfigs = [{
      job_name = "jellyfin";
      static_configs = [
        {
          targets = ["127.0.0.1:${toString cfg.port}"];
          labels = {
            "hostname" = config.networking.hostName;
            "domain" = cfg.domain;
          };
        }
      ];
    }];

    # LDAP config but you need to install the plugin by hand

    systemd.services.jellyfin.preStart =
      let
        ldapConfig = pkgs.writeText "LDAP-Auth.xml" ''
          <?xml version="1.0" encoding="utf-8"?>
          <PluginConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
            <LdapServer>${cfg.ldap.host}</LdapServer>
            <LdapPort>${builtins.toString cfg.ldap.port}</LdapPort>
            <UseSsl>false</UseSsl>
            <UseStartTls>false</UseStartTls>
            <SkipSslVerify>false</SkipSslVerify>
            <LdapBindUser>uid=admin,ou=people,${cfg.ldap.dcdomain}</LdapBindUser>
            <LdapBindPassword>%SECRET_LDAP_PASSWORD%</LdapBindPassword>
            <LdapBaseDn>ou=people,${cfg.ldap.dcdomain}</LdapBaseDn>
            <LdapSearchFilter>(memberof=cn=${cfg.ldap.userGroup},ou=groups,${cfg.ldap.dcdomain})</LdapSearchFilter>
            <LdapAdminBaseDn>ou=people,${cfg.ldap.dcdomain}</LdapAdminBaseDn>
            <LdapAdminFilter>(memberof=cn=${cfg.ldap.adminGroup},ou=groups,${cfg.ldap.dcdomain})</LdapAdminFilter>
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

        # SchemeOverride is needed because of
        # https://github.com/9p4/jellyfin-plugin-sso/issues/264
        ssoConfig = pkgs.writeText "SSO-Auth.xml" ''
          <?xml version="1.0" encoding="utf-8"?>
          <PluginConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
            <SamlConfigs />
            <OidConfigs>
              <item>
                <key>
                  <string>${cfg.sso.provider}</string>
                </key>
                <value>
                  <PluginConfiguration>
                    <SchemeOverride>https</SchemeOverride>
                    <OidEndpoint>${cfg.sso.endpoint}</OidEndpoint>
                    <OidClientId>${cfg.sso.clientID}</OidClientId>
                    <OidSecret>%SECRET_SSO_SECRET%</OidSecret>
                    <Enabled>true</Enabled>
                    <EnableAuthorization>true</EnableAuthorization>
                    <EnableAllFolders>true</EnableAllFolders>
                    <EnabledFolders />
                    <AdminRoles>
                      <string>${cfg.sso.adminUserGroup}</string>
                    </AdminRoles>
                    <Roles>
                      <string>${cfg.sso.userGroup}</string>
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
            <LoginDisclaimer>&lt;a href="https://${cfg.subdomain}.${cfg.domain}/SSO/OID/p/${cfg.sso.provider}" class="raised cancel block emby-button authentik-sso"&gt;
                Sign in with ${cfg.sso.provider}&amp;nbsp;
                &lt;img alt="OpenID Connect (authentik)" title="OpenID Connect (authentik)" class="oauth-login-image" src="https://raw.githubusercontent.com/goauthentik/authentik/master/web/icons/icon.png"&gt;
              &lt;/a&gt;
              &lt;a href="https://${cfg.subdomain}.${cfg.domain}/SSOViews/linking" class="raised cancel block emby-button authentik-sso"&gt;
                Link ${cfg.sso.provider} config&amp;nbsp;
              &lt;/a&gt;
              &lt;a href="${cfg.sso.endpoint}" class="raised cancel block emby-button authentik-sso"&gt;
                ${cfg.sso.provider} config&amp;nbsp;
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

        debugLogging = pkgs.writeText "debugLogging.json" ''
          {
            "Serilog": {
              "MinimumLevel": {
                "Default": "Debug",
                "Override": {
                  "": "Debug"
                }
              }
            }
          }
        '';

        networkConfig = pkgs.writeText "" ''
          <?xml version="1.0" encoding="utf-8"?>
          <NetworkConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
            <BaseUrl />
            <EnableHttps>false</EnableHttps>
            <RequireHttps>false</RequireHttps>
            <CertificatePath />
            <CertificatePassword />
            <InternalHttpPort>${toString cfg.port}</InternalHttpPort>
            <InternalHttpsPort>8920</InternalHttpsPort>
            <PublicHttpPort>${toString cfg.port}</PublicHttpPort>
            <PublicHttpsPort>8920</PublicHttpsPort>
            <AutoDiscovery>true</AutoDiscovery>
            <EnableUPnP>false</EnableUPnP>
            <EnableIPv4>true</EnableIPv4>
            <EnableIPv6>false</EnableIPv6>
            <EnableRemoteAccess>false</EnableRemoteAccess>
            <LocalNetworkSubnets />
            <LocalNetworkAddresses />
            <KnownProxies />
            <IgnoreVirtualInterfaces>true</IgnoreVirtualInterfaces>
            <VirtualInterfaceNames>
              <string>veth</string>
            </VirtualInterfaceNames>
            <EnablePublishedServerUriByRequest>false</EnablePublishedServerUriByRequest>
            <PublishedServerUriBySubnet />
            <RemoteIPFilter />
            <IsRemoteIPFilterBlacklist>false</IsRemoteIPFilterBlacklist>
          </NetworkConfiguration>
        '';
      in
        lib.strings.optionalString cfg.debug
          ''
          if [ -f "${config.services.jellyfin.configDir}/logging.json" ] && [ ! -L "${config.services.jellyfin.configDir}/logging.json" ]; then
            echo "A ${config.services.jellyfin.configDir}/logging.json file exists already, this indicates probably an existing installation. Please remove it before continuing."
            exit 1
          fi
          ln -fs "${debugLogging}" "${config.services.jellyfin.configDir}/logging.json"
          ''
        + (lib.shb.replaceSecretsScript {
          file = networkConfig;
          # Write permissions are needed otherwise the jellyfin-cli tool will not work correctly.
          permissions = "u=rw,g=rw,o=";
          resultPath = "${config.services.jellyfin.dataDir}/config/network.xml";
          replacements = [
          ];
        })
        + lib.strings.optionalString cfg.ldap.enable (lib.shb.replaceSecretsScript {
          file = ldapConfig;
          resultPath = "${config.services.jellyfin.dataDir}/plugins/configurations/LDAP-Auth.xml";
          replacements = [
            {
              name = [ "LDAP_PASSWORD" ];
              source = cfg.ldap.adminPassword.result.path;
            }
          ];
        })
        + lib.strings.optionalString cfg.sso.enable (lib.shb.replaceSecretsScript {
          file = ssoConfig;
          resultPath = "${config.services.jellyfin.dataDir}/plugins/configurations/SSO-Auth.xml";
          replacements = [
            {
              name = [ "SSO_SECRET" ];
              source = cfg.sso.sharedSecret.result.path;
            }
          ];
        })
        + lib.strings.optionalString cfg.sso.enable (lib.shb.replaceSecretsScript {
          file = brandingConfig;
          resultPath = "${config.services.jellyfin.dataDir}/config/branding.xml";
          replacements = [
          ];
        });

    systemd.services.jellyfin.serviceConfig.ExecStartPost = let
      # We must always wait for the service to be fully initialized,
      # even if we're planning on changing the config and restarting.
      waitForCurl = pkgs.writeShellApplication {
        name = "waitForCurl";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          URL="http://127.0.0.1:${toString cfg.port}/System/Info/Public"
          SLEEP_INTERVAL_SEC=2
          TIMEOUT=60

          start_time=$(date +%s)

          echo "Waiting for $URL to return HTTP 200..."

          while true; do
              status_code=$(curl -s -o /dev/null -w "%{http_code}" "$URL" || true)
              if [ "$status_code" = "200" ]; then
                  echo "Service is up (HTTP 200 received)."
                  exit 0
              fi

              now=$(date +%s)
              elapsed=$(( now - start_time ))

              if [ $elapsed -ge $TIMEOUT ]; then
                  echo "Timeout reached ($TIMEOUT seconds). Exiting with failure."
                  exit 1
              fi

              echo "Waiting for service... (status: $status_code), elapsed: ''${elapsed}s"
              sleep "$SLEEP_INTERVAL_SEC"
          done

          echo "Finished waiting, curl returned a 200."
        '';
      };

      # This file is used to know if the jellyfin service has been restarted
      # because a new config just got written to.
      #
      # If the file does not exist, write the config, create the file then restart.
      # If the file exists, do nothing and remove the file, resetting the state for the next time.
      restartedFile="${config.services.jellyfin.dataDir}/.jellyfin-restarted";

      writeConfig = pkgs.writeShellApplication {
        name = "writeConfig";
        runtimeInputs = [ pkgs.systemd ];
        text = ''
          if ! [ -f "${restartedFile}" ]; then
            ${lib.getExe jellyfin-cli} wizard \
              --datadir='${config.services.jellyfin.dataDir}' \
              --configdir='${config.services.jellyfin.configDir}' \
              --cachedir='${config.services.jellyfin.cacheDir}' \
              --logdir='${config.services.jellyfin.logDir}' \
              --username=${cfg.admin.username} \
              --password-file=${cfg.admin.password.result.path} \
              --enable-remote-access=true \
              --write
          fi
        '';
      };

      restartJellyfinOnce = pkgs.writeShellApplication {
        name = "restartJellyfin";
        runtimeInputs = [ pkgs.systemd ];
        text = ''
          if [ -f "${restartedFile}" ]; then
            echo "jellyfin.service has been restarted"
            rm "${restartedFile}"
          else
            echo "Restarting jellyfin.service"
            touch "${restartedFile}"
            systemctl reload-or-restart jellyfin.service
          fi
        '';
      };
    in
      lib.optionals (cfg.admin != null) [
        (lib.getExe waitForCurl)

        (lib.getExe writeConfig)

        # The '+' is to get elevated privileges to be able to restart the service.
        "+${lib.getExe restartJellyfinOnce}"
      ];

    systemd.services.jellyfin.serviceConfig.TimeoutStartSec = 300;

    shb.authelia.oidcClients = lib.lists.optionals (!(isNull cfg.sso)) [
      {
        client_id = cfg.sso.clientID;
        client_name = "Jellyfin";
        client_secret.source = cfg.sso.sharedSecretForAuthelia.result.path;
        public = false;
        authorization_policy = cfg.sso.authorization_policy;
        redirect_uris = [
          "https://${cfg.subdomain}.${cfg.domain}/sso/OID/r/${cfg.sso.provider}"
          "https://${cfg.subdomain}.${cfg.domain}/sso/OID/redirect/${cfg.sso.provider}"
        ];
        require_pkce = true;
        pkce_challenge_method = "S256";
        userinfo_signed_response_alg = "none";
        token_endpoint_auth_method = "client_secret_post";
      }
    ];
  };
}
