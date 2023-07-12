{ stdenv
, pkgs
, utils
}:
{ name ? "keycloak-haproxy"
, domain
, realms ? []
, every ? "10m"

, KeycloakService
}:

rec {
  inherit name;

  stateDir = "keycloak-public-keys";
  downloadDir = "/var/lib/keycloak-public-keys";
  systemdUnitFile = "keycloak-haproxy.service";
  
  pkg =
    with pkgs.lib;
    let
      bin = pkgs.writeShellApplication {
        name = "get-realms.sh";
        runtimeInputs = [ pkgs.coreutils pkgs.curl pkgs.jq ];
        text = ''
          set -euxo pipefail

          realms="$1"

          for realm in $realms; do
            curl "${domain}/realms/$realm" | jq --raw-output .public_key > "${downloadDir}/$realm.pem"
          done
          '';
      };
    in
      { KeycloakService
      , ...
      }: utils.systemd.mkService rec {
        name = "keycloak-haproxy";

        content = ''
        [Unit]
        Description=Get Keycloak realms for Haproxy

        [Service]
        ExecStart=${bin}/bin/get-realms.sh ${concatStringsSep " " realms}
        DynamicUser=true

        CapabilityBoundingSet=
        AmbientCapabilities=
        StateDirectory=${stateDir}
        PrivateUsers=yes
        NoNewPrivileges=yes
        ProtectSystem=strict
        ProtectHome=yes
        PrivateTmp=yes
        PrivateDevices=yes
        ProtectHostname=yes
        ProtectClock=yes
        ProtectKernelTunables=yes
        ProtectKernelModules=yes
        ProtectKernelLogs=yes
        ProtectControlGroups=yes
        RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
        RestrictNamespaces=yes
        LockPersonality=yes
        MemoryDenyWriteExecute=yes
        RestrictRealtime=yes
        RestrictSUIDSGID=yes
        RemoveIPC=yes
        
        SystemCallFilter=@system-service
        SystemCallFilter=~@privileged @resources
        SystemCallArchitectures=native
        '';

        timer = ''
        [Unit]
        Description=Run ${name}
        After=network.target ${KeycloakService.systemdUnitFile}

        [Timer]
        OnUnitActiveSec=${every}

        [Install]
        WantedBy=timers.target
        ''; 
      };

  dependsOn = {
    inherit KeycloakService;
  };
  type = "systemd-unit";
}
