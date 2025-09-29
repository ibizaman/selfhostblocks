{ pkgs, ... }:
let
  oidcSecret = "oidcSecret";

  testLib = pkgs.callPackage ../common.nix {};

  commonTestScript = testLib.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.open-webui.ssl);
    waitForServices = { ... }: [
      "open-webui.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      node.config.shb.open-webui.port
    ];
  };

  basic = { config, ... }: {
    imports = [
      testLib.baseModule
      ../../modules/blocks/hardcodedsecret.nix
      ../../modules/blocks/lldap.nix
      ../../modules/services/open-webui.nix
    ];

    test = {
      subdomain = "o";
    };

    shb.open-webui = {
      enable = true;
      inherit (config.test) subdomain domain;
    };

    networking.hosts = {
      "127.0.0.1" = [ "${config.test.subdomain}.${config.test.domain}" ];
    };
  };

  https = { config, ... }: {
    shb.open-webui = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };

    systemd.services.open-webui.environment = {
      # Needed for open-webui to be able to talk to auth server.
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    };
  };

  ldap = { config, ... }: {
    shb.open-webui = {
      ldap = {
        userGroup = "user_group";
        adminGroup = "admin_group";
      };
    };
  };

  clientLoginSso = { config, ... }: {
    imports = [
      testLib.baseModule
      testLib.clientLoginModule
    ];
    test = {
      subdomain = "o";
    };

    test.login = {
      startUrl = "https://${config.test.fqdn}/auth";
      beforeHook = ''
        page.get_by_role("button", name="continue").click()
      '';
      usernameFieldLabelRegex = "Username";
      passwordFieldLabelRegex = "Password";
      loginButtonNameRegex = "[sS]ign [iI]n";
      testLoginWith = [
        { username = "alice"; password = "NotAlicePassword"; nextPageExpect = [
            "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
          ]; }
        { username = "alice"; password = "AlicePassword"; nextPageExpect = [
            "page.get_by_role('button', name=re.compile('Accept')).click()"
            "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).not_to_be_visible()"
            "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
            "expect(page.get_by_text('logged in')).to_be_visible()"
          ]; }
        { username = "bob"; password = "NotBobPassword"; nextPageExpect = [
            "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
          ]; }
        { username = "bob"; password = "BobPassword"; nextPageExpect = [
            "page.get_by_role('button', name=re.compile('Accept')).click()"
            "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).not_to_be_visible()"
            "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
            "expect(page.get_by_text('logged in')).to_be_visible()"
          ]; }
        { username = "charlie"; password = "NotCharliePassword"; nextPageExpect = [
            "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
          ]; }
        { username = "charlie"; password = "CharliePassword"; nextPageExpect = [
            "page.get_by_role('button', name=re.compile('Accept')).click()"
            "expect(page.get_by_text('pending activation')).to_be_visible()"
          ]; }
      ];
    };
  };

  sso = { config, ... }: {
    shb.open-webui = {
      sso = {
        enable = true;
        authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        clientID = "open-webui";

        sharedSecret.result = config.shb.hardcodedsecret.oidcSecret.result;
        sharedSecretForAuthelia.result = config.shb.hardcodedsecret.oidcAutheliaSecret.result;
      };
    };

    shb.hardcodedsecret.oidcSecret = {
      request = config.shb.open-webui.sso.sharedSecret.request;
      settings.content = oidcSecret;
    };
    shb.hardcodedsecret.oidcAutheliaSecret = {
      request = config.shb.open-webui.sso.sharedSecretForAuthelia.request;
      settings.content = oidcSecret;
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "open-webui_basic";

    nodes.client = {};
    nodes.server = {
      imports = [
        basic
      ];
    };

    testScript = commonTestScript.access;
  };

  backup = pkgs.testers.runNixOSTest {
    name = "open-webui_backup";

    nodes.server = { config, ... }: {
      imports = [
        basic
        (testLib.backup config.shb.open-webui.backup)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.backup;
  };

  https = pkgs.testers.runNixOSTest {
    name = "open-webui_https";

    nodes.client = {};
    nodes.server = {
      imports = [
        basic
        testLib.certs
        https
      ];
    };

    testScript = commonTestScript.access;
  };

  sso = pkgs.testers.runNixOSTest {
    name = "open-webui_sso";
    interactive.sshBackdoor.enable = true;

    nodes.client = {
      imports = [
        clientLoginSso
      ];

      virtualisation.memorySize = 4096;
    };
    nodes.server = { config, pkgs, ... }: {
      imports = [
        basic
        testLib.certs
        https
        testLib.ldap
        ldap
        (testLib.sso config.shb.certs.certs.selfsigned.n)
        sso
      ];

      virtualisation.memorySize = 4096;
    };

    testScript = commonTestScript.access;
  };
}
