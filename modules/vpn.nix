{ config, pkgs, lib, ... }:

let
  cfg = config.shb.vpn;

  quoteEach = lib.concatMapStrings (x: ''"${x}"'');

  nordvpnConfig =
    { name
    , dev
    , authFile
    , remoteServerIP
    , dependentServices ? []
    }: ''
    client
    dev ${dev}
    proto tcp
    remote ${remoteServerIP} 443
    resolv-retry infinite
    remote-random
    nobind
    tun-mtu 1500
    tun-mtu-extra 32
    mssfix 1450
    persist-key
    persist-tun
    ping 15
    ping-restart 0
    ping-timer-rem
    reneg-sec 0
    comp-lzo no

    status /tmp/openvpn/${name}.status

    remote-cert-tls server

    auth-user-pass ${authFile}
    verb 3
    pull
    fast-io
    cipher AES-256-CBC
    auth SHA512

    script-security 2
    route-noexec
    route-up ${routeUp name dependentServices}/bin/routeUp.sh
    down ${routeDown name dependentServices}/bin/routeDown.sh

    <ca>
    -----BEGIN CERTIFICATE-----
    MIIFCjCCAvKgAwIBAgIBATANBgkqhkiG9w0BAQ0FADA5MQswCQYDVQQGEwJQQTEQ
    MA4GA1UEChMHTm9yZFZQTjEYMBYGA1UEAxMPTm9yZFZQTiBSb290IENBMB4XDTE2
    MDEwMTAwMDAwMFoXDTM1MTIzMTIzNTk1OVowOTELMAkGA1UEBhMCUEExEDAOBgNV
    BAoTB05vcmRWUE4xGDAWBgNVBAMTD05vcmRWUE4gUm9vdCBDQTCCAiIwDQYJKoZI
    hvcNAQEBBQADggIPADCCAgoCggIBAMkr/BYhyo0F2upsIMXwC6QvkZps3NN2/eQF
    kfQIS1gql0aejsKsEnmY0Kaon8uZCTXPsRH1gQNgg5D2gixdd1mJUvV3dE3y9FJr
    XMoDkXdCGBodvKJyU6lcfEVF6/UxHcbBguZK9UtRHS9eJYm3rpL/5huQMCppX7kU
    eQ8dpCwd3iKITqwd1ZudDqsWaU0vqzC2H55IyaZ/5/TnCk31Q1UP6BksbbuRcwOV
    skEDsm6YoWDnn/IIzGOYnFJRzQH5jTz3j1QBvRIuQuBuvUkfhx1FEwhwZigrcxXu
    MP+QgM54kezgziJUaZcOM2zF3lvrwMvXDMfNeIoJABv9ljw969xQ8czQCU5lMVmA
    37ltv5Ec9U5hZuwk/9QO1Z+d/r6Jx0mlurS8gnCAKJgwa3kyZw6e4FZ8mYL4vpRR
    hPdvRTWCMJkeB4yBHyhxUmTRgJHm6YR3D6hcFAc9cQcTEl/I60tMdz33G6m0O42s
    Qt/+AR3YCY/RusWVBJB/qNS94EtNtj8iaebCQW1jHAhvGmFILVR9lzD0EzWKHkvy
    WEjmUVRgCDd6Ne3eFRNS73gdv/C3l5boYySeu4exkEYVxVRn8DhCxs0MnkMHWFK6
    MyzXCCn+JnWFDYPfDKHvpff/kLDobtPBf+Lbch5wQy9quY27xaj0XwLyjOltpiST
    LWae/Q4vAgMBAAGjHTAbMAwGA1UdEwQFMAMBAf8wCwYDVR0PBAQDAgEGMA0GCSqG
    SIb3DQEBDQUAA4ICAQC9fUL2sZPxIN2mD32VeNySTgZlCEdVmlq471o/bDMP4B8g
    nQesFRtXY2ZCjs50Jm73B2LViL9qlREmI6vE5IC8IsRBJSV4ce1WYxyXro5rmVg/
    k6a10rlsbK/eg//GHoJxDdXDOokLUSnxt7gk3QKpX6eCdh67p0PuWm/7WUJQxH2S
    DxsT9vB/iZriTIEe/ILoOQF0Aqp7AgNCcLcLAmbxXQkXYCCSB35Vp06u+eTWjG0/
    pyS5V14stGtw+fA0DJp5ZJV4eqJ5LqxMlYvEZ/qKTEdoCeaXv2QEmN6dVqjDoTAo
    k0t5u4YRXzEVCfXAC3ocplNdtCA72wjFJcSbfif4BSC8bDACTXtnPC7nD0VndZLp
    +RiNLeiENhk0oTC+UVdSc+n2nJOzkCK0vYu0Ads4JGIB7g8IB3z2t9ICmsWrgnhd
    NdcOe15BincrGA8avQ1cWXsfIKEjbrnEuEk9b5jel6NfHtPKoHc9mDpRdNPISeVa
    wDBM1mJChneHt59Nh8Gah74+TM1jBsw4fhJPvoc7Atcg740JErb904mZfkIEmojC
    VPhBHVQ9LHBAdM8qFI2kRK0IynOmAZhexlP/aT/kpEsEPyaZQlnBn3An1CRz8h0S
    PApL8PytggYKeQmRhl499+6jLxcZ2IegLfqq41dzIjwHwTMplg+1pKIOVojpWA==
    -----END CERTIFICATE-----
    </ca>
    key-direction 1
    <tls-auth>
    #
    # 2048 bit OpenVPN static key
    #
    -----BEGIN OpenVPN Static key V1-----
    e685bdaf659a25a200e2b9e39e51ff03
    0fc72cf1ce07232bd8b2be5e6c670143
    f51e937e670eee09d4f2ea5a6e4e6996
    5db852c275351b86fc4ca892d78ae002
    d6f70d029bd79c4d1c26cf14e9588033
    cf639f8a74809f29f72b9d58f9b8f5fe
    fc7938eade40e9fed6cb92184abb2cc1
    0eb1a296df243b251df0643d53724cdb
    5a92a1d6cb817804c4a9319b57d53be5
    80815bcfcb2df55018cc83fc43bc7ff8
    2d51f9b88364776ee9d12fc85cc7ea5b
    9741c4f598c485316db066d52db4540e
    212e1518a9bd4828219e24b20d88f598
    a196c9de96012090e333519ae18d3509
    9427e7b372d348d352dc4c85e18cd4b9
    3f8a56ddb2e64eb67adfc9b337157ff4
    -----END OpenVPN Static key V1-----
    </tls-auth>
    '';

  routeUp = name: dependentServices: pkgs.writeShellApplication {
    name = "routeUp.sh";

    runtimeInputs = [ pkgs.iproute2 pkgs.systemd pkgs.nettools ];

    text = ''
    echo "Running route-up..."

    echo "dev=''${dev:?}"
    echo "ifconfig_local=''${ifconfig_local:?}"
    echo "route_vpn_gateway=''${route_vpn_gateway:?}"

    set -x

    ip rule
    ip rule add from "''${ifconfig_local:?}/32" table ${name}
    ip rule add to "''${route_vpn_gateway:?}/32" table ${name}
    ip rule

    ip route list table ${name} || :
    retVal=$?
    if [ $retVal -eq 2 ]; then
      echo "table is empty"
    elif [ $retVal -ne 0 ]; then
      exit 1
    fi
    ip route add default via "''${route_vpn_gateway:?}" dev "''${dev:?}" table ${name}
    ip route flush cache
    ip route list table ${name} || :
    retVal=$?
    if [ $retVal -eq 2 ]; then
      echo "table is empty"
    elif [ $retVal -ne 0 ]; then
      exit 1
    fi

    echo "''${ifconfig_local:?}" > /run/openvpn/${name}/ifconfig_local

    dependencies=(${quoteEach dependentServices})
    for i in "''${dependencies[@]}"; do
        systemctl restart "$i" || :
    done

    echo "Running route-up DONE"
    '';
  };

  routeDown = name: dependentServices: pkgs.writeShellApplication {
    name = "routeDown.sh";

    runtimeInputs = [ pkgs.iproute2 pkgs.systemd pkgs.nettools pkgs.coreutils ];

    text = ''
    echo "Running route-down..."

    echo "dev=''${dev:?}"
    echo "ifconfig_local=''${ifconfig_local:?}"
    echo "route_vpn_gateway=''${route_vpn_gateway:?}"

    set -x

    ip rule
    ip rule del from "''${ifconfig_local:?}/32" table ${name}
    ip rule del to "''${route_vpn_gateway:?}/32" table ${name}
    ip rule

    # This will probably fail because the dev is already gone.
    ip route list table ${name} || :
    retVal=$?
    if [ $retVal -eq 2 ]; then
      echo "table is empty"
    elif [ $retVal -ne 0 ]; then
      exit 1
    fi
    ip route del default via "''${route_vpn_gateway:?}" dev "''${dev:?}" table ${name} || :
    ip route flush cache
    ip route list table ${name} || :
    retVal=$?
    if [ $retVal -eq 2 ]; then
      echo "table is empty"
    elif [ $retVal -ne 0 ]; then
      exit 1
    fi

    rm /run/openvpn/${name}/ifconfig_local

    dependencies=(${quoteEach dependentServices})
    for i in "''${dependencies[@]}"; do
        systemctl stop "$i" || :
    done

    echo "Running route-down DONE"
    '';
  };

  someEnabled = lib.any (lib.mapAttrsToList (name: c: c.enable) cfg);
