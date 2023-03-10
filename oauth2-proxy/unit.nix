{ stdenv
, pkgs
, utils
}:
{ name
, serviceName
, domain
, keycloakSubdomain ? "keycloak"
, keycloakDomain ? domain
, realm
, allowed_roles ? []
, skip_auth_routes ? []
, api_routes ? []

, ingress
, egress
, metricsPort
, keys

, distribution
, KeycloakService
, KeycloakCliService
, HaproxyService

, debug ? true
}:

with builtins;
with pkgs.lib.lists;
with pkgs.lib.strings;
rec {
  inherit name;
  
  pkg =
    { KeycloakService
    , KeycloakCliService
    , HaproxyService
    }:
    let
      config = pkgs.writeText "${serviceName}.cfg" (''
        provider = "keycloak-oidc"
        provider_display_name="Keycloak"
        http_address = "${ingress}"
        upstreams = [ "${concatStringsSep " " egress}" ]
        metrics_address = "127.0.0.1:${toString metricsPort}"
        
        client_id = "${serviceName}"
        scope="openid"
        
        redirect_url = "https://${serviceName}.${domain}/oauth2/callback"
        oidc_issuer_url = "https://${keycloakSubdomain}.${keycloakDomain}/realms/${realm}"
        
        email_domains = [ "*" ]
        allowed_roles = ${builtins.toJSON allowed_roles}
        skip_auth_routes = ${builtins.toJSON skip_auth_routes}
        api_routes = ${builtins.toJSON api_routes}
        
        reverse_proxy = "true"
        # trusted_ips = "@"
        
        skip_provider_button = "true"

        # pass_authorization_header = true
        # pass_access_token = true
        # pass_user_headers = true
        # set_authorization_header = true
        # set_xauthrequest = true
        '' + (if !debug then "" else ''
        auth_logging = "true"
        request_logging = "true"
        ''));

      exec = pkgs.writeShellApplication {
        name = "oauth2proxy-wrapper";
        runtimeInputs = with pkgs; [curl coreutils];
        text = ''
        while ! curl --silent ${KeycloakService.hostname}:${builtins.toString KeycloakService.listenPort} > /dev/null; do
          echo "Waiting for port ${builtins.toString KeycloakService.listenPort} to open..."
          sleep 10
        done
        sleep 2
        '';
      };

      oauth2-proxy = 
        let
          version = "f93166229fe9b57f7d54fb0a9c42939f3f30340f";
          src = pkgs.fetchFromGitHub {
            owner = "ibizaman";
            repo = "oauth2-proxy";
            rev = version;
            sha256 = "sha256-RI34N+YmUqAanuJOGUA+rUTS1TpUoy8rw6EFGeLh5L0=";
            # sha256 = pkgs.lib.fakeSha256;
          };
        in
          (pkgs.callPackage "${pkgs.path}/pkgs/tools/backup/kopia" {
            buildGoModule = args: pkgs.buildGo118Module (args // {
              vendorSha256 = "sha256-2WUd2RxeOal0lpp/TuGSyfP1ppvG/Vd3bgsSsNO8ejo=";
              inherit src version;
            });
          });

      oauth2proxyBin = "${oauth2-proxy}/bin/oauth2-proxy";
    in utils.systemd.mkService rec {
      name = "oauth2proxy-${serviceName}";

      content = ''
      [Unit]
      Description=Oauth2 proxy for ${serviceName}
      After=${KeycloakService.systemdUnitFile}
      Wants=${KeycloakService.systemdUnitFile}
      After=${utils.keyServiceDependencies keys}
      Wants=${utils.keyServiceDependencies keys}

      [Service]
      ExecStartPre=${exec}/bin/oauth2proxy-wrapper
      TimeoutStartSec=8m
      ExecStart=${oauth2proxyBin} --config ${config}
      DynamicUser=true
      RuntimeDirectory=oauth2proxy-${serviceName}
      ${utils.keyEnvironmentFiles keys}

      CapabilityBoundingSet=
      AmbientCapabilities=
      PrivateUsers=yes
      NoNewPrivileges=yes
      ProtectSystem=strict
      ProtectHome=yes
      PrivateTmp=yes
      PrivateDevices=yes
      ProtectHostname=yes
      ProtectClock=yes
      ProtectKernelTunables=yes
      ProtectKernelModules=yes
      ProtectKernelLogs=yes
      ProtectControlGroups=yes
      RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
      RestrictNamespaces=yes
      LockPersonality=yes
      MemoryDenyWriteExecute=yes
      RestrictRealtime=yes
      RestrictSUIDSGID=yes
      RemoveIPC=yes
      
      SystemCallFilter=@system-service
      SystemCallFilter=~@privileged @resources
      SystemCallArchitectures=native

      [Install]
      WantedBy=multi-user.target
      '';
    };

  dependsOn = {
    inherit HaproxyService KeycloakService KeycloakCliService;
  };
  type = "systemd-unit";
}
