{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  subdomain = "g";
  domain = "example.com";
  fqdn = "${subdomain}.${domain}";

  # TODO: Test login
  commonTestScript = { nodes, ... }:
    let
      hasSSL = !(isNull nodes.server.shb.grocy.ssl);
      proto_fqdn = if hasSSL then "https://${fqdn}" else "http://${fqdn}";
    in
    ''
    import json
    import os
    import pathlib

    start_all()
    server.wait_for_unit("phpfpm-grocy.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_open_unix_socket("${nodes.server.services.phpfpm.pools.grocy.socket}")

    if ${if hasSSL then "True" else "False"}:
        server.copy_from_vm("/etc/ssl/certs/ca-certificates.crt")
        client.succeed("rm -r /etc/ssl/certs")
        client.copy_from_host(str(pathlib.Path(os.environ.get("out", os.getcwd())) / "ca-certificates.crt"), "/etc/ssl/certs/ca-certificates.crt")

    def curl(target, format, endpoint, succeed=True):
        return json.loads(target.succeed(
            "curl --fail-with-body --silent --show-error --output /dev/null --location"
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + f" --write-out '{format}'"
            + " " + endpoint
        ))

    with subtest("access"):
        response = curl(client, """{"code":%{response_code}}""", "${proto_fqdn}")

        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")
    '';

  base = {
    imports = [
      (pkgs'.path + "/nixos/modules/profiles/headless.nix")
      (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
      {
        options = {
          shb.backup = lib.mkOption { type = lib.types.anything; };
        };
      }
      ../../modules/services/grocy.nix
    ];

    # Nginx port.
    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };

  certs = { config, ... }: {
    imports = [
      ../../modules/blocks/ssl.nix
    ];

    shb.certs = {
      cas.selfsigned.myca = {
        name = "My CA";
      };
      certs.selfsigned = {
        n = {
          ca = config.shb.certs.cas.selfsigned.myca;
          domain = "*.${domain}";
          group = "nginx";
        };
      };
    };

    systemd.services.nginx.after = [ config.shb.certs.certs.selfsigned.n.systemdService ];
    systemd.services.nginx.requires = [ config.shb.certs.certs.selfsigned.n.systemdService ];
  };

  basic = { config, ... }: {
    shb.grocy = {
      enable = true;
      inherit domain subdomain;
    };
  };

  https = { config, ...}: {
    shb.grocy = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "grocy-basic";

    nodes.server = lib.mkMerge [
      base
      basic
      {
        options = {
          shb.authelia = lib.mkOption { type = lib.types.anything; };
        };
      }
    ];

    nodes.client = {};

    testScript = commonTestScript;
  };

  https = pkgs.testers.runNixOSTest {
    name = "grocy-https";

    nodes.server = lib.mkMerge [
      base
      certs
      basic
      https
      {
        options = {
          shb.authelia = lib.mkOption { type = lib.types.anything; };
        };
      }
    ];

    nodes.client = {};

    testScript = commonTestScript;
  };
}
