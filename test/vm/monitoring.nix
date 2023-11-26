{ pkgs, lib, ... }:
{
  # This test, although simple, makes sure all provisioning went fine.
  auth = pkgs.nixosTest {
    name = "monitoring-basic";

    nodes.machine = { config, pkgs, ... }: {
      imports = [
        {
          options = {
            shb.ssl.enable = lib.mkEnableOption "ssl";
          };
        }
        ../../modules/blocks/postgresql.nix
        ../../modules/blocks/monitoring.nix
      ];

      shb.monitoring = {
        enable = true;
        subdomain = "grafana";
        domain = "example.com";
        grafanaPort = 3000;
        adminPasswordFile = pkgs.writeText "admin_password" "securepw";
        secretKeyFile = pkgs.writeText "secret_key" "secret_key";
      };
    };

    testScript = { nodes, ... }: ''
    start_all()
    machine.wait_for_unit("grafana.service")

    def curl_req(password, wantStatus, endpoint):
        response = machine.wait_until_succeeds("curl -i http://admin:{password}@localhost:3000{endpoint}".format(password=password, endpoint=endpoint), timeout=10)
        if not response.startswith("HTTP/1.1 {wantStatus}".format(wantStatus=wantStatus)):
            raise Exception("Wrong status, expected {}, got {}".format(wantStatus, response[9:12]))
        return response

    curl_req("securepw", 200, "/api/org")
    curl_req("wrong", 401, "/api/org")
    '';
  };
}