in
{
  options =
    let
      instanceOption = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption (lib.mdDoc "OpenVPN config");

          package = lib.mkPackageOptionMD pkgs "openvpn" {};

          provider = lib.mkOption {
            description = lib.mdDoc "VPN provider, if given uses ready-made configuration.";
            type = lib.types.nullOf (lib.types.enum [ "nordvpn" ]);
            default = null;
          };

          dev = lib.mkOption {
            description = lib.mdDoc "Name of the interface.";
            type = lib.types.str;
            example = "tun0";
          };

          routingNumber = lib.mkOption {
            description = lib.mdDoc "Unique number used to route packets.";
            type = lib.types.int;
            example = 10;
          };

          remoteServerIP = lib.mkOption {
            description = lib.mdDoc "IP of the VPN server to connect to.";
            type = lib.types.str;
          };

          sopsFile = lib.mkOption {
            description = lib.mdDoc "Location of file holding authentication secrets for provider.";
            type = lib.types.anything;
          };

          proxyPort = lib.mkOption {
            description = lib.mdDoc "If not null, sets up a proxy that listens on the given port and sends traffic to the VPN.";
            type = lib.types.nullOr lib.types.int;
            default = null;
          };
        };
      };
    in
      {
        shb.vpn = lib.mkOption {
          description = "OpenVPN instances.";
          default = {};
          type = lib.types.attrsOf instanceOption;
        };
      };

  config = {
    services.openvpn.servers =
      let
        instanceConfig = name: c: lib.mkIf c.enable {
          ${name} = {
            autoStart = true;

            up = "mkdir -p /run/openvpn/${name}";

            config = nordvpnConfig {
              inherit name;
              inherit (c) dev remoteServerIP;
              authFile = config.sops.secrets."${name}/auth".path;
              dependentServices = lib.optional (c.proxyPort != null) "tinyproxy-${name}.service";
            };
          };
        };
      in
        lib.mkMerge (lib.mapAttrsToList instanceConfig cfg);

    sops.secrets =
      let
        instanceConfig = name: c: lib.mkIf c.enable {
          "${name}/auth" = {
            sopsFile = c.sopsFile;
            mode = "0440";
            restartUnits = [ "openvpn-${name}" ];
          };
        };
      in
        lib.mkMerge (lib.mapAttrsToList instanceConfig cfg);

    systemd.tmpfiles.rules = map (name:
      "d /tmp/openvpn/${name}.status 0700 root root"
    ) (lib.attrNames cfg);

    networking.iproute2.enable = true;
    networking.iproute2.rttablesExtraConfig =
      lib.concatStringsSep "\n" (lib.mapAttrsToList (name: c: "${toString c.routingNumber} ${name}") cfg);

    shb.tinyproxy =
      let
        instanceConfig = name: c: lib.mkIf (c.enable && c.proxyPort != null) {
          ${name} = {
            enable = true;
            # package = pkgs.tinyproxy.overrideAttrs (old: {
            #   withDebug = false;
            #   patches = old.patches ++ [
            #     (pkgs.fetchpatch {
            #       name = "";
            #       url = "https://github.com/tinyproxy/tinyproxy/pull/494/commits/2532ba09896352b31f3538d7819daa1fc3f829f1.patch";
            #       sha256 = "sha256-Q0MkHnttW8tH3+hoCt9ACjHjmmZQgF6pC/menIrU0Co=";
            #     })
            #   ];
            # });
            dynamicBindFile = "/run/openvpn/${name}/ifconfig_local";
            settings = {
              Port = c.proxyPort;
              Listen = "127.0.0.1";
              Syslog = "On";
              LogLevel = "Info";
              Allow = [ "127.0.0.1" "::1" ];
              ViaProxyName = ''"tinyproxy"'';
            };
          };
        };
      in
        lib.mkMerge (lib.mapAttrsToList instanceConfig cfg);
  };
}
