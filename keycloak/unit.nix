{ stdenv
, pkgs
, lib
, utils
}:
{ configDir ? "/etc/keycloak"
, configFile ? "keycloak.conf"
, user ? "keycloak"
, group ? "keycloak"
, dbType ? "postgres"
, postgresServiceName
, initialAdminUsername ? null
, keys
}:
{ ... }:

assert lib.assertOneOf "dbType" dbType ["postgres"];

let
  keycloak = pkgs.keycloak.override {
    # This is needed for keycloak to build with the correct driver.
    confFile = pkgs.writeText "keycloak.conf" ''
      db=${dbType}
    '';
  };
in

with lib.attrsets;
utils.systemd.mkService rec {
  name = "keycloak";

  content = ''
  [Unit]
  Description=Keycloak server
  After=network-online.target
  Wants=network-online.target systemd-networkd-wait-online.service ${postgresServiceName}
  After=${utils.keyServiceDependencies keys}
  Wants=${utils.keyServiceDependencies keys}
  
  [Service]
  User=${user}
  Group=${group}
  
  ${utils.keyEnvironmentFile keys.dbPassword}
  ${if initialAdminUsername != null then "Environment=KEYCLOAK_ADMIN="+initialAdminUsername else ""}
  ${if hasAttr "initialAdminPassword" keys then utils.keyEnvironmentFile keys.initialAdminPassword else ""}
  Environment=PATH=${pkgs.coreutils}/bin
  Environment=KC_HOME_DIR="/run/keycloak"

  # running the ExecStartPre as root is not ideal, but at the moment
  # the only solution for Quarkus modifying the serialized
  # data under <keycloak-home>/lib/quarkus
  # Raised upstream as https://github.com/keycloak/keycloak/discussions/10323
  # ExecStartPre=!${keycloak}/bin/kc.sh -cf ${configDir}/${configFile} build
  ExecStart=${keycloak}/bin/kc.sh -cf ${configDir}/${configFile} start

  # ReadWritePaths=/var/lib/keycloak
  # ReadWritePaths=/var/log/keycloak
  # ReadWritePaths=/usr/share/java/keycloak/lib/quarkus
  # ReadOnlyPaths=${configDir}
  RuntimeDirectory=keycloak
  DynamicUser=true
  
  # Disable timeout logic and wait until process is stopped
  TimeoutStopSec=0
  TimeoutStartSec=10min
  
  # SIGTERM signal is used to stop the Java process
  KillSignal=SIGTERM
  
  # Send the signal only to the JVM rather than its control group
  KillMode=process
  
  # Java process is never killed
  SendSIGKILL=no
  
  # When a JVM receives a SIGTERM signal it exits with code 143
  SuccessExitStatus=143
  
  # Hardening options
  # CapabilityBoundingSet=
  # AmbientCapabilities=CAP_NET_BIND_SERVICES
  # NoNewPrivileges=true
  # Fails with:
  # Failed to set up mount namespacing: /run/systemd/unit-root/var/lib/keycloak: No such file or directory
  # ProtectHome=true
  # ProtectSystem=strict
  # ProtectKernelTunables=true
  # ProtectKernelModules=true
  # ProtectControlGroups=true
  # PrivateTmp=true
  # PrivateDevices=true
  # LockPersonality=true
  
  [Install]
  WantedBy=multi-user.target
  '';
}
