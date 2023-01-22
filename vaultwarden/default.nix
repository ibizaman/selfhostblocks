{ customPkgs
, pkgs
, utils
}:
{ serviceName ? "Vaultwarden"
, subdomain ? "vaultwarden"
, domain ? ""
, ingress ? 18005
, signupsAllowed ? false
, signupsVerify ? true

, user ? "vaultwarden"
, group ? "vaultwarden"
, dataFolder ? "/var/lib/vaultwarden"
, postgresDatabase ? "vaultwarden"
, postgresUser ? "vaultwarden"
, postgresPasswordLocation ? "vaultwarden"
, webvaultEnabled ? true
, webvaultPath ? "/usr/share/webapps/vaultwarden"

, smtp ? {}
, sso ? {}

, distribution ? {}
}:
let
  mkVaultwardenWeb = pkgs.callPackage ./web.nix {inherit utils;};
in
rec {
  inherit user group;

  dnsmasqSubdomains = [subdomain];

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
          After=${utils.keyServiceDependencies smtp.keys}
          Wants=${utils.keyServiceDependencies smtp.keys}

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
          Environment=ROCKET_PORT=${builtins.toString ingress}
          Environment=USE_SYSLOG=true
          Environment=EXTENDED_LOGGING=true
          Environment=LOG_FILE=
          Environment=LOG_LEVEL=trace

          ${utils.keyEnvironmentFiles smtp.keys}
          Environment=SMTP_FROM=${smtp.from}
          Environment=SMTP_FROM_NAME=${smtp.fromName}
          Environment=SMTP_PORT=${builtins.toString smtp.port}
          Environment=SMTP_AUTH_MECHANISM=${smtp.authMechanism}

          ExecStart=${pkgs.vaultwarden-postgresql}/bin/vaultwarden
          WorkingDirectory=${dataFolder}
          StateDirectory=${name}
          User=${user}
          Group=${group}

          # Allow vaultwarden to bind ports in the range of 0-1024 and restrict it to
          # that capability
          CapabilityBoundingSet=${if ingress <= 1024 then "CAP_NET_BIND_SERVICE" else ""}
          AmbientCapabilities=${if ingress <= 1024 then "CAP_NET_BIND_SERVICE" else ""}

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

  keycloakCliConfig = {
    clients = {
      vaultwarden = {
        roles = ["uma_protection"];
      };
    };
  };
}
