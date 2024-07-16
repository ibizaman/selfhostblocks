{ pkgs, lib, ... }:
let
  pkgs' = pkgs;
  adminUser = "root";
  adminPass = "rootpw";

  subdomain = "n";
  domain = "example.com";
  fqdn = "${subdomain}.${domain}";

  testLib = pkgs.callPackage ../common.nix {};

  commonTestScript = lib.makeOverridable testLib.accessScript {
    inherit subdomain domain;
    hasSSL = { node, ... }: !(isNull node.config.shb.nextcloud.ssl);
    waitForServices = { ... }: [
      "phpfpm-nextcloud.service"
      "nginx.service"
    ];
    waitForUnixSocket = { node, ... }: [
      node.config.services.phpfpm.pools.nextcloud.socket
    ];
    extraScript = { node, proto_fqdn, ... }: ''
    import time

    def find_in_logs(unit, text):
        return server.systemctl("status {}".format(unit))[1].find(text) != -1

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
  };

  base = testLib.base pkgs' [
    ../../modules/services/nextcloud-server.nix
  ];

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

  ldap = { config, ... }: {
    shb.nextcloud = {
      apps.ldap = {
        enable = true;
        host = "127.0.0.1";
        port = config.shb.ldap.ldapPort;
        dcdomain = config.shb.ldap.dcdomain;
        adminName = "admin";
        adminPasswordFile = config.shb.ldap.ldapUserPasswordFile;
        userGroup = "nextcloud_user";
      };
    };
  };

  sso = { config, ... }:
    let
      authSecret = pkgs.writeText "authSecret" "authSecret";
    in
      {
        shb.nextcloud = {
          apps.sso = {
            enable = true;
            endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
            clientID = "nextcloud";
            # adminUserGroup = "nextcloud_admin";

            secretFile = authSecret;
            secretFileForAuthelia = authSecret;

            fallbackDefaultAuth = false;
          };
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
    name = "nextcloud_basic";

    nodes.server = {
      imports = [
        base
        basic
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  https = pkgs.testers.runNixOSTest {
    name = "nextcloud_https";

    nodes.server = {
      imports = [
        base
        (testLib.certs domain)
        basic
        https
      ];
    };

    nodes.client = {};

    # TODO: Test login
    testScript = commonTestScript;
  };

  previewGenerator = pkgs.testers.runNixOSTest {
    name = "nextcloud_previewGenerator";

    nodes.server = {
      imports = [
        base
        (testLib.certs domain)
        basic
        https
        previewgenerator
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  externalStorage = pkgs.testers.runNixOSTest {
    name = "nextcloud_externalStorage";

    nodes.server = {
      imports = [
        base
        (testLib.certs domain)
        basic
        https
        externalstorage
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  ldap = pkgs.testers.runNixOSTest {
    name = "nextcloud_ldap";
  
    nodes.server = { config, ... }: {
      imports = [
        base
        (testLib.certs domain)
        basic
        https
        (testLib.ldap domain pkgs')
        ldap
      ];
    };
  
    nodes.client = {};
  
    testScript = commonTestScript;
  };

  sso = pkgs.testers.runNixOSTest {
    name = "nextcloud_sso";
  
    nodes.server = { config, ... }: {
      imports = [
        base
        (testLib.certs domain)
        basic
        https
        (testLib.ldap domain pkgs')
        ldap
        (testLib.sso domain pkgs' config.shb.certs.certs.selfsigned.n)
        sso
      ];
    };
  
    nodes.client = {};
  
    testScript = commonTestScript;
  };
}
