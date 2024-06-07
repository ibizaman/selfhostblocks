{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  subdomain = "grafana";
  domain = "example.com";
  fqdn = "${subdomain}.${domain}";

  password = "securepw";

  commonTestScript = { nodes, ... }:
    let
      hasSSL = !(isNull nodes.server.shb.monitoring.ssl);
      proto_fqdn = if hasSSL then "https://${fqdn}" else "http://${fqdn}";
    in
    ''
    import base64
    import json
    import os
    import pathlib

    start_all()
    server.wait_for_unit("nginx.service")
    server.wait_for_open_port(${toString nodes.server.shb.monitoring.grafanaPort})

    if ${if hasSSL then "True" else "False"}:
        server.copy_from_vm("/etc/ssl/certs/ca-certificates.crt")
        client.succeed("rm -r /etc/ssl/certs")
        client.copy_from_host(str(pathlib.Path(os.environ.get("out", os.getcwd())) / "ca-certificates.crt"), "/etc/ssl/certs/ca-certificates.crt")

    def find_in_logs(unit, text):
        return server.systemctl("status {}".format(unit))[1].find(text) != -1

    def curl(target, format, endpoint, user = None):
        errcode, r = target.execute(
            "curl --fail-with-body --silent --show-error --location"
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + (f" --header \"Authorization: Basic {base64.b64encode(user).decode('utf-8')}\"" if user is not None else "")
            + (" --output /dev/null" if format != "" else "")
            + (f" --write-out '{format}'" if format != "" else "")
            + " " + endpoint
        )
        if format == "":
            return r
        return json.loads(r)

    with subtest("access"):
        response = curl(client, """{"code":%{response_code}}""", "${proto_fqdn}")

        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")

    with subtest("api succeed"):
        response = curl(client, """{"code":%{response_code}}""", "${proto_fqdn}/api/org", user=b"admin:${password}")
        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")

    with subtest("api wrong code"):
        response = curl(client, """{"code":%{response_code}}""", "${proto_fqdn}/api/org", user=b"admin:wrong")
        if response['code'] != 401:
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
      ../../modules/blocks/postgresql.nix
      ../../modules/blocks/monitoring.nix
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
    shb.monitoring = {
      enable = true;
      inherit subdomain domain;
      grafanaPort = 3000;
      adminPasswordFile = pkgs.writeText "admin_password" password;
      secretKeyFile = pkgs.writeText "secret_key" "secret_key";
    };
  };

  https = { config, ...}: {
    shb.monitoring = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "monitoring-basic";

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
    name = "monitoring-https";

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
