{ pkgs, lib, ... }:
let
  commonTestScript = lib.shb.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.pinchflat.ssl);
    waitForServices = { ... }: [
      "pinchflat.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      node.config.shb.pinchflat.port
    ];
  };

  basic = { config, ... }: {
    imports = [
      lib.shb.baseModule
      ../../modules/blocks/hardcodedsecret.nix
      ../../modules/services/pinchflat.nix
    ];

    test = {
      subdomain = "p";
    };

    shb.pinchflat = {
      enable = true;
      inherit (config.test) subdomain domain;
      mediaDir = "/src/pinchflat";
      timeZone = "America/Los_Angeles";
      secretKeyBase.result = config.shb.hardcodedsecret.secretKeyBase.result;
    };

    systemd.tmpfiles.rules = [
      "d '/src/pinchflat' 0750 pinchflat pinchflat - -"
    ];

    # Needed for gitea-runner-local to be able to ping pinchflat.
    networking.hosts = {
      "127.0.0.1" = [ "${config.test.subdomain}.${config.test.domain}" ];
    };

    shb.hardcodedsecret.secretKeyBase = {
      request = config.shb.pinchflat.secretKeyBase.request;
      settings.content = pkgs.lib.strings.replicate 64 "Z";
    };
  };

  clientLogin = { config, ... }: {
    imports = [
      lib.shb.baseModule
      lib.shb.clientLoginModule
    ];
    test = {
      subdomain = "p";
    };

    test.login = {
      startUrl = "http://${config.test.fqdn}";
      # There is no login without SSO integration.
      testLoginWith = [
        { username = null; password = null; nextPageExpect = [
            "expect(page.get_by_text('Create a media profile')).to_be_visible()"
          ]; }
      ];
    };
  };

  https = { config, ... }: {
    shb.pinchflat = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  ldap = { config, ... }: {
    shb.pinchflat = {
      ldap = {
        enable = true;

        userGroup = "user_group";
      };
    };
  };

  clientLoginSso = { config, ... }: {
    imports = [
      lib.shb.baseModule
      lib.shb.clientLoginModule
    ];
    test = {
      subdomain = "p";
    };

    test.login = {
      startUrl = "https://${config.test.fqdn}";
      usernameFieldLabelRegex = "Username";
      passwordFieldLabelRegex = "Password";
      loginButtonNameRegex = "[sS]ign [iI]n";
      testLoginWith = [
        { username = "alice"; password = "NotAlicePassword"; nextPageExpect = [
            "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
          ]; }
        { username = "alice"; password = "AlicePassword"; nextPageExpect = [
            "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).not_to_be_visible()"
            "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
            "expect(page.get_by_text('Create a media profile')).to_be_visible()"
          ]; }
        { username = "bob"; password = "NotBobPassword"; nextPageExpect = [
            "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
          ]; }
        { username = "bob"; password = "BobPassword"; nextPageExpect = [
            "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).not_to_be_visible()"
            "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
            "expect(page.get_by_text('Create a media profile')).to_be_visible()"
          ]; }
        { username = "charlie"; password = "NotCharliePassword"; nextPageExpect = [
            "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
          ]; }
        { username = "charlie"; password = "CharliePassword"; nextPageExpect = [
            "expect(page).to_have_url(re.compile('.*/authenticated'))"
          ]; }
      ];
    };
  };

  sso = { config, ... }: {
    shb.pinchflat = {
      sso = {
        enable = true;
        authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
      };
    };
  };
in
{
  basic = lib.shb.runNixOSTest {
    name = "pinchflat_basic";

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

    testScript = commonTestScript.access;
  };

  backup = lib.shb.runNixOSTest {
    name = "pinchflat_backup";

    nodes.server = { config, ... }: {
      imports = [
        basic
        (lib.shb.backup config.shb.pinchflat.backup)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.backup;
  };

  https = lib.shb.runNixOSTest {
    name = "pinchflat_https";

    nodes.client = {
      imports = [
        clientLogin
      ];
    };
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
    name = "pinchflat_sso";

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

    testScript = commonTestScript.access.override {
      redirectSSO = true;
    };
  };
}
