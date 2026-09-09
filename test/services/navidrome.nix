{
  pkgs,
  lib,
  shb,
  ...
}:
let
  subdomain = "m";
  domain = "example.com";

  commonTestScript = shb.test.accessScript {
    hasSSL = { node, ... }: !(isNull node.config.shb.navidrome.ssl);
    waitForServices =
      { ... }:
      [
        "navidrome.service"
        "nginx.service"
      ];
    waitForPorts =
      { ... }:
      [
        4533
        80
      ];
    waitForUrls = { proto_fqdn, ... }: [ "${proto_fqdn}" ];
  };

  base =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        ../../modules/services/navidrome.nix
      ];

      test = {
        inherit subdomain domain;
      };

      shb.navidrome = {
        enable = true;
        inherit subdomain domain;
      };

      environment.systemPackages = [ pkgs.curl ];
    };

  basic =
    { config, ... }:
    {
      imports = [ base ];
      test.hasSSL = false;
    };

  https =
    { config, ... }:
    {
      imports = [
        base
        shb.test.certs
      ];

      test.hasSSL = true;
      shb.navidrome.ssl = config.shb.certs.certs.selfsigned.n;
    };

  sso =
    { config, lib, ... }:
    {
      imports = [
        https
        shb.test.ldap
        (shb.test.sso config.shb.certs.certs.selfsigned.n)
      ];

      shb.navidrome.sso = {
        enable = true;
        endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
      };

      shb.lldap.ensureGroups.navidrome_user = { };

      shb.lldap.ensureUsers.alice = lib.mkForce {
        email = "alice@example.com";
        displayName = "Alice Alice";
        groups = [ "navidrome_user" ];
        password.result = config.shb.hardcodedsecret.alice.result;
      };
    };

  clientSso =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        shb.test.clientLoginModule
      ];

      test = {
        inherit subdomain domain;
        hasSSL = true;
      };

      test.login = {
        startUrl = "https://${config.test.fqdn}";
        passwordFieldSelector = ''get_by_role("textbox", name=re.compile('[Pp]assword'))'';
        loginButtonNameRegex = "[Ss]ign [Ii]n";
        testLoginWith = [
          {
            username = "alice";
            password = "NotAlicePassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
            ];
          }
          {
            username = "alice";
            password = "AlicePassword";
            nextPageExpect = [
              "expect(page).to_have_title(re.compile('Navidrome'))"
              "expect(page.get_by_role('button', name='Settings')).to_be_visible()"
            ];
          }
        ];
      };
    };
in
{
  basic = shb.test.runNixOSTest {
    name = "navidrome-basic";

    nodes.server = basic;
    nodes.client = { };

    testScript = commonTestScript;
  };

  https = shb.test.runNixOSTest {
    name = "navidrome-https";

    nodes.server = https;
    nodes.client = { };

    testScript = commonTestScript;
  };

  sso = shb.test.runNixOSTest {
    name = "navidrome-sso";

    nodes.server = sso;
    nodes.client = clientSso;

    testScript = commonTestScript;
  };
}
