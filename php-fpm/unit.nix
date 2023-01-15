{ stdenv
, pkgs
, utils
}:
{ name
, siteName
, user
, group
, socketUser
, socketGroup
, runtimeDirectory ? "/run/${siteName}"
, phpIniConfig ? {}
, siteConfig ? {}
, extensions ? []
, zend_extensions ? []

, dependsOn ? {}
}:

let
  phpIniFile = pkgs.callPackage (import ./php-ini.nix) {
    inherit siteName;
    inherit extensions zend_extensions;
  } // phpIniConfig;

  siteSocket = "${runtimeDirectory}/${siteName}.sock";

  siteConfigFile = pkgs.callPackage (import ./php-fpm.nix) {
    inherit siteName;
    inherit user group;
    inherit siteSocket socketUser socketGroup;
  } // siteConfig;
in
# This service runs as root, each pool runs as a user.
{
  inherit name;
  inherit user group;
  inherit socketUser socketGroup;

  inherit siteSocket;

  pkg = utils.systemd.mkService rec {
    name = "php-fpm-${siteName}";

    content = ''
    [Unit]
    Description=The PHP FastCGI Process Manager
    After=network.target
    
    [Service]
    Type=notify
    PIDFile=/run/${siteName}/php-fpm.pid
    ExecStart=${pkgs.php}/bin/php-fpm --nodaemonize --fpm-config ${siteConfigFile} --php-ini ${phpIniFile}
    ExecReload=/bin/kill -USR2 $MAINPID

    # Keeping this around to avoid uncommenting them. These directories
    # are handled through tmpfiles.d.
    #
    #   RuntimeDirectory=${siteName}
    #   StateDirectory=${siteName}
    
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
  };

  inherit dependsOn;
  type = "systemd-unit";
}
