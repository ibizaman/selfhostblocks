{ stdenv
, pkgs
, utils
}:
{ serviceSuffix
, configFile ? "/etc/php/php-fpm.conf"
, phpIni ? "/etc/php/php.ini"
}:
{...}:

# This service runs as root, each pool runs as a user.

utils.systemd.mkService rec {
  name = "php-fpm-${serviceSuffix}";

  content = ''
  [Unit]
  Description=The PHP FastCGI Process Manager
  After=network.target
  
  [Service]
  Type=notify
  PIDFile=/run/${serviceSuffix}/php-fpm.pid
  ExecStart=${pkgs.php}/bin/php-fpm --nodaemonize --fpm-config ${configFile} --php-ini ${phpIni}
  ExecReload=/bin/kill -USR2 $MAINPID

  # Keeping this around to avoid uncommenting them. These directories
  # are handled through tmpfiles.d.
  #
  #   RuntimeDirectory=${serviceSuffix}
  #   StateDirectory=${serviceSuffix}
  
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
  
  [Install]
  WantedBy=multi-user.target
  '';
}
