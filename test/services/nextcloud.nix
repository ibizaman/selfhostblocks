{ pkgs, lib, ... }:
let
  adminUser = "root";
  adminPass = "rootpw";
  oidcSecret = "oidcSecret";

  testLib = pkgs.callPackage ../common.nix {};

  commonTestScript = testLib.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.nextcloud.ssl);
    waitForServices = { ... }: [
      "phpfpm-nextcloud.service"
      "nginx.service"
    ];
    waitForUnixSocket = { node, ... }: [
      node.config.services.phpfpm.pools.nextcloud.socket
    ];
    extraScript = { node, fqdn, proto_fqdn, ... }: ''
    import time

    def find_in_logs(unit, text):
        return server.systemctl("status {}".format(unit))[1].find(text) != -1

    with subtest("cron job starts"):
        # This call does not block until the service is done.
        server.succeed("systemctl start nextcloud-cron.service&")

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

    with subtest("cron job succeeds"):
        # If the service failed, then we're not happy.
        status = "active"
        while status == "active":
            status = server.get_unit_info("nextcloud-cron")["ActiveState"]
            time.sleep(5)
        if status != "inactive":
            raise Exception("Cron job did not finish correctly")

        if not find_in_logs("nextcloud-cron", "nextcloud-cron.service: Deactivated successfully."):
            raise Exception("Nextcloud cron job did not finish successfully.")
    '';
  };

  basic = { config, ... }: {
    imports = [
      testLib.baseModule
      ../../modules/services/nextcloud-server.nix
    ];

    test = {
      subdomain = "n";
    };

    shb.nextcloud = {
      enable = true;
      inherit (config.test) subdomain domain;

      dataDir = "/var/lib/nextcloud";
      tracing = null;
      defaultPhoneRegion = "US";

      # This option is only needed because we do not access Nextcloud at the default port in the VM.
      externalFqdn = "${config.test.fqdn}:8080";

      adminUser = adminUser;
      adminPass.result = config.shb.hardcodedsecret.adminPass.result;
      debug = true;
    };

    shb.hardcodedsecret.adminPass = {
      request = config.shb.nextcloud.adminPass.request;
      settings.content = adminPass;
    };
  };

  clientLogin = { config, ... }: {
    imports = [
      testLib.baseModule
      testLib.clientLoginModule
    ];
    virtualisation.memorySize = 4096;

    test = {
      subdomain = "n";
    };

    test.login = {
      startUrl = "http://${config.test.fqdn}";
      usernameFieldLabelRegex = "[Ee]mail";
      passwordFieldLabelRegex = "^ *[Pp]assword";
      loginButtonNameRegex = "[Ll]og [Ii]n";
      testLoginWith = [
        { username = adminUser; password = adminPass; nextPageExpect = [
            "expect(page.get_by_text('Wrong login or password')).not_to_be_visible()"
            "expect(page.get_by_role('button', name=re.compile('[Ll]og [Ii]n'))).not_to_be_visible()"
            "expect(page).to_have_title(re.compile('Dashboard'))"
          ]; }
        # Failure is after so we're not throttled too much.
        { username = adminUser; password = adminPass + "oops"; nextPageExpect = [
            "expect(page.get_by_text('Wrong login or password')).to_be_visible()"
          ]; }
      ];
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
        adminPassword.result = config.shb.hardcodedsecret.nextcloudLdapUserPassword.result;
        userGroup = "nextcloud_user";
      };
    };
    shb.hardcodedsecret.nextcloudLdapUserPassword = {
      request = config.shb.nextcloud.apps.ldap.adminPassword.request;
      settings = config.shb.hardcodedsecret.ldapUserPassword.settings;
    };
  };

  sso = { config, ... }:
    {
      shb.nextcloud = {
        apps.sso = {
          enable = true;
          endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
          clientID = "nextcloud";
          # adminUserGroup = "nextcloud_admin";

          secret.result = config.shb.hardcodedsecret.oidcSecret.result;
          secretForAuthelia.result = config.shb.hardcodedsecret.oidcAutheliaSecret.result;

          fallbackDefaultAuth = false;
        };
      };

      shb.hardcodedsecret.oidcSecret = {
        request = config.shb.nextcloud.apps.sso.secret.request;
        settings.content = oidcSecret;
      };
      shb.hardcodedsecret.oidcAutheliaSecret = {
        request = config.shb.nextcloud.apps.sso.secretForAuthelia.request;
        settings.content = oidcSecret;
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

  memories = { config, ...}: {
    systemd.tmpfiles.rules = [
      "d '/srv/nextcloud' 0750 nextcloud nextcloud - -"
    ];

    shb.nextcloud = {
      apps.memories.enable = true;
      apps.memories.vaapi = true;
    };
  };

  recognize = { config, ...}: {
    systemd.tmpfiles.rules = [
      "d '/srv/nextcloud' 0750 nextcloud nextcloud - -"
    ];

    shb.nextcloud = {
      apps.recognize.enable = true;
    };
  };

  prometheus = { config, ... }: {
    shb.nextcloud = {
      phpFpmPrometheusExporter.enable = true;
    };
  };

  prometheusTestScript = { nodes, ... }:
    ''
    server.wait_for_open_unix_socket("${nodes.server.services.phpfpm.pools.nextcloud.socket}")
    server.wait_for_open_port(${toString nodes.server.services.prometheus.exporters.php-fpm.port})
    with subtest("prometheus"):
        response = server.succeed(
            "curl -sSf "
            + " http://localhost:${toString nodes.server.services.prometheus.exporters.php-fpm.port}/metrics"
        )
        print(response)
    '';
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "nextcloud_basic";

    nodes.client = {
      imports = [
        clientLogin
      ];
    };
    nodes.server = {
      imports = [
        basic
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  backup = pkgs.testers.runNixOSTest {
    name = "nextcloud_backup";

    nodes.server = { config, ... }: {
      imports = [
        basic
        (testLib.backup config.shb.nextcloud.backup)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.backup;
  };

  https = pkgs.testers.runNixOSTest {
    name = "nextcloud_https";

    nodes.server = {
      imports = [
        basic
        testLib.certs
        https
      ];
    };

    nodes.client = {};

    # TODO: Test login
    testScript = commonTestScript.access;
  };

  previewGenerator = pkgs.testers.runNixOSTest {
    name = "nextcloud_previewGenerator";

    nodes.server = {
      imports = [
        basic
        testLib.certs
        https
        previewgenerator
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  externalStorage = pkgs.testers.runNixOSTest {
    name = "nextcloud_externalStorage";

    nodes.server = {
      imports = [
        basic
        testLib.certs
        https
        externalstorage
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  # TODO: fix memories app
  # See https://github.com/ibizaman/selfhostblocks/issues/476

  # memories = pkgs.testers.runNixOSTest {
  #   name = "nextcloud_memories";

  #   nodes.server = {
  #     imports = [
  #       basic
  #       testLib.certs
  #       https
  #       memories
  #     ];
  #   };

  #   nodes.client = {};

  #   testScript = commonTestScript.access;
  # };

  recognize = pkgs.testers.runNixOSTest {
    name = "nextcloud_recognize";

    nodes.server = {
      imports = [
        basic
        testLib.certs
        https
        recognize
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  ldap = pkgs.testers.runNixOSTest {
    name = "nextcloud_ldap";
  
    nodes.server = { config, ... }: {
      imports = [
        basic
        testLib.certs
        https
        testLib.ldap
        ldap
      ];
    };
  
    nodes.client = {};
  
    testScript = commonTestScript.access;
  };

  sso = pkgs.testers.runNixOSTest {
    name = "nextcloud_sso";
  
    nodes.server = { config, ... }: {
      imports = [
        basic
        testLib.certs
        https
        testLib.ldap
        ldap
        (testLib.sso config.shb.certs.certs.selfsigned.n)
        sso
      ];
    };
  
    nodes.client = {};
  
    testScript = commonTestScript.access;
  };

  prometheus = pkgs.testers.runNixOSTest {
    name = "nextcloud_prometheus";

    nodes.server = { config, ... }: {
      imports = [
        basic
        prometheus
      ];
    };

    nodes.client = {};

    testScript = prometheusTestScript;
  };
}
