{ pkgs, ... }:
let
  testLib = pkgs.callPackage ../common.nix {};

  port = 9096;

  commonTestScript = testLib.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.jellyfin.ssl);
    waitForServices = { ... }: [
      "jellyfin.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      port
    ];
    waitForUrls = { proto_fqdn, ... }: [
      "${proto_fqdn}/System/Info/Public"
    ];
    extraScript = { node, ... }: ''
      headers = unline_with(" ", """
          -H 'Content-Type: application/json'
          -H 'Authorization: MediaBrowser Client="Android TV", Device="Nvidia Shield", DeviceId="ZQ9YQHHrUzk24vV", Version="0.15.3"'
      """)
      with subtest("api login success"):
          response = curl(client, """{"code":%{response_code}}""", "${node.config.test.proto_fqdn}/Users/AuthenticateByName",
              data="""{"Username": "jellyfin", "Pw": "admin"}""",
              extra=headers)
          if response['code'] != 200:
              raise Exception(f"Expected success, got: {response['code']}")

      with subtest("api login failure"):
          response = curl(client, """{"code":%{response_code}}""", "${node.config.test.proto_fqdn}/Users/AuthenticateByName",
              data="""{"Username": "jellyfin", "Pw": "badpassword"}""",
              extra=headers)
          if response['code'] != 401:
              raise Exception(f"Expected failure, got: {response['code']}")
    '';
  };

  basic = { config, ... }: {
    imports = [
      testLib.baseModule
      ../../modules/services/jellyfin.nix
    ];
    test = {
      subdomain = "j";
    };

    shb.jellyfin = {
      enable = true;
      inherit (config.test) subdomain domain;
      inherit port;
      admin = {
        username = "jellyfin";
        password.result = config.shb.hardcodedsecret.jellyfinAdminPassword.result;
      };
      debug = true;
    };

    shb.hardcodedsecret.jellyfinAdminPassword = {
      request = config.shb.jellyfin.admin.password.request;
      settings.content = "admin";
    };

    environment.systemPackages = [
      pkgs.sqlite
    ];
  };

  clientLogin = { config, ... }: {
    imports = [
      testLib.clientLoginModule
    ];
    virtualisation.memorySize = 4096;

    test = {
      subdomain = "j";
    };

    test.login = {
      browser = "firefox";
      # I tried without the path part but it randomly selects either the wizard
      # or the page that selects a server.
      # startUrl = "${config.test.proto}://${config.test.fqdn}/web/#/wizardstart.html";
      # startUrl = "${config.test.proto}://${config.test.fqdn}";
      startUrl = "${config.test.proto}://${config.test.fqdn}/web/#/login.html";
      usernameFieldLabelRegex = "[Uu]ser";
      loginButtonNameRegex = "Sign In";
      testLoginWith = [
        # I just couldn't make this work. It's very flaky.
        # Most of the time, the login jellyfin page doesn't even load
        # and the playwright browser is stuck on the splash page.
        # I resorted to test the API directly.
        # { username = "jellyfin"; password = "badpassword"; nextPageExpect = [
        #     "expect(page).to_have_title(re.compile('Jellyfin'))"
        #     "expect(page.get_by_text(re.compile('[Ii]nvalid'))).to_be_visible(timeout=30000)"
        #   ]; }
        # { username = "jellyfin"; password = "admin"; nextPageExpect = [
        #     "expect(page).to_have_title(re.compile('Jellyfin'))"
        #     "expect(page.get_by_text(re.compile('[Ii]nvalid'))).not_to_be_visible(timeout=30000)"
        #     "expect(page.get_by_role('label', re.compile('[Uu]ser'))).not_to_be_visible(timeout=30000)"
        #     "expect(page.get_by_text(re.compile('[Pp]assword'))).not_to_be_visible(timeout=30000)"
        #   ]; }
      ];
    };
  };

  https = { config, ... }: {
    shb.jellyfin = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
    test = {
      hasSSL = true;
    };
  };

  ldap = { config, ... }: {
    shb.jellyfin = {
      ldap = {
        enable = true;
        host = "127.0.0.1";
        port = config.shb.lldap.ldapPort;
        dcdomain = config.shb.lldap.dcdomain;
        adminPassword.result = config.shb.hardcodedsecret.jellyfinLdapUserPassword.result;
      };
    };

    shb.hardcodedsecret.jellyfinLdapUserPassword = {
      request = config.shb.jellyfin.ldap.adminPassword.request;
      settings.content = "ldapUserPassword";
    };
  };

  sso = { config, ... }: {
    shb.jellyfin = {
      sso = {
        enable = true;
        endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        sharedSecret.result = config.shb.hardcodedsecret.jellyfinSSOPassword.result;
        sharedSecretForAuthelia.result = config.shb.hardcodedsecret.jellyfinSSOPasswordAuthelia.result;
      };
    };

    shb.hardcodedsecret.jellyfinSSOPassword = {
      request = config.shb.jellyfin.sso.sharedSecret.request;
      settings.content = "ssoPassword";
    };

    shb.hardcodedsecret.jellyfinSSOPasswordAuthelia = {
      request = config.shb.jellyfin.sso.sharedSecretForAuthelia.request;
      settings.content = "ssoPassword";
    };
  };

  jellyfinTest = name: { nodes, testScript }: pkgs.testers.runNixOSTest {
    name = "jellyfin_${name}";

    interactive.sshBackdoor.enable = true;
    interactive.nodes.server = {
      environment.systemPackages = [
        pkgs.sqlite
      ];
    };

    inherit nodes;
    inherit testScript;
  };
in
{
  basic = jellyfinTest "basic" {
    nodes.server = {
      imports = [
        basic
        clientLogin
      ];
    };

    # Client login does not work without SSL.
    # At least, I couldn't make it work.
    nodes.client = {};

    testScript = commonTestScript.access;
  };

  backup = jellyfinTest "backup" {
    nodes.server = { config, ... }: {
      imports = [
        basic
        (testLib.backup config.shb.jellyfin.backup)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.backup;
  };

  https = jellyfinTest "https" {
    nodes.server = {
      imports = [
        basic
        testLib.certs
        https
      ];
    };

    nodes.client = { config, lib, ... }: {
      imports = [
        testLib.baseModule
        clientLogin
      ];
    };

    testScript = commonTestScript.access;
  };

  ldap = jellyfinTest "ldap" {
    nodes.server = {
      imports = [
        basic
        testLib.ldap
        ldap
      ];
    };
  
    nodes.client = {};
  
    testScript = commonTestScript.access;
  };

  sso = jellyfinTest "sso" {
    nodes.server = { config, pkgs, ... }: {
      imports = [
        basic
        testLib.certs
        https
        testLib.ldap
        (testLib.sso config.shb.certs.certs.selfsigned.n)
        sso
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };
}
