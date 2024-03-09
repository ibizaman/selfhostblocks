{ pkgs, lib, ... }:
let
  # TODO: Test login
  commonTestScript = appname: { nodes, ... }:
    let
      shbapp = nodes.server.shb.arr.${appname};
      hasSSL = !(isNull shbapp.ssl);
      fqdn = if hasSSL then "https://${appname}.example.com" else "http://${appname}.example.com";
    in
    ''
    import json
    import os
    import pathlib

    start_all()
    server.wait_for_unit("${appname}.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_open_port(${builtins.toString shbapp.settings.Port})

    if ${if hasSSL then "True" else "False"}:
        server.copy_from_vm("/etc/ssl/certs/ca-certificates.crt")
        client.succeed("rm -r /etc/ssl/certs")
        client.copy_from_host(str(pathlib.Path(os.environ.get("out", os.getcwd())) / "ca-certificates.crt"), "/etc/ssl/certs/ca-certificates.crt")

    def curl(target, format, endpoint, succeed=True):
        return json.loads(target.succeed(
            "curl -X GET --fail-with-body --silent --show-error --output /dev/null --location"
            + " --connect-to ${appname}.example.com:443:server:443"
            + " --connect-to ${appname}.example.com:80:server:80"
            + f" --write-out '{format}'"
            + " " + endpoint
        ))

    with subtest("health"):
        response = curl(client, """{"code":%{response_code}}""", "${fqdn}/health")

        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")

    with subtest("login"):
        response = curl(client, """{"code":%{response_code}}""", "${fqdn}/UI/Login")

        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")
    '';

  basic = appname: pkgs.nixosTest {
    name = "arr-${appname}-basic";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        {
          options = {
            shb.backup = lib.mkOption { type = lib.types.anything; };
          };
        }
        ../../modules/blocks/authelia.nix
        ../../modules/blocks/postgresql.nix
        ../../modules/blocks/nginx.nix
        ../../modules/services/arr.nix
      ];

      shb.arr.${appname} = {
        enable = true;
        domain = "example.com";
        subdomain = appname;

        settings.APIKey.source = pkgs.writeText "APIKey" "01234567890123456789"; # Needs to be >=20 characters.
      };
      # Nginx port.
      networking.firewall.allowedTCPPorts = [ 80 ];
    };

    nodes.client = {};

    testScript = commonTestScript appname;
  };
in
{
  radarr_basic = basic "radarr";
  sonarr_basic = basic "sonarr";
  bazarr_basic = basic "bazarr";
  readarr_basic = basic "readarr";
  lidarr_basic = basic "lidarr";
  jackett_basic = basic "jackett";
}
