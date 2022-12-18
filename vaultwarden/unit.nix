{ stdenv
, pkgs
, utils
}:
{ name ? "vaultwarden"
, user ? "vaultwarden"
, group ? "vaultwarden"
, port ? 18005
, dataFolder ? "/var/lib/vaultwarden"
, hostname
, postgresDatabase ? "vaultwarden"
, postgresUser ? "vaultwarden"
, postgresPassword
, postgresHost ? x: "127.0.0.1"

, smtpFrom
, smtpFromName ? "vaultwarden"
, smtpPort ? 587
, smtpAuthMechanism ? "Login"

, webvaultEnabled ? false
, webvaultFolder ? "/usr/share/webapps/vaultwarden-web"
, signupsAllowed ? false
, signupsVerify ? true

, keys

, VaultwardenWeb
, VaultwardenPostgresDB
}:

{
  inherit name;

  inherit port;
  
  pkg =
    { VaultwardenPostgresDB
    , VaultwardenWeb
    }: utils.systemd.mkService rec {
    name = "vaultwarden";

    content = ''
    [Unit]
    Description=Vaultwarden Server
    Documentation=https://github.com/dani-garcia/vaultwarden
    After=network.target
    After=${utils.keyServiceDependencies keys}
    Wants=${utils.keyServiceDependencies keys}
  
    [Service]
    Environment=DATA_FOLDER=${dataFolder}
    Environment=DATABASE_URL=postgresql://${postgresUser}:${postgresPassword}@${postgresHost {inherit VaultwardenPostgresDB;}}/${postgresDatabase}
    Environment=IP_HEADER=X-Real-IP
  
    Environment=WEB_VAULT_FOLDER=${webvaultFolder}
    Environment=WEB_VAULT_ENABLED=${if webvaultEnabled then "true" else "false"}
  
    Environment=SIGNUPS_ALLOWED=${if signupsAllowed then "true" else "false"}
    Environment=SIGNUPS_VERIFY=${if signupsVerify then "true" else "false"}
    # Implies the /admin path is protected
    Environment=DISABLE_ADMIN_TOKEN=true
    Environment=INVITATIONS_ALLOWED=true
    Environment=DOMAIN=https://${hostname}
  
    # Assumes we're behind a reverse proxy
    Environment=ROCKET_ADDRESS=127.0.0.1
    Environment=ROCKET_PORT=${builtins.toString port}
    Environment=USE_SYSLOG=true
    Environment=EXTENDED_LOGGING=true
    Environment=LOG_FILE=
    Environment=LOG_LEVEL=trace
  
    ${utils.keyEnvironmentFile keys.smtpSetup}
    Environment=SMTP_FROM=${smtpFrom}
    Environment=SMTP_FROM_NAME=${smtpFromName}
    Environment=SMTP_PORT=${builtins.toString smtpPort}
    Environment=SMTP_AUTH_MECHANISM=${smtpAuthMechanism}
  
    ExecStart=${pkgs.vaultwarden-postgresql}/bin/vaultwarden
    WorkingDirectory=${dataFolder}
    User=${user}
    Group=${group}
    
    # Allow vaultwarden to bind ports in the range of 0-1024 and restrict it to
    # that capability
    #CapabilityBoundingSet=CAP_NET_BIND_SERVICE
    #AmbientCapabilities=CAP_NET_BIND_SERVICE
    
    # If vaultwarden is run at ports >1024, you should apply these options via a
    # drop-in file
    CapabilityBoundingSet=
    AmbientCapabilities=
    PrivateUsers=yes
    
    NoNewPrivileges=yes
    
    LimitNOFILE=1048576
    UMask=0077
    
    ProtectSystem=strict
    ProtectHome=yes
    ReadWritePaths=${dataFolder}
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
    inherit VaultwardenWeb;
    inherit VaultwardenPostgresDB;
  };
  type = "systemd-unit";
}
