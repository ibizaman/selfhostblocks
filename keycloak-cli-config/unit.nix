{ stdenv
, pkgs
, lib
, utils
}:
{ name

, config

, keycloakServiceName
, keycloakSecretsDir
, keycloakAvailabilityTimeout ? "120s"
, keycloakUrl
, keycloakUser
, keys
, debug ? false

, dependsOn ? {}
}:

# https://github.com/adorsys/keycloak-config-cli

# Password must be given through a file name "keycloak.password" under keycloakSecretsDir.

let
  configcreator = pkgs.callPackage ./configcreator.nix {};

  configfile = pkgs.writeText "keycloakcliconfig.json" (builtins.toJSON (configcreator config));

  envs = lib.concatMapStrings (x: "\nEnvironment=" + x) ([
    "SPRING_CONFIG_IMPORT=configtree:${keycloakSecretsDir}/"
    "KEYCLOAK_URL=${keycloakUrl}"
    "KEYCLOAK_USER=${keycloakUser}"
    "KEYCLOAK_AVAILABILITYCHECK_ENABLED=true"
    "KEYCLOAK_AVAILABILITYCHECK_TIMEOUT=${keycloakAvailabilityTimeout}"
    "IMPORT_VARSUBSTITUTION_ENABLED=true"
    "IMPORT_FILES_LOCATIONS=${configfile}"
  ] ++ (if !debug then [] else [
    "DEBUG=true"
    "LOGGING_LEVEL_ROOT=debug"
    "LOGGING_LEVEL_HTTP=debug"
    "LOGGING_LEVEL_REALMCONFIG=debug"
    "LOGGING_LEVEL_KEYCLOAKCONFIGCLI=debug"
  ]));

  keycloak-cli-config = pkgs.stdenv.mkDerivation rec {
    pname = "keycloak-cli-config";
    version = "5.3.1";
    keycloakVersion = "18.0.2";

    src = pkgs.fetchurl {
      url = "https://github.com/adorsys/keycloak-config-cli/releases/download/v${version}/keycloak-config-cli-${keycloakVersion}.jar";
      sha256 = "sha256-vC0d0g5TFddetpBwRDMokloTCr7ibFK//Yuvh+m77RA=";
    };

    buildInputs = [ pkgs.makeWrapper pkgs.jre ];

    phases = [ "installPhase" ];

    installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/keycloak-cli-config.jar
    '';
  };

in

{
  inherit name;

  pkg = {...}: utils.systemd.mkService rec {
    name = "keycloak-cli-config";

    content = ''
    [Unit]
    Description=Keycloak Realm Config
    After=${keycloakServiceName}
    Wants=${keycloakServiceName}
    After=${utils.keyServiceDependencies keys}
    Wants=${utils.keyServiceDependencies keys}

    [Service]
    User=keycloakcli
    Group=keycloakcli

    ${utils.keyEnvironmentFile keys.userpasswords}
    Type=oneshot${envs}
    ExecStart=${pkgs.jre}/bin/java -jar ${keycloak-cli-config}/bin/keycloak-cli-config.jar

    RuntimeDirectory=keycloak-cli-config

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
    '';
  };

  inherit dependsOn;
  type = "systemd-unit";
}
