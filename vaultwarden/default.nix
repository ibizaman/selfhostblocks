{ customPkgs
, pkgs
, utils
}:
{ serviceName ? "Vaultwarden"
, subdomain ? "vaultwarden"
, ingress ? 18005
, signupsAllowed ? true  # signups allowed since we're behind SSO
, signupsVerify ? false

, user ? "vaultwarden"
, group ? "vaultwarden"
, dataFolder ? "/var/lib/vaultwarden"
, postgresDatabase ? "vaultwarden"
, postgresUser ? "vaultwarden"
, postgresPasswordLocation ? "vaultwarden"
, webvaultEnabled ? true
, webvaultPath ? "/usr/share/webapps/vaultwarden"

, cookieSecretName ? "cookiesecret"
, clientSecretName ? "clientsecret"

, smtp ? {}
, sso ? {}

, distribution ? {}
, KeycloakService ? null
, KeycloakCliService ? null
, HaproxyService ? null
}:
let
  mkVaultwardenWeb = pkgs.callPackage ./web.nix {inherit utils;};

  ssoIngress = if sso != {} then ingress else null;
  serviceIngress = if sso != {} then ingress+1 else ingress;
  metricsPort = if sso != {} then ingress+2 else ingress+1;

  smtpConfig = smtp;
in
rec {
  inherit user group;
  inherit subdomain;

  db = customPkgs.mkPostgresDB {
    name = "${serviceName}PostgresDB";

    database = postgresDatabase;
    username = postgresUser;
    # TODO: use passwordFile
    password = postgresPasswordLocation;
  };

  web = mkVaultwardenWeb {
    name = "${serviceName}Web";

    path = webvaultPath;
  };

  service = let
    name = "${serviceName}Service";
    domain = utils.getDomain distribution name;

    pkgsVaultwarden-1_27_0 =
      let pkg = builtins.fetchurl {
            url = "https://raw.githubusercontent.com/NixOS/nixpkgs/988cc958c57ce4350ec248d2d53087777f9e1949/pkgs/tools/security/vaultwarden/default.nix";
            sha256 = "0hwjbq5qb8y5frb2ca3m501x84zaibzyn088zzaf7zcwkxvqb0im";
          };
      in pkgs.callPackage pkg {
        inherit (pkgs.darwin.apple_sdk.frameworks) Security CoreServices;
        dbBackend = "postgresql";
      };
  in {
    inherit name;

    pkg =
      { db
      , web
      }: let
        postgresHost = db.target.properties.hostname;
      in utils.systemd.mkService rec {
        name = "vaultwarden";

        content = ''
          [Unit]
          Description=Vaultwarden Server
          Documentation=https://github.com/dani-garcia/vaultwarden
          After=network.target
          After=${utils.keyServiceDependencies smtpConfig.keys}
          Wants=${utils.keyServiceDependencies smtpConfig.keys}

          [Service]
          Environment=DATA_FOLDER=${dataFolder}
          Environment=DATABASE_URL=postgresql://${postgresUser}:${postgresPasswordLocation}@${postgresHost}/${postgresDatabase}
          Environment=IP_HEADER=X-Real-IP

          Environment=WEB_VAULT_FOLDER=${web.path}
          Environment=WEB_VAULT_ENABLED=${if webvaultEnabled then "true" else "false"}

          Environment=SIGNUPS_ALLOWED=${if signupsAllowed then "true" else "false"}
          Environment=SIGNUPS_VERIFY=${if signupsVerify then "true" else "false"}
          # Disabled because the /admin path is protected by SSO
          Environment=DISABLE_ADMIN_TOKEN=true
          Environment=INVITATIONS_ALLOWED=true
          Environment=DOMAIN=https://${subdomain}.${domain}

          # Assumes we're behind a reverse proxy
          Environment=ROCKET_ADDRESS=127.0.0.1
          Environment=ROCKET_PORT=${builtins.toString serviceIngress}
          Environment=USE_SYSLOG=true
          Environment=EXTENDED_LOGGING=true
          Environment=LOG_FILE=
          Environment=LOG_LEVEL=trace

          ${utils.keyEnvironmentFiles smtpConfig.keys}
          Environment=SMTP_FROM=${smtpConfig.from}
          Environment=SMTP_FROM_NAME=${smtpConfig.fromName}
          Environment=SMTP_PORT=${builtins.toString smtpConfig.port}
          Environment=SMTP_AUTH_MECHANISM=${smtpConfig.authMechanism}

          ExecStart=${pkgsVaultwarden-1_27_0}/bin/vaultwarden
          WorkingDirectory=${dataFolder}
          StateDirectory=${name}
          User=${user}
          Group=${group}

          # Allow vaultwarden to bind ports in the range of 0-1024 and restrict it to
          # that capability
          CapabilityBoundingSet=${if serviceIngress <= 1024 then "CAP_NET_BIND_SERVICE" else ""}
          AmbientCapabilities=${if serviceIngress <= 1024 then "CAP_NET_BIND_SERVICE" else ""}

          PrivateUsers=yes
          NoNewPrivileges=yes
          LimitNOFILE=1048576
          UMask=0077
          ProtectSystem=strict
          ProtectHome=yes
          # ReadWritePaths=${dataFolder}
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
      inherit db;
      inherit web;
    };
    type = "systemd-unit";
  };

  haproxy = service: {
    frontend = {
      acl = {
        acl_vaultwarden = "hdr_beg(host) vaultwarden.";
      };
      use_backend = "if acl_vaultwarden";
    };
    backend = {
      # TODO: instead, we should generate target specific service https://hydra.nixos.org/build/203347995/download/2/manual/#idm140737322273072
      servers = map (dist: {
        name = "vaultwarden_${dist.properties.hostname}_1";
        # TODO: should use the hostname 
        # address = "${dist.properties.hostname}:${builtins.toString ingress}";
        address = "127.0.0.1:${builtins.toString ingress}";
        resolvers = "default";
      }) service;
    };
  };

  oauth2Proxy =
    let
      name = "${serviceName}Oauth2Proxy";
    in customPkgs.mkOauth2Proxy {
      inherit name;
      serviceName = subdomain;
      domain = utils.getDomain distribution name;
      keycloakSubdomain = KeycloakService.subdomain;
      keycloakDomain = utils.getDomain distribution "KeycloakService";
      ingress = "127.0.0.1:${toString ssoIngress}";
      egress = [ "http://127.0.0.1:${toString serviceIngress}" ];
      realm = sso.realm;
      allowed_roles = [ "user" "/admin|admin" ];
      skip_auth_routes = [ "^/api" "^/identity/connect/token" ];
      inherit metricsPort;
      keys = {
        cookieSecret = "${serviceName}_oauth2proxy_cookiesecret";
        clientSecret = "${serviceName}_oauth2proxy_clientsecret";
      };

    inherit distribution HaproxyService KeycloakService KeycloakCliService;
  };

  keycloakCliConfig = {
    clients = {
      vaultwarden = {
        resourcesUris = {
          adminPath = ["/admin/*"];
          userPath = ["/*"];
        };
        access = {
          admin = {
            roles = [ "admin" ];
            resources = [ "adminPath" ];
          };
          user = {
            roles = [ "user" ];
            resources = [ "userPath" ];
          };
        };
      };
    };
  };

  deployKeys = domain: {
    "${serviceName}_oauth2proxy_cookiesecret".text = ''
        OAUTH2_PROXY_COOKIE_SECRET="${builtins.extraBuiltins.pass "${domain}/${subdomain}/${cookieSecretName}"}"
        '';
    "${serviceName}_oauth2proxy_clientsecret".text = ''
        OAUTH2_PROXY_CLIENT_SECRET="${builtins.extraBuiltins.pass "${domain}/${subdomain}/${clientSecretName}"}"
        '';
    "${serviceName}_smtp_all".text = ''
        SMTP_HOST="${builtins.extraBuiltins.pass "mailgun.com/mg.tiserbox.com/smtp_hostname"}"
        SMTP_USERNAME="${builtins.extraBuiltins.pass "mailgun.com/mg.tiserbox.com/smtp_login"}"
        SMTP_PASSWORD="${builtins.extraBuiltins.pass "mailgun.com/mg.tiserbox.com/password"}"
        '';
  };

  smtp.keys.setup = "${serviceName}_smtp_all";

  services = {
    ${db.name} = db;
    ${web.name} = web;
    ${service.name} = service;
    ${oauth2Proxy.name} = oauth2Proxy;
  };

  distribute = on: {
    ${db.name} = on;
    ${web.name} = on;
    ${service.name} = on;
    ${oauth2Proxy.name} = on;
  };
}
