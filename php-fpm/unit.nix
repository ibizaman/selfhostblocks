{ stdenv
, pkgs
, utils
}:
{ user ? "http"
, group ? "http"
, configFile ? "/etc/php/php-fpm.conf"
, phpIni ? "/etc/php/php.ini"
}:
{...}:

utils.systemd.mkService rec {
  name = "php-fpm";

  content = ''
  [Unit]
  Description=The PHP FastCGI Process Manager
  After=network.target
  
  [Service]
  Type=notify
  # User=${user}
  # Group=${group}
  PIDFile=/run/php-fpm/php-fpm.pid
  ExecStart=${pkgs.php}/bin/php-fpm --nodaemonize --fpm-config ${configFile} --php-ini ${phpIni}
  ExecReload=/bin/kill -USR2 $MAINPID
  RuntimeDirectory=php-fpm
  # ReadWritePaths=/usr/share/webapps/nextcloud/apps
  # ReadWritePaths=/usr/share/webapps/nextcloud/apps
  # ReadWritePaths=/usr/share/webapps/nextcloud/config
  # ReadWritePaths=/etc/webapps/nextcloud
  
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
