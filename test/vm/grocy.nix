{ pkgs, lib, ... }:
{
  basic = pkgs.nixosTest {
    name = "grocy-basic";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        {
          options = {
            shb.backup = lib.mkOption { type = lib.types.anything; };
          };
        }
        ../../modules/services/grocy.nix
      ];

      shb.grocy = {
        enable = true;
        domain = "example.com";
        subdomain = "g";
      };
      # Nginx port.
      networking.firewall.allowedTCPPorts = [ 80 ];
    };

    nodes.client = {};

    # TODO: Test login
    testScript = { nodes, ... }: ''
    import json

    def curl(target, format, endpoint):
        return json.loads(target.succeed(
            "curl --fail-with-body --silent --show-error --output /dev/null --location"
            + " --connect-to g.example.com:443:server:443"
            + " --connect-to g.example.com:80:server:80"
            + f" --write-out '{format}'"
            + " " + endpoint
        ))

    start_all()
    server.wait_for_unit("phpfpm-grocy.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_open_unix_socket("${nodes.server.services.phpfpm.pools.grocy.socket}")

    response = curl(client, """{"code":%{response_code}}""", "http://g.example.com")

    if response['code'] != 200:
        raise Exception(f"Code is {response['code']}")
    '';
  };

  cert = pkgs.nixosTest {
    name = "grocy-cert";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        {
          options = {
            shb.backup = lib.mkOption { type = lib.types.anything; };
            shb.authelia = lib.mkOption { type = lib.types.anything; };
          };
        }
        ../../modules/blocks/nginx.nix
        ../../modules/blocks/ssl.nix
        ../../modules/services/grocy.nix
      ];

      shb.certs = {
        cas.selfsigned.myca = {
          name = "My CA";
        };
        certs.selfsigned = {
          n = {
            ca = config.shb.certs.cas.selfsigned.myca;
            domain = "*.example.com";
            group = "nginx";
          };
        };
      };

      systemd.services.nginx.after = [ config.shb.certs.certs.selfsigned.n.systemdService ];
      systemd.services.nginx.requires = [ config.shb.certs.certs.selfsigned.n.systemdService ];

      shb.grocy = {
        enable = true;
        domain = "example.com";
        subdomain = "g";
        ssl = config.shb.certs.certs.selfsigned.n;
      };
      # Nginx port.
      networking.firewall.allowedTCPPorts = [ 80 443 ];

      shb.nginx.accessLog = true;
    };

    nodes.client = {};

    # TODO: Test login
    testScript = { nodes, ... }: ''
    import json
    import os
    import pathlib

    def curl(target, format, endpoint):
        return json.loads(target.succeed(
            "curl --fail-with-body --silent --show-error --output /dev/null --location"
            + " --connect-to g.example.com:443:server:443"
            + " --connect-to g.example.com:80:server:80"
            + f" --write-out '{format}'"
            + " " + endpoint
        ))

    start_all()
    server.wait_for_unit("phpfpm-grocy.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_open_unix_socket("${nodes.server.services.phpfpm.pools.grocy.socket}")

    server.copy_from_vm("/etc/ssl/certs/ca-certificates.crt")
    client.succeed("rm -r /etc/ssl/certs")
    client.copy_from_host(str(pathlib.Path(os.environ.get("out", os.getcwd())) / "ca-certificates.crt"), "/etc/ssl/certs/ca-certificates.crt")

    response = curl(client, """{"code":%{response_code}}""", "https://g.example.com")

    if response['code'] != 200:
        raise Exception(f"Code is {response['code']}")
    '';
  };
}
