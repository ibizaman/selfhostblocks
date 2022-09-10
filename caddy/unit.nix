{ stdenv
, pkgs
, utils
}:
{ user ? "http"
, group ? "http"
, configDir ? "/etc/caddy"
, configFile ? "Caddyfile"
}:
{...}:

utils.systemd.mkService rec {
  name = "caddy";

  content = ''
  [Unit]
  Description=Caddy webserver
  Documentation=https://caddyserver.com/docs/

  After=network.target network-online.target
  Wants=network-online.target systemd-networkd-wait-online.target

  StartLimitInterval=14400
  StartLimitBurst=10

  [Service]
  Type=notify
  User=${user}
  Group=${group}
  #  Environment=XDG_DATA_HOME=/var/lib
  #  Environment=XDG_CONFIG_HOME=${configDir}
  ExecStart=${pkgs.caddy}/bin/caddy run --environ --config ${configDir}/${configFile}
  ExecReload=${pkgs.caddy}/bin/caddy reload --config ${configDir}/${configFile}

  #  Restart=on-abnormal
  RuntimeDirectory=caddy

  #  KillMode=mixed
  #  KillSignal=SIGQUIT
  TimeoutStopSec=5s

  LimitNOFILE=1048576
  LimitNPROC=512

  #  PrivateDevices=true
  LockPersonality=true
  NoNewPrivileges=true
  PrivateDevices=true
  PrivateTmp=true
  ProtectClock=true
  ProtectControlGroups=true
  ProtectHome=true
  ProtectHostname=true
  ProtectKernelLogs=true
  ProtectKernelModules=true
  ProtectKernelTunables=true
  ProtectSystem=full
  RestrictAddressFamilies=AF_INET AF_INET6 AF_NETLINK AF_UNIX
  RestrictNamespaces=true
  RestrictRealtime=true
  RestrictSUIDSGID=true

  #  CapabilityBoundingSet=CAP_NET_BIND_SERVICE
  AmbientCapabilities=CAP_NET_BIND_SERVICE

  #  ProtectSystem=strict
  #  ReadWritePaths=/var/lib/caddy /var/log/caddy

  [Install]
  WantedBy=multi-user.target
  '';
}
