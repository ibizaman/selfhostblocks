{ stdenv
, pkgs
, lib
, utils
}:
{ name
, user
, group
, documentRoot
, readOnlyPaths ? []
, readWritePaths ? []
, postgresServiceName

, dependsOn ? {}
}:

# Assumptions:
# - Do not run as root.
# - Image cache should be writable.
# - Upload cache should be writable.
# - Data export cache should be writable.
# - ICONS_DIR should be writable.
# - LOCK_DIRECTORY should be writable.

let
  fullPath = "${documentRoot}";
  roPaths = [fullPath] ++ readOnlyPaths;
in
{
  inherit name;
  pkg = {...}: utils.systemd.mkService rec {
    name = "ttrss-update";
    content = ''
      [Unit]
      Description=${name}
      After=network.target ${postgresServiceName}

      [Service]
      User=${user}
      Group=${group}
      ExecStart=${pkgs.php}/bin/php ${fullPath}/update_daemon2.php

      RuntimeDirectory=${name}

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
      LockPersonality=true
      NoNewPrivileges=true

      SystemCallFilter=@basic-io @file-system @process @system-service

      ProtectSystem=strict
      ReadOnlyPaths=${builtins.concatStringsSep " " roPaths}
      ReadWritePaths=${builtins.concatStringsSep " " readWritePaths}

      # NoExecPaths=/
      # ExecPaths=${pkgs.php}/bin

      [Install]
      WantedBy=multi-user.target
    '';
  };

  inherit dependsOn;
  type = "systemd-unit";
}
