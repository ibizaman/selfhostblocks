{ stdenv
, pkgs
, utils
}:
{ configDir ? "/etc/haproxy"
, configFile ? "haproxy.cfg"
, pidfile ? "/run/haproxy/haproxy.pid"
, socket ? "/run/haproxy/haproxy.sock"
}:
{...}:

# User and group are set in config.nix

utils.systemd.mkService rec {
  name = "haproxy";

  content = ''
  [Unit]
  Description=HAProxy Load Balancer
  Documentation=https://www.haproxy.com/documentation/hapee/latest/onepage/
  After=network.target network-online.target
  Wants=network-online.target systemd-networkd-wait-online.target

  StartLimitInterval=14400
  StartLimitBurst=10
  
  [Service]
  Environment="CONFIG=${configDir}/${configFile}" "PIDFILE=${pidfile}" "EXTRAOPTS=-S ${socket}"
  ExecStart=${pkgs.haproxy}/bin/haproxy -Ws -f $CONFIG -p $PIDFILE $EXTRAOPTS
  ExecReload=${pkgs.haproxy}/bin/haproxy -Ws -f $CONFIG -c -q $EXTRAOPTS
  ExecReload=${pkgs.coreutils}/bin/kill -USR2 $MAINPID
  KillMode=mixed
  Restart=always
  SuccessExitStatus=143
  Type=notify


  #  Restart=on-abnormal
  RuntimeDirectory=haproxy

  #  KillMode=mixed
  #  KillSignal=SIGQUIT
  TimeoutStopSec=5s

  LimitNOFILE=1048576
  LimitNPROC=512

  PrivateDevices=true
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
  #  AmbientCapabilities=CAP_NET_BIND_SERVICE

  #  ProtectSystem=strict
  #  ReadWritePaths=/var/lib/haproxy /var/log/haproxy

  [Install]
  WantedBy=multi-user.target
  '';
}
