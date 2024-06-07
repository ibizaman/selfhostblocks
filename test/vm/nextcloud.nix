{ pkgs, lib, ... }:
let
  pkgs' = pkgs;
  adminUser = "root";
  adminPass = "rootpw";

  subdomain = "n";
  domain = "example.com";
  fqdn = "${subdomain}.${domain}";

  commonTestScript = { nodes, ... }:
    let
      hasSSL = !(isNull nodes.server.shb.nextcloud.ssl);
      proto_fqdn = if hasSSL then "https://${fqdn}" else "http://${fqdn}";
    in
    ''
    import json
    import os
    import pathlib
    import time

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
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + f" --write-out '{format}'"
            + " " + endpoint
        ))

    with subtest("access"):
        response = curl(client, """{"code":%{response_code}}""", "${proto_fqdn}")

        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")

    with subtest("cron job succeeds"):
        # This calls blocks until the service is done.
        server.systemctl("start nextcloud-cron.service")

        # If the service failed, then we're not happy.
        status = "active"
        while status == "active":
            status = server.get_unit_info("nextcloud-cron")["ActiveState"]
            time.sleep(5)
        if status != "inactive":
            raise Exception("Cron job did not finish correctly")

        if not find_in_logs("nextcloud-cron", "nextcloud-cron.service: Deactivated successfully."):
            raise Exception("Nextcloud cron job did not finish successfully.")

    with subtest("fails with incorrect authentication"):
        client.fail(
            "curl -f -s --location -X PROPFIND"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:other """
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + " ${proto_fqdn}/remote.php/dav/files/${adminUser}/"
        )

        client.fail(
            "curl -f -s --location -X PROPFIND"
            + """ -H "Depth: 1" """
            + """ -u root:rootpw """
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + " ${proto_fqdn}/remote.php/dav/files/other/"
        )

    with subtest("fails with incorrect path"):
        client.fail(
            "curl -f -s --location -X PROPFIND"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + " ${proto_fqdn}/remote.php/dav/files/other/"
        )

    with subtest("can access webdav"):
        client.succeed(
            "curl -f -s --location -X PROPFIND"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + " ${proto_fqdn}/remote.php/dav/files/${adminUser}/"
        )

    with subtest("can create and retrieve file"):
        client.fail(
            "curl -f -s --location -X GET"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + """ -T file """
            + " ${proto_fqdn}/remote.php/dav/files/${adminUser}/file"
        )
        client.succeed("echo 'hello' > file")
        client.succeed(
            "curl -f -s --location -X PUT"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + """ -T file """
            + " ${proto_fqdn}/remote.php/dav/files/${adminUser}/"
        )
        content = client.succeed(
            "curl -f -s --location -X GET"
            + """ -H "Depth: 1" """
            + """ -u ${adminUser}:${adminPass} """
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + """ -T file """
            + " ${proto_fqdn}/remote.php/dav/files/${adminUser}/file"
        )
        if content != "hello\n":
            raise Exception("Got incorrect content for file, expected 'hello\n' but got:\n{}".format(content))
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
      ../../modules/services/nextcloud-server.nix
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
    shb.nextcloud = {
      enable = true;
      inherit domain subdomain;
      dataDir = "/var/lib/nextcloud";
      tracing = null;
      defaultPhoneRegion = "US";

      # This option is only needed because we do not access Nextcloud at the default port in the VM.
      externalFqdn = "${fqdn}:8080";

      adminUser = adminUser;
      adminPassFile = pkgs.writeText "adminPassFile" adminPass;
      debug = true;
    };
  };

  https = { config, ...}: {
    shb.nextcloud = {
      ssl = config.shb.certs.certs.selfsigned.n;

      externalFqdn = lib.mkForce null;
    };
  };

  previewgenerator = { config, ...}: {
    systemd.tmpfiles.rules = [
      "d '/srv/nextcloud' 0750 nextcloud nextcloud - -"
    ];

    shb.nextcloud = {
      apps.previewgenerator.enable = true;
    };
  };

  externalstorage = {
    systemd.tmpfiles.rules = [
      "d '/srv/nextcloud' 0750 nextcloud nextcloud - -"
    ];

    shb.nextcloud = {
      apps.externalStorage = {
        enable = true;
        userLocalMount.directory = "/srv/nextcloud/$user";
        userLocalMount.mountName = "home";
      };
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "nextcloud-basic";

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
    name = "nextcloud-https";

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

    # TODO: Test login
    testScript = commonTestScript;
  };

  previewGenerator = pkgs.testers.runNixOSTest {
    name = "nextcloud-previewGenerator";

    nodes.server = lib.mkMerge [
      base
      certs
      basic
      https
      previewgenerator
      {
        options = {
          shb.authelia = lib.mkOption { type = lib.types.anything; };
        };
      }
    ];

    nodes.client = {};

    testScript = commonTestScript;
  };

  externalStorage = pkgs.testers.runNixOSTest {
    name = "nextcloud-externalStorage";

    nodes.server = lib.mkMerge [
      base
      certs
      basic
      https
      externalstorage
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
