{ pkgs, lib, ... }:
let
  adminUser = "root";
  adminPass = "rootpw";
  subdomain = "n";
  domain = "example.com";
  fqdn = "${subdomain}.${domain}";
in
{
  basic = pkgs.nixosTest {
    name = "nextcloud-basic";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        {
          options = {
            shb.ssl.enable = lib.mkEnableOption "ssl";
            shb.backup = lib.mkOption { type = lib.types.anything; };
            shb.authelia = lib.mkOption { type = lib.types.anything; };
          };
        }
        # ../../modules/blocks/authelia.nix
        # ../../modules/blocks/ldap.nix
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

    testScript = { nodes, ... }: ''
    start_all()
    server.wait_for_unit("phpfpm-nextcloud.service")
    server.wait_for_unit("nginx.service")

    def find_in_logs(unit, text):
        return server.systemctl("status {}".format(unit))[1].find(text) != -1

    with subtest("cron job succeeds"):
        # This calls blocks until the service is done.
        server.systemctl("start nextcloud-cron.service")

        # If the service failed, then we're not happy.
        server.require_unit_state("nextcloud-cron", "inactive")

        if not find_in_logs("nextcloud-cron", "nextcloud-cron.service: Deactivated successfully."):
            raise Exception("Nextcloud cron job did not finish successfully.")

    with subtest("fails with incorrect authentication"):
        client.fail(
            "curl -f -s -X PROPFIND"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:other """
            + """ -H "Host: ${fqdn}" """
            + " http://server/remote.php/dav/files/${adminUser}/"
        )

    with subtest("fails with incorrect path"):
        client.fail(
            "curl -f -s -X PROPFIND"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + """ -H "Host: ${fqdn}" """
            + " http://server/remote.php/dav/files/other/"
        )

    with subtest("can access webdav"):
        client.succeed(
            "curl -f -s -X PROPFIND"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + """ -H "Host: ${fqdn}" """
            + " http://server/remote.php/dav/files/${adminUser}/"
        )

    with subtest("can create and retrieve file"):
        client.fail(
            "curl -f -s -X GET"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + """ -H "Host: ${fqdn}" """
            + """ -T file """
            + " http://server/remote.php/dav/files/${adminUser}/file"
        )
        client.succeed("echo 'hello' > file")
        client.succeed(
            "curl -f -s -X PUT"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + """ -H "Host: ${fqdn}" """
            + """ -T file """
            + " http://server/remote.php/dav/files/${adminUser}/"
        )
        content = client.succeed(
            "curl -f -s -X GET"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + """ -H "Host: ${fqdn}" """
            + """ -T file """
            + " http://server/remote.php/dav/files/${adminUser}/file"
        )
        if content != "hello\n":
            raise Exception("Got incorrect content for file, expected 'hello\n' but got:\n{}".format(content))
    '';
  };
}
