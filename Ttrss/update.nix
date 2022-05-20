{ stdenv
, pkgs
, lib
, utils
}:
{ readOnlyPaths ? []
, readWritePaths ? []
}:
{ TtrssService
, TtrssPostgresDB
, ...
}:

# Assumptions:
# - Do not run as root.
# - Image cache should be writable.
# - Upload cache should be writable.
# - Data export cache should be writable.
# - ICONS_DIR should be writable.
# - LOCK_DIRECTORY should be writable.

let
  fullPath = "${TtrssService.documentRoot}/${TtrssService.documentName}";
  roPaths = [fullPath] ++ readOnlyPaths;
in
utils.systemd-service-derivation rec {
  name = "ttrss-update";
  content = ''
    [Unit]
    Description=${name}
    After=network.target ${TtrssPostgresDB.postgresServiceName}
    
    [Service]
    User=${TtrssService.user}
    Group=${TtrssService.group}
    ExecStart=${pkgs.php}/bin/php ${fullPath}/update_daemon2.php

    PrivateDevices=true
    PrivateTmp=true
    ProtectKernelTunables=true
    ProtectKernelModules=true
    ProtectControlGroups=true
    ProtectKernelLogs=true
    ProtectHome=true
    ProtectHostname=true
    ProtectClock=true
    RestrictSUIDSGID=true
    SystemCallFilter=@basic-io @file-system @process @system-service

    ProtectSystem=strict
    ReadOnlyPaths=${builtins.concatStringsSep " " roPaths}
    ReadWritePaths=${builtins.concatStringsSep " " readWritePaths}

    # NoExecPaths=/
    # ExecPaths=${pkgs.php}/bin

    NoNewPrivileges=true

    RuntimeDirectory=${name}
    
    [Install]
    WantedBy=multi-user.target
  '';
}
