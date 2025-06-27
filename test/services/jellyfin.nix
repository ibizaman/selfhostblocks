{ pkgs, ... }:
let
  testLib = pkgs.callPackage ../common.nix {};

  commonTestScript = testLib.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.jellyfin.ssl);
    waitForServices = { ... }: [
      "jellyfin.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      8096
    ];
    waitForUrls = { proto_fqdn, ... }: [
      "${proto_fqdn}/System/Info/Public"
    ];
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
    };
  };

  clientLogin = { config, ... }: {
    imports = [
      testLib.baseModule
      testLib.clientLoginModule
    ];
    virtualisation.memorySize = 4096;

    test = {
      subdomain = "j";
    };

    test.login = {
      # I tried without the path part but it randomly selects either the wizard
      # or the page that selects a server.
      # startUrl = "http://${config.test.fqdn}/web/#/wizardstart.html";
      startUrl = "http://${config.test.fqdn}";
      # startUrl = "http://127.0.0.1:8096";
      testLoginWith = [
        { nextPageExpect = [
            "expect(page.get_by_text(re.compile('Welcome to Jellyfin'))).to_be_visible(timeout=15_000)"
            "page.get_by_role('button', name=re.compile('Next')).click()"

            "expect(page.get_by_text('Tell us about yourself')).to_be_visible()"
            "page.get_by_label(re.compile('Username')).fill('Admin')"
            "page.get_by_label(re.compile('Password$')).fill('adminpassword')"
            "page.get_by_label(re.compile('Password ')).fill('adminpassword')"

            "expect(page.get_by_text('Set up your media libraries')).to_be_visible()"
            "page.get_by_role('button', name=re.compile('Next')).click()"

            "expect(page.get_by_text('Preferred Metadata Language')).to_be_visible()"
            "page.get_by_role('button', name=re.compile('Next')).click()"

            "expect(page.get_by_text('Set up Remote Access')).to_be_visible()"
            "page.get_by_role('button', name=re.compile('Next')).click()"

            "expect(page.get_by_text('You\'re Done!')).to_be_visible()"
            "page.get_by_role('button', name=re.compile('Finish')).click()"

            "expect(page.get_by_text('Please sign in')).to_be_visible()"
            "page.get_by_label(re.compile('User')).fill('Admin')"
            "page.get_by_label(re.compile('Password')).fill('adminpassword')"
            "page.get_by_role('button', name=re.compile('Sign In')).click()"

            "expect(page.get_by_text('Hello')).to_be_visible()"
          ]; }
        { username = "admin"; password = "admin"; nextPageExpect = [
            "expect(page.get_by_text('Invalid credentials, please try again')).not_to_be_visible()"
            "expect(page.get_by_role('button', name=re.compile('OK'))).not_to_be_visible()"
            "expect(page).to_have_title(re.compile('Grocy'))"
          ]; }
      ];
    };
  };

  https = { config, ... }: {
    shb.jellyfin = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  ldap = { config, ... }: {
    shb.jellyfin = {
      ldap = {
        enable = true;
        host = "127.0.0.1";
        port = config.shb.ldap.ldapPort;
        dcdomain = config.shb.ldap.dcdomain;
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
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "jellyfin_basic";

    interactive.sshBackdoor.enable = true;
    interactive.nodes.server = {
      environment.systemPackages = [
        pkgs.sqlite
      ];
    };

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

  backup = pkgs.testers.runNixOSTest {
    name = "jellyfin_backup";

    nodes.server = { config, ... }: {
      imports = [
        basic
        (testLib.backup config.shb.jellyfin.backup)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.backup;
  };

  https = pkgs.testers.runNixOSTest {
    name = "jellyfin_https";

    nodes.server = {
      imports = [
        basic
        testLib.certs
        https
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  ldap = pkgs.testers.runNixOSTest {
    name = "jellyfin_ldap";

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

  sso = pkgs.testers.runNixOSTest {
    name = "jellyfin_sso";

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
