{ pkgs, lib, ... }:
let
  pkgs' = pkgs;
  adminUser = "root";
  adminPass = "rootpw";

  commonTestScript = { nodes, ... }:
    let
      hasSSL = !(isNull nodes.server.shb.nextcloud.ssl);
      fqdn = if hasSSL then "https://n.example.com" else "http://n.example.com";
    in
    ''
    import json
    import os
    import pathlib

    start_all()
    server.wait_for_unit("phpfpm-nextcloud.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_open_unix_socket("${nodes.server.services.phpfpm.pools.nextcloud.socket}")

    if ${if hasSSL then "True" else "False"}:
        server.copy_from_vm("/etc/ssl/certs/ca-certificates.crt")
        client.succeed("rm -r /etc/ssl/certs")
        client.copy_from_host(str(pathlib.Path(os.environ.get("out", os.getcwd())) / "ca-certificates.crt"), "/etc/ssl/certs/ca-certificates.crt")

    def find_in_logs(unit, text):
        return server.systemctl("status {}".format(unit))[1].find(text) != -1

    def curl(target, format, endpoint, succeed=True):
        return json.loads(target.succeed(
            "curl --fail-with-body --silent --show-error --output /dev/null --location"
            + " --connect-to n.example.com:443:server:443"
            + " --connect-to n.example.com:80:server:80"
            + f" --write-out '{format}'"
            + " " + endpoint
        ))

    with subtest("access"):
        response = curl(client, """{"code":%{response_code}}""", "${fqdn}")

        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")

    with subtest("cron job succeeds"):
        # This calls blocks until the service is done.
        server.systemctl("start nextcloud-cron.service")

        # If the service failed, then we're not happy.
        server.require_unit_state("nextcloud-cron", "inactive")

        if not find_in_logs("nextcloud-cron", "nextcloud-cron.service: Deactivated successfully."):
            raise Exception("Nextcloud cron job did not finish successfully.")

    with subtest("fails with incorrect authentication"):
        client.fail(
            "curl -f -s --location -X PROPFIND"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:other """
            + " --connect-to n.example.com:443:server:443"
            + " --connect-to n.example.com:80:server:80"
            + " ${fqdn}/remote.php/dav/files/${adminUser}/"
        )

        client.fail(
            "curl -f -s --location -X PROPFIND"
            + """ -H "Depth: 1" """
            + """ -u root:rootpw """
            + " --connect-to n.example.com:443:server:443"
            + " --connect-to n.example.com:80:server:80"
            + " ${fqdn}/remote.php/dav/files/other/"
        )

    with subtest("fails with incorrect path"):
        client.fail(
            "curl -f -s --location -X PROPFIND"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + " --connect-to n.example.com:443:server:443"
            + " --connect-to n.example.com:80:server:80"
            + " ${fqdn}/remote.php/dav/files/other/"
        )

    with subtest("can access webdav"):
        client.succeed(
            "curl -f -s --location -X PROPFIND"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + " --connect-to n.example.com:443:server:443"
            + " --connect-to n.example.com:80:server:80"
            + " ${fqdn}/remote.php/dav/files/${adminUser}/"
        )

    with subtest("can create and retrieve file"):
        client.fail(
            "curl -f -s --location -X GET"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + " --connect-to n.example.com:443:server:443"
            + " --connect-to n.example.com:80:server:80"
            + """ -T file """
            + " ${fqdn}/remote.php/dav/files/${adminUser}/file"
        )
        client.succeed("echo 'hello' > file")
        client.succeed(
            "curl -f -s --location -X PUT"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + " --connect-to n.example.com:443:server:443"
            + " --connect-to n.example.com:80:server:80"
            + """ -T file """
            + " ${fqdn}/remote.php/dav/files/${adminUser}/"
        )
        content = client.succeed(
            "curl -f -s --location -X GET"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + " --connect-to n.example.com:443:server:443"
            + " --connect-to n.example.com:80:server:80"
            + """ -T file """
            + " ${fqdn}/remote.php/dav/files/${adminUser}/file"
        )
        if content != "hello\n":
            raise Exception("Got incorrect content for file, expected 'hello\n' but got:\n{}".format(content))
    '';
in
{
  basic = pkgs.nixosTest {
    name = "nextcloud-basic";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        (pkgs'.path + "/nixos/modules/profiles/minimal.nix")
        (pkgs'.path + "/nixos/modules/profiles/headless.nix")
        (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
        {
          options = {
            shb.backup = lib.mkOption { type = lib.types.anything; };
            shb.authelia = lib.mkOption { type = lib.types.anything; };
          };
        }
        ../../modules/services/nextcloud-server.nix
      ];

      shb.nextcloud = {
        enable = true;
        domain = "example.com";
        subdomain = "n";
        dataDir = "/var/lib/nextcloud";
        tracing = null;
        defaultPhoneRegion = "US";

        # This option is only needed because we do not access Nextcloud at the default port in the VM.
        externalFqdn = "n.example.com:8080";

        adminUser = adminUser;
        adminPassFile = pkgs.writeText "adminPassFile" adminPass;
        debug = true;
      };
      # Nginx port.
      networking.firewall.allowedTCPPorts = [ 80 ];
      # VM needs a bit more memory than default.
      virtualisation.memorySize = 4096;
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  cert = pkgs.nixosTest {
    name = "nextcloud-cert";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        (pkgs'.path + "/nixos/modules/profiles/minimal.nix")
        (pkgs'.path + "/nixos/modules/profiles/headless.nix")
        (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
        {
          options = {
            shb.backup = lib.mkOption { type = lib.types.anything; };
            shb.authelia = lib.mkOption { type = lib.types.anything; };
          };
        }
        ../../modules/blocks/nginx.nix
        # ../../modules/blocks/postgresql.nix
        ../../modules/blocks/ssl.nix
        ../../modules/services/nextcloud-server.nix
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

      shb.nextcloud = {
        enable = true;
        domain = "example.com";
        subdomain = "n";
        dataDir = "/var/lib/nextcloud";
        tracing = null;
        defaultPhoneRegion = "US";

        ssl = config.shb.certs.certs.selfsigned.n;

        # This option is only needed because we do not access Nextcloud at the default port in the VM.
        externalFqdn = "n.example.com:8080";

        adminUser = adminUser;
        adminPassFile = pkgs.writeText "adminPassFile" adminPass;
        debug = true;
      };
      # Nginx port.
      networking.firewall.allowedTCPPorts = [ 80 443 ];

      shb.nginx.accessLog = true;
    };

    nodes.client = {};

    # TODO: Test login
    testScript = commonTestScript;
  };
}
