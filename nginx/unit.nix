{ stdenv
, pkgs
, utils
}:
{ serviceSuffix
, user ? "http"
, group ? "http"
, configDir ? "/etc/nginx"
, configFile ? "nginx.conf"
, pidFile ? "/run/nginx/nginx.pid"
}:
{...}:

utils.systemd.mkService rec {
  name = "nginx-${serviceSuffix}";

  content = ''
  [Unit]
  Description=Nginx webserver

  After=network.target network-online.target
  Wants=network-online.target systemd-networkd-wait-online.target

  StartLimitInterval=14400
  StartLimitBurst=10

  [Service]
  Type=forking
  User=${user}
  Group=${group}
  PIDFile=${pidFile}
  ExecStart=${pkgs.nginx}/bin/nginx -c ${configDir}/${configFile} -g 'pid ${pidFile};'
  ExecReload=${pkgs.nginx}/bin/nginx -s reload
  KillMode=mixed
  # Nginx verifies it can open a file under here even when configured
  # to write elsewhere.
  LogsDirectory=nginx
  CacheDirectory=nginx
  RuntimeDirectory=nginx

  #  Restart=on-abnormal

  #  KillSignal=SIGQUIT
  TimeoutStopSec=5s

  LimitNOFILE=1048576
  LimitNPROC=512

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
  #  ReadWritePaths=/var/lib/nginx /var/log/nginx

  [Install]
  WantedBy=multi-user.target
  '';
}
