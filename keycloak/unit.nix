{ stdenv
, pkgs
, lib
, utils
}:
{ name
, user ? "keycloak"
, group ? "keycloak"
, dbType ? "postgres"
, postgresServiceName
, initialAdminUsername ? null
, keys

, logLevel ? "INFO"
, metricsEnabled ? false
, hostname

, dbUsername ? "keycloak"
, dbHost ? x: "localhost"
, dbPort ? "5432"
, dbDatabase ? "keycloak"

, KeycloakPostgresDB
}:

assert lib.assertOneOf "dbType" dbType ["postgres"];

let
  keycloak = pkgs.keycloak.override {
    # This is needed for keycloak to build with the correct driver.
    confFile = pkgs.writeText "keycloak.conf" ''
      db=${dbType}
    '';
  };
in

{
  inherit name;

  inherit initialAdminUsername;

  systemdUnitFile = "${name}.service";

  pkg = { KeycloakPostgresDB }:
    let
      configFile = pkgs.writeText "keycloak.conf" ''
      # The password of the database user is given by an environment variable.
      db=${dbType}
      db-username=${dbUsername}
      db-url-host=${dbHost {inherit KeycloakPostgresDB;}}
      db-url-port=${dbPort}
      db-url-database=${dbDatabase}
      # db-url-properties=  # Would be used for ssl, see https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/web-apps/keycloak.nix#L491

      # Observability

      # If the server should expose metrics and healthcheck endpoints.
      metrics-enabled=${if metricsEnabled then "true" else "false"}

      # HTTP

      # The file path to a server certificate or certificate chain in PEM format.
      #https-certificate-file=''${kc.home.dir}conf/server.crt.pem

      # The file path to a private key in PEM format.
      #https-certificate-key-file=''${kc.home.dir}conf/server.key.pem

      # The proxy address forwarding mode if the server is behind a reverse proxy.
      # https://www.keycloak.org/server/reverseproxy
      proxy=edge

      # Do not attach route to cookies and rely on the session affinity capabilities from reverse proxy
      #spi-sticky-session-encoder-infinispan-should-attach-route=false

      # Hostname for the Keycloak server.
      hostname=${hostname}

      spi-x509cert-lookup-provider=haproxy

      log-level=${logLevel}
      '';
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
      # ExecStartPre=!${keycloak}/bin/kc.sh -cf ${configFile} build
      ExecStart=${keycloak}/bin/kc.sh -cf ${configFile} start

      # ReadWritePaths=/var/lib/keycloak
      # ReadWritePaths=/var/log/keycloak
      # ReadWritePaths=/usr/share/java/keycloak/lib/quarkus
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
    };

  dependsOn = {
    inherit KeycloakPostgresDB;
  };
  type = "systemd-unit";
}
