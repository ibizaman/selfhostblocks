{ lib, ... }:
let
  oidcSecret = "oidcSecret";

  commonTestScript = lib.shb.mkScripts {
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
      lib.shb.baseModule
      ../../modules/blocks/hardcodedsecret.nix
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
      lib.shb.baseModule
      lib.shb.clientLoginModule
    ];
    virtualisation.memorySize = 4096;
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
            "expect(page.get_by_text('unauthorized')).to_be_visible()"
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
  basic = lib.shb.runNixOSTest {
    name = "open-webui_basic";

    nodes.client = {};
    nodes.server = {
      imports = [
        basic
      ];
    };

    testScript = commonTestScript.access;
  };

  backup = lib.shb.runNixOSTest {
    name = "open-webui_backup";

    nodes.server = { config, ... }: {
      imports = [
        basic
        (lib.shb.backup config.shb.open-webui.backup)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.backup;
  };

  https = lib.shb.runNixOSTest {
    name = "open-webui_https";

    nodes.client = {};
    nodes.server = {
      imports = [
        basic
        lib.shb.certs
        https
      ];
    };

    testScript = commonTestScript.access;
  };

  sso = lib.shb.runNixOSTest {
    name = "open-webui_sso";

    nodes.client = {
      imports = [
        clientLoginSso
      ];
    };
    nodes.server = { config, pkgs, ... }: {
      imports = [
        basic
        lib.shb.certs
        https
        lib.shb.ldap
        ldap
        (lib.shb.sso config.shb.certs.certs.selfsigned.n)
        sso
      ];
    };

    testScript = commonTestScript.access;
  };
}
